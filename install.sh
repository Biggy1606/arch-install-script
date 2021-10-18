#!/bin/bash

# Notes:
# Most code copied from: https://github.com/MatMoul/archfi
# End

disk=/dev/sda
diskpartition=${disk}
locale={en_US.UTF-8}
newuser=biggy
hostname="beq"

pause(){
    read -p "Press any key to continue ..."
    clear
}

archchroot(){
	echo "arch-chroot /mnt /root"
	cp ${0} /mnt/root
	chmod 755 /mnt/root/$(basename "${0}")
	arch-chroot /mnt /root/$(basename "${0}") --chroot ${1} ${2}
	rm /mnt/root/$(basename "${0}")
	echo "exit"
}

createpartitions(){
	echo -e "-- Create partitions and format them --\n\n"
	# MBR -> GPT
	parted ${disk} mklabel gpt
	# Create EFI partition
	sgdisk ${disk} -n=1:0:+512M -t=1:ef00
	# Calc swap size and create swap partition
	swapsize=$(cat /proc/meminfo | grep MemTotal | awk '{ print $2 }')
	swapsize=$((${swapsize}/1000))"M"
	sgdisk ${disk} -n=2:0:+${swapsize} -t=2:8200
	# Create Linux data partition
	sgdisk ${disk} -n=3:0:0
	# Make file systems
	mkfs.fat -F32 ${diskpartition}1
	mkswap ${diskpartition}2
	mkfs.btrfs ${diskpartition}3
	pause
}

mountpartition() {
	echo -e "-- Mount linux partition --\n\n"
	mount ${diskpartition}3 /mnt
	pause
}

installbasepackages() {
	echo -e "-- Install base system and gen fstab --\n\n"
	pacstrap /mnt base linux linux-firmware btrfs-progs vim sudo grub grub-btrfs efibootmgr os-prober
	genfstab -U /mnt >> /mnt/etc/fstab
	cat /mnt/etc/fstab
	pause
}

inchrootsteps(){
	echo -e "-- Mount EFI and install GRUB --\n\n"
	mkdir -p /boot/efi
	mount ${diskpartition}1 /boot/efi
	grub-install --target=x86_64-efi --bootloader-id=GRUB --efi-directory=/boot/efi
  grub-mkconfig -o /boot/
	pause

	echo -e "-- Set locale ${locale} --\n\n"
	echo LANG=${locale} > /etc/locale.conf
	export LANG=${locale}
	pause

	echo -e "-- Set hostname to ${hostname} --\n\n"
	echo ${hostname} > /etc/hostname
	pause

	echo -e "-- Create /etc/hosts --\n\n"
  hostsfile=/etc/hosts
	touch ${hostsfile}
	echo -e "\n127.0.0.1    localhost\n::1          localhost\n127.0.1.1    beq\n" >> ${hostsfile}
  echo "########################"
  cat ${hostsfile}
  echo "########################"
	pause

	echo -e "-- Change root password --\n\n"
	passwd
	pause

	echo -e "-- Create normal user --\n\n"
	useradd --create-home ${newuser}
  echo "New user '${newuser}' created"
	passwd ${newuser}
	usermod --append --groups wheel biggy
	pause

	echo -e "-- Manually enable wheel group --\n\n"
  pause
	visudo
	pause
}

createpartitions
mountpartition
installbasepackages
# inchrootsteps
