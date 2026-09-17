#!/usr/bin/env bash
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202609131048-git
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
VERSION="202609131048-git"
USER="${SUDO_USER:-${USER}}"
HOME="${USER_HOME:-${HOME}}"
CONFIG_TEMP_DIR="${TMPDIR:-/tmp}/minConfigFiles"
PKMGR_FORCE_INSTALL="${PKMGR_FORCE_INSTALL:-no}"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Set bash options
if [ "$1" = "--debug" ]; then shift 1 && set -xo pipefail && export SCRIPT_OPTS="--debug" && export _DEBUG="on"; fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
clear
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
# Vendored from casjay-dotfiles/scripts system-installer.bash (self-contained,
# no network fetch) - only the functions this script actually calls.
if [ -n "${NO_COLOR+x}" ] || [ "$SHOW_RAW" = "true" ]; then
	__printf_color() { printf '%b' "$1" | tr -d '\t'; }
else
	__printf_color() { printf "%b" "$(tput setaf "$2" 2>/dev/null)" "$1" "$(tput sgr0 2>/dev/null)"; }
fi
__printf_green() { __printf_color "$1\n" 2; }
__printf_red() { __printf_color "$1\n" 208; }
__printf_yellow() { __printf_color "$1\n" 3; }
__printf_blue() { __printf_color "$1\n" 33; }
__printf_cyan() { __printf_color "$1\n" 6; }
__printf_exit() {
	__printf_color "$1\n" 208 1>&2
	exit 1
}
__printf_execute_success() { __printf_color "[ ✔ ] $1 \n" 2; }
__printf_execute_error() { __printf_color "[ ✖ ] $1 $2 \n" 1; }
__printf_execute_error_stream() { while read -r line; do __printf_execute_error "↳ ERROR: $line"; done; }
__printf_execute_result() {
	if [ "$1" -eq 0 ]; then __printf_execute_success "$2"; else __printf_execute_error "$2"; fi
	return "$1"
}
__printf_return() {
	test -n "$1" && test -z "${1//[0-9]/}" && local color="$1" && shift 1 || local color="208"
	test -n "$1" && test -z "${1//[0-9]/}" && local exitCode="$1" && shift 1 || local exitCode="1"
	local msg="$*"
	[ ${#msg} = 0 ] || { __printf_color "$msg" "$color" 1>&2 && printf "\n"; }
	return ${exitCode:-2}
}
__urlcheck() { __devnull curl --output /dev/null --silent --head --fail "$1"; }
__urlinvalid() {
	if [ -z "$1" ]; then
		__printf_red "Invalid URL\n"
	else
		__printf_red "Can't find $1\n"
	fi
	exit 1
}
__urlverify() { __urlcheck $1 || __urlinvalid $1; }
__setexitstatus() {
	EXIT="${EXIT:-$?}"
	local EXITSTATUS+="$EXIT"
	if [ -z "$EXITSTATUS" ] || [ "$EXITSTATUS" -ne 0 ]; then
		BG_EXIT="${BG_RED}"
		return 1
	else
		BG_EXIT="${BG_GREEN}"
		return 0
	fi
}
__set_trap() { trap -p "$1" | grep -- "$2" &>/dev/null || trap "$2" "$1"; }
__execute() {
	__kill_all_subprocesses() {
		local i=""
		for i in $(jobs -p); do
			kill "$i"
			wait "$i" &>/dev/null
		done
	}
	__show_spinner() {
		local -r FRAMES='/-\|'
		local -r NUMBER_OR_FRAMES=${#FRAMES}
		local -r CMDS="$2"
		local -r MSG="$3"
		local -r PID="$1"
		local i=0
		local frameText=""
		if [ "$TRAVIS" != "true" ]; then
			printf "\n\n\n"
			tput cuu 3
			tput sc
		fi
		while kill -0 "$PID" &>/dev/null; do
			frameText="[ ${FRAMES:i++%NUMBER_OR_FRAMES:1} ] $MSG"
			if [ "$TRAVIS" != "true" ]; then
				printf "%s\n" "$frameText"
			else
				printf "%s" "$frameText"
			fi
			sleep 0.2
			if [ "$TRAVIS" != "true" ]; then
				tput rc
			else
				printf "\r"
			fi
		done
	}
	local -r CMDS="$1"
	local -r MSG="${2:-$1}"
	local -r TMP_FILE="$(mktemp /tmp/XXXXX)"
	local exitCode=0
	local cmdsPID=""
	__set_trap "EXIT" "__kill_all_subprocesses"
	eval "$CMDS" >/dev/null 2>"$TMP_FILE" &
	cmdsPID=$!
	__show_spinner "$cmdsPID" "$CMDS" "$MSG"
	wait "$cmdsPID" &>/dev/null
	exitCode=$?
	__printf_execute_result $exitCode "$MSG"
	if [ $exitCode -ne 0 ]; then
		__printf_execute_error_stream <"$TMP_FILE"
	fi
	rm -rf "$TMP_FILE"
	return $exitCode
}
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
__printf_blue "System setup completed continuing setup" && sleep 3 && clear
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
				if ! grep -qs -- "$swap_dir/$swap_file" /etc/fstab; then
					echo "$swap_dir/$swap_file          swap        swap             defaults          0 0" | tee -a /etc/fstab >/dev/null
				fi
			fi
		fi
		unset SWAP_SIZE swap_file_size swap_file swap_dir mem_kb mem_kb_padded mem_gb disk_avail_kb disk_avail_gb max_swap_mb
		swapon --show 2>/dev/null | grep -v -- '^NAME ' | grep -q -- '^' && echo "Swap has been enabled"
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
SCRIPT_OS="RHEL/AlmaLinux/Rocky/Oracle/CentOS"
SCRIPT_DESCRIBE="Minimal"
PKMGR_GITHUB_USER="${PKMGR_GITHUB_USER:-casjay}"
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
RELEASE_ID="$(. /etc/os-release 2>/dev/null; echo "${ID,,}")"
RELEASE_TYPE="$(
	. /etc/os-release 2>/dev/null
	i="${ID,,}"
	l=" ${ID_LIKE,,} "
	if [ "$i" = "rhel" ] || [ "$i" = "ubuntu" ] || [ "$i" = "ol" ] || [[ "$l" == *" rhel "* ]] || [[ "$l" == *" centos "* ]]; then
		echo ""
	fi
)"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
PKMGR_DEFAULT_KERNEL="${PKMGR_DEFAULT_KERNEL:-kernel-ml}"
ARCH="$(uname -m | tr '[:upper:]' '[:lower:]')"
BACKUP_DIR="$HOME/Documents/backups/$(date +'%Y/%m/%d')"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
PKMGR_SSH_KEY_LOCATION="${PKMGR_SSH_KEY_LOCATION:-https://github.com/$PKMGR_GITHUB_USER.keys}"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
PKMGR_SETUP_ACCOUNT_ADMIN="${PKMGR_SETUP_ACCOUNT_ADMIN:-administrator:random}"
PKMGR_SETUP_ACCOUNT_USERS="${PKMGR_SETUP_ACCOUNT_USERS:-}"
PKMGR_SETUP_ACCOUNT_BASE_UID="${PKMGR_SETUP_ACCOUNT_BASE_UID:-10000}"
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
if [ "$RELEASE_TYPE" != "rhel" ]; then
	__printf_exit "This installer is meant to be run on a $SCRIPT_OS based system"
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
[ "$1" == "--help" ] && __printf_exit "${GREEN}${SCRIPT_DESCRIBE} installer for $SCRIPT_OS${NC}"
__devnull() { "$@" >/dev/null 2>&1; }
__port_in_use() { netstatg 2>&1 | awk '{print $4}' | grep -- ':[0-9]' | awk -F':' '{print $2}' | grep -- '[0-9]' | grep -q -- "^$1$" || return 2; }
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__system_service_exists() { systemctl status "$1" 2>&1 | grep -- 'Loaded:' | grep -iq -- "$1" && return 0 || return 1; }
__system_service_active() { (systemctl is-enabled "$1" || systemctl is-active "$1") | grep -qiE -- 'enabled|active' || return 1; }
__system_service_enable() { systemctl is-enabled --quiet "$1" 2>/dev/null || __execute "systemctl enable --now $1" "Enabling service: $1" || return 1; }
__system_service_disable() { systemctl is-active --quiet "$1" && __execute "systemctl disable --now $1" "Disabling service: $1" || return 1; }
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__does_user_exist() { grep -qs -- "^$1:" "/etc/passwd" || return 1; }
__does_group_exist() { grep -qs -- "^$1:" "/etc/group" || return 1; }
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__get_www_user() {
	local u=""
	while IFS=: read -r u _; do
		case "$u" in www-data|apache|nginx) echo "$u"; return 0 ;; esac
	done </etc/passwd
	return 1
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__get_www_group() {
	local g=""
	while IFS=: read -r g _; do
		case "$g" in www-data|apache|nginx) echo "$g"; return 0 ;; esac
	done </etc/group
	return 1
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__copy_ca_certs() {
	local ssl_cn="" ssl_key="/etc/ssl/CA/CasjaysDev/private/localhost.key" ssl_crt="/etc/ssl/CA/CasjaysDev/certs/localhost.crt"
	if [ ! -d "/etc/letsencrypt/live/domain" ] || [ ! -L "/etc/letsencrypt/live/domain" ]; then
		__printf_red "letsencrypt seemed to have failed: Installing self-signed certificates"
		mkdir -p "/etc/letsencrypt/live/domain" "/etc/ssl/CA/CasjaysDev/private" "/etc/ssl/CA/CasjaysDev/certs"
		# casjay-base ships a committed key/cert pair at this path - this is only a
		# fallback for the rare case it's missing on the deployed host
		if [ ! -s "$ssl_key" ] || [ ! -s "$ssl_crt" ]; then
			ssl_cn="$(hostname -f 2>/dev/null || hostname 2>/dev/null || echo 'localhost')"
			__printf_cyan "Generating a self-signed certificate for $ssl_cn"
			__devnull openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes -keyout "$ssl_key" -out "$ssl_crt" \
				-subj "/CN=$ssl_cn" -addext "subjectAltName=DNS:$ssl_cn,DNS:localhost,IP:127.0.0.1" ||
				__printf_red "Failed to generate a self-signed certificate"
		fi
		chmod -f 600 "$ssl_key"
		chmod -f 644 "$ssl_crt"
		# cert.pem must be the leaf certificate that matches $ssl_key - it
		# was previously set to the CA cert instead, which left cert.pem
		# and privkey.pem as a non-matching pair (apache2: AH02565)
		[ -f "$ssl_crt" ] && cp -Rf "$ssl_crt" "/etc/letsencrypt/live/domain/cert.pem"
		[ -f "/etc/ssl/CA/CasjaysDev/certs/ca.crt" ] && cp -Rf "/etc/ssl/CA/CasjaysDev/certs/ca.crt" "/etc/letsencrypt/live/domain/chain.pem"
		if [ -f "$ssl_crt" ] && [ -f "/etc/ssl/CA/CasjaysDev/certs/ca.crt" ]; then
			cat "$ssl_crt" "/etc/ssl/CA/CasjaysDev/certs/ca.crt" >"/etc/letsencrypt/live/domain/fullchain.pem"
		elif [ -f "$ssl_crt" ]; then
			cp -Rf "$ssl_crt" "/etc/letsencrypt/live/domain/fullchain.pem"
		fi
		[ -f "$ssl_key" ] && cp -Rf "$ssl_key" "/etc/letsencrypt/live/domain/privkey.pem"
		find "/etc/letsencrypt" -type f -exec chmod 644 {} \;
		find "/etc/letsencrypt" -type d -exec chmod 755 {} \;
		chmod -f 600 "/etc/letsencrypt/live/domain/privkey.pem"
		# Cockpit loads every pair in ws-certs.d - the key must stay owner-only
		if [ -d "/etc/cockpit/ws-certs.d" ] && [ -s "$ssl_key" ]; then
			cp -f "$ssl_crt" "/etc/cockpit/ws-certs.d/1-my-cert.cert"
			cp -f "$ssl_key" "/etc/cockpit/ws-certs.d/1-my-cert.key"
			chmod -f 644 "/etc/cockpit/ws-certs.d/1-my-cert.cert"
			chmod -f 600 "/etc/cockpit/ws-certs.d/1-my-cert.key"
		fi
	fi
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__dnf_yum() {
	DEBIAN_FRONTEND=noninteractive apt-get -y -q "$@"
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__test_pkg() {
	for pkg in "$@"; do
		if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "ok installed"; then
			__printf_blue "[ ✔ ] $pkg is already installed"
			return 1
		else
			return 0
		fi
	done
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__remove_pkg() {
	local pkg=""
	for pkg in "$@"; do
		if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "ok installed"; then
			__execute "DEBIAN_FRONTEND=noninteractive apt-get remove -y -q $pkg" "Removing: $pkg"
		fi
	done
	return 0
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__install_pkg() {
	local statusCode=0
	if __test_pkg "$*"; then
		__execute "DEBIAN_FRONTEND=noninteractive apt-get install -y -q $*" "Installing: $*"
		__test_pkg "$*" &>/dev/null && statusCode=1 || statusCode=0
	else
		statusCode=0
	fi
	return $statusCode
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__detect_selinux() {
	return 0
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__disable_selinux() {
	__printf_blue "SELinux not applicable on this distro — skipping"
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__get_user_ssh_key() {
	local col=${COLUMNS:-120}
	col=$((col - 40))
	[ -n "$PKMGR_SSH_KEY_LOCATION" ] || return 0
	[ -d "$HOME/.ssh" ] || mkdir -p "$HOME/.ssh"
	chmod 700 "$HOME/.ssh"
	get_keys="$(curl -q -LSsf "$PKMGR_SSH_KEY_LOCATION" 2>/dev/null)"
	if [ -n "$get_keys" ]; then
		echo "$get_keys" | while read -r key; do
			key_value="$(echo "$key" | awk -F ' ' '{print $2}')"
			if grep -qs -- "$key" "$HOME/.ssh/authorized_keys"; then
				__printf_cyan "Key exists in ~/.ssh/authorized_keys: ${key_value:0:$col}"
			else
				echo "$key" | tee -a "/root/.ssh/authorized_keys" &>/dev/null
				__printf_green "Successfully added key: ${key_value:0:$col}"
			fi
		done
	else
		__printf_return "Can not get key from $PKMGR_SSH_KEY_LOCATION"
		return 1
	fi
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__run_init_check() {
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
__grab_remote_file() { __urlverify "$1" && curl -q -SLs "$1" || exit 1; }
__backup_repo_files() {
	cp -Rf "/etc/apt/sources.list.d/." "$BACKUP_DIR" 2>/dev/null || return 0
}
__rm_repo_files() {
	[ "${1:-$APT_DELETE}" = "yes" ] && rm -Rf "/etc/apt/sources.list.d"/* &>/dev/null || return 0
}
__run_external() { __printf_green "Executing $*" && eval "$*" >/dev/null 2>&1 || return 1; }
__save_remote_file() { __urlverify "$1" && curl -q -SLs "$1" | tee "$2" &>/dev/null || exit 1; }
__retrieve_version_file() { __grab_remote_file "https://github.com/casjay-base/ubuntu/raw/main/version.txt" | head -n1 || echo "Unknown version"; }
__domain_name() {
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
__printf_head() {
	__printf_color "\n##################################################\n$*\n##################################################\n" 6
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__printf_clear() {
	clear
	__printf_head "$*"
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__rm_if_exists() {
	local file_loc=("$@") && shift $#
	for file in "${file_loc[@]}"; do
		if [ -e "$file" ]; then
			__execute "rm -Rf $file" "Removing $file"
		fi
	done
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__retrieve_repo_file() {
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
__run_grub() {
	local cfg="" efi="" grub_cfg="" grub_efi="" grub_bin=""
	grub_cfg="$(find /boot/grub*/* -name 'grub*.cfg' 2>/dev/null)"
	grub_efi="$(find /boot/efi/EFI/* -name 'grub*.cfg' 2>/dev/null)"
	grub_bin="$(builtin type -P grub-mkconfig 2>/dev/null || builtin type -P grub2-mkconfig 2>/dev/null)"
	if [ -n "$grub_bin" ]; then
		if [ -f "/etc/default/grub" ]; then
			for opt in 'biosdevname' 'net.ifnames'; do
				if grep -shq -- "$opt" '/etc/default/grub'; then
					__devnull sed -i '/^GRUB_CMDLINE_LINUX=/ s/'$opt'=[01]/'$opt'=0/' /etc/default/grub
				else
					__devnull sed -i '/^GRUB_CMDLINE_LINUX=/ s/"$/ '$opt'=0"/' /etc/default/grub
				fi
			done
			if ! stat -fc %T '/sys/fs/cgroup' | grep -q -- 'cgroup2fs' && ! grep -sq -- 'systemd.unified_cgroup_hierarchy' /etc/default/grub; then
				__devnull sed -i '/^GRUB_CMDLINE_LINUX=/ s/"$/ systemd.unified_cgroup_hierarchy=1"/' /etc/default/grub
			fi
		fi
		if grep -sq -- 'GRUB_ENABLE_BLSCFG' "/etc/default/grub"; then
			sed -i 's|GRUB_ENABLE_BLSCFG=.*|GRUB_ENABLE_BLSCFG=false|g' '/etc/default/grub'
		else
			echo "GRUB_ENABLE_BLSCFG=false" >>'/etc/default/grub'
		fi
		__rm_if_exists /boot/*rescue*
		__rm_if_exists /boot/loader/entries/*
		if [ -n "$grub_cfg" ]; then
			for cfg in $grub_cfg; do
				if [ -e "$cfg" ]; then
					if __devnull $grub_bin -o "$cfg"; then
						__printf_green "Updated $cfg"
					else
						__printf_return "Failed to update $cfg"
					fi
				fi
			done
		fi
		if [ -n "$grub_efi" ]; then
			for efi in $grub_efi; do
				if [ -e "$efi" ]; then
					# EL9+/Fedora/Debian ship /boot/efi/EFI/{distro}/grub.cfg as a stub that only chainloads the real grub.cfg - grub-mkconfig refuses to overwrite it, so skip it
					if grep -qs -- 'configfile' "$efi" && ! grep -qs -- 'BEGIN /etc/grub.d/' "$efi"; then
						continue
					fi
					if __devnull $grub_bin -o "$efi"; then
						__printf_green "Updated $efi"
					else
						__printf_return "Failed to update $efi"
					fi
				fi
			done
		fi
	fi
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__run_post() {
	local e="$*"
	local m="${e//__devnull /}"
	__execute "$e" "${run_post_message:-executing: $m}"
	__setexitstatus
	set --
	unset run_post_message
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__kernel_ml() {
	__printf_blue "Custom kernel not applicable on this distro — using distribution default"
	return 0
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__kernel_lt() {
	__printf_blue "Custom kernel not applicable on this distro — using distribution default"
	return 0
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__fix_network_device_name() {
	local device="${NETDEV:-eth0}"
	__printf_green "Setting network device name to $device in $1"
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
	if __does_user_exist "$user"; then
		__printf_yellow "User $user already exists - updating password only"
		echo "$user:$pass" | __devnull chpasswd
	else
		existing_uid="$(getent passwd "$uid" | awk -F':' '{print $1}')"
		if [ -n "$existing_uid" ]; then
			__printf_yellow "UID $uid already in use by $existing_uid - skipping $user"
			return 1
		fi
		__devnull groupadd -g "$uid" "$user"
		__devnull useradd -u "$uid" -g "$uid" -m -s /bin/bash "$user"
		echo "$user:$pass" | __devnull chpasswd
	fi
	if [ "$is_admin" = "yes" ]; then
		__devnull usermod -aG sudo "$user"
		if [ -d "/etc/sudoers.d" ]; then
			echo "$user ALL=(ALL) ALL" >"/etc/sudoers.d/$user"
			chmod 440 "/etc/sudoers.d/$user"
		fi
	fi
	SETUP_ACCOUNT_CREDS+=("$user:$pass")
	__printf_green "Account ready: $user (uid $uid)"
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
##################################################################################################################
__printf_clear "Initializing the installer for $RELEASE_NAME using $SCRIPT_DESCRIBE script"
##################################################################################################################
[ -d "/etc/casjaysdev/updates/versions" ] || mkdir -p "/etc/casjaysdev/updates/versions"
if [ -f "/etc/casjaysdev/updates/versions/$SCRIPT_NAME.txt" ]; then
	__printf_red "$(<"/etc/casjaysdev/updates/versions/$SCRIPT_NAME.txt")"
	__printf_red "To reinstall please remove the version file in"
	__printf_red "/etc/casjaysdev/updates/versions/$SCRIPT_NAME.txt"
	exit 1
elif [ -f "/etc/casjaysdev/updates/versions/installed.txt" ]; then
	__printf_red "$(<"/etc/casjaysdev/updates/versions/installed.txt")"
	__printf_red "To reinstall please remove the version file in"
	__printf_red "/etc/casjaysdev/updates/versions/installed.txt"
	exit 1
else
	__run_init_check
	if ! __retrieve_repo_file; then
		__devnull __rm_if_exists "/etc/casjaysdev/updates/versions/installed.txt"
		__devnull __rm_if_exists "/etc/casjaysdev/updates/versions/$SCRIPT_NAME.txt"
		__printf_red "The script has failed to initialize"
		exit 2
	fi
	if [ ! -f "/etc/casjaysdev/updates/versions/os_version.txt" ]; then
		echo "$RELEASE_VER" >"/etc/casjaysdev/updates/versions/os_version.txt"
	fi
fi
if type -P systemmgr >/dev/null 2>&1; then
	__run_external /usr/local/share/CasjaysDev/scripts/install.sh
	__run_external /usr/local/share/CasjaysDev/scripts/bin/systemmgr --config
	__run_external /usr/local/share/CasjaysDev/scripts/bin/systemmgr update scripts
	__run_external "__yum clean"
fi
__printf_green "Installer has been initialized"
##################################################################################################################
__printf_head "Installing vnstat"
##################################################################################################################
__install_pkg vnstat
__system_service_enable vnstat && systemctl restart vnstat &>/dev/null
##################################################################################################################
__printf_head "Configuring cores for compiling"
##################################################################################################################
numberofcores=$(grep -c -- ^processor /proc/cpuinfo)
__printf_yellow "Total cores available: $numberofcores"
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
CFLAGS="-march=x86-64 -mtune=generic -O2 -pipe -fno-plt -fexceptions -Wp,-D_FORTIFY_SOURCE=3 -Wformat \
-Werror=format-security -fstack-clash-protection -fcf-protection -fno-omit-frame-pointer -mno-omit-leaf-frame-pointer"
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
__printf_head "Grabbing ssh key[s]: from $PKMGR_SSH_KEY_LOCATION for $USER"
##################################################################################################################
__get_user_ssh_key
##################################################################################################################
__printf_head "Configuring the system"
##################################################################################################################
__retrieve_repo_file
__run_external timedatectl set-timezone America/New_York
_oci_pkgs="$(dpkg -l 2>/dev/null | awk '/^ii/{print $2}' | grep -E -- '^(oci|cloud|oracle)')"
[ -n "$_oci_pkgs" ] && __remove_pkg $_oci_pkgs
unset _oci_pkgs
__remove_pkg chrony cronie-anacron sendmail sendmail-cf esmtp
__install_pkg postfix
__install_pkg net-tools
__install_pkg wget
__install_pkg curl
__install_pkg git
__install_pkg s-nail
__install_pkg e2fsprogs
__install_pkg vim
__install_pkg unzip
__install_pkg bind9
__install_pkg dnsutils
__rm_if_exists /tmp/dotfiles
__rm_if_exists /root/anaconda-ks.cfg /var/log/anaconda
__run_external "apt-get upgrade -y -q"
##################################################################################################################
__printf_head "Enabling ip forwarding"
##################################################################################################################
sysctl_ip4_found=no
sysctl_ip6_found=no
shopt -s nullglob
for sysctlconf in /etc/sysctl.conf /etc/sysctl.d/*; do
	[ -f "$sysctlconf" ] || continue
	if grep -qsF -- 'net.ipv4.ip_forward' "$sysctlconf"; then
		__devnull sed -i 's/net.ipv4.ip_forward.*/net.ipv4.ip_forward=1/g' "$sysctlconf"
		sysctl_ip4_found=yes
	fi
	if grep -qsF -- 'net.ipv6.conf.all.forwarding' "$sysctlconf"; then
		__devnull sed -i 's/net.ipv6.conf.all.forwarding.*/net.ipv6.conf.all.forwarding=1/g' "$sysctlconf"
		sysctl_ip6_found=yes
	fi
done
shopt -u nullglob
[ "$sysctl_ip4_found" = "yes" ] || echo "net.ipv4.ip_forward=1" >>'/etc/sysctl.conf'
[ "$sysctl_ip6_found" = "yes" ] || echo "net.ipv6.conf.all.forwarding=1" >>'/etc/sysctl.conf'
unset sysctl_ip4_found sysctl_ip6_found sysctlconf
##################################################################################################################
__printf_head "Installing the packages for $RELEASE_NAME"
##################################################################################################################
__install_pkg base-files
__install_pkg bash
__install_pkg bash-completion
__install_pkg certbot
__install_pkg cockpit
__install_pkg cockpit-packagekit
__install_pkg cockpit-storaged
__install_pkg coreutils
__install_pkg cowsay
__install_pkg libcrack2
__install_pkg cracklib-runtime
__install_pkg cron
__install_pkg cron
__install_pkg curl
__install_pkg universal-ctags
__install_pkg dialog
__install_pkg docker-ce
__install_pkg ethtool
__install_pkg findutils
__install_pkg gawk
__install_pkg libgc-dev
__install_pkg gcc
__install_pkg git
__install_pkg gnupg2
__install_pkg libgnutls30
__install_pkg grub-pc
__install_pkg gzip
__install_pkg util-linux
__install_pkg libharfbuzz0b
__install_pkg hdparm
__install_pkg hostname
__install_pkg htop
__install_pkg apache2
__install_pkg less
__install_pkg logrotate
__install_pkg lsof
__install_pkg make
__install_pkg man-db
__install_pkg manpages
__install_pkg libapache2-mod-fcgid
__install_pkg libapache2-mod-perl2
__install_pkg libapache2-mod-wsgi-py3
__install_pkg libapache2-mod-proxy-uwsgi
__install_pkg mosh
__install_pkg mrtg
__install_pkg munin
__install_pkg munin-common
__install_pkg munin-node
__install_pkg ncurses-base
__install_pkg ncurses-base
__install_pkg libncurses6
__install_pkg net-tools
__install_pkg nginx
__install_pkg libpam-mkhomedir
__install_pkg openssh-server
__install_pkg openssl
__install_pkg passwd
__install_pkg perl
__install_pkg perl
__install_pkg libdbd-pg-perl
__install_pkg libdbd-mysql-perl
__install_pkg libdbd-sqlite3-perl
__install_pkg libdbd-mariadb-perl
# Debian family ships unversioned PHP meta packages that pull the default slot
__install_pkg php php-cli php-common php-fpm php-gd php-gmp php-intl php-mbstring php-mysql php-pdo php-pgsql php-xml
__install_pkg pinentry-curses
__install_pkg postfix
__install_pkg python3-certbot-dns-rfc2136
__install_pkg python3-configargparse
__install_pkg python3-cryptography
__install_pkg python3-idna
__install_pkg python3-pynvim
__install_pkg python3-pip
__install_pkg python3-psutil
__install_pkg python3-requests
__install_pkg python3-virtualenv
__install_pkg libreadline-dev
__install_pkg rsync
__install_pkg rsyslog
__install_pkg screen
__install_pkg sed
__install_pkg sqlite3
__install_pkg sudo
__install_pkg symlinks
__install_pkg tar
__install_pkg tzdata
__install_pkg unzip
__install_pkg wget
__install_pkg which
__install_pkg whois
__install_pkg xz-utils
__install_pkg liblzma5
__install_pkg apt-utils
__install_pkg zip
##################################################################################################################
__printf_head "Installing version-specific packages"
##################################################################################################################
# Detect installed PHP version for dynamic config path construction
# (PHP paths in this script use ${PHP_VER} — set it before any config copy operations)
PHP_VER="$(php --version 2>/dev/null | awk 'NR==1{print $2}' | cut -d. -f1,2)"
[ -z "$PHP_VER" ] && PHP_VER="$(ls /etc/php/ 2>/dev/null | grep -E -- '^[0-9]' | sort -V | tail -1)"
[ -z "$PHP_VER" ] && PHP_VER="8.2"
# lsb-release: available on all supported Debian/Ubuntu versions
__install_pkg lsb-release
__install_pkg awstats
__install_pkg fortune-mod
# mlocate was replaced by plocate
__install_pkg plocate
__install_pkg zlib1g
__install_pkg python3-future
##################################################################################################################
if [ "$SYSTEM_TYPE" = "dns" ]; then
	if __devnull __install_pkg ntp || __devnull __install_pkg ntpsec; then
		__printf_cyan "Installed ntp"
		SERVICES_ENABLE="$SERVICES_ENABLE ntpd"
		[ -d "/var/lib/ntp/stats" ] || mkdir -p "/var/lib/ntp/stats"
	fi
else
	__install_pkg chrony
	SERVICES_ENABLE="$SERVICES_ENABLE chrony"
fi
##################################################################################################################
__printf_head "Fixing grub"
##################################################################################################################
__run_grub
##################################################################################################################
__printf_head "Installing custom web server files"
##################################################################################################################
if [ "${PKMGR_CONFIG_SETUP:-yes}" != "no" ]; then
[ -d "$CONFIG_TEMP_DIR" ] && __devnull __rm_if_exists "$CONFIG_TEMP_DIR"
__devnull git clone -q "https://github.com/casjay-base/ubuntu" "$CONFIG_TEMP_DIR"
if [ -d "/var/www/html/sysinfo/.git" ]; then
	__devnull git -C "/var/www/html/sysinfo" reset --hard
	__run_post git -C "/var/www/html/sysinfo" pull -q
else
	__devnull __rm_if_exists "/var/www/html/sysinfo"
	__run_post git clone -q "https://github.com/phpsysinfo/phpsysinfo" "/var/www/html/sysinfo"
fi
if [ -d "/var/www/html/vnstat/.git" ]; then
	__devnull git -C "/var/www/html/vnstat" reset --hard
	__run_post git -C "/var/www/html/vnstat" pull -q
else
	__devnull __rm_if_exists "/var/www/html/vnstat"
	__run_post git clone -q "https://github.com/solbu/vnstat-php-frontend" "/var/www/html/vnstat"
fi
run_post_message="Installing default server files" __run_post sudo -HE STATICSITE="$(hostname -f)" \
	bash -c "$(curl -LSs "https://github.com/casjay-templates/default-web-assets/raw/main/setup.sh")"
[ -f "/etc/apache2/modules/mod_wsgi_python3.so" ] && ln -sf /etc/apache2/modules/mod_wsgi_python3.so /etc/apache2/modules/mod_wsgi.so
##################################################################################################################
__printf_head "Deleting files"
##################################################################################################################
if __system_service_active named || __port_in_use "53"; then
	__devnull __rm_if_exists $CONFIG_TEMP_DIR/etc/bind*
	__devnull __rm_if_exists $CONFIG_TEMP_DIR/var/cache/bind*
else
	__devnull __rm_if_exists /etc/bind* /var/cache/bind/*
fi
if ! type -P ntp >/dev/null 2>&1 && ! type -P ntpd >/dev/null 2>&1 && ! type -P ntpq >/dev/null 2>&1; then
	__devnull __rm_if_exists /etc/ntp*
	__devnull __rm_if_exists $CONFIG_TEMP_DIR/etc/ntp*
fi
if ! type -P chronyd >/dev/null 2>&1; then
	__devnull __rm_if_exists /etc/chrony*
	__devnull __rm_if_exists $CONFIG_TEMP_DIR/etc/chrony*
fi
if ! type -P apache2 >/dev/null 2>&1; then
	IS_INSTALLED_HTTPD=no
	__devnull __rm_if_exists /etc/apache2*
	__devnull __rm_if_exists $CONFIG_TEMP_DIR/etc/apache2*
fi
if ! type -P nginx >/dev/null 2>&1; then
	IS_INSTALLED_NGINX=no
	__devnull __rm_if_exists /etc/nginx*
	__devnull __rm_if_exists $CONFIG_TEMP_DIR/etc/nginx*
fi
if ! type -P named >/dev/null 2>&1; then
	IS_INSTALLED_BIND=no
	__devnull __rm_if_exists /etc/bind*
	__devnull __rm_if_exists /var/cache/bind*
	__devnull __rm_if_exists $CONFIG_TEMP_DIR/etc/bind*
	__devnull __rm_if_exists $CONFIG_TEMP_DIR/var/cache/bind*
fi
if ! type -P proftpd >/dev/null 2>&1; then
	__devnull __rm_if_exists /etc/proftpd*
	__devnull __rm_if_exists $CONFIG_TEMP_DIR/etc/proftpd*
fi
if [ -f "/etc/certbot/dns.conf" ]; then
	__devnull __rm_if_exists "$CONFIG_TEMP_DIR/etc/certbot/dns.conf"
fi
for rm_file in /etc/cron*/0* /etc/cron*/dailyjobs /var/ftp/uploads /etc/apache2/conf.d/ssl.conf; do
	__run_post __devnull __rm_if_exists "$rm_file"
done
##################################################################################################################
__printf_head "setting up config files"
##################################################################################################################
set_domainname="$(__domain_name)"
myhostnameshort="$SET_HOSTNAME"
myserverhostname="$(hostname -f)"
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
ip -6 addr show dev lo 2>/dev/null | grep -q -- '::1' && does_lo_have_ipv6="yes"

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
__devnull find "$CONFIG_TEMP_DIR" -type f -iname "*.sh" -exec chmod 755 {} \;
__devnull find "$CONFIG_TEMP_DIR" -type f -iname "*.pl" -exec chmod 755 {} \;
__devnull find "$CONFIG_TEMP_DIR" -type f -iname "*.cgi" -exec chmod 755 {} \;
__devnull find "$CONFIG_TEMP_DIR" -type f -iname ".gitkeep" -exec rm -Rf {} \;
__devnull find "$CONFIG_TEMP_DIR" -type f -exec sed -i "s#mydomainname#$set_domainname#g" {} \;
__devnull find "$CONFIG_TEMP_DIR" -type f -exec sed -i "s#myhostnameshort#$myhostnameshort#g" {} \;
__devnull find "$CONFIG_TEMP_DIR" -type f -exec sed -i "s#myserverhostname#$myserverhostname#g" {} \;
__devnull find "$CONFIG_TEMP_DIR" -type f -exec sed -i "s#myserverdomainname#$myserverdomainname#g" {} \;
__devnull find "$CONFIG_TEMP_DIR" -type f -exec sed -i "s#mycurrentipaddress_6#$mycurrentipaddress_6#g" {} \;
__devnull find "$CONFIG_TEMP_DIR" -type f -exec sed -i "s#mycurrentipaddress_4#$mycurrentipaddress_4#g" {} \;
if [ -n "$NETDEV" ]; then
	__fix_network_device_name "$CONFIG_TEMP_DIR"
fi
if [ -z "$does_lo_have_ipv6" ]; then
	sed -i 's|inet_interfaces.*|inet_interfaces = 127.0.0.1|g' $CONFIG_TEMP_DIR/etc/postfix/main.cf
fi
__devnull __rm_if_exists $CONFIG_TEMP_DIR/etc/{shorewall,shorewall6}
__devnull mkdir -p /etc/rsync.d /var/log/named
__devnull rsync -avhP $CONFIG_TEMP_DIR/{etc,root,usr,var}* /
# mod_geoip has no installable package on EL9/10 (the legacy Apache GeoIP
# module was retired); guard the deployed apache2.conf so apache2 can still
# start when it's missing, without touching hosts where it's installed
if [ -f /etc/apache2/conf/apache2.conf ] && [ ! -e /usr/lib64/apache2/modules/mod_geoip.so ] && [ ! -e /etc/apache2/modules/mod_geoip.so ]; then
	__devnull sed -i '/^LoadModule geoip_module/s/^/#/' /etc/apache2/conf/apache2.conf
	__devnull sed -i '/^GeoIPEnable\|^GeoIPDBFile/s/^/#/' /etc/apache2/conf/apache2.conf
fi
fi
# docker-ce on el8 (26.x) refuses to start with "ip6tables": true unless
# "experimental": true is also set ("ip6tables rules are only available
# if experimental features are enabled"); docker-ce on el9/10 (29.x) does
# not enforce this, so only patch el8 to avoid changing behavior elsewhere
if [ "$RELEASE_VER" -le 8 ] && [ -f /etc/docker/daemon.json ] && ! grep -q -- '"experimental"' /etc/docker/daemon.json; then
	__devnull sed -i 's/"ip6tables": true,/"ip6tables": true,\n  "experimental": true,/' /etc/docker/daemon.json
fi
if [ -f /etc/fail2ban/jail.local ]; then
	# Every jail in jail.local is permanently enabled - min.sh only runs
	# once, at bootstrap, so a jail could never be enabled later if it
	# depended on detecting the service at bootstrap time. Instead we just
	# make sure each jail's logpath exists (as an empty file, if needed) so
	# fail2ban never errors on a missing log; once the real service is
	# installed and starts writing to that same path, the already-running
	# jail picks it up immediately with no further changes here.
	__devnull mkdir -p /var/log/proftpd /var/log/apache2 /var/log/nginx /var/log/named /var/log/mysql /var/opt/mssql/log
	__devnull touch /var/log/proftpd/auth.log /var/log/apache2/error_log /var/log/nginx/error.log /var/log/nginx/access.log \
		/var/log/named/security.log /var/log/mysql/mysql.log /var/opt/mssql/log/errorlog /var/log/mail.log /var/log/auth.log /var/log/fail2ban.log
fi
__devnull chmod 644 -Rf /etc/cron.d/* /etc/logrotate.d/*
__devnull chmod -f 600 /etc/my.cnf
__devnull touch /etc/postfix/mydomains.pcre
__devnull chattr +i /etc/resolv.conf
if [ -z "$IS_INSTALLED_BIND" ]; then
	if __does_user_exist 'named'; then
		__devnull mkdir -p /etc/bind /var/cache/bind /var/log/named
		__devnull chown -Rf named:named /etc/bind* /var/cache/bind /var/log/named
	fi
fi
if ! type -P postfix >/dev/null 2>&1; then
	__rm_if_exists /etc/postfix
else
	for postfix_proto in "/etc/postfix"/*.proto; do
		__devnull __rm_if_exists $postfix_proto
	done
	__devnull chgrp postdrop /usr/sbin/postqueue
	__devnull chgrp postdrop /usr/sbin/postdrop
	__devnull chgrp postdrop /var/spool/postfix/maildrop
	__devnull chgrp postdrop /var/spool/postfix/public
	__devnull chown root /var/spool/postfix/pid
	__devnull chmod g+s /usr/sbin/postqueue
	__devnull chmod g+s /usr/sbin/postdrop
	__devnull killall -9 postdrop
	__devnull postfix set-permissions create-missing
	if [ "$RELEASE_VER" -ge 10 ]; then
		# el10's postfix build drops hash-map support (only lmdb/cdb/sdbm
		# remain), but default_database_type is still compiled as "hash" -
		# force lmdb explicitly, in main.cf and in postmap, so postfix
		# doesn't hit "fatal: unsupported map type: hash"
		__devnull sed -i 's#^smtp_sasl_password_maps.*#smtp_sasl_password_maps          = lmdb:/etc/postfix/sasl/passwd#' /etc/postfix/main.cf
		__devnull postmap lmdb:/etc/postfix/transport lmdb:/etc/postfix/canonical lmdb:/etc/postfix/virtual lmdb:/etc/postfix/mydomains lmdb:/etc/postfix/sasl/passwd
	else
		__devnull postmap /etc/postfix/transport /etc/postfix/canonical /etc/postfix/virtual /etc/postfix/mydomains /etc/postfix/sasl/passwd
	fi
	__devnull newaliases &>/dev/null || newaliases.postfix -I &>/dev/null
fi
if ! grep -sq -- 'kernel.domainname' "/etc/sysctl.conf"; then
	echo "kernel.domainname=$set_domainname" >>/etc/sysctl.conf
fi
__devnull systemctl daemon-reload
unset postfix_proto
##################################################################################################################
__printf_head "Installing incus"
##################################################################################################################
incus_setup_failed="no"
# Install incus via upstream apt repository
if ! command -v incus >/dev/null 2>&1; then
	if ! grep -qsi 'zabbly' /etc/apt/sources.list.d/*.list 2>/dev/null; then
		__printf_green "Enabling the incus repository"
		curl -fsSL https://pkgs.zabbly.com/key.asc | gpg --dearmor -o /etc/apt/keyrings/zabbly.gpg 2>/dev/null
		echo "deb [signed-by=/etc/apt/keyrings/zabbly.gpg] https://pkgs.zabbly.com/incus/stable $(. /etc/os-release && echo "$VERSION_CODENAME") main" \
			| tee /etc/apt/sources.list.d/zabbly-incus-stable.list >/dev/null
		DEBIAN_FRONTEND=noninteractive apt-get update -q &>/dev/null
	fi
	__install_pkg incus
fi
echo "0:1000000:1000000000" | tee /etc/subuid /etc/subgid >/dev/null
if __system_service_exists "incus"; then
	__devnull systemctl start "incus"
	__devnull systemctl restart "incus"
	__devnull systemctl enable --now incus || incus_setup_failed="yes"
else
	incus_setup_failed=yes
fi
[ -n "$(find /var/lib/incus -mindepth 1 2>/dev/null)" ] || incus_setup_failed="yes"
if [ "$incus_setup_failed" = "no" ]; then
	if incus admin init --network-address 127.0.0.1 --network-port 60443 --storage-backend dir --quiet --auto; then
		__devnull incus network set incusbr0 ipv4.firewall false
		__devnull incus network set incusbr0 ipv6.firewall false
		__devnull systemctl restart incus
		__printf_blue "incus has been initialized"
		unset incus_setup_failed
	else
		incus_setup_failed="yes"
	fi
fi
##################################################################################################################
__printf_head "Configuring applications"
##################################################################################################################
__devnull timedatectl set-ntp true
##################################################################################################################
__printf_head "Configuring cloudflare dns for $SET_HOSTNAME"
##################################################################################################################
[ -f "$HOME/.config/secure/cloudflare.txt" ] && . "$HOME/.config/secure/cloudflare.txt"
if [ -n "$CLOUDFLARE_EMAIL" ] && [ -n "$CLOUDFLARE_API_KEY" ] && [ -n "$CLOUDFLARE_ZONE_NAME" ] && type -P cloudflare >/dev/null 2>&1; then
	cf_args=()
	[ -n "$CLOUDFLARE_PROXY" ] && cf_args+=(--proxy "$CLOUDFLARE_PROXY")
	if __devnull cloudflare update "$SET_HOSTNAME" "${cf_args[@]}"; then
		CLOUDFLARE_DOMAIN="yes"
		__devnull cloudflare update "*.$SET_HOSTNAME" "${cf_args[@]}"
		__printf_blue "Successfully updated $SET_HOSTNAME in $CLOUDFLARE_ZONE_NAME"
	elif __devnull cloudflare create "$SET_HOSTNAME" "${cf_args[@]}"; then
		CLOUDFLARE_DOMAIN="yes"
		__devnull cloudflare create "*.$SET_HOSTNAME" "${cf_args[@]}"
		__printf_blue "Created $SET_HOSTNAME for $CLOUDFLARE_ZONE_NAME"
	else
		__printf_red "Failed to create record $SET_HOSTNAME for zone $CLOUDFLARE_ZONE_NAME"
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
__printf_head "Setting up ssl certificates"
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
				__printf_cyan "Attempting to get certificates from letsencrypt for $le_primary_domain and *.$le_primary_domain"
				__run_post acme-cli --init $le_options
			else
				__printf_cyan "Attempting to get certificates from letsencrypt for $le_primary_domain and all domains in var: le_domain_list"
				__run_post acme-cli --init --no-test --no-subs
			fi
		fi
	fi
	if [ -d "/etc/letsencrypt/live/$le_primary_domain" ] || [ -d "/etc/letsencrypt/live/domain" ]; then
		[ -d "/etc/letsencrypt/live/domain" ] || ln -sf "/etc/letsencrypt/live/$le_primary_domain" /etc/letsencrypt/live/domain
		find /etc/postfix /etc/apache2 /etc/nginx -type f -exec sed -i 's#/etc/ssl/CA/CasjaysDev/certs/localhost.crt#/etc/letsencrypt/live/domain/fullchain.pem#g' {} \;
		find /etc/postfix /etc/apache2 /etc/nginx -type f -exec sed -i 's#/etc/ssl/CA/CasjaysDev/private/localhost.key#/etc/letsencrypt/live/domain/privkey.pem#g' {} \;
		if [ -d "/etc/cockpit/ws-certs.d" ]; then
			__devnull __rm_if_exists "/etc/cockpit/ws-certs.d"/*
			cat /etc/letsencrypt/live/domain/fullchain.pem >/etc/cockpit/ws-certs.d/1-my-cert.cert
			cat /etc/letsencrypt/live/domain/privkey.pem >/etc/cockpit/ws-certs.d/1-my-cert.key
			chmod -f 644 /etc/cockpit/ws-certs.d/1-my-cert.cert
			chmod -f 600 /etc/cockpit/ws-certs.d/1-my-cert.key
		fi
		find "/etc/postfix" "/etc/apache2" "/etc/nginx" /etc/proftpd* -type f \
			-exec sed -i 's#/etc/ssl/CA/CasjaysDev/certs/localhost.crt#/etc/letsencrypt/live/domain/fullchain.pem#g' {} \; 2>/dev/null
		find "/etc/postfix" "/etc/apache2" "/etc/nginx" /etc/proftpd* -type f \
			-exec sed -i 's#/etc/ssl/CA/CasjaysDev/private/localhost.key#/etc/letsencrypt/live/domain/privkey.pem#g' {} \; 2>/dev/null
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
chmod -f 600 "/etc/ssl/certs/\$HOSTNAME.key"
chmod -f 644 "/etc/ssl/certs/\$HOSTNAME.cert"
EOF

			cat <<EOF | tee "/etc/letsencrypt/renewal-hooks/post/cockpit.sh" >/dev/null
#!/usr/bin/env sh
cat "/etc/letsencrypt/live/domain/privkey.pem" >"/etc/cockpit/ws-certs.d/1-my-cert.key"
cat "/etc/letsencrypt/live/domain/fullchain.pem" >"/etc/cockpit/ws-certs.d/1-my-cert.cert"
chmod -f 600 "/etc/cockpit/ws-certs.d/1-my-cert.key"
chmod -f 644 "/etc/cockpit/ws-certs.d/1-my-cert.cert"
systemctl is-enabled cockpit >/dev/null 2>&1 && systemctl restart cockpit >/dev/null 2>&1

EOF
			cat <<EOF | tee "/etc/letsencrypt/renewal-hooks/post/nginx.sh" >/dev/null
#!/usr/bin/env sh
systemctl is-enabled nginx >/dev/null 2>&1 && systemctl reload nginx >/dev/null 2>&1

EOF

			cat <<EOF | tee "/etc/letsencrypt/renewal-hooks/post/apache2.sh" >/dev/null
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
		__printf_blue "letsencrypt certificates have been created"
	else
		__copy_ca_certs
	fi
else
	__copy_ca_certs
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
type -P update-ca-certificates >/dev/null 2>&1 && __devnull update-ca-certificates && __devnull update-ca-certificates extract
type -P dpkg-reconfigure >/dev/null 2>&1 && __devnull dpkg-reconfigure ca-certificates
##################################################################################################################
__printf_head "Setting up rsyncd"
##################################################################################################################
# The [backup] module requires an auth secret - generate one on first run only,
# it is never shipped in casjay-base
if [ -f "/etc/rsyncd.conf" ] && [ ! -s "/etc/rsyncd.secrets" ]; then
	printf "backup:%s\n" "$(openssl rand -base64 24 | tr -d '\n')" >"/etc/rsyncd.secrets"
	__printf_cyan "Generated rsync credentials in /etc/rsyncd.secrets"
fi
chown -f root:root "/etc/rsyncd.secrets" 2>/dev/null
chmod -f 600 "/etc/rsyncd.secrets" 2>/dev/null
##################################################################################################################
__printf_head "Setting up munin-node"
##################################################################################################################
mkdir -p "/var/log/munin"
chmod -f 777 "/var/log/munin"
__does_user_exist 'munin' && chown -Rf "munin" "/var/log/munin"
__does_group_exist "munin" && chgrp -Rf "munin" "/var/log/munin"
__does_user_exist 'munin-node' && chown -Rf "munin" "/var/log/munin-node"
__does_group_exist "munin-node" && chgrp -Rf "munin" "/var/log/munin-node"
__run_post "munin-node-configure --remove-also --shell" >/dev/null 2>/dev/null
# Plugin credentials ship as the non-functional token CHANGEME_AT_BOOTSTRAP so a
# real password is never committed - say so loudly instead of failing silently
if grep -q -- 'CHANGEME_AT_BOOTSTRAP' "/etc/munin/plugin-conf.d/munin-node" 2>/dev/null; then
	__printf_yellow "Placeholder credentials remain in /etc/munin/plugin-conf.d/munin-node"
	__printf_yellow "Set the real passwords there, or delete the sections you do not monitor"
fi
# This file holds credentials once they are filled in - keep it off world-read
chown -f root:munin "/etc/munin/plugin-conf.d/munin-node" 2>/dev/null
chmod -f 640 "/etc/munin/plugin-conf.d/munin-node" 2>/dev/null
##################################################################################################################
__printf_head "Setting up tor"
##################################################################################################################
if type -P tor >/dev/null 2>&1; then
	__devnull systemctl restart tor && sleep 5
	tor_hostnames="$(find "/var/lib/tor/hidden_service" -type f -name 'hostname' 2>/dev/null)"
	if [ -n "$tor_hostnames" ]; then
		__devnull __rm_if_exists "/var/www/html/tor_hostname"
		for f in $tor_hostnames; do
			cat "$f" >>"/var/www/html/tor_hostname" 2>/dev/null
		done
	fi
	printf '%s\n%s\n' "# Generate tor hostnames" "#30 * * * * root " >"/etc/cron.d/tor_hostname"
fi
##################################################################################################################
__printf_head "Setting up bind dns [named]"
##################################################################################################################
if ! command -v named >/dev/null 2>&1; then
	__devnull __rm_if_exists /etc/bind
	__devnull __rm_if_exists /var/cache/bind
	__devnull __rm_if_exists /var/log/named
	__devnull __rm_if_exists /etc/logrotate.d/named
fi
##################################################################################################################
__printf_head "Generating default webserver for $HOSTNAME"
##################################################################################################################
if [ -z "$IS_INSTALLED_HTTPD" ] || [ -z "$IS_INSTALLED_NGINX" ]; then
	if [ -d "/var/www/nginx/domains/$HOSTNAME" ]; then
		__printf_blue "Server directory already exists"
	else
		__devnull gen-nginx --config
		__devnull gen-nginx php $HOSTNAME
		if [ -d "/var/www/nginx/domains/$HOSTNAME" ]; then
			__printf_green "Created server in /var/www/nginx/domains/$HOSTNAME"
		else
			__printf_red "Failed to create default server"
		fi
	fi
fi
if [ -f "/etc/apache2/conf/apache2.conf" ]; then
	sed -i 's|ServerTokens .*|ServerTokens Prod|g' "/etc/apache2/conf/apache2.conf"
fi
if [ -n "$GET_WEB_USER" ]; then
	if [ -f "/etc/nginx/nginx.conf" ]; then
		sed -i '0,/^user .*/s//user  '$GET_WEB_USER';/' "/etc/nginx/nginx.conf"
		grep -sqh -- "^user  $GET_WEB_USER" "/etc/nginx/nginx.conf" || echo "Failed to change the user in /etc/nginx/nginx.conf"
	fi
	if [ -f "/etc/php/${PHP_VER}/fpm/pool.d/www.conf" ]; then
		sed -i '0,/^user .*/s//user = '$GET_WEB_USER'/' "/etc/php/${PHP_VER}/fpm/pool.d/www.conf"
		grep -sqh -- "^user = $GET_WEB_USER" "/etc/php/${PHP_VER}/fpm/pool.d/www.conf" || echo "Failed to change the user in /etc/php/${PHP_VER}/fpm/pool.d/www.conf"
	fi
	if [ -f "/etc/apache2/conf/apache2.conf" ]; then
		sed -i '0,/^User .*/s//User '$GET_WEB_USER'/' "/etc/apache2/conf/apache2.conf"
		grep -sqh -- "^User $GET_WEB_USER" "/etc/apache2/conf/apache2.conf" || echo "Failed to change the user in /etc/apache2/conf/apache2.conf"
	fi
	for apache_dir in "/usr/local/share/apache2" "/var/www"; do
		[ -d "$apache_dir" ] && chown -Rf $GET_WEB_USER "$apache_dir"
	done
fi
if [ -n "$GET_WEB_GROUP" ]; then
	if [ -f "/etc/php/${PHP_VER}/fpm/pool.d/www.conf" ]; then
		sed -i '0,/^group .*/s//group = '$GET_WEB_GROUP'/' "/etc/php/${PHP_VER}/fpm/pool.d/www.conf"
		grep -sqh -- "^group = $GET_WEB_GROUP" "/etc/php/${PHP_VER}/fpm/pool.d/www.conf" || echo "Failed to change the group in /etc/php/${PHP_VER}/fpm/pool.d/www.conf"
	fi
	if [ -f "/etc/apache2/conf/apache2.conf" ]; then
		sed -i '0,/^Group .*/s//Group '$GET_WEB_GROUP'/' "/etc/apache2/conf/apache2.conf"
		grep -sqh -- "^Group $GET_WEB_GROUP" "/etc/apache2/conf/apache2.conf" || echo "Failed to change the group in /etc/apache2/conf/apache2.conf"
	fi
	for apache_dir in "/usr/local/share/apache2" "/var/www"; do
		[ -d "$apache_dir" ] && chgrp -Rf $GET_WEB_GROUP "$apache_dir"
	done
fi
##################################################################################################################
__printf_head "Setting up the reverse proxy for cockpit"
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
__printf_head "Creating directories"
##################################################################################################################
mkdir -p "/mnt/backups" "/var/www/html/.well-known" "/etc/letsencrypt/live"
echo "" >>/etc/fstab
if [ -n "$IS_NETWORK_INTERNAL" ] && __devnull ping -q -W 1 -c 2 10.0.254.1; then
	{
		echo "10.0.254.1:/mnt/Volume_1/backups         /mnt/backups                 nfs defaults,rw 0 0"
		echo "10.0.254.1:/etc/letsencrypt              /etc/letsencrypt             nfs defaults,rw 0 0"
		echo "10.0.254.1:/var/www/html/.well-known     /var/www/html/.well-known    nfs defaults,rw 0 0"
	} >>/etc/fstab
fi
mount -a
##################################################################################################################
__printf_head "Installing custom system configs"
##################################################################################################################
__run_post "systemmgr install $SYSTEMMGR_CONFIGS"
##################################################################################################################
__printf_head "Installing custom dotfiles"
##################################################################################################################
__run_post "dfmgr update $DFMGR_CONFIGS"
##################################################################################################################
__printf_head "Updating personal dotfiles"
##################################################################################################################
if [ -x "$HOME/.local/dotfiles/personal/install.sh" ]; then
	__run_external "$HOME/.local/dotfiles/personal/install.sh"
fi
[ -f "$HOME/.bashrc" ] && . "$HOME/.bashrc"
[ -f "$HOME/.profile" ] && . "$HOME/.profile"
##################################################################################################################
if [ "$SYSTEM_TYPE" = "vpn" ]; then
	__printf_head "Disabling services: apache2,nginx"
	__system_service_disable apache2
	__system_service_disable nginx
fi
if [ "$SYSTEM_TYPE" = "mail" ]; then
	if [ -x "$HOME/Projects/github/dfprivate/email/install.sh" ]; then
		__printf_head "Running installer script for email server"
		eval "$HOME/Projects/github/dfprivate/email/install.sh" >/dev/null 2>&1
	fi
elif [ "$SYSTEM_TYPE" = "db" ] || [ "$set_domainname" = "sqldb.us" ]; then
	if [ -x "$HOME/Projects/github/dfprivate/sql/install.sh" ]; then
		__printf_head "Running installer script for database server"
		eval "$HOME/Projects/github/dfprivate/sql/install.sh" >/dev/null 2>&1
	fi
elif [ "$SYSTEM_TYPE" = "dns" ] || [ "$set_domainname" = "casjaydns.com" ]; then
	if [ -x "$HOME/Projects/github/dfprivate/dns/install.sh" ]; then
		__printf_head "Running installer script for dns server"
		eval "$HOME/Projects/github/dfprivate/dns/install.sh" >/dev/null 2>&1
	fi
fi
##################################################################################################################
__printf_head "Installing and enabling intrusion detection/prevention"
##################################################################################################################
__install_pkg fail2ban
__install_pkg ipset
__install_pkg rkhunter
if type -P rkhunter >/dev/null 2>&1; then
	__devnull rkhunter --propupd
	__devnull rkhunter --update
fi
##################################################################################################################
__printf_head "Enabling services"
##################################################################################################################
for service_enable in $SERVICES_ENABLE; do
	if [ -n "$service_enable" ] && __system_service_exists "$service_enable"; then
		__system_service_enable $service_enable
		systemctl restart $service_enable >/dev/null 2>&1
	fi
done
##################################################################################################################
__printf_head "Disabling services"
##################################################################################################################
for service_disable in $SERVICES_DISABLE; do
	if [ -n "$service_disable" ] && __system_service_exists "$service_disable"; then
		__system_service_disable $service_disable
	fi
done
##################################################################################################################
__printf_head "Setting up docker"
##################################################################################################################
if type -P dockermgr >/dev/null 2>&1; then
	__system_service_enable docker
	__devnull systemctl restart docker
	__run_post dockermgr init && __devnull dockermgr init
fi
if type -P composemgr >/dev/null 2>&1; then
	__run_post composemgr --config && __devnull composemgr --env
fi
##################################################################################################################
__printf_head "Configuring the firewall"
##################################################################################################################
__devnull apt-get install -y -q ufw
__devnull ufw --force reset
__devnull ufw default deny incoming
__devnull ufw default allow outgoing
__devnull ufw allow ssh
__devnull ufw allow http
__devnull ufw allow https
__devnull ufw allow 60000:61000/udp
__devnull ufw --force enable
##################################################################################################################
__printf_head "Disabling dnsmasq"
##################################################################################################################
__system_service_disable dnsmasq
__devnull systemctl mask dnsmasq
__devnull sed -i 's/^dns=dnsmasq/#&/' /etc/NetworkManager/NetworkManager.conf
# Do not killall dnsmasq - libvirt, incus, and docker each spawn their own dnsmasq
# instance for their bridge networks; killing them breaks DHCP/DNS for VMs/containers
##################################################################################################################
__printf_head "Fixing ip address"
##################################################################################################################
/root/bin/changeip.sh >/dev/null 2>&1
##################################################################################################################
__printf_head "Setting up accounts"
##################################################################################################################
SETUP_ACCOUNT_NEXT_UID="$PKMGR_SETUP_ACCOUNT_BASE_UID"
if [ -n "$PKMGR_SETUP_ACCOUNT_ADMIN" ]; then
	__create_account "$PKMGR_SETUP_ACCOUNT_ADMIN" "$SETUP_ACCOUNT_NEXT_UID" "yes"
	SETUP_ACCOUNT_NEXT_UID=$((SETUP_ACCOUNT_NEXT_UID + 1))
fi
if [ -n "$PKMGR_SETUP_ACCOUNT_USERS" ]; then
	for user_spec in ${PKMGR_SETUP_ACCOUNT_USERS//,/ }; do
		[ -z "$user_spec" ] && continue
		__create_account "$user_spec" "$SETUP_ACCOUNT_NEXT_UID" "no"
		SETUP_ACCOUNT_NEXT_UID=$((SETUP_ACCOUNT_NEXT_UID + 1))
	done
fi
unset user_spec SETUP_ACCOUNT_NEXT_UID
##################################################################################################################
__printf_head "Cleaning up"
##################################################################################################################
find "/etc" "/usr" "/var" -iname '*.dpkg-new' -exec rm -Rf {} \; >/dev/null 2>&1
find "/etc" "/usr" "/var" -iname '*.dpkg-old' -exec rm -Rf {} \; >/dev/null 2>&1
__devnull rm -Rf /tmp/*.tar "/tmp/dotfiles" "$CONFIG_TEMP_DIR"
__devnull __retrieve_repo_file
history -c && history -w
##################################################################################################################
__printf_head "Installer version: $(__retrieve_version_file)"
##################################################################################################################
mkdir -p "/etc/casjaysdev/updates/versions"
echo "$VERSION" >"/etc/casjaysdev/updates/versions/configs.txt"
date +'Installed on %Y-%m-%d at %H:%M' >"/etc/casjaysdev/updates/versions/installed.txt"
echo "Installed on $(date +'%Y-%m-%d at %H:%M %Z')" >"/etc/casjaysdev/updates/versions/$SCRIPT_NAME.txt"
chmod -Rf 664 "/etc/casjaysdev/updates/versions/configs.txt"
chmod -Rf 664 "/etc/casjaysdev/updates/versions/installed.txt"
##################################################################################################################
__printf_head "Finished configuring $HOSTNAME"
echo ""
##################################################################################################################
if [ "${#SETUP_ACCOUNT_CREDS[@]}" -gt 0 ]; then
	__printf_head "Account credentials"
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
exit 0
# end
