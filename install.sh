#!/bin/bash

# Notes:
# Most code copied from: https://github.com/MatMoul/archfi
# $1 - manual execute functions
# $2 - enter disk path
# End

## Debug
debug() {
	echo "pajac"
	echo $diskpartition
}

# Heper functions

loaddisk() {
	if [ -e "$2" ]
	then
		disk=$2
		diskpartition="${disk}p"
	else
		echo "Disk $2 dont exist in your filesystem"
		exit 1
	fi
}
loadconfig() {
	loaddisk
	locale=("en_US.UTF-8" "pl_PL.UTF-8")
	vconsolefile=("KEYMAP=pl" "FONT=Lat2-Terminus16" "FONT_MAP=8859-2")
	newuser="biggy"
	hostname="beq"
}
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

#  Sequence functions

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
	return 0
}
mountpartition() {
	echo -e "-- Mount linux partition --\n\n"
	mount ${diskpartition}3 /mnt
	return 0
}
installbasepackages() {
	echo -e "-- Install base system and gen fstab --\n\n"
	pacstrap /mnt base linux linux-firmware btrfs-progs vim sudo grub grub-btrfs efibootmgr os-prober
	fstabfile=/mnt/etc/fstab
	if [[ -f "${fstabfile}" ]]; then
    	rm "${fstabfile}"
	fi
	genfstab -U /mnt >> /mnt/etc/fstab
	return 0
}
# Use after configuring base system
installpackages() {
	echo -e "-- Install plasma and other software --\n\n"
	pacstrap /mnt xorg plasma konsole firefox
	return 0
}

## Rest of the functions use from chroot!!!
installgrub() {
	echo -e "-- Mount EFI and install GRUB --\n\n"
	mkdir -p /boot/efi
	mount ${diskpartition}1 /boot/efi
	grub-install --target=x86_64-efi --bootloader-id=GRUB --efi-directory=/boot/efi
  	grub-mkconfig -o /boot/
	return 0
}
setsystemtime() {
	echo -e "-- Set time --\n\n"
  	ln -sf /usr/share/zoneinfo/Europe/Warsaw /etc/localtime
  	hwclock --systohc
	return 0
}
setlocales() {
	echo -e "-- Set locale ${locales[@]} --\n\n"
	# Set supported locales
  	rm /etc/locale.gen
  	for local in "${locale[@]}"
  	do
    echo "$local" >> /etc/locale.gen
  	done
  	locale-gen
	# Set main LANG
  	echo "LANG=${locale[0]}" > /etc/locale.conf
  	export "LANG=${locale[0]}"
	# PL chars in console
  	rm /etc/vconsole.conf
  	for config in "${vconsolefile[@]}"
  	do
    	echo "$config" >> /etc/vconsole.conf
  	done
	return 0
}
sethostname(){
	echo -e "-- Set hostname to ${hostname} --\n\n"
	echo ${hostname} > /etc/hostname
	return 0
}
createhostsfile() {
	echo -e "-- Create /etc/hosts --\n\n"
  	hostsfile=/etc/hosts
	touch ${hostsfile}
	echo '127.0.0.1    localhost' >> ${hostsfile}
	echo '::1          localhost' >> ${hostsfile}
	echo '127.0.1.1    beq' >> ${hostsfile}
	return 0
}
changerootpassword() {
	echo -e "-- Change root password --\n\n"
	passwd
	return 0
}
createnewuser() {
	echo -e "-- Create normal user ${newuser} and password --\n\n"
	useradd --create-home ${newuser}
  	echo "> New user created"
	passwd ${newuser}
	usermod --append --groups wheel biggy
	return 0
}
enablewheelgroup() {
	echo -e "-- Manually enable wheel group --\n\n"
	visudo
	return 0
}

$1