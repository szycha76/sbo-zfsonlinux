#!/bin/bash

set -e
wd=$(mktemp -d)
cd $wd

LINUXPATH=${LINUXPATH:-/usr/src/linux}
PKGTYPE=${PKGTYPE:-txz}
slackver=${slackver:-14.2}
sbourl=${sbopkg:-https://www.slackbuilds.org/slackbuilds}

export LINUXPATH PKGTYPE

for sbo in spl-solaris zfs-on-linux; do
	curl -# --insecure $sbourl/$slackver/system/$sbo.tar.gz > $sbo.tar.gz
	tar xf $sbo.tar.gz
	(
		cd $sbo
		srcurl=$(grep DOWNLOAD= $sbo.info|cut -d'"' -f2)
		wget --no-check-certificate "$srcurl"
		tar xf *.gz
		./$sbo.SlackBuild
		installpkg /tmp/$sbo-*_SBo.$PKGTYPE
	)
done

rm -rf $wd /tmp/SBo
