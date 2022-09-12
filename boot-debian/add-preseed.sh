#!/bin/sh

#see https://wiki.debian.org/DebianInstaller/Preseed/EditIso

sudo apt install -y xorriso isolinux wget gzip cpio

preseed=${1}
authorized_keys=${2}

arch="amd64"
minarch="amd"

menuentry_file="/etc/grub.d/45_custom"

re_url="https.*${arch}-netinst\.iso"
isourl=$(wget -O - "https://www.debian.org/releases/stable/debian-installer/"|grep -oP ${re_url}|grep -v nonfree)
#isofile=$(echo ${isourl} | sed -e 's/.*\///')
isofile="debian-stable-${arch}-netinst.iso"

isofiles=$(mktemp -d)

#fetch iso
wget -O ${isofile} ${isourl}

#unpack iso
xorriso -osirrox on -indev ${isofile} -extract / ${isofiles}

#go there
_pwd=$(pwd)
cd ${isofiles}

#Adding a Preseed File to the Initrd
kernelloc="install.${minarch}/"
chmod +w -R "${kernelloc}/"
gunzip "${kernelloc}/initrd.gz"

if [ -n ${preseed} ]; then
    unset old_preseed
    if [ -f preseed.cfg ]; then
        old_preseed=$(cat preseed.cfg)
    fi
    cp ${preseed} preseed.cfg
    echo preseed.cfg | cpio -H newc -o -A -F "${kernelloc}/initrd"
    rm preseed.cfg
    if [ -n ${old_preseed+isset} ]; then
        echo ${old_preseed} > preseed.cfg
    fi
fi

if [ -n ${authorized_keys} ]; then
    unset old_authorized_keys
    if [ -f authorized_keys ]; then
        old_authorized_keys=$(cat authorized_keys)
    fi
    cp ${authorized_keys} authorized_keys
    echo authorized_keys | cpio -H newc -o -A -F "${kernelloc}/initrd"
    rm authorized_keys
    if [ -n ${old_authorized_keys+isset} ]; then
        echo ${old_authorized_keys} > authorized_keys
    fi
fi

gzip "${kernelloc}/initrd"
chmod -w -R "${kernelloc}/"

#Regenerating md5sum.txt
chmod +w md5sum.txt
find -follow -type f ! -name md5sum.txt -print0 | xargs -0 md5sum > md5sum.txt
chmod -w md5sum.txt

#come back
cd ${_pwd}

#Creating a New Bootable ISO Image
xorriso -as mkisofs -o "preseed-${isofile}" \
        -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
        -c isolinux/boot.cat -b isolinux/isolinux.bin -no-emul-boot \
        -boot-load-size 4 -boot-info-table ${isofiles}

preseed_md5=$(cat ${preseed} | awk '{print $1}')

cat > ${menuentry_file} << EOM
#!/bin/sh
exec tail -n +3 \$0
# This file provides an easy way to add custom menu entries.  Simply type the
# menu entries you want to add after this comment.  Be careful not to change
# the 'exec tail' line above.
menuentry "${isofile}" {
    echo 1
    set isofile="$(pwd)/${isofile}"
    loopback loop (hd0,msdos1)\$isofile
    linux (loop)/install.${minarch}/vmlinuz file=preseed.cfg preseed-md5=${preseed_md5}
    splash quiet "\${loopback}"
    initrd (loop)/install.${minarch}/initrd.gz
}
EOM
chmod +x ${menuentry_file}

update-grub

#remove isofiles
echo "Should remove ${isofiles}"
#chmod +w -R ${isofiles}
#rm -r ${isofiles}

#download hd-images
#wget ${hd_image}/vmlinuz
#wget ${hd_image}/initrd.gz
