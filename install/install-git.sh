#!/bin/bash
source "$(dirname "$0")/_install_preambule.sh"

${SUDO} dnf install -y autoconf libcurl-devel openssl-devel expat-devel

GIT_VER=$(curl -fs --retry 3 --retry-delay 2 "https://api.github.com/repos/git/git/tags?per_page=10" | grep -oP '"name":\s*"v\K[0-9]+\.[0-9]+\.[0-9]+(?=")' | head -1)

if [ -z "$GIT_VER" ]; then
  echo "ERROR: Failed to detect latest git version" >&2
  exit 1
fi

echo "Detected git version: $GIT_VER"
_workdir
curl -fOLJs --retry 3 --retry-delay 2 "https://mirrors.edge.kernel.org/pub/software/scm/git/git-$GIT_VER.tar.xz"
tar xf "git-$GIT_VER.tar.xz" && cd "git-$GIT_VER"
make configure && ./configure --with-curl --without-tcltk --prefix=/opt/git && make -j
${SUDO} make install

${SUDO} update-alternatives --install /usr/local/bin/git git /opt/git/bin/git 100
hash -r # reload hash table so that the new version of git is found
