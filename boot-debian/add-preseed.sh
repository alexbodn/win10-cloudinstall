#!/bin/sh

#see https://wiki.debian.org/DebianInstaller/Preseed/EditIso

sudo apt install -y xorriso isolinux wget gzip cpio

preseed=${1}

release="11.4.0"
arch="amd64"
isofile="debian-${release}-${arch}-netinst.iso"
isourl="https://cdimage.debian.org/debian-cd/current/${arch}/iso-cd/${isofile}"
hd_media="http://http.us.debian.org/debian/dists/stable/main/installer-amd64/current/images/hd-media/"
isofiles=$(mktemp -d)

mkdir ${isofiles}

#fetch iso
wget -o ${isofile} ${isourl}

#unpack iso
xorriso -osirrox on -indev ${isofile} -extract / ${isofiles}

#Adding a Preseed File to the Initrd
chmod +w -R "${isofiles}/install.${arch}/"
gunzip "${isofiles}/install.${arch}/initrd.gz"
echo ${preseed} | cpio -H newc -o -A -F "${isofiles}/install.${arch}/initrd"
gzip "${isofiles}/install.${arch}/initrd"
chmod -w -R "${isofiles}/install.${arch}/"

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
wget ${hd_image}/vmlinuz
wget ${hd_image}/initrd.gz
