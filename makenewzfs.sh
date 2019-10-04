#!/bin/bash

function guessnewversion() {
	txt=$(curl --silent https://zfsonlinux.org/ | grep -A4 '#80ff00'|tr /- "\n"|grep '[0-9]\+.*<$'|sed 's/<$//'|uniq)
	c=$(echo "$txt"|wc -l)
	if [ '1' == "$c" ]; then
		echo $txt
	fi
}

set -e
pwd=$(pwd)
wd=$(mktemp -d)
cd $wd

guessed=$(guessnewversion)
NEWVERSION=${NEWVERSION:-${guessed:-0.7.9}}

KERN=${KERN:-"$(uname -r)"}
PKGTYPE=${PKGTYPE:-txz}
slackver=${slackver:-14.2}
sbourl=${sbourl:-https://www.slackbuilds.org/slackbuilds}
pending=$(echo $sbourl|sed 's?/slackbuilds?/pending/?')
sbolist=zfs-on-linux
out=$pwd/out/$NEWVERSION

failfast=$(curl --silent --insecure $pending|grep zfs-on-linux.tar|cut -d'>' -f4-|cut -d'<' -f1)
if [[ ! -z "$failfast" ]]; then
	echo Submission pending since $failfast UTC.  Skipping.
	exit 0
fi

export KERN PKGTYPE
mkdir -pv $out

for sbo in $sbolist; do
	curl -# --insecure $sbourl/$slackver/system/$sbo.tar.gz > $sbo.tar.gz
	tar xf $sbo.tar.gz
	(
		cd $sbo
		VERSION=$(grep ^VERSION= $sbo.info|cut -d'"' -f2|sed 's:\.:\\.:g')
		sed -i.old s/$VERSION/$NEWVERSION/g $sbo.info $sbo.SlackBuild
		sums=$(md5sum $sbo.info $sbo.info.old|cut -d ' ' -f1|uniq|wc -l)
		if [ "1" == "$sums" ]; then
			echo Nothing has changed yet, leave it.
			exit 1
		fi
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

cd $pwd
for sbo in $sbolist; do
	curl \
		-F "userfile=@out/$sbo.tar.gz;filename=$sbo.tar.gz" \
		-F 'comments=Updated for version $NEWVERSION' \
		-F submail=szycha@gmail.com \
		-F MAX_FILE_SIZE=1048576 -F category=System -F submit=Submit \
			https://www.slackbuilds.org/process_submit/
done

rm -rf $wd /tmp/SBo
