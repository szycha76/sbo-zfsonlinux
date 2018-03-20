#!/bin/bash

set -e
pwd=$(pwd)
wd=$(mktemp -d)
cd $wd

NEWVERSION=${NEWVERSION:-0.7.7}

KERN=${KERN:-"$(uname -r)"}
PKGTYPE=${PKGTYPE:-txz}
slackver=${slackver:-14.2}
sbourl=${sbourl:-https://www.slackbuilds.org/slackbuilds}
out=$pwd/out/$NEWVERSION

export KERN PKGTYPE
mkdir -pv $out

for sbo in spl-solaris zfs-on-linux; do
	curl -# --insecure $sbourl/$slackver/system/$sbo.tar.gz > $sbo.tar.gz
	tar xf $sbo.tar.gz
	(
		cd $sbo
		VERSION=$(grep ^VERSION= $sbo.info|cut -d'"' -f2|sed 's:\.:\\.:g')
		sed -i.old s/$VERSION/$NEWVERSION/g $sbo.info $sbo.SlackBuild
		srcurl=$(grep DOWNLOAD= $sbo.info|cut -d'"' -f2)
		wget --no-check-certificate "$srcurl"
		MD5SUM=$(md5sum *.gz |cut -d' ' -f1)
		sed -i.old.md5 "s/^MD5SUM=.*$/MD5SUM=\"$MD5SUM\"/" $sbo.info
		tar xf *.gz
		./$sbo.SlackBuild
		installpkg /tmp/$sbo-${NEWVERSION}_${KERN}-*_SBo.$PKGTYPE
	)
	tar tf $sbo.tar.gz|grep -v /$|tar cvvf - -T -|gzip -9 > $out/$sbo.tar.gz
	ln -f $out/$sbo.tar.gz $out/../$sbo.tar.gz
done

rm -rf $wd /tmp/SBo
