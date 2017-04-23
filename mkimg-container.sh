#!/bin/sh -ex

# Gentoo Linux Docker container builder
# Copyright (C) 2017  Stuart Longland
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA

DEVROOT=/tmp/work/${BASENAME}-dev-${TAG}
RTROOT=/tmp/work/${BASENAME}-rt-${TAG}

sed -i -e '/^USE=/ d' /etc/portage/make.conf
cat >> /etc/portage/make.conf <<EOF
FEATURES="buildpkg"
GENTOO_MIRRORS="http://mirror.internode.on.net/pub/gentoo"
EOF

emerge ${EMERGE_OPTS} -k layman
layman -S
layman -a musl

emerge -evkuDN ${EMERGE_OPTS} @system @world

# Clean up root, set up new packages
for root in ${DEVROOT} ${RTROOT}; do
	rm -frv ${root}
	mkdir ${root}
	tar -C / --exclude=usr/portage/distfiles \
		--exclude=usr/portage/packages \
		-cf - \
		etc/portage var/lib/layman usr/portage \
		| tar -C ${root} -xvf -
done

ROOT=${DEVROOT} emerge ${EMERGE_OPTS} -eKuDN @system @world

tar -C ${DEVROOT} -cvf /tmp/work/${BASENAME}-dev-${TAG}.tar .
chown -R ${OUT_UID}:${OUT_GID} /tmp/work/${BASENAME}-dev-${TAG}.tar /usr/portage/packages
rm -fr ${DEVROOT}

INSTALL_MASK=""
INSTALL_MASK="${INSTALL_MASK} /usr/share/man/*"
INSTALL_MASK="${INSTALL_MASK} /usr/share/info/*"
INSTALL_MASK="${INSTALL_MASK} /usr/share/doc/*"
INSTALL_MASK="${INSTALL_MASK} /usr/include/*"
INSTALL_MASK="${INSTALL_MASK} /usr/lib/charset.alias"
INSTALL_MASK="${INSTALL_MASK} /usr/share/gcc-data/*/*/man/*"
INSTALL_MASK="${INSTALL_MASK} /usr/share/gcc-data/*/*/info/*"
INSTALL_MASK="${INSTALL_MASK} /usr/*/gcc-bin"
INSTALL_MASK="${INSTALL_MASK} /usr/lib/gcc/*/*/plugin"
INSTALL_MASK="${INSTALL_MASK} *.a"
INSTALL_MASK="${INSTALL_MASK} *.la"
INSTALL_MASK="${INSTALL_MASK} *.h"
INSTALL_MASK="${INSTALL_MASK} *.o"
export INSTALL_MASK

sed -i -e '/^FEATURES/ s:buildpkg:usepkg:' \
	${RTROOT}/etc/portage/make.conf
cat >> ${RTROOT}/etc/portage/make.conf <<EOF
INSTALL_MASK="${INSTALL_MASK}"
EOF

# Install base packages.
ROOT=${RTROOT} emerge ${EMERGE_OPTS} -eKuDN1 \
	'>=sys-apps/baselayout-2' \
	'app-arch/bzip2' \
	'app-arch/gzip' \
	'app-arch/tar' \
	'app-arch/xz-utils' \
	'app-shells/bash:0' \
	'net-misc/iputils' \
	'net-misc/rsync' \
	'net-misc/wget' \
	'sys-apps/coreutils' \
	'sys-apps/file' \
	'>=sys-apps/findutils-4.4' \
	'sys-apps/gawk' \
	'sys-apps/grep' \
	'sys-apps/kbd' \
	'sys-apps/less' \
	'sys-apps/openrc' \
	'sys-process/procps' \
	'sys-process/psmisc' \
	'sys-apps/sed' \
	'sys-apps/which' \
	'virtual/libc' \
	'virtual/package-manager' \
	'virtual/service-manager' \
	'sys-apps/util-linux'

# Clean up, because Portage ignores INSTALL_MASK sometimes.
rm -frv ${RTROOT}/usr/include ${RTROOT}/usr/share/man ${RTROOT}/usr/share/info ${RTROOT}/usr/share/doc
find ${RTROOT} -name \*.a -print -delete
find ${RTROOT} -name \*.o -print -delete
find ${RTROOT} -name \*.h -print -delete
find ${RTROOT} -name \*.la -print -delete

tar -C ${RTROOT} -cvf /tmp/work/${BASENAME}-rt-${TAG}.tar .
chown ${OUT_UID}:${OUT_GID} /tmp/work/${BASENAME}-rt-${TAG}.tar
rm -fr ${RTROOT}
