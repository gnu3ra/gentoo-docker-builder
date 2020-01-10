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

SRC_STAGE3=${1}
SRC_SNAPSHOT=${2}
REPO=${3}
BASENAME=${4}
TAG=${5}
WORKDIR=$( pwd )
OUT_UID=$( id -u )
OUT_GID=$( id -g )

EMERGE_OPTS="-j6 --load-average 12.0"
PKGDIR=${WORKDIR}/packages/${TAG}
SNAPSHOT_DIR=${WORKDIR}/portage/${TAG}
DISTDIR=$( portageq distdir )

if [ ! -d "${SNAPSHOT_DIR}" ]; then
	mkdir -pv "${SNAPSHOT_DIR}"
	tar -C "${SNAPSHOT_DIR}" -xf "${SRC_SNAPSHOT}"
fi

mkdir -pv ${PKGDIR}
bzcat ${SRC_STAGE3} | docker import - ${REPO}/${BASENAME}-raw:${TAG}
docker run -it --rm -v ${SNAPSHOT_DIR}/portage:/var/db/repos/gentoo \
		-v ${DISTDIR}:/var/cache/distfiles \
		-v ${PKGDIR}:/var/cache/binpkgs\
		-v ${WORKDIR}:/tmp/work \
		-e BASENAME=${BASENAME} \
		-e TAG=${TAG} \
		-e OUT_UID=${OUT_UID} \
		-e OUT_GID=${OUT_GID} \
		-e EMERGE_OPTS="${EMERGE_OPTS}" \
		--privileged \
		${REPO}/${BASENAME}-raw:${TAG} \
    /bin/bash -ex /tmp/work/mkimg-container.sh

docker import \
	-c "VOLUME /var/db/repos/gentoo" \
	-c "VOLUME /var/lib/layman" \
	- ${REPO}/${BASENAME}-dev:${TAG} \
	< ${WORKDIR}/${BASENAME}-dev-${TAG}.tar

docker import - \
	-c "VOLUME /var/db/repos/gentoo" \
	-c "VOLUME /var/lib/layman" \
	${REPO}/${BASENAME}-rt:${TAG} \
	< ${WORKDIR}/${BASENAME}-rt-${TAG}.tar

docker push ${REPO}/${BASENAME}-dev:${TAG}
docker push ${REPO}/${BASENAME}-rt:${TAG}
( docker images -q --filter dangling=true | xargs docker rmi ) || true
