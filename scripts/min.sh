#!/usr/bin/env bash
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202211071239-git
# @@Author           :  Jason Hempstead
# @@Contact          :  jason@casjaysdev.pro
# @@License          :  WTFPL
# @@ReadME           :  min.sh --help
# @@Copyright        :  Copyright: (c) 2022 Jason Hempstead, Casjays Developments
# @@Created          :  Monday, Nov 07, 2022 12:39 EST
# @@File             :  min.sh
# @@Description      :  Script to setup min for Ubuntu
# @@Changelog        :  New script
# @@TODO             :  Better documentation
# @@Other            :
# @@Resource         :
# @@Terminal App     :  no
# @@sudo/root        :  yes
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# shellcheck disable=SC1090
# shellcheck disable=SC1091
# shellcheck disable=SC2016
# shellcheck disable=SC2031
# shellcheck disable=SC2086
# shellcheck disable=SC2120
# shellcheck disable=SC2155
# shellcheck disable=SC2199
# shellcheck disable=SC2317
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
APPNAME="min-ubuntu"
VERSION="202211071239-git"
USER="${SUDO_USER:-${USER}}"
HOME="${USER_HOME:-${HOME}}"
CONFIG_TEMP_DIR="${TMPDIR:-/tmp}/minConfigFiles"
FORCE_INSTALL="${FORCE_INSTALL:-no}"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Set bash options
if [ "$1" = "--debug" ]; then shift 1 && set -xo pipefail && export SCRIPT_OPTS="--debug" && export _DEBUG="on"; fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
if [ ! -d "/etc/casjaysdev" ]; then
	if apt-get update -q && apt-get upgrade -y -q; then
		echo "Rebooting your system: Please rerun this script after reboot"
		mkdir -p "/etc/casjaysdev"
		sleep 20 && reboot
	fi
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
if ! type -P ifconfig >/dev/null 2>&1 && ! type -P hostname >/dev/null 2>&1; then
	echo "Installing net-tools package"
	apt-get install -y -q net-tools
fi
for pkg in sudo git curl wget; do
	command -v $pkg &>/dev/null || { echo "Installing $pkg" && apt-get install -y -q $pkg &>/dev/null || exit 1; } || { echo "Failed to install $pkg" && exit 1; }
done
unset pkg
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
read -r -t 30 -p "Enter your full hostname: (default: $HOSTNAME) " set_hostname
set_hostname="${set_hostname:-$(hostname -f 2>/dev/null)}"
set_hostname="${set_hostname:-$HOSTNAME}"
if [ -n "$set_hostname" ]; then
	if hostnamectl set-hostname "$set_hostname" && echo "$set_hostname" >/etc/hostname; then
		type -P hostname >/dev/null 2>&1 && hostname -F /etc/hostname
	fi
	MY_HOST_NAME="$set_hostname"
	unset set_hostname
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
if type -P systemd-ask-password >/dev/null 2>&1; then
	sap_args=("--timeout=30")
	systemd-ask-password --help 2>&1 | grep -q -- '--emoji' && sap_args+=("--emoji=no")
	systemd-ask-password --help 2>&1 | grep -q -- '--echo' && sap_args+=("--echo=masked")
	root_pass_1="$(systemd-ask-password "${sap_args[@]}" "Enter your root password: ")"
	root_pass_2="$(systemd-ask-password "${sap_args[@]}" "Confirm your root password: ")"
	unset sap_args
else
	stty -echo
	printf "Enter your root password: " && read -r -t 30 -s root_pass_1
	printf '\n'
	printf "Confirm your root password: " && read -r -t 30 -s root_pass_2
	printf '\n'
	stty echo
fi
if [ -n "$root_pass_1" ]; then
	if [ "$root_pass_1" = "$root_pass_2" ]; then
		echo "root:$root_pass_1" | chpasswd >/dev/null
	fi
fi
unset root_pass_1 root_pass_2
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
if [ -z "$(find /var/cache/swaps -mindepth 1 2>/dev/null)" ]; then
	SWAP_SIZE="$(swapon --show=SIZE --noheadings 2>/dev/null | awk 'NR==1{gsub(/[0-9.]/,""); gsub(/ /,""); print}')"
	if [ "$SWAP_SIZE" != "G" ]; then
		swap_file="swapFile"
		swap_dir="/var/cache/swaps"
		mkdir -p "$swap_dir"

		# Detect RAM (KB) and pad 5% to absorb kernel/firmware reservations
		# (e.g. a 96 GB host that `free` reports as ~93 GB)
		mem_kb="$(free | awk 'NR==2 {print $2}')"
		mem_kb="${mem_kb:-1024}"
		mem_kb_padded=$((mem_kb * 105 / 100))
		mem_gb=$(((mem_kb_padded + 1048575) / 1048576))

		# Free disk at swap location, in GB
		disk_avail_kb="$(df -Pk "$swap_dir" | awk 'NR==2 {print $4}')"
		disk_avail_gb=$((disk_avail_kb / 1048576))

		# Tiered swap size in MB
		if [ "$mem_gb" -le 2 ]; then
			swap_file_size=$((mem_gb * 2 * 1024))
		elif [ "$mem_gb" -le 4 ]; then
			swap_file_size=$((mem_gb * 1024))
		elif [ "$mem_gb" -le 8 ]; then
			swap_file_size=$((4 * 1024))
		else
			if [ "$disk_avail_gb" -gt 100 ]; then
				swap_file_size=$((16 * 1024))
			elif [ "$disk_avail_gb" -gt 50 ]; then
				swap_file_size=$((8 * 1024))
			else
				swap_file_size=$((4 * 1024))
			fi
		fi

		# Cap at 50% of free disk; skip if cap drops below 2 GB
		max_swap_mb=$((disk_avail_kb / 1024 / 2))
		[ "$swap_file_size" -gt "$max_swap_mb" ] && swap_file_size=$max_swap_mb
		[ "$swap_file_size" -lt 2048 ] && swap_file_size=0

		if [ "$swap_file_size" -gt 0 ] && [ ! -f "$swap_dir/$swap_file" ]; then
			echo "RAM: ${mem_gb}GB, free disk at $swap_dir: ${disk_avail_gb}GB"
			echo "Setting up ${swap_file_size}MB swap in $swap_dir/$swap_file"
			echo "This may take a few minutes so enjoy your coffee"
			if dd if=/dev/zero of=$swap_dir/$swap_file bs=1MB count=$swap_file_size &>/dev/null; then
				echo "swap size is: ${swap_file_size}MB"
				chmod 600 $swap_dir/$swap_file
				mkswap $swap_dir/$swap_file >/dev/null
				swapon $swap_dir/$swap_file >/dev/null
				if ! grep -qs "$swap_dir/$swap_file" /etc/fstab; then
					echo "$swap_dir/$swap_file          swap        swap             defaults          0 0" | tee -a /etc/fstab >/dev/null
				fi
			fi
		fi
		unset SWAP_SIZE swap_file_size swap_file swap_dir mem_kb mem_kb_padded mem_gb disk_avail_kb disk_avail_gb max_swap_mb
		swapon --show 2>/dev/null | grep -v '^NAME ' | grep -q '^' && echo "Swap has been enabled"
		sleep 5
	fi
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
if [ ! -d "/usr/local/share/CasjaysDev/scripts" ]; then
	git clone "https://github.com/casjay-dotfiles/scripts" "/usr/local/share/CasjaysDev/scripts" -q
	eval "/usr/local/share/CasjaysDev/scripts/install.sh" || { echo "Failed to initialize" && exit 1; }
	export PATH="/usr/local/share/CasjaysDev/scripts/bin:$PATH"
	sleep 5
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Set functions
SCRIPTSFUNCTURL="${SCRIPTSFUNCTURL:-https://github.com/casjay-dotfiles/scripts/raw/main/functions}"
SCRIPTSFUNCTDIR="${SCRIPTSFUNCTDIR:-/usr/local/share/CasjaysDev/scripts}"
SCRIPTSFUNCTFILE="${SCRIPTSFUNCTFILE:-system-installer.bash}"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
if [ -f "../functions/$SCRIPTSFUNCTFILE" ]; then
	. "../functions/$SCRIPTSFUNCTFILE"
elif [ -f "$SCRIPTSFUNCTDIR/functions/$SCRIPTSFUNCTFILE" ]; then
	. "$SCRIPTSFUNCTDIR/functions/$SCRIPTSFUNCTFILE"
else
	curl -LSs "$SCRIPTSFUNCTURL/$SCRIPTSFUNCTFILE" -o "/tmp/$SCRIPTSFUNCTFILE" || exit 1
	. "/tmp/$SCRIPTSFUNCTFILE"
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
SCRIPT_OS="Ubuntu"
SCRIPT_DESCRIBE="Minimal"
GITHUB_USER="${GITHUB_USER:-casjay}"
SYSTEMMGR_CONFIGS="cron ssh ssl"
DFMGR_CONFIGS="misc vim bash git tmux"
SET_HOSTNAME=""
command -v hostname >/dev/null 2>&1 && SET_HOSTNAME="$(hostname -s 2>/dev/null)"
SET_HOSTNAME="${SET_HOSTNAME:-${MY_HOST_NAME%%.*}}"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
SCRIPT_NAME="$APPNAME"
SCRIPT_NAME="${SCRIPT_NAME%.*}"
RELEASE_VER="$(. /etc/os-release 2>/dev/null; echo "${VERSION_ID%%.*}")"
RELEASE_NAME="$(. /etc/os-release 2>/dev/null; n="${NAME,,}"; echo "${n%% *}")"
RELEASE_TYPE="$(. /etc/os-release 2>/dev/null; [[ " $ID_LIKE " == *centos* ]] && echo "ubuntu")"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
DEFAULT_KERNEL="${DEFAULT_KERNEL:-kernel-ml}"
ARCH="$(uname -m | tr '[:upper:]' '[:lower:]')"
BACKUP_DIR="$HOME/Documents/backups/$(date +'%Y/%m/%d')"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
SSH_KEY_LOCATION="${SSH_KEY_LOCATION:-https://github.com/$GITHUB_USER.keys}"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
SETUP_ACCOUNT_ADMIN="${SETUP_ACCOUNT_ADMIN:-administrator:random}"
SETUP_ACCOUNT_USERS="${SETUP_ACCOUNT_USERS:-}"
SETUP_ACCOUNT_BASE_UID="${SETUP_ACCOUNT_BASE_UID:-10000}"
declare -a SETUP_ACCOUNT_CREDS=()
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
case "${SET_HOSTNAME:-$HOSTNAME}" in
	pbx*)                            SYSTEM_TYPE="pbx" ;;
	dns*)                            SYSTEM_TYPE="dns" ;;
	vpn*)                            SYSTEM_TYPE="vpn" ;;
	mail*)                           SYSTEM_TYPE="mail" ;;
	server*)                         SYSTEM_TYPE="server" ;;
	sql*|db*)                        SYSTEM_TYPE="sql" ;;
	devel*|build*|ci*|testing*)      SYSTEM_TYPE="devel" ;;
esac
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
SERVICES_ENABLE="cockpit cockpit.socket docker apache2 munin-node nginx php-fpm postfix proftpd rsyslog snmpd sshd uptimed downtimed "
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
SERVICES_DISABLE="avahi-daemon.service avahi-daemon.socket cups.path cups.service cups.socket dhcpd dhcpd6 dm-event.socket fail2ban irqbalance.service iscsi iscsid.socket iscsiuio.socket lvm2-lvmetad.socket lvm2-lvmpolld.socket lvm2-monitor mdmonitor named nfs-client.target radvd rpcbind.service rpcbind.socket smb sssd-kcm.socket udisks2.service"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
if ! grep --no-filename -sE '^ID=|^ID_LIKE=|^NAME=' /etc/*-release | grep -qiwE "ubuntu"; then
	printf_exit "This installer is meant to be run on a $SCRIPT_OS based system"
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
[ "$1" == "--help" ] && printf_exit "${GREEN}${SCRIPT_DESCRIBE} installer for $SCRIPT_OS${NC}"
port_in_use() { netstatg 2>&1 | awk '{print $4}' | grep ':[0-9]' | awk -F':' '{print $2}' | grep '[0-9]' | grep -q "^$1$" || return 2; }
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
system_service_exists() { systemctl status "$1" 2>&1 | grep 'Loaded:' | grep -iq "$1" && return 0 || return 1; }
system_service_active() { (systemctl is-enabled "$1" || systemctl is-active "$1") | grep -qiE 'enabled|active' || return 1; }
system_service_enable() { systemctl status "$1" 2>&1 | grep -iq 'inactive' && execute "systemctl enable --now $1" "Enabling service: $1" || return 1; }
system_service_disable() { systemctl is-active --quiet "$1" && execute "systemctl disable --now $1" "Disabling service: $1" || return 1; }
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
does_user_exist() { grep -qs "^$1:" "/etc/passwd" || return 1; }
does_group_exist() { grep -qs "^$1:" "/etc/group" || return 1; }
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__get_www_user() {
	local u=""
	while IFS=: read -r u _; do
		case "$u" in www-data|apache|nginx) echo "$u"; return 0 ;; esac
	done </etc/passwd
	return 9
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__get_www_group() {
	local g=""
	while IFS=: read -r g _; do
		case "$g" in www-data|apache|nginx) echo "$g"; return 0 ;; esac
	done </etc/group
	return 9
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
copy_ca_certs() {
	if [ ! -d "/etc/letsencrypt/live/domain" ] || [ ! -L "/etc/letsencrypt/live/domain" ]; then
		printf_red "letsencrypt seemed to have failed: Installing self-signed certificates"
		mkdir -p "/etc/letsencrypt/live/domain"
		[ -f "/etc/ssl/CA/CasjaysDev/certs/ca.crt" ] && cp -Rf "/etc/ssl/CA/CasjaysDev/certs/ca.crt" "/etc/letsencrypt/live/domain/cert.pem"
		[ -f "/etc/ssl/CA/CasjaysDev/certs/localhost.crt" ] && cp -Rf "/etc/ssl/CA/CasjaysDev/certs/localhost.crt" "/etc/letsencrypt/live/domain/chain.pem"
		[ -f "/etc/ssl/CA/CasjaysDev/certs/localhost.crt" ] && cp -Rf "/etc/ssl/CA/CasjaysDev/certs/localhost.crt" "/etc/letsencrypt/live/domain/fullchain.pem"
		[ -f "/etc/ssl/CA/CasjaysDev/private/localhost.key" ] && cp -Rf "/etc/ssl/CA/CasjaysDev/private/localhost.key" "/etc/letsencrypt/live/domain/privkey.pem"
		find "/etc/letsencrypt" -type f -exec chmod 664 {} \;
		find "/etc/letsencrypt" -type d -exec chmod 755 {} \;
	fi
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__dnf_yum() {
	DEBIAN_FRONTEND=noninteractive apt-get -y -q "$@"
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
test_pkg() {
	for pkg in "$@"; do
		if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "ok installed"; then
			printf_blue "[ ✔ ] $pkg is already installed"
			return 1
		else
			return 0
		fi
	done
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
remove_pkg() {
	local pkg=""
	for pkg in "$@"; do
		if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "ok installed"; then
			execute "DEBIAN_FRONTEND=noninteractive apt-get remove -y -q $pkg" "Removing: $pkg"
		fi
	done
	return 0
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
install_pkg() {
	local statusCode=0
	if test_pkg "$*"; then
		execute "DEBIAN_FRONTEND=noninteractive apt-get install -y -q $*" "Installing: $*"
		test_pkg "$*" &>/dev/null && statusCode=1 || statusCode=0
	else
		statusCode=0
	fi
	return $statusCode
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
detect_selinux() {
	return 0
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
disable_selinux() {
	printf_blue "SELinux not applicable on this distro — skipping"
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
get_user_ssh_key() {
	local col=${COLUMNS:-120}
	col=$((col - 40))
	[ -n "$SSH_KEY_LOCATION" ] || return 0
	[ -d "$HOME/.ssh" ] || mkdir -p "$HOME/.ssh"
	chmod 700 "$HOME/.ssh"
	get_keys="$(curl -q -LSsf "$SSH_KEY_LOCATION" 2>/dev/null)"
	if [ -n "$get_keys" ]; then
		echo "$get_keys" | while read -r key; do
			key_value="$(echo "$key" | awk -F ' ' '{print $2}')"
			if grep -qs "$key" "$HOME/.ssh/authorized_keys"; then
				printf_cyan "Key exists in ~/.ssh/authorized_keys: ${key_value:0:$col}"
			else
				echo "$key" | tee -a "/root/.ssh/authorized_keys" &>/dev/null
				printf_green "Successfully added key: ${key_value:0:$col}"
			fi
		done
	else
		printf_return "Can not get key from $SSH_KEY_LOCATION"
		return 1
	fi
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
run_init_check() {
	if [ -d "/usr/local/share/CasjaysDev/scripts/.git" ]; then
		if ! git -C /usr/local/share/CasjaysDev/scripts pull -q; then
			rm -Rf "/usr/local/share/CasjaysDev/scripts"
			git clone https://github.com/casjay-dotfiles/scripts /usr/local/share/CasjaysDev/scripts -q
		fi
	fi
	DEBIAN_FRONTEND=noninteractive apt-get update -q &>/dev/null || true
	DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -q &>/dev/null || true
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__yum() {
	DEBIAN_FRONTEND=noninteractive apt-get "$@" &>/dev/null || return 1
}
grab_remote_file() { urlverify "$1" && curl -q -SLs "$1" || exit 1; }
backup_repo_files() {
	cp -Rf "/etc/apt/sources.list.d/." "$BACKUP_DIR" 2>/dev/null || return 0
}
rm_repo_files() {
	[ "${1:-$APT_DELETE}" = "yes" ] && rm -Rf "/etc/apt/sources.list.d"/* &>/dev/null || return 0
}
run_external() { printf_green "Executing $*" && eval "$*" >/dev/null 2>&1 || return 1; }
save_remote_file() { urlverify "$1" && curl -q -SLs "$1" | tee "$2" &>/dev/null || exit 1; }
retrieve_version_file() { grab_remote_file "https://github.com/casjay-base/ubuntu/raw/main/version.txt" | head -n1 || echo "Unknown version"; }
domain_name() {
	local d="" f=""
	d="$(hostname -d 2>/dev/null)"
	[ "$d" = "(none)" ] && d=""
	if [ -n "$d" ]; then
		echo "$d"
	elif f="$(hostname -f 2>/dev/null)" && [[ "$f" == *.* ]]; then
		echo "${f#*.}"
	else
		echo "$HOSTNAME"
	fi
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
printf_head() {
	printf '%b##################################################\n' "$CYAN"
	printf '%b%s%b\n' $GREEN "$*" $CYAN
	printf '##################################################%b\n' $NC
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
printf_clear() {
	clear
	printf_head "$*"
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
rm_if_exists() {
	local file_loc=("$@") && shift $#
	for file in "${file_loc[@]}"; do
		if [ -e "$file" ]; then
			execute "rm -Rf $file" "Removing $file"
		fi
	done
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
retrieve_repo_file() {
	local statusCode="0"
	# Add Docker apt repository if not already present
	if [ ! -f "/etc/apt/sources.list.d/docker.list" ]; then
		printf '%b
' "${YELLOW}Adding Docker apt repository${NC}"
		DEBIAN_FRONTEND=noninteractive apt-get install -y -q ca-certificates curl gnupg lsb-release &>/dev/null
		install -m 0755 -d /etc/apt/keyrings
		curl -fsSL "https://download.docker.com/linux/$(. /etc/os-release && echo "$ID")/gpg" 			| gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null
		chmod a+r /etc/apt/keyrings/docker.gpg
		echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$(. /etc/os-release && echo "$ID") $(. /etc/os-release && echo "$VERSION_CODENAME") stable" 			| tee /etc/apt/sources.list.d/docker.list >/dev/null
	fi
	DEBIAN_FRONTEND=noninteractive apt-get update -q &>/dev/null || statusCode=1
	[ "$statusCode" -ne 0 ] || printf '%b
' "${YELLOW}Done updating repos${NC}"
	return $statusCode
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
run_grub() {
	local cfg="" efi="" grub_cfg="" grub_efi="" grub_bin=""
	grub_cfg="$(find /boot/grub*/* -name 'grub*.cfg' 2>/dev/null)"
	grub_efi="$(find /boot/efi/EFI/* -name 'grub*.cfg' 2>/dev/null)"
	grub_bin="$(builtin type -P grub-mkconfig 2>/dev/null || builtin type -P grub2-mkconfig 2>/dev/null)"
	if [ -n "$grub_bin" ]; then
		if [ -f "/etc/default/grub" ]; then
			for opt in 'biosdevname' 'net.ifnames'; do
				if grep -shq "$opt" '/etc/default/grub'; then
					devnull sed -i '/^GRUB_CMDLINE_LINUX=/ s/'$opt'=[01]/'$opt'=0/' /etc/default/grub
				else
					devnull sed -i '/^GRUB_CMDLINE_LINUX=/ s/"$/ '$opt'=0"/' /etc/default/grub
				fi
			done
			if ! stat -fc %T '/sys/fs/cgroup' | grep -q 'cgroup2fs' && ! grep -sq 'systemd.unified_cgroup_hierarchy' /etc/default/grub; then
				devnull sed -i '/^GRUB_CMDLINE_LINUX=/ s/"$/ systemd.unified_cgroup_hierarchy=1"/' /etc/default/grub
			fi
		fi
		if grep -sq 'GRUB_ENABLE_BLSCFG' "/etc/default/grub"; then
			sed -i 's|GRUB_ENABLE_BLSCFG=.*|GRUB_ENABLE_BLSCFG=false|g' '/etc/default/grub'
		else
			echo "GRUB_ENABLE_BLSCFG=false" >>'/etc/default/grub'
		fi
		# if grep -sq 'crashkernel=' '/etc/default/grub'; then
		#   sed -i '/^GRUB_CMDLINE_LINUX=/s/crashkernel=.*[KMG][, ]//' '/etc/default/grub'
		# fi
		rm_if_exists /boot/*rescue*
		rm_if_exists /boot/loader/entries/*
		if [ -n "$grub_cfg" ]; then
			for cfg in $grub_cfg; do
				if [ -e "$cfg" ]; then
					if devnull $grub_bin -o "$cfg"; then
						printf_green "Updated $cfg"
					else
						printf_return "Failed to update $cfg"
					fi
				fi
			done
		fi
		if [ -n "$grub_efi" ]; then
			for efi in $grub_efi; do
				if [ -e "$efi" ]; then
					if devnull $grub_bin -o "$efi"; then
						printf_green "Updated $efi"
					else
						printf_return "Failed to update $efi"
					fi
				fi
			done
		fi
	fi
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
run_post() {
	local e="$*"
	local m="${e//devnull /}"
	execute "$e" "${run_post_message:-executing: $m}"
	setexitstatus
	set --
	unset run_post_message
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__kernel_ml() {
	printf_blue "Custom kernel not applicable on this distro — using distribution default"
	return 0
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__kernel_lt() {
	printf_blue "Custom kernel not applicable on this distro — using distribution default"
	return 0
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
fix_network_device_name() {
	local device="${NETDEV:-eth0}"
	printf_green "Setting network device name to $device in $1"
	find "$1" -type f -exec sed -i "s|mynetworkdevice|$device|g" {} +
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__generate_password() {
	tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__create_account() {
	local user_spec="$1" uid="$2" is_admin="${3:-no}"
	local user="" pass="" existing_uid=""
	user="${user_spec%%:*}"
	pass="${user_spec#*:}"
	[ "$user" = "$pass" ] && pass=""
	if [ -z "$pass" ] || [ "$pass" = "random" ]; then
		pass="$(__generate_password)"
	fi
	if does_user_exist "$user"; then
		printf_yellow "User $user already exists - updating password only"
		echo "$user:$pass" | devnull chpasswd
	else
		existing_uid="$(getent passwd "$uid" | awk -F':' '{print $1}')"
		if [ -n "$existing_uid" ]; then
			printf_yellow "UID $uid already in use by $existing_uid - skipping $user"
			return 1
		fi
		devnull groupadd -g "$uid" "$user"
		devnull useradd -u "$uid" -g "$uid" -m -s /bin/bash "$user"
		echo "$user:$pass" | devnull chpasswd
	fi
	if [ "$is_admin" = "yes" ]; then
		devnull usermod -aG sudo "$user"
		if [ -d "/etc/sudoers.d" ]; then
			echo "$user ALL=(ALL) ALL" >"/etc/sudoers.d/$user"
			chmod 440 "/etc/sudoers.d/$user"
		fi
	fi
	SETUP_ACCOUNT_CREDS+=("$user:$pass")
	printf_green "Account ready: $user (uid $uid)"
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
##################################################################################################################
printf_clear "Initializing the installer for $RELEASE_NAME using $SCRIPT_DESCRIBE script"
##################################################################################################################
[ -d "/etc/casjaysdev/updates/versions" ] || mkdir -p "/etc/casjaysdev/updates/versions"
if [ -f "/etc/casjaysdev/updates/versions/$SCRIPT_NAME.txt" ]; then
	printf_red "$(<"/etc/casjaysdev/updates/versions/$SCRIPT_NAME.txt")"
	printf_red "To reinstall please remove the version file in"
	printf_red "/etc/casjaysdev/updates/versions/$SCRIPT_NAME.txt"
	exit 1
elif [ -f "/etc/casjaysdev/updates/versions/installed.txt" ]; then
	printf_red "$(<"/etc/casjaysdev/updates/versions/installed.txt")"
	printf_red "To reinstall please remove the version file in"
	printf_red "/etc/casjaysdev/updates/versions/installed.txt"
	exit 1
else
	run_init_check
	if ! retrieve_repo_file; then
		devnull rm_if_exists "/etc/casjaysdev/updates/versions/installed.txt"
		devnull rm_if_exists "/etc/casjaysdev/updates/versions/$SCRIPT_NAME.txt"
		printf_red "The script has failed to initialize"
		exit 2
	fi
	if [ ! -f "/etc/casjaysdev/updates/versions/os_version.txt" ]; then
		echo "$RELEASE_VER" >"/etc/casjaysdev/updates/versions/os_version.txt"
	fi
fi
if type -P systemmgr >/dev/null 2>&1; then
	run_external /usr/local/share/CasjaysDev/scripts/install.sh
	run_external /usr/local/share/CasjaysDev/scripts/bin/systemmgr --config
	run_external /usr/local/share/CasjaysDev/scripts/bin/systemmgr update scripts
	run_external "__yum clean"
fi
printf_green "Installer has been initialized"
##################################################################################################################
printf_head "Installing vnstat"
##################################################################################################################
install_pkg vnstat
system_service_enable vnstat && systemctl restart vnstat &>/dev/null
##################################################################################################################
printf_head "Configuring cores for compiling"
##################################################################################################################
numberofcores=$(grep -c ^processor /proc/cpuinfo)
printf_yellow "Total cores available: $numberofcores"
if [ $numberofcores -gt 1 ]; then
	if [ -f "/etc/makepkg.conf" ]; then
		sed -i 's/#MAKEFLAGS="-j2"/MAKEFLAGS="-j'$((numberofcores + 1))'"/g' /etc/makepkg.conf
		sed -i 's/COMPRESSXZ=(xz -c -z -)/COMPRESSXZ=(xz -c -T '"$numberofcores"' -z -)/g' /etc/makepkg.conf
	else
		cat <<EOF >"/etc/makepkg.conf"
#########################################################################
# ARCHITECTURE, COMPILE FLAGS
#########################################################################
CARCH="x86_64"
CHOST="x86_64-pc-linux-gnu"
CFLAGS="-march=x86-64 -mtune=generic -O2 -pipe -fno-plt -fexceptions -Wp,-D_FORTIFY_SOURCE=3 -Wformat -Werror=format-security -fstack-clash-protection -fcf-protection -fno-omit-frame-pointer -mno-omit-leaf-frame-pointer"
CXXFLAGS="\$CFLAGS -Wp,-D_GLIBCXX_ASSERTIONS"
LDFLAGS="-Wl,-O1 -Wl,--sort-common -Wl,--as-needed -Wl,-z,relro -Wl,-z,now -Wl,-z,pack-relative-relocs"
LTOFLAGS="-flto=auto"
RUSTFLAGS="-Cforce-frame-pointers=yes"
MAKEFLAGS="-j$((numberofcores + 1))"
DEBUG_CFLAGS="-g"
DEBUG_CXXFLAGS="\$DEBUG_CFLAGS"
DEBUG_RUSTFLAGS="-C debuginfo=2"
#########################################################################
# BUILD ENVIRONMENT
#########################################################################
BUILDENV=(!distcc color !ccache check !sign)
#DISTCC_HOSTS=""
#BUILDDIR=/tmp/makepkg
#########################################################################
# GLOBAL PACKAGE OPTIONS
#########################################################################
OPTIONS=(strip docs !libtool !staticlibs emptydirs zipman purge debug lto)
INTEGRITY_CHECK=(sha256)
STRIP_BINARIES="--strip-all"
STRIP_SHARED="--strip-unneeded"
STRIP_STATIC="--strip-debug"
MAN_DIRS=({usr{,/local}{,/share},opt/*}/{man,info})
DOC_DIRS=(usr/{,local/}{,share/}{doc,gtk-doc} opt/*/{doc,gtk-doc})
PURGE_TARGETS=(usr/{,share}/info/dir .packlist *.pod)
DBGSRCDIR="/usr/src/debug"
LIB_DIRS=('lib:usr/lib' 'lib32:usr/lib32')
#########################################################################
# COMPRESSION DEFAULTS
#########################################################################
COMPRESSGZ=(gzip -c -f -n)
COMPRESSBZ2=(bzip2 -c -f)
COMPRESSXZ=(xz -c -T $numberofcores -z -)
COMPRESSZST=(zstd -c -T0 --ultra -20 -)
COMPRESSLRZ=(lrzip -q)
COMPRESSLZO=(lzop -q)
COMPRESSZ=(compress -c -f)
COMPRESSLZ4=(lz4 -q)
COMPRESSLZ=(lzip -c -f)
#########################################################################
# END
#########################################################################
EOF
	fi
fi
##################################################################################################################
printf_head "Grabbing ssh key[s]: from $SSH_KEY_LOCATION for $USER"
##################################################################################################################
get_user_ssh_key
##################################################################################################################
printf_head "Configuring the system"
##################################################################################################################
retrieve_repo_file
run_external timedatectl set-timezone America/New_York
_oci_pkgs="$(rpm -qa 'oci*' 'cloud*' 'oracle*' 2>/dev/null)"
[ -n "$_oci_pkgs" ] && remove_pkg $_oci_pkgs
unset _oci_pkgs
remove_pkg chrony cronie-anacron sendmail sendmail-cf esmtp
# install_pkg cronie-noanacron  # skipped on ubuntu
install_pkg postfix
install_pkg net-tools
install_pkg wget
install_pkg curl
install_pkg git
install_pkg mailutils
install_pkg e2fsprogs
install_pkg vim
install_pkg unzip
install_pkg bind9
install_pkg dnsutils
rm_if_exists /tmp/dotfiles
rm_if_exists /root/anaconda-ks.cfg /var/log/anaconda
run_external "apt-get upgrade -y -q"
##################################################################################################################
printf_head "Enabling ip forwarding"
##################################################################################################################
sysctl_ip4_found=no
sysctl_ip6_found=no
shopt -s nullglob
for sysctlconf in /etc/sysctl.conf /etc/sysctl.d/*; do
	[ -f "$sysctlconf" ] || continue
	if grep -qsF 'net.ipv4.ip_forward' "$sysctlconf"; then
		devnull sed -i 's/net.ipv4.ip_forward.*/net.ipv4.ip_forward=1/g' "$sysctlconf"
		sysctl_ip4_found=yes
	fi
	if grep -qsF 'net.ipv6.conf.all.forwarding' "$sysctlconf"; then
		devnull sed -i 's/net.ipv6.conf.all.forwarding.*/net.ipv6.conf.all.forwarding=1/g' "$sysctlconf"
		sysctl_ip6_found=yes
	fi
done
shopt -u nullglob
[ "$sysctl_ip4_found" = "yes" ] || echo "net.ipv4.ip_forward=1" >>'/etc/sysctl.conf'
[ "$sysctl_ip6_found" = "yes" ] || echo "net.ipv6.conf.all.forwarding=1" >>'/etc/sysctl.conf'
unset sysctl_ip4_found sysctl_ip6_found sysctlconf
##################################################################################################################
printf_head "Installing the packages for $RELEASE_NAME"
##################################################################################################################
install_pkg awffull
install_pkg awstats
install_pkg base-files
install_pkg bash
install_pkg bash-completion
# install_pkg biosdevname  # skipped on ubuntu
install_pkg certbot
install_pkg cockpit
install_pkg cockpit-packagekit
install_pkg cockpit-storaged
install_pkg cockpit-pcp
# install_pkg cockpit-bridge  # skipped on ubuntu
# install_pkg cockpit-system  # skipped on ubuntu
# install_pkg cockpit-ws  # skipped on ubuntu
install_pkg coreutils
install_pkg cowsay
install_pkg libcrack2
install_pkg cracklib-runtime
install_pkg cron
# install_pkg cronie-noanacron  # skipped on ubuntu
install_pkg cron
install_pkg curl
install_pkg universal-ctags
install_pkg dialog
install_pkg docker-ce
install_pkg ethtool
install_pkg findutils
install_pkg fortune-mod
install_pkg gawk
install_pkg libgc-dev
install_pkg gcc
install_pkg git
install_pkg gnupg2
install_pkg libgnutls30
install_pkg grub-pc
# install_pkg grub2-tools-extra  # skipped on ubuntu
# install_pkg grubby  # skipped on ubuntu
install_pkg gzip
install_pkg hardlink
install_pkg libharfbuzz0b
install_pkg hdparm
install_pkg hostname
install_pkg htop
install_pkg apache2
install_pkg less
install_pkg logrotate
install_pkg lsof
install_pkg mailutils
install_pkg make
install_pkg man-db
install_pkg manpages
install_pkg mlocate
install_pkg libapache2-mod-fcgid
# install_pkg mod_geoip  # skipped on ubuntu
# install_pkg mod_http2  # skipped on ubuntu
# install_pkg mod_maxminddb  # skipped on ubuntu
install_pkg libapache2-mod-perl2
# install_pkg mod_ssl  # skipped on ubuntu
install_pkg libapache2-mod-wsgi-py3
# install_pkg mod_proxy_html  # skipped on ubuntu
install_pkg libapache2-mod-proxy-uwsgi
install_pkg mosh
install_pkg mrtg
install_pkg munin
install_pkg munin-common
install_pkg munin-node
install_pkg ncurses-base
install_pkg ncurses-base
install_pkg libncurses6
install_pkg net-tools
install_pkg nginx
install_pkg ntp
install_pkg libpam-mkhomedir
install_pkg openssh-server
install_pkg openssl
install_pkg passwd
install_pkg perl
install_pkg perl
install_pkg libdbd-pg-perl
install_pkg libdbd-mysql-perl
install_pkg libdbd-sqlite3-perl
install_pkg libdbd-mariadb-perl
# install_pkg perl-DBD-Firebird  # skipped on ubuntu
install_pkg php
install_pkg php-cli
install_pkg php-common
install_pkg php-fpm
install_pkg php-gd
install_pkg php-gmp
install_pkg php-intl
install_pkg php-mbstring
install_pkg php-mysqlnd
install_pkg php-pdo
install_pkg php-pgsql
install_pkg php-xml
install_pkg pinentry-curses
install_pkg postfix
# install_pkg postfix-pcre  # skipped on ubuntu
install_pkg python3-certbot-dns-rfc2136
install_pkg python3-configargparse
install_pkg python3-cryptography
# install_pkg python3-enum34  # skipped on ubuntu
# install_pkg python3-funcsigs  # skipped on ubuntu
install_pkg python3-future
install_pkg python3-idna
# install_pkg python3-josepy  # skipped on ubuntu
# install_pkg python3-mock  # skipped on ubuntu
install_pkg python3-pynvim
# install_pkg python3-parsedatetime  # skipped on ubuntu
# install_pkg python3-pbr  # skipped on ubuntu
install_pkg python3-pip
install_pkg python3-psutil
# install_pkg python3-pyasn1  # skipped on ubuntu
# install_pkg python3-pyrfc3339  # skipped on ubuntu
# install_pkg python3-pysocks  # skipped on ubuntu
install_pkg python3-requests
# install_pkg python3-six  # skipped on ubuntu
install_pkg python3-virtualenv
install_pkg libreadline-dev
# install_pkg rootfiles  # skipped on ubuntu
install_pkg rsync
install_pkg rsyslog
install_pkg screen
install_pkg sed
install_pkg sqlite3
install_pkg sudo
install_pkg symlinks
install_pkg tar
install_pkg tzdata
install_pkg unzip
install_pkg webalizer
install_pkg wget
install_pkg which
install_pkg whois
install_pkg xz-utils
install_pkg liblzma5
install_pkg apt-utils
install_pkg zip
install_pkg zlib1g
##################################################################################################################
printf_head "Installing version-specific packages"
##################################################################################################################
# Detect installed PHP version for dynamic config path construction
# (PHP paths in this script use ${PHP_VER} — set it before any config copy operations)
PHP_VER="$(php --version 2>/dev/null | awk 'NR==1{print $2}' | cut -d. -f1,2)"
[ -z "$PHP_VER" ] && PHP_VER="$(ls /etc/php/ 2>/dev/null | grep -E -- '^[0-9]' | sort -V | tail -1)"
[ -z "$PHP_VER" ] && PHP_VER="8.2"
# lsb-release: available on all supported Debian/Ubuntu versions
install_pkg lsb-release
##################################################################################################################
if [ "$SYSTEM_TYPE" = "dns" ]; then
	if devnull install_pkg ntp || devnull install_pkg ntpsec; then
		printf_cyan "Installed ntp"
		SERVICES_ENABLE="$SERVICES_ENABLE ntpd"
		[ -d "/var/lib/ntp/stats" ] || mkdir -p "/var/lib/ntp/stats"
	fi
else
	install_pkg chrony
	SERVICES_ENABLE="$SERVICES_ENABLE chrony"
fi
##################################################################################################################
printf_head "Fixing grub"
##################################################################################################################
run_grub
##################################################################################################################
printf_head "Installing custom web server files"
##################################################################################################################
[ -d "$CONFIG_TEMP_DIR" ] && devnull rm_if_exists "$CONFIG_TEMP_DIR"
devnull git clone -q "https://github.com/casjay-base/ubuntu" "$CONFIG_TEMP_DIR"
if [ -d "/var/www/html/sysinfo/.git" ]; then
	devnull git -C "/var/www/html/sysinfo" reset --hard
	run_post git -C "/var/www/html/sysinfo" pull -q
else
	devnull rm_if_exists "/var/www/html/sysinfo"
	run_post git clone -q "https://github.com/phpsysinfo/phpsysinfo" "/var/www/html/sysinfo"
fi
if [ -d "/var/www/html/vnstat/.git" ]; then
	devnull git -C "/var/www/html/vnstat" reset --hard
	run_post git -C "/var/www/html/vnstat" pull -q
else
	devnull rm_if_exists "/var/www/html/vnstat"
	run_post git clone -q "https://github.com/solbu/vnstat-php-frontend" "/var/www/html/vnstat"
fi
run_post_message="Installing default server files" run_post sudo -HE STATICSITE="$(hostname -f)" bash -c "$(curl -LSs "https://github.com/casjay-templates/default-web-assets/raw/main/setup.sh")"
[ -f "/etc/apache2/modules/mod_wsgi_python3.so" ] && ln -sf /etc/apache2/modules/mod_wsgi_python3.so /etc/apache2/modules/mod_wsgi.so
##################################################################################################################
printf_head "Deleting files"
##################################################################################################################
if system_service_active named || port_in_use "53"; then
	devnull rm_if_exists $CONFIG_TEMP_DIR/etc/bind*
	devnull rm_if_exists $CONFIG_TEMP_DIR/var/cache/bind*
else
	devnull rm_if_exists /etc/bind* /var/cache/bind/*
fi
if ! type -P ntp >/dev/null 2>&1 && ! type -P ntpd >/dev/null 2>&1 && ! type -P ntpq >/dev/null 2>&1; then
	devnull rm_if_exists /etc/ntp*
	devnull rm_if_exists $CONFIG_TEMP_DIR/etc/ntp*
fi
if ! type -P chronyd >/dev/null 2>&1; then
	devnull rm_if_exists /etc/chrony*
	devnull rm_if_exists $CONFIG_TEMP_DIR/etc/chrony*
fi
if ! type -P apache2 >/dev/null 2>&1; then
	IS_INSTALLED_HTTPD=no
	devnull rm_if_exists /etc/apache2*
	devnull rm_if_exists $CONFIG_TEMP_DIR/etc/apache2*
fi
if ! type -P nginx >/dev/null 2>&1; then
	IS_INSTALLED_NGINX=no
	devnull rm_if_exists /etc/nginx*
	devnull rm_if_exists $CONFIG_TEMP_DIR/etc/nginx*
fi
if ! type -P named >/dev/null 2>&1; then
	IS_INSTALLED_BIND=no
	devnull rm_if_exists /etc/bind*
	devnull rm_if_exists /var/cache/bind*
	devnull rm_if_exists $CONFIG_TEMP_DIR/etc/bind*
	devnull rm_if_exists $CONFIG_TEMP_DIR/var/cache/bind*
fi
if ! type -P proftpd >/dev/null 2>&1; then
	devnull rm_if_exists /etc/proftpd*
	devnull rm_if_exists $CONFIG_TEMP_DIR/etc/proftpd*
fi
if [ -f "/etc/certbot/dns.conf" ]; then
	devnull rm_if_exists "$CONFIG_TEMP_DIR/etc/certbot/dns.conf"
fi
for rm_file in /etc/cron*/0* /etc/cron*/dailyjobs /var/ftp/uploads /etc/apache2/conf.d/ssl.conf; do
	run_post devnull rm_if_exists "$rm_file"
done
##################################################################################################################
printf_head "setting up config files"
##################################################################################################################
set_domainname="$(domain_name)"
myhostnameshort="$SET_HOSTNAME"
myserverdomainname="$(hostname -f)"
NETDEV=""
while read -r _dev; do
	case "$_dev" in
		docker*|incus*|virbr*|lxcbr*|veth*|cni*|flannel*|weave*|tap*|tun*|wg*) continue ;;
		br-[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]) continue ;;
		*) NETDEV="$_dev"; break ;;
	esac
done < <(ip -4 route ls 2>/dev/null | awk '/^default/ {print $5}')
unset _dev

does_lo_have_ipv6=""
ip -6 addr show dev lo 2>/dev/null | grep -q '::1' && does_lo_have_ipv6="yes"

GET_WEB_USER="$(__get_www_user)"
GET_WEB_GROUP="$(__get_www_group)"

mycurrentipaddress_4=""
mycurrentipaddress_6=""
if [ -n "$NETDEV" ]; then
	mycurrentipaddress_4="$(ip -4 -o addr show "$NETDEV" 2>/dev/null | awk '{sub("/.*","",$4); print $4; exit}')"
	mycurrentipaddress_6="$(ip -6 -o addr show "$NETDEV" scope global 2>/dev/null | awk '{sub("/.*","",$4); print $4; exit}')"
fi
if [ -z "$mycurrentipaddress_4" ] || [ -z "$mycurrentipaddress_6" ]; then
	read -ra _ips < <(hostname -I 2>/dev/null)
	for _ip in "${_ips[@]}"; do
		if [[ "$_ip" == *:*:* ]]; then
			[ -z "$mycurrentipaddress_6" ] && [ "$_ip" != "::1" ] && mycurrentipaddress_6="$_ip"
		elif [[ "$_ip" == [0-9]*.[0-9]* ]]; then
			[ -z "$mycurrentipaddress_4" ] && [[ "$_ip" != 127.0.0.* ]] && [[ "$_ip" != 172.17.0.* ]] && mycurrentipaddress_4="$_ip"
		fi
	done
	unset _ips _ip
fi
mycurrentipaddress_4="${mycurrentipaddress_4:-127.0.0.1}"
mycurrentipaddress_6="${mycurrentipaddress_6:-::1}"
devnull find "$CONFIG_TEMP_DIR" -type f -iname "*.sh" -exec chmod 755 {} \;
devnull find "$CONFIG_TEMP_DIR" -type f -iname "*.pl" -exec chmod 755 {} \;
devnull find "$CONFIG_TEMP_DIR" -type f -iname "*.cgi" -exec chmod 755 {} \;
devnull find "$CONFIG_TEMP_DIR" -type f -iname ".gitkeep" -exec rm -Rf {} \;
devnull find "$CONFIG_TEMP_DIR" -type f -exec sed -i "s#mydomainname#$set_domainname#g" {} \;
devnull find "$CONFIG_TEMP_DIR" -type f -exec sed -i "s#myhostnameshort#$myhostnameshort#g" {} \;
devnull find "$CONFIG_TEMP_DIR" -type f -exec sed -i "s#myserverdomainname#$myserverdomainname#g" {} \;
devnull find "$CONFIG_TEMP_DIR" -type f -exec sed -i "s#mycurrentipaddress_6#$mycurrentipaddress_6#g" {} \;
devnull find "$CONFIG_TEMP_DIR" -type f -exec sed -i "s#mycurrentipaddress_4#$mycurrentipaddress_4#g" {} \;
if [ -n "$NETDEV" ]; then
	fix_network_device_name "$CONFIG_TEMP_DIR"
	if [ -f "/etc/sysconfig/network-scripts/ifcfg-eth0.sample" ]; then
		devnull mv -f "/etc/sysconfig/network-scripts/ifcfg-eth0.sample" "/etc/sysconfig/network-scripts/ifcfg-$NETDEV.sample"
	fi
fi
if [ -z "$does_lo_have_ipv6" ]; then
	sed -i 's|inet_interfaces.*|inet_interfaces = 127.0.0.1|g' $CONFIG_TEMP_DIR/etc/postfix/main.cf
fi
devnull rm_if_exists $CONFIG_TEMP_DIR/etc/{fail2ban,shorewall,shorewall6}
devnull mkdir -p /etc/rsync.d /var/log/named
devnull rsync -avhP $CONFIG_TEMP_DIR/{etc,root,usr,var}* /
devnull sed -i "s#myserverdomainname#$HOSTNAME#g" /etc/sysconfig/network
devnull sed -i "s#mydomain#$set_domainname#g" /etc/sysconfig/network
devnull chmod 644 -Rf /etc/cron.d/* /etc/logrotate.d/*
devnull touch /etc/postfix/mydomains.pcre
devnull chattr +i /etc/resolv.conf
if [ -z "$IS_INSTALLED_BIND" ]; then
	if does_user_exist 'named'; then
		devnull mkdir -p /etc/bind /var/cache/bind /var/log/named
		devnull chown -Rf named:named /etc/bind* /var/cache/bind /var/log/named
	fi
fi
if ! type -P postfix >/dev/null 2>&1; then
	rm_if_exists /etc/postfix
else
	for postfix_proto in "/etc/postfix"/*.proto; do
		devnull rm_if_exists $postfix_proto
	done
	devnull chgrp postdrop /usr/sbin/postqueue
	devnull chgrp postdrop /usr/sbin/postdrop
	devnull chgrp postdrop /var/spool/postfix/maildrop
	devnull chgrp postdrop /var/spool/postfix/public
	devnull chown root /var/spool/postfix/pid
	devnull chmod g+s /usr/sbin/postqueue
	devnull chmod g+s /usr/sbin/postdrop
	devnull killall -9 postdrop
	devnull postfix set-permissions create-missing
	devnull postmap /etc/postfix/transport /etc/postfix/canonical /etc/postfix/virtual /etc/postfix/mydomains /etc/postfix/sasl/passwd
	devnull newaliases &>/dev/null || newaliases.postfix -I &>/dev/null
fi
if ! grep -sq 'kernel.domainname' "/etc/sysctl.conf"; then
	echo "kernel.domainname=$set_domainname" >>/etc/sysctl.conf
fi
devnull systemctl daemon-reload
unset postfix_proto
##################################################################################################################
printf_head "Installing incus"
##################################################################################################################
incus_setup_failed="no"
# Install incus via upstream apt repository
if ! command -v incus >/dev/null 2>&1; then
	if ! grep -qsi 'zabbly' /etc/apt/sources.list.d/*.list 2>/dev/null; then
		printf_green "Enabling the incus repository"
		curl -fsSL https://pkgs.zabbly.com/key.asc | gpg --dearmor -o /etc/apt/keyrings/zabbly.gpg 2>/dev/null
		echo "deb [signed-by=/etc/apt/keyrings/zabbly.gpg] https://pkgs.zabbly.com/incus/stable $(. /etc/os-release && echo "$VERSION_CODENAME") main" \
			| tee /etc/apt/sources.list.d/zabbly-incus-stable.list >/dev/null
		DEBIAN_FRONTEND=noninteractive apt-get update -q &>/dev/null
	fi
	install_pkg incus
fi
echo "0:1000000:1000000000" | tee /etc/subuid /etc/subgid >/dev/null
if system_service_exists "incus"; then
	devnull systemctl start "incus"
	devnull systemctl restart "incus"
	devnull systemctl enable --now incus || incus_setup_failed="yes"
else
	incus_setup_failed=yes
fi
[ -n "$(find /var/lib/incus -mindepth 1 2>/dev/null)" ] || incus_setup_failed="yes"
if [ "$incus_setup_failed" = "no" ]; then
	if incus admin init --network-address 127.0.0.1 --network-port 60443 --storage-backend dir --quiet --auto; then
		devnull incus network set incusbr0 ipv4.firewall false
		devnull incus network set incusbr0 ipv6.firewall false
		devnull systemctl restart incus
		printf_blue "incus has been initialized"
		unset incus_setup_failed
	else
		incus_setup_failed="yes"
	fi
fi
##################################################################################################################
printf_head "Configuring the firewall"
##################################################################################################################
devnull apt-get install -y -q ufw
devnull ufw --force reset
devnull ufw default deny incoming
devnull ufw default allow outgoing
devnull ufw allow ssh
devnull ufw allow http
devnull ufw allow https
devnull ufw allow 60000:61000/udp
devnull ufw --force enable
##################################################################################################################
printf_head "Configuring applications"
##################################################################################################################
devnull timedatectl set-ntp true
##################################################################################################################
printf_head "Configuring cloudflare dns for $SET_HOSTNAME"
##################################################################################################################
[ -f "$HOME/.config/secure/cloudflare.txt" ] && . "$HOME/.config/secure/cloudflare.txt"
if [ -n "$CLOUDFLARE_EMAIL" ] && [ -n "$CLOUDFLARE_API_KEY" ] && [ -n "$CLOUDFLARE_ZONE_NAME" ] && type -P cloudflare >/dev/null 2>&1; then
	cf_args=()
	[ -n "$CLOUDFLARE_PROXY" ] && cf_args+=(--proxy "$CLOUDFLARE_PROXY")
	if devnull cloudflare update "$SET_HOSTNAME" "${cf_args[@]}"; then
		CLOUDFLARE_DOMAIN="yes"
		devnull cloudflare update "*.$SET_HOSTNAME" "${cf_args[@]}"
		printf_blue "Successfully updated $SET_HOSTNAME in $CLOUDFLARE_ZONE_NAME"
	elif devnull cloudflare create "$SET_HOSTNAME" "${cf_args[@]}"; then
		CLOUDFLARE_DOMAIN="yes"
		devnull cloudflare create "*.$SET_HOSTNAME" "${cf_args[@]}"
		printf_blue "Created $SET_HOSTNAME for $CLOUDFLARE_ZONE_NAME"
	else
		printf_red "Failed to create record $SET_HOSTNAME for zone $CLOUDFLARE_ZONE_NAME"
	fi
	unset cf_args
fi
if [ "$CLOUDFLARE_DOMAIN" = "yes" ] && [ "$CLOUDFLARE_PROXY" = "true" ]; then
	if [ -d "/etc/nginx/vhosts.d" ]; then
		cat <<EOF >"/etc/nginx/vhosts.d/$SET_HOSTNAME.$CLOUDFLARE_ZONE_NAME.conf"
server {
    listen                                  80;
    server_name                             $SET_HOSTNAME.$CLOUDFLARE_ZONE_NAME *.$SET_HOSTNAME.$CLOUDFLARE_ZONE_NAME;
    access_log                              /var/log/nginx/access.$SET_HOSTNAME.$CLOUDFLARE_ZONE_NAME.log;
    error_log                               /var/log/nginx/error.$SET_HOSTNAME.$CLOUDFLARE_ZONE_NAME.log info;

  location / {
    proxy_ssl_verify                        off;
    send_timeout                            3600;
    proxy_connect_timeout                   3600;
    proxy_send_timeout                      3600;
    proxy_read_timeout                      3600;
    proxy_http_version                      1.1;
    proxy_request_buffering                 off;
    proxy_buffering                         off;
    proxy_set_header                        Host               \$host;
    proxy_set_header                        X-Real-IP          \$remote_addr;
    proxy_set_header                        X-Forwarded-Proto  \$scheme;
    proxy_set_header                        X-Forwarded-Scheme \$scheme;
    proxy_set_header                        X-Forwarded-For    \$remote_addr;
    proxy_set_header                        X-Forwarded-Port   \$server_port;
    proxy_set_header                        Upgrade            \$http_upgrade;
    proxy_set_header                        Connection         \$connection_upgrade;
    proxy_set_header                        Accept-Encoding "";
    proxy_pass                              https://$HOSTNAME;
    }
}
EOF
	fi
	unset CLOUDFLARE_DOMAIN
fi
##################################################################################################################
printf_head "Setting up ssl certificates"
##################################################################################################################
## If using letsencrypt certificates
[ -f "$HOME/.config/myscripts/acme-cli/settings.conf" ] && . "$HOME/.config/myscripts/acme-cli/settings.conf"
le_primary_domain="$(hostname -d 2>/dev/null)"
le_primary_domain="${le_primary_domain:-$(hostname -f 2>/dev/null)}"
[[ "$le_primary_domain" == *[a-zA-Z0-9].[a-zA-Z0-9]* ]] || le_primary_domain=""
if [ -n "$le_primary_domain" ]; then
	le_options="--primary $le_primary_domain"
	le_domain_list="${ACME_CLI_DOMAIN_LIST:-$le_domains}"
	[ "$le_primary_domain" = "$HOSTNAME" ] || le_options=""
	if [ -f "/etc/certbot/dns.conf" ]; then
		chmod -f 600 "/etc/certbot/dns.conf"
		if command -v acme-cli >/dev/null 2>&1; then
			if [ -z "$le_domain_list" ]; then
				printf_cyan "Attempting to get certificates from letsencrypt for $le_primary_domain and *.$le_primary_domain"
				run_post acme-cli --init $le_options
			else
				printf_cyan "Attempting to get certificates from letsencrypt for $le_primary_domain and all domains in var: le_domain_list"
				run_post acme-cli --init --no-test --no-subs
			fi
		fi
	fi
	if [ -d "/etc/letsencrypt/live/$le_primary_domain" ] || [ -d "/etc/letsencrypt/live/domain" ]; then
		[ -d "/etc/letsencrypt/live/domain" ] || ln -sf "/etc/letsencrypt/live/$le_primary_domain" /etc/letsencrypt/live/domain
		find /etc/postfix /etc/apache2 /etc/nginx -type f -exec sed -i 's#/etc/ssl/CA/CasjaysDev/certs/localhost.crt#/etc/letsencrypt/live/domain/fullchain.pem#g' {} \;
		find /etc/postfix /etc/apache2 /etc/nginx -type f -exec sed -i 's#/etc/ssl/CA/CasjaysDev/private/localhost.key#/etc/letsencrypt/live/domain/privkey.pem#g' {} \;
		if [ -d "/etc/cockpit/ws-certs.d" ]; then
			devnull rm_if_exists "/etc/cockpit/ws-certs.d"/*
			cat /etc/letsencrypt/live/domain/fullchain.pem >/etc/cockpit/ws-certs.d/1-my-cert.cert
			cat /etc/letsencrypt/live/domain/privkey.pem >>/etc/cockpit/ws-certs.d/1-my-cert.key
		fi
		find "/etc/postfix" "/etc/apache2" "/etc/nginx" /etc/proftpd* -type f -exec sed -i 's#/etc/ssl/CA/CasjaysDev/certs/localhost.crt#/etc/letsencrypt/live/domain/fullchain.pem#g' {} \; 2>/dev/null
		find "/etc/postfix" "/etc/apache2" "/etc/nginx" /etc/proftpd* -type f -exec sed -i 's#/etc/ssl/CA/CasjaysDev/private/localhost.key#/etc/letsencrypt/live/domain/privkey.pem#g' {} \; 2>/dev/null
		if [ -d "/etc/letsencrypt/renewal-hooks/post" ]; then
			if [ ! -f "/etc/letsencrypt/renewal-hooks/post/exec.sh" ]; then
				cat <<EOF | tee "/etc/letsencrypt/renewal-hooks/post/system.sh" >/dev/null
#!/usr/bin/env sh
# Insert any custom commands you want executed after a new cert or upon renewal

EOF
			fi
			cat <<EOF | tee "/etc/letsencrypt/renewal-hooks/post/system.sh" >/dev/null
#!/usr/bin/env sh
cat "/etc/letsencrypt/live/domain/privkey.pem" >"/etc/ssl/certs/\$HOSTNAME.key"
cat "/etc/letsencrypt/live/domain/fullchain.pem" >"/etc/ssl/certs/\$HOSTNAME.cert"
EOF

			cat <<EOF | tee "/etc/letsencrypt/renewal-hooks/post/cockpit.sh" >/dev/null
#!/usr/bin/env sh
cat "/etc/letsencrypt/live/domain/privkey.pem" >"/etc/cockpit/ws-certs.d/1-my-cert.key"
cat "/etc/letsencrypt/live/domain/fullchain.pem" >"/etc/cockpit/ws-certs.d/1-my-cert.cert"
systemctl is-enabled cockpit >/dev/null 2>&1 && systemctl restart cockpit >/dev/null 2>&1

EOF
			cat <<EOF | tee "/etc/letsencrypt/renewal-hooks/post/nginx.sh" >/dev/null
#!/usr/bin/env sh
systemctl is-enabled nginx >/dev/null 2>&1 && systemctl reload nginx >/dev/null 2>&1

EOF

			cat <<EOF | tee "/etc/letsencrypt/renewal-hooks/post/httpd.sh" >/dev/null
#!/usr/bin/env sh
systemctl is-enabled apache2 >/dev/null 2>&1 && systemctl reload apache2 >/dev/null 2>&1

EOF

			cat <<EOF | tee "/etc/letsencrypt/renewal-hooks/post/postfix.sh" >/dev/null
#!/usr/bin/env sh
systemctl is-enabled postfix >/dev/null 2>&1 && systemctl reload postfix >/dev/null 2>&1

EOF
			if [ -d "/opt/openfire/resources/security" ]; then
				cat <<EOF | tee "/etc/letsencrypt/renewal-hooks/post/openfire.sh" >/dev/null
#!/usr/bin/env sh
privkey="\$(realpath "/etc/letsencrypt/live/domain/privkey.pem")"
fullchain="\$(realpath "/etc/letsencrypt/live/domain/fullchain.pem")"
openfireSSL="/opt/openfire/resources/security/hotdeploy"
[ -d "\$openfireSSL" ] || mkdir -p "\$openfireSSL"
cat "\$fullchain" >"\$openfireSSL/casjay-social-cert.pem"
cat "\$privkey" >"\$openfireSSL/casjay-social-privkey.pem"
chown -R daemon /opt/openfire/resources/security/hotdeploy
systemctl is-enabled openfire >/dev/null 2>&1 && systemctl restart openfire >/dev/null 2>&1

EOF
			fi
			chmod +x "/etc/letsencrypt/renewal-hooks/post"/*
		fi
		printf_blue "letsencrypt certificates have been created"
	else
		copy_ca_certs
	fi
else
	copy_ca_certs
fi
if [ -f "/etc/ssl/CA/CasjaysDev/certs/ca.crt" ]; then
	if [ -d "/usr/local/share/ca-certificate" ]; then
		cp -Rf "/etc/ssl/CA/CasjaysDev/certs/ca.crt" "/usr/local/share/ca-certificate/"
	elif [ -d "/etc/pki/ca-trust/source/anchors" ]; then
		cp -Rf "/etc/ssl/CA/CasjaysDev/certs/ca.crt" "/etc/pki/ca-trust/source/anchors/"
	elif [ -d "/etc/pki/ca-trust/source" ]; then
		cp -Rf "/etc/ssl/CA/CasjaysDev/certs/ca.crt" "/etc/pki/ca-trust/source/"
	fi
fi
type -P update-ca-certificates >/dev/null 2>&1 && devnull update-ca-certificates && devnull update-ca-certificates extract
type -P dpkg-reconfigure >/dev/null 2>&1 && devnull dpkg-reconfigure ca-certificates
##################################################################################################################
printf_head "Setting up munin-node"
##################################################################################################################
mkdir -p "/var/log/munin"
chmod -f 777 "/var/log/munin"
does_user_exist 'munin' && chown -Rf "munin" "/var/log/munin"
does_group_exist "munin" && chgrp -Rf "munin" "/var/log/munin"
does_user_exist 'munin-node' && chown -Rf "munin" "/var/log/munin-node"
does_group_exist "munin-node" && chgrp -Rf "munin" "/var/log/munin-node"
run_post "munin-node-configure --remove-also --shell" >/dev/null 2>/dev/null
##################################################################################################################
printf_head "Setting up tor"
##################################################################################################################
if type -P tor >/dev/null 2>&1; then
	devnull systemctl restart tor && sleep 5
	tor_hostnames="$(find "/var/lib/tor/hidden_service" -type f -name 'hostname' 2>/dev/null)"
	if [ -n "$tor_hostnames" ]; then
		devnull rm_if_exists "/var/www/html/tor_hostname"
		for f in $tor_hostnames; do
			cat "$f" >>"/var/www/html/tor_hostname" 2>/dev/null
		done
	fi
	printf '%s\n%s\n' "# Generate tor hostnames" "#30 * * * * root " >"/etc/cron.d/tor_hostname"
fi
##################################################################################################################
printf_head "Setting up bind dns [named]"
##################################################################################################################
if ! command -v named >/dev/null 2>&1; then
	devnull rm_if_exists /etc/bind
	devnull rm_if_exists /var/cache/bind
	devnull rm_if_exists /var/log/named
	devnull rm_if_exists /etc/logrotate.d/named
fi
##################################################################################################################
printf_head "Generating default webserver for $HOSTNAME"
##################################################################################################################
if [ -z "$IS_INSTALLED_HTTPD" ] || [ -z "$IS_INSTALLED_NGINX" ]; then
	if [ -d "/var/www/nginx/domains/$HOSTNAME" ]; then
		printf_blue "Server directory already exists"
	else
		devnull gen-nginx --config
		devnull gen-nginx php $HOSTNAME
		if [ -d "/var/www/nginx/domains/$HOSTNAME" ]; then
			printf_green "Created server in /var/www/nginx/domains/$HOSTNAME"
		else
			printf_red "Failed to create default server"
		fi
	fi
fi
if [ -f "/etc/apache2/conf/httpd.conf" ]; then
	sed -i 's|ServerTokens .*|ServerTokens Prod|g' "/etc/apache2/conf/httpd.conf"
fi
if [ -n "$GET_WEB_USER" ]; then
	if [ -f "/etc/nginx/nginx.conf" ]; then
		sed -i '0,/^user .*/s//user  '$GET_WEB_USER';/' "/etc/nginx/nginx.conf"
		grep -sqh "^user  $GET_WEB_USER" "/etc/nginx/nginx.conf" || echo "Failed to change the user in /etc/nginx/nginx.conf"
	fi
	if [ -f "/etc/php/${PHP_VER}/fpm/pool.d/www.conf" ]; then
		sed -i '0,/^user .*/s//user = '$GET_WEB_USER'/' "/etc/php/${PHP_VER}/fpm/pool.d/www.conf"
		grep -sqh "^user = $GET_WEB_USER" "/etc/php/${PHP_VER}/fpm/pool.d/www.conf" || echo "Failed to change the user in /etc/php/${PHP_VER}/fpm/pool.d/www.conf"
	fi
	if [ -f "/etc/apache2/conf/httpd.conf" ]; then
		sed -i '0,/^User .*/s//User '$GET_WEB_USER'/' "/etc/apache2/conf/httpd.conf"
		grep -sqh "^User $GET_WEB_USER" "/etc/apache2/conf/httpd.conf" || echo "Failed to change the user in /etc/apache2/conf/httpd.conf"
	fi
	for apache_dir in "/usr/local/share/httpd" "/var/www"; do
		[ -d "$apache_dir" ] && chown -Rf $GET_WEB_USER "$apache_dir"
	done
fi
if [ -n "$GET_WEB_GROUP" ]; then
	if [ -f "/etc/php/${PHP_VER}/fpm/pool.d/www.conf" ]; then
		sed -i '0,/^group .*/s//group = '$GET_WEB_GROUP'/' "/etc/php/${PHP_VER}/fpm/pool.d/www.conf"
		grep -sqh "^group = $GET_WEB_GROUP" "/etc/php/${PHP_VER}/fpm/pool.d/www.conf" || echo "Failed to change the group in /etc/php/${PHP_VER}/fpm/pool.d/www.conf"
	fi
	if [ -f "/etc/apache2/conf/httpd.conf" ]; then
		sed -i '0,/^Group .*/s//Group '$GET_WEB_GROUP'/' "/etc/apache2/conf/httpd.conf"
		grep -sqh "^Group $GET_WEB_GROUP" "/etc/apache2/conf/httpd.conf" || echo "Failed to change the group in /etc/apache2/conf/httpd.conf"
	fi
	for apache_dir in "/usr/local/share/httpd" "/var/www"; do
		[ -d "$apache_dir" ] && chgrp -Rf $GET_WEB_GROUP "$apache_dir"
	done
fi
##################################################################################################################
printf_head "Setting up the reverse proxy for cockpit"
##################################################################################################################
if [ -d "/etc/nginx/vhosts.d" ]; then
	cat <<EOF | tee "/etc/nginx/vhosts.d/cockpit.$set_domainname.conf" >/dev/null
# reverse proxy for cockpit.$set_domainname
# upstream cockpit { server https://localhost:41443 fail_timeout=0; }

server {
  listen                                    443 ssl;
  listen                                    [::]:443 ssl;
  server_name                               cockpit.$set_domainname;
  access_log                                /var/log/nginx/access.cockpit.$set_domainname.log;
  error_log                                 /var/log/nginx/error.cockpit.$set_domainname.log info;
  keepalive_timeout                         75 75;
  client_max_body_size                      0;
  chunked_transfer_encoding                 on;
  add_header Strict-Transport-Security      "max-age=7200";
  ssl_protocols                             TLSv1.1 TLSv1.2;
  ssl_ciphers                               'EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH';
  ssl_prefer_server_ciphers                 on;
  ssl_session_cache                         shared:SSL:10m;
  ssl_session_timeout                       1d;
  ssl_certificate                           /etc/letsencrypt/live/domain/fullchain.pem;
  ssl_certificate_key                       /etc/letsencrypt/live/domain/privkey.pem;

  location / {
    proxy_ssl_verify                        off;
    send_timeout                            3600;
    proxy_connect_timeout                   3600;
    proxy_send_timeout                      3600;
    proxy_read_timeout                      3600;
    proxy_http_version                      1.1;
    proxy_request_buffering                 off;
    proxy_buffering                         off;
    proxy_set_header                        Host               \$host;
    proxy_set_header                        X-Real-IP          \$remote_addr;
    proxy_set_header                        X-Forwarded-Proto  \$scheme;
    proxy_set_header                        X-Forwarded-Scheme \$scheme;
    proxy_set_header                        X-Forwarded-For    \$remote_addr;
    proxy_set_header                        X-Forwarded-Port   \$server_port;
    proxy_set_header                        Upgrade            \$http_upgrade;
    proxy_set_header                        Connection         \$connection_upgrade;
    proxy_set_header                        Accept-Encoding "";
    proxy_redirect                          http:// https://;
    proxy_pass                              https://localhost:41443;
    }
}

EOF
fi
##################################################################################################################
printf_head "Creating directories"
##################################################################################################################
mkdir -p "/mnt/backups" "/var/www/html/.well-known" "/etc/letsencrypt/live"
echo "" >>/etc/fstab
if [ -n "$IS_NETWORK_INTERNAL" ] && devnull ping -q -W 1 -c 2 10.0.254.1; then
	{
		echo "10.0.254.1:/mnt/Volume_1/backups         /mnt/backups                 nfs defaults,rw 0 0"
		echo "10.0.254.1:/etc/letsencrypt              /etc/letsencrypt             nfs defaults,rw 0 0"
		echo "10.0.254.1:/var/www/html/.well-known     /var/www/html/.well-known    nfs defaults,rw 0 0"
	} >>/etc/fstab
fi
mount -a
##################################################################################################################
printf_head "Installing custom system configs"
##################################################################################################################
run_post "systemmgr install $SYSTEMMGR_CONFIGS"
##################################################################################################################
printf_head "Installing custom dotfiles"
##################################################################################################################
run_post "dfmgr update $DFMGR_CONFIGS"
##################################################################################################################
printf_head "Updating personal dotfiles"
##################################################################################################################
if [ -x "$HOME/.local/dotfiles/personal/install.sh" ]; then
	run_external "$HOME/.local/dotfiles/personal/install.sh"
fi
[ -f "$HOME/.bashrc" ] && . "$HOME/.bashrc"
[ -f "$HOME/.profile" ] && . "$HOME/.profile"
##################################################################################################################
if [ "$SYSTEM_TYPE" = "vpn" ]; then
	printf_head "Disabling services: httpd,nginx"
	system_service_disable httpd
	system_service_disable nginx
fi
if [ "$SYSTEM_TYPE" = "mail" ]; then
	if [ -x "$HOME/Projects/github/dfprivate/email/install.sh" ]; then
		printf_head "Running installer script for email server"
		eval "$HOME/Projects/github/dfprivate/email/install.sh" >/dev/null 2>&1
	fi
elif [ "$SYSTEM_TYPE" = "db" ] || [ "$set_domainname" = "sqldb.us" ]; then
	if [ -x "$HOME/Projects/github/dfprivate/sql/install.sh" ]; then
		printf_head "Running installer script for database server"
		eval "$HOME/Projects/github/dfprivate/sql/install.sh" >/dev/null 2>&1
	fi
elif [ "$SYSTEM_TYPE" = "dns" ] || [ "$set_domainname" = "casjaydns.com" ]; then
	if [ -x "$HOME/Projects/github/dfprivate/dns/install.sh" ]; then
		printf_head "Running installer script for dns server"
		eval "$HOME/Projects/github/dfprivate/dns/install.sh" >/dev/null 2>&1
	fi
fi
##################################################################################################################
printf_head "Enabling services"
##################################################################################################################
for service_enable in $SERVICES_ENABLE; do
	if [ -n "$service_enable" ] && system_service_exists "$service_enable"; then
		system_service_enable $service_enable
		systemctl restart $service_enable >/dev/null 2>&1
	fi
done
##################################################################################################################
printf_head "Disabling services"
##################################################################################################################
for service_disable in $SERVICES_DISABLE; do
	if [ -n "$service_disable" ] && system_service_exists "$service_disable"; then
		system_service_disable $service_disable
	fi
done
##################################################################################################################
printf_head "Setting up docker"
##################################################################################################################
if type -P dockermgr >/dev/null 2>&1; then
	system_service_enable docker
	devnull systemctl restart docker
	run_post dockermgr init && devnull dockermgr init
fi
if type -P composemgr >/dev/null 2>&1; then
	run_post composemgr --config && devnull composemgr --env
fi
##################################################################################################################
printf_head "Disabling dnsmasq"
##################################################################################################################
system_service_disable dnsmasq
devnull systemctl mask dnsmasq
devnull sed -i 's/^dns=dnsmasq/#&/' /etc/NetworkManager/NetworkManager.conf
# Do not killall dnsmasq - libvirt, incus, and docker each spawn their own dnsmasq
# instance for their bridge networks; killing them breaks DHCP/DNS for VMs/containers
##################################################################################################################
printf_head "Fixing ip address"
##################################################################################################################
/root/bin/changeip.sh >/dev/null 2>&1
##################################################################################################################
printf_head "Setting up accounts"
##################################################################################################################
SETUP_ACCOUNT_NEXT_UID="$SETUP_ACCOUNT_BASE_UID"
if [ -n "$SETUP_ACCOUNT_ADMIN" ]; then
	__create_account "$SETUP_ACCOUNT_ADMIN" "$SETUP_ACCOUNT_NEXT_UID" "yes"
	SETUP_ACCOUNT_NEXT_UID=$((SETUP_ACCOUNT_NEXT_UID + 1))
fi
if [ -n "$SETUP_ACCOUNT_USERS" ]; then
	for user_spec in ${SETUP_ACCOUNT_USERS//,/ }; do
		[ -z "$user_spec" ] && continue
		__create_account "$user_spec" "$SETUP_ACCOUNT_NEXT_UID" "no"
		SETUP_ACCOUNT_NEXT_UID=$((SETUP_ACCOUNT_NEXT_UID + 1))
	done
fi
unset user_spec SETUP_ACCOUNT_NEXT_UID
##################################################################################################################
printf_head "Cleaning up"
##################################################################################################################
[ -f "/etc/yum/pluginconf.d/subscription-manager.conf" ] && echo "" >"/etc/yum/pluginconf.d/subscription-manager.conf"
find "/etc" "/usr" "/var" -iname '*.rpmnew' -exec rm -Rf {} \; >/dev/null 2>&1
find "/etc" "/usr" "/var" -iname '*.rpmsave' -exec rm -Rf {} \; >/dev/null 2>&1
devnull rm -Rf /tmp/*.tar "/tmp/dotfiles" "$CONFIG_TEMP_DIR"
devnull retrieve_repo_file
history -c && history -w
##################################################################################################################
printf_head "Installer version: $(retrieve_version_file)"
##################################################################################################################
mkdir -p "/etc/casjaysdev/updates/versions"
echo "$VERSION" >"/etc/casjaysdev/updates/versions/configs.txt"
date +'Installed on %Y-%m-%d at %H:%M' >"/etc/casjaysdev/updates/versions/installed.txt"
echo "Installed on $(date +'%Y-%m-%d at %H:%M %Z')" >"/etc/casjaysdev/updates/versions/$SCRIPT_NAME.txt"
chmod -Rf 664 "/etc/casjaysdev/updates/versions/configs.txt"
chmod -Rf 664 "/etc/casjaysdev/updates/versions/installed.txt"
##################################################################################################################
printf_head "Finished configuring $HOSTNAME"
echo ""
##################################################################################################################
if [ "${#SETUP_ACCOUNT_CREDS[@]}" -gt 0 ]; then
	printf_head "Account credentials"
	pad=0
	for entry in "${SETUP_ACCOUNT_CREDS[@]}"; do
		u="${entry%%:*}"
		[ "${#u}" -gt "$pad" ] && pad="${#u}"
	done
	pad=$((pad + 2))
	for entry in "${SETUP_ACCOUNT_CREDS[@]}"; do
		u="${entry%%:*}"
		p="${entry#*:}"
		printf "%-${pad}s : %s\n" "$u" "$p"
	done
	echo ""
	unset entry pad u p
fi
unset SETUP_ACCOUNT_CREDS
##################################################################################################################
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
exit
# end
