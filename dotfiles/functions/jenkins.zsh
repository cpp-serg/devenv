
MASTER_ROOT=job/pente-ggsn
MVNO_ROOT=view/%20%20%20%20%20MVNO%20Official%20Builds/job/pente-ggsn-MVNO
PATCHES_ROOT=view/%20%20%20%20%20Patch%20builds/job/pente-ggsn_patch
TAGS_ROOT=view/%20%20%20%20Dev%20Builds/job/pente-ggsn_tag

function jenk
{
    user='sergiy@pentenetworks.com'
    token='11555f916ea5a61c13f876455ea547f351'
    wget --auth-no-challenge  --user $user --password $token $*
}

function jenkapi
{
    jenk_serv=http://jenkinsil.jpu.io
    jenk -q -O - ${jenk_serv}/${1}/api/json | jq
}

function jtags
{
    jenkapi view/%20%20%20%20Dev%20Builds/job/pente-ggsn_tag | jq '.jobs[].url' | sed -nE 's/.*job\/([0-9][^/]+)\/"/\1/p' | tac
}

function jpatches
{
    #jenkapi $MASTER_ROOT 
    #'.builds[].url'
    #| sed -nE 's/.*job\/[^/]+\/([0-9]+)\/"/\1/p'
    #
}

function ccc
{
    delta $1 ~/ggsn/$1
}

