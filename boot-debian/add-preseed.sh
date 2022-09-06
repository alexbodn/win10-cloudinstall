#!/bin/sh

#see https://wiki.debian.org/DebianInstaller/Preseed/EditIso

sudo apt install -y xorriso isolinux wget gzip cpio

preseed=${1}

arch="amd64"
minarch="amd"
#release="11.4.0"
#isofile="debian-${release}-${arch}-netinst.iso"
#isourl="https://cdimage.debian.org/debian-cd/current/${arch}/iso-cd/${isofile}"
#
re_url="https.*${arch}-netinst\.iso"
isourl=$(wget -O - "https://www.debian.org/releases/stable/debian-installer/"|grep -oP ${re_url}|grep -v nonfree)
#isofile=$(echo ${isourl} | sed -e 's/.*\///')
isofile="debian-stable-${arch}-netinst.iso"

isofiles=$(mktemp -d)

#fetch iso
wget -O ${isofile} ${isourl}

#unpack iso
xorriso -osirrox on -indev ${isofile} -extract / ${isofiles}

#Adding a Preseed File to the Initrd
kernelloc="${isofiles}/install.${minarch}/"
chmod +w -R "${kernelloc}/"
gunzip "${kernelloc}/initrd.gz"
echo ${preseed} | cpio -H newc -o -A -F "${kernelloc}/initrd"
gzip "${kernelloc}/initrd"
chmod -w -R "${kernelloc}/"

#Regenerating md5sum.txt
pushd ${isofiles}
chmod +w md5sum.txt
find -follow -type f ! -name md5sum.txt -print0 | xargs -0 md5sum > md5sum.txt
chmod -w md5sum.txt
popd

#Creating a New Bootable ISO Image
xorriso -as mkisofs -o "preseed-${isofile}" \
        -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
        -c isolinux/boot.cat -b isolinux/isolinux.bin -no-emul-boot \
        -boot-load-size 4 -boot-info-table ${isofiles}

#remove isofiles
echo "Should remove ${isofiles}"
chmod +w -R ${isofiles}
rm -r ${isofiles}

#download hd-images
#wget ${hd_image}/vmlinuz
#wget ${hd_image}/initrd.gz
