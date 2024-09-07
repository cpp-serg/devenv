#!/bin/bash

dnf install -y autoconf libcurl-devel openssl-devel expat-devel
GIT_VER=$(curl -s https://git-scm.com/downloads | awk "/<\//{a=0};a==1;/<span class=\"version\">/{a=1};" | grep -oE "[0-9.]+")
curl -OLJs https://mirrors.edge.kernel.org/pub/software/scm/git/git-$GIT_VER.tar.xz
tar xf git-$GIT_VER.tar.xz && cd git-$GIT_VER
make configure && ./configure --with-curl --without-tcltk --prefix=/opt/git && make -j
sudo make install
cd ..
rm -rf git-$GIT_VER git-$GIT_VER.tar.xz
sudo update-alternatives --install /usr/local/bin/git git /opt/git/bin/git 100
