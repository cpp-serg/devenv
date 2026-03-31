#!/bin/bash
set -euo pipefail

SUDO=$([ "$(id -u)" -ne 0 ] && echo "sudo" || echo "")
PREFIX="eth"

find_free_name() {
    local pfx="$1" n=0
    while [[ -e "/sys/class/net/${pfx}${n}" ]]; do
        ((n++))
    done
    printf "%s%d" "$pfx" "$n"
}

is_physical_nic() {
    local iface="$1"
    [[ "$iface" =~ ^(lo|tun|tap|veth|virbr|docker|br-|vnet|vpn|wg|dummy|bond|team) ]] && return 1
    ip link show "$iface" 2>/dev/null | grep -q 'link/ether' || return 1
    return 0
}

is_renamed() {
    local iface="$1"
    local syspath="/sys/class/net/$iface"
    # A NIC is NOT renamed if its current name matches any kernel predictable name
    local name
    for prop in ID_NET_NAME_PATH ID_NET_NAME_SLOT ID_NET_NAME_ONBOARD; do
        name=$(udevadm info "$syspath" 2>/dev/null | awk -F= "/^E: ${prop}=/{print \$2}")
        [[ "$name" == "$iface" ]] && return 1
    done
    # If none of the predictable names match, check if we can identify an original name
    local orig
    orig=$(get_original_name "$iface")
    [[ "$orig" != "unknown" && "$orig" != "$iface" ]]
}

get_original_name() {
    local iface="$1"
    local syspath="/sys/class/net/$iface"
    # udevadm can tell us the kernel's predictable name
    local orig
    orig=$(udevadm info "$syspath" 2>/dev/null | awk -F= '/ID_NET_NAME_PATH=/{print $2}')
    [[ -n "$orig" ]] && { printf "%s" "$orig"; return; }
    orig=$(udevadm info "$syspath" 2>/dev/null | awk -F= '/ID_NET_NAME_SLOT=/{print $2}')
    [[ -n "$orig" ]] && { printf "%s" "$orig"; return; }
    orig=$(udevadm info "$syspath" 2>/dev/null | awk -F= '/ID_NET_NAME_ONBOARD=/{print $2}')
    [[ -n "$orig" ]] && { printf "%s" "$orig"; return; }
    printf "unknown"
}

find_rename_source() {
    local mac="$1" iface="$2" sources=()
    # Check udev rules
    for f in /etc/udev/rules.d/*net*.rules /etc/udev/rules.d/*persistent*.rules; do
        [[ -f "$f" ]] && grep -qi "$mac\|$iface" "$f" 2>/dev/null && sources+=("$f")
    done
    # Check ifcfg
    local ifcfg="/etc/sysconfig/network-scripts/ifcfg-$iface"
    [[ -f "$ifcfg" ]] && sources+=("$ifcfg")
    # Check NetworkManager connection files
    for f in /etc/NetworkManager/system-connections/*; do
        [[ -f "$f" ]] && grep -qi "$iface" "$f" 2>/dev/null && sources+=("$f")
    done
    # Check systemd link files
    for f in /etc/systemd/network/*.link; do
        [[ -f "$f" ]] && grep -qi "$mac\|$iface" "$f" 2>/dev/null && sources+=("$f")
    done
    if [[ ${#sources[@]} -gt 0 ]]; then
        printf "%s" "${sources[*]}"
    else
        printf "unknown"
    fi
}

list_renamable() {
    printf "%-16s %-19s %s\n" "INTERFACE" "MAC" "IP"
    while IFS= read -r iface; do
        is_physical_nic "$iface" || continue
        is_renamed "$iface" && continue
        mac=$(ip link show "$iface" 2>/dev/null | awk '/link\/ether/ {print $2}')
        ip_addr=$(ip -4 addr show "$iface" 2>/dev/null | awk '/inet / {print $2}' | head -1)
        printf "%-16s %-19s %s\n" "$iface" "$mac" "${ip_addr:-none}"
    done < <(ls /sys/class/net/ 2>/dev/null | sort)
}

list_renamed() {
    printf "%-12s %-19s %-16s %-16s %s\n" "INTERFACE" "MAC" "IP" "ORIGINAL" "RENAMED BY"
    while IFS= read -r iface; do
        is_physical_nic "$iface" || continue
        is_renamed "$iface" || continue
        mac=$(ip link show "$iface" 2>/dev/null | awk '/link\/ether/ {print $2}')
        ip_addr=$(ip -4 addr show "$iface" 2>/dev/null | awk '/inet / {print $2}' | head -1)
        orig=$(get_original_name "$iface")
        source=$(find_rename_source "$mac" "$iface")
        printf "%-12s %-19s %-16s %-16s %s\n" "$iface" "$mac" "${ip_addr:-none}" "$orig" "$source"
    done < <(ls /sys/class/net/ 2>/dev/null | sort)
}

# Parse options
ACTION=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        -p|--prefix) PREFIX="$2"; shift 2 ;;
        -l|--list) ACTION="list"; shift ;;
        -L|--list-renamed) ACTION="list-renamed"; shift ;;
        -u|--unrename) ACTION="unrename"; shift ;;
        -h|--help) ACTION="help"; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

NEW_NAME=$(find_free_name "$PREFIX")

case "$ACTION" in
    list)
        list_renamable
        exit 0
        ;;
    list-renamed)
        list_renamed
        exit 0
        ;;
    unrename)
        # Check dialog is installed
        if ! command -v dialog &>/dev/null; then
            echo "ERROR: 'dialog' is not installed. Install it with: yum install dialog"
            exit 1
        fi

        # Build menu of renamed NICs
        declare -a UMENU=()
        while IFS= read -r iface; do
            is_physical_nic "$iface" || continue
            is_renamed "$iface" || continue
            mac=$(ip link show "$iface" 2>/dev/null | awk '/link\/ether/ {print $2}')
            orig=$(get_original_name "$iface")
            ip_addr=$(ip -4 addr show "$iface" 2>/dev/null | awk '/inet / {print $2}' | head -1)
            UMENU+=("$iface" "-> $orig  MAC: $mac  IP: ${ip_addr:-none}")
        done < <(ls /sys/class/net/ 2>/dev/null | sort)

        if [[ ${#UMENU[@]} -eq 0 ]]; then
            echo "No renamed NICs found."
            exit 1
        fi

        SEL=$(dialog --title "Select NIC to restore original name" \
            --menu "Choose the interface to unrename:" 15 70 8 \
            "${UMENU[@]}" 3>&1 1>&2 2>&3) || { echo "Cancelled."; exit 1; }
        clear

        MAC=$(ip link show "$SEL" 2>/dev/null | awk '/link\/ether/ {print $2}')
        ORIG=$(get_original_name "$SEL")
        if [[ "$ORIG" == "unknown" ]]; then
            echo "ERROR: Cannot determine original name for '$SEL'."
            exit 1
        fi

        echo "Restoring '$SEL' (MAC: $MAC) -> '$ORIG'"

        # 1. Remove/update udev rules
        for f in /etc/udev/rules.d/*net*.rules /etc/udev/rules.d/*persistent*.rules; do
            [[ -f "$f" ]] || continue
            if grep -qi "$MAC" "$f" 2>/dev/null; then
                # Remove lines matching this MAC
                $SUDO sed -i "/$MAC/Id" "$f"
                # Remove file if empty
                if [[ ! -s "$f" ]]; then
                    $SUDO rm -f "$f"
                    echo "Removed empty udev rule: $f"
                else
                    echo "Removed entry from udev rule: $f"
                fi
            fi
        done

        # 2. Update ifcfg file
        IFCFG="/etc/sysconfig/network-scripts/ifcfg-$SEL"
        IFCFG_ORIG="/etc/sysconfig/network-scripts/ifcfg-$ORIG"
        if [[ -f "$IFCFG" ]]; then
            $SUDO sed -i "s/DEVICE=$SEL/DEVICE=$ORIG/; s/NAME=$SEL/NAME=$ORIG/" "$IFCFG"
            $SUDO mv "$IFCFG" "$IFCFG_ORIG"
            echo "Restored ifcfg: $IFCFG -> $IFCFG_ORIG"
        fi

        # 3. Update NetworkManager connection
        UUID=$(nmcli -t -f UUID,DEVICE connection show 2>/dev/null | grep ":${SEL}$" | cut -d: -f1)
        if [[ -n "$UUID" ]]; then
            $SUDO nmcli connection modify "$UUID" connection.interface-name "$ORIG" connection.id "$ORIG"
            echo "Updated NetworkManager connection -> $ORIG"
        fi

        # 4. Remove systemd .link files
        for f in /etc/systemd/network/*.link; do
            [[ -f "$f" ]] || continue
            if grep -qi "$MAC" "$f" 2>/dev/null; then
                $SUDO rm -f "$f"
                echo "Removed systemd link file: $f"
            fi
        done

        echo "Done. Reboot to apply changes."
        exit 0
        ;;
    help)
        echo "Usage: $0 [OPTION]"
        echo "  -p, --prefix PREFIX  Name prefix (default: eth), new name will be <PREFIX>N"
        echo "  -l, --list           List renamable NICs"
        echo "  -L, --list-renamed   List already renamed NICs"
        echo "  -u, --unrename       Restore original name for a renamed NIC"
        echo "  -h, --help           Show this help"
        echo "  (no option)          Interactive rename dialog"
        exit 0
        ;;
esac

# Check dialog is installed
if ! command -v dialog &>/dev/null; then
    echo "ERROR: 'dialog' is not installed. Install it with: yum install dialog"
    exit 1
fi

# Build list of physical NICs for dialog menu
declare -a MENU_ITEMS=()
while IFS= read -r iface; do
    is_physical_nic "$iface" || continue
    is_renamed "$iface" && continue
    mac=$(ip link show "$iface" 2>/dev/null | awk '/link\/ether/ {print $2}')
    ip_addr=$(ip -4 addr show "$iface" 2>/dev/null | awk '/inet / {print $2}' | head -1)
    MENU_ITEMS+=("$iface" "MAC: $mac  IP: ${ip_addr:-none}")
done < <(ls /sys/class/net/ 2>/dev/null | sort)

if [[ ${#MENU_ITEMS[@]} -eq 0 ]]; then
    echo "No renameable physical NICs found."
    exit 1
fi

OLD_NAME=$(dialog --title "Select NIC to rename to $NEW_NAME" \
    --menu "Choose the interface to rename:" 15 60 8 \
    "${MENU_ITEMS[@]}" 3>&1 1>&2 2>&3) || { echo "Cancelled."; exit 1; }
clear

# Get MAC address
MAC=$(ip link show "$OLD_NAME" 2>/dev/null | awk '/link\/ether/ {print $2}')
if [[ -z "$MAC" ]]; then
    echo "ERROR: Interface '$OLD_NAME' not found."
    exit 1
fi

echo "Renaming '$OLD_NAME' (MAC: $MAC) -> '$NEW_NAME'"

# 1. Create udev rule
echo "SUBSYSTEM==\"net\", ACTION==\"add\", ATTR{address}==\"$MAC\", NAME=\"$NEW_NAME\"" \
    | $SUDO tee /etc/udev/rules.d/70-persistent-net.rules > /dev/null
echo "Created udev rule"

# 2. Update ifcfg file
IFCFG="/etc/sysconfig/network-scripts/ifcfg-$OLD_NAME"
IFCFG_NEW="/etc/sysconfig/network-scripts/ifcfg-$NEW_NAME"
if [[ -f "$IFCFG" ]]; then
    $SUDO sed -i "s/DEVICE=$OLD_NAME/DEVICE=$NEW_NAME/; s/NAME=$OLD_NAME/NAME=$NEW_NAME/" "$IFCFG"
    $SUDO mv "$IFCFG" "$IFCFG_NEW"
    echo "Updated ifcfg file"
fi

# 3. Update NetworkManager connection
UUID=$(nmcli -t -f UUID,DEVICE connection show | grep ":${OLD_NAME}$" | cut -d: -f1)
if [[ -n "$UUID" ]]; then
    $SUDO nmcli connection modify "$UUID" connection.interface-name "$NEW_NAME" connection.id "$NEW_NAME"
    echo "Updated NetworkManager connection"
fi

echo "Done. Reboot to apply changes."
