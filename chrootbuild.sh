#!/bin/bash

MOODEREL=r40
MOODENAME=$(date +%Y-%m-%d)-moode-$MOODEREL
ENABLE_CCACHE=1
CREATE_ZIP=0

[ ! -d moode ] && mkdir moode
cd moode

ZIPNAME=$(basename $(wget -nc -q -S --content-disposition https://downloads.raspberrypi.org/raspbian_lite_latest 2>&1 | grep Location: | tail -n1 | awk '{print $2}'))
unzip -n $ZIPNAME
IMGNAME=$(unzip -v $ZIPNAME | grep ".img" | awk '{print $8}')

truncate -s 3G $IMGNAME
sfdisk -d $IMGNAME | sed '$s/ size.*,//' | sfdisk $IMGNAME

sudo losetup -f -P $IMGNAME
LOOPDEV=$(sudo losetup -j $IMGNAME | awk '{print $1}' | sed 's/.$//g')

sudo e2fsck -f $LOOPDEV"p2"
sudo resize2fs $LOOPDEV"p2"

[ ! -d root ] && mkdir root

if [ $ENABLE_CCACHE -eq 1 ] && [ ! -d /var/cache/ccache ]
then
	sudo mkdir /var/cache/ccache
	sudo chown root:root /var/cache/ccache
	sudo chmod 777 /var/cache/ccache
fi

sudo mount -t ext4 $LOOPDEV"p2" root
sudo mount -t vfat $LOOPDEV"p1" root/boot
sudo mount -t devpts /dev/pts root/dev/pts
sudo mount -t proc /proc root/proc
 
if [ $ENABLE_CCACHE -eq 1 ]
then
	sudo mkdir root/var/cache/ccache
	sudo chmod 777 root/var/cache/ccache
	sudo mount --bind /var/cache/ccache root/var/cache/ccache
	sudo cp /etc/ccache.conf root/etc/
	sudo chroot root apt-get -y install ccache
fi

if [ ! "x$1" = "x" ]
then
	sudo cp ../$1 root/home/pi/build.sh
	sudo chmod +x root/home/pi/build.sh
	sudo chroot root su - pi -c "MOODEREL=$MOODEREL ENABLE_CCACHE=$ENABLE_CCACHE /home/pi/build.sh" 2>&1
	sudo rm root/home/pi/build.sh
else
	sudo chroot root su - pi -c "MOODEREL=$MOODEREL ENABLE_CCACHE=$ENABLE_CCACHE bash"
fi

if [ $ENABLE_CCACHE -eq 1 ]
then
	sudo apt-get -y remove ccache
	sudo umount root/var/cache/ccache
	sudo rm -r root/var/cache/ccache
fi

sudo umount root/proc
sudo umount root/dev/pts
sudo umount root/boot
sudo umount root
sudo losetup -D

if [ $CREATE_ZIP -eq 1 ]
then
	mv $IMGNAME $MOODENAME".img"
	zip $MOODENAME".zip" $MOODENAME".img"
	rm $MOODENAME".img"
fi

cd ..
