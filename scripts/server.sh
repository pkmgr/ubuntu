#!/usr/bin/env bash
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version       : 202111041659-git
# @Author        : Jason Hempstead
# @Contact       : jason@casjaysdev.pro
# @License       : WTFPL
# @ReadME        : server.sh --help
# @Copyright     : Copyright: (c) 2021 Jason Hempstead, Casjays Developments
# @Created       : Thursday, Nov 04, 2021 16:59 EDT
# @File          : server.sh
# @Description   : server installer for ubuntu
# @TODO          :
# @Other         :
# @Resource      :
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
APPNAME="$(basename "$0")"
VERSION="202111041659-git"
USER="${SUDO_USER:-${USER}}"
HOME="${USER_HOME:-${HOME}}"
SRC_DIR="${BASH_SOURCE%/*}"
SCRIPT_DESCRIBE="server"
SCRIPT_OS="ubuntu"
GITHUB_USER="${GITHUB_USER:-casjay}"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Set bash options
if [[ "$1" == "--debug" ]]; then shift 1 && set -xo pipefail && export SCRIPT_OPTS="--debug" && export _DEBUG="on"; fi
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
__printf_info() { __printf_color "[ ℹ️ ] $1\n" 3; }
__printf_exit() {
  __printf_color "$1\n" 208 1>&2
  exit 1
}
__printf_success() { __printf_color "[ ✔ ] $1\n" 2; }
__printf_head() {
  [[ $1 == ?(-)+([0-9]) ]] && local color="$1" && shift 1 || local color="6"
  local msg="$*"
  shift
  __printf_color "
##################################################
$msg
##################################################\n" "$color"
}
__printf_return() {
  test -n "$1" && test -z "${1//[0-9]/}" && local color="$1" && shift 1 || local color="208"
  test -n "$1" && test -z "${1//[0-9]/}" && local exitCode="$1" && shift 1 || local exitCode="1"
  local msg="$*"
  [ ${#msg} = 0 ] || { __printf_color "$msg" "$color" 1>&2 && printf "\n"; }
  return ${exitCode:-2}
}
__printf_execute_success() { __printf_color "[ ✔ ] $1 \n" 2; }
__printf_execute_error() { __printf_color "[ ✖ ] $1 $2 \n" 1; }
__printf_execute_error_stream() { while read -r line; do __printf_execute_error "↳ ERROR: $line"; done; }
__printf_execute_result() {
  if [ "$1" -eq 0 ]; then __printf_execute_success "$2"; else __printf_execute_error "$2"; fi
  return "$1"
}
__devnull() { "$@" >/dev/null 2>&1; }
__cmd_exists() { builtin type -P "$1" &>/dev/null; }
__urlcheck() { __devnull curl --output /dev/null --silent --head --fail "$1"; }
__urlinvalid() { if [ -z "$1" ]; then __printf_red "Invalid URL\n"; else
  __printf_red "Can't find $1\n"
  exit 1
fi; }
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
[[ "$1" == "--help" ]] && __printf_exit "${GREEN}${SCRIPT_DESCRIBE} installer for $SCRIPT_OS"
cat /etc/*-release | grep -E -- 'ID=|ID_LIKE=' | grep -qwE -- "$SCRIPT_OS" &>/dev/null && true || __printf_exit "This installer is meant to be run on a $SCRIPT_OS based system"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
system_service_exists() { systemctl status "$1" 2>&1 | grep -iq -- "$1" && return 0 || return 1; }
__system_service_enable() { systemctl is-enabled --quiet "$1" 2>/dev/null || __execute "systemctl enable $1" "Enabling service: $1" || return 1; }
__system_service_disable() { systemctl status "$1" 2>&1 | grep -iq -- 'active' && __execute "systemctl disable --now $1" "Disabling service: $1" || return 1; }
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
test_pkg() {
  dpkg --get-selections "$1" 2>/dev/null | grep -qw -- "$1" &&
    __printf_success "$1 is installed" && return 0 || return 1
  __setexitstatus
  set --
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
remove_pkg() {
  aptbin=$(type -P apt || type -P apt-get)
  apt() { sudo DEBIAN_FRONTEND=noninteractive $aptbin $1 $2 -yy; }
  test_pkg "$1" &>/dev/null &&
    __execute "apt remove $1" "Removing: $1" ||
    __printf_green "$1 is not installed"
  __setexitstatus
  set --
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__install_pkg() {
  aptbin=$(type -P apt || type -P apt-get)
  apt() { sudo DEBIAN_FRONTEND=noninteractive $aptbin $1 $2 --ignore-missing -yy -qq --allow-unauthenticated --assume-yes; }
  test_pkg "$1" || __execute "apt install $1" "Installing: $1"
  __setexitstatus
  set --
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
run_update() {
  aptbin=$(type -P apt || type -P apt-get)
  apt() { sudo DEBIAN_FRONTEND=noninteractive $aptbin $1 $2 --ignore-missing -yy -qq --allow-unauthenticated --assume-yes; }
  run_external apt-get clean all
  run_external apt-get update
  run_external apt upgrade
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
detect_selinux() {
  builtin command -v selinuxenabled &>/dev/null && selinuxenabled
  if [ $? -ne 0 ]; then return 0; else return 1; fi
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
disable_selinux() {
  if builtin command -v selinuxenabled &>/dev/null && selinuxenabled; then
    __printf_blue "Disabling selinux"
    __devnull setenforce 0
  else
    __printf_green "selinux is already disabled"
  fi
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
ssh_key() {
  __printf_green "Grabbing $GITHUB_USER ssh key"
  [[ -d "/root/.ssh" ]] || mkdir -p "/root/.ssh"
  if __urlverify "https://github.com/$GITHUB_USER.keys"; then
    curl -q -SLs "https://github.com/$GITHUB_USER.keys" | tee "/root/.ssh/authorized_keys" &>/dev/null &&
      __printf_green "Successfully added github ssh key" || __printf_return "Failed to add github ssh key"
  else
    __printf_return "Can not get key from https://github.com/$GITHUB_USER.keys"
  fi
  return 0
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
run_external() { __printf_green "Executing $*" && eval "$*" >/dev/null 2>&1 || return 1; }
grab_remote_file() { __urlverify "$1" && curl -q -SLs "$1" || exit 1; }
save_remote_file() { __urlverify "$1" && curl -q -SLs "$1" | tee "$2" &>/dev/null || exit 1; }
retrieve_version_file() { grab_remote_file "https://github.com/casjay-base/ubuntu/raw/main/version.txt" | head -n1 || echo "Unknown version"; }
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
run_grub() {
  __printf_green "Setting up grub"
  local grub_cnf="/boot/grub/grub.cfg"
  local grub2_cnf="/boot/grub2/grub.cfg"
  rm -Rf /boot/*rescue*
  if __cmd_exists grub2-mkconfig && [[ -f "$grub2_cnf" ]]; then
    __devnull grub2-mkconfig -o "$grub2_cnf" &&
      __printf_green "Updated $grub2_cnf"
    __printf_return "Failed to update $grub2_cnf"
  elif __cmd_exists grub-mkconfig && [[ -f "$grub_cnf" ]]; then
    __devnull grub-mkconfig -o "$grub_cnf" &&
      __printf_green "Updated $grub_cnf" ||
      __printf_return "Failed to update $grub_cnf"
  fi
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
run_post() {
  local e="$*"
  local m="${e//__devnull /}"
  __execute "$e" "executing: $m"
  __setexitstatus
  set --
}
##################################################################################################################
clear
ARGS="$*" && shift $#
##################################################################################################################
__printf_head "Initializing the installer"
##################################################################################################################
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
if [ -f /etc/casjaysdev/updates/versions/default.txt ]; then
  __printf_red "This has already been installed"
  __printf_red "To reinstall please remove the version file in"
  __printf_exit "/etc/casjaysdev/updates/versions/default.txt"
fi
if ! builtin type -P systemmgr &>/dev/null; then
  if [[ -d "/usr/local/share/CasjaysDev/scripts" ]]; then
    run_external "git -C https://github.com/casjay-dotfiles/scripts pull"
  else
    run_external "git clone https://github.com/casjay-dotfiles/scripts /usr/local/share/CasjaysDev/scripts"
  fi
  run_external /usr/local/share/CasjaysDev/scripts/install.sh
  run_external systemmgr --config &>/dev/null
  run_external systemmgr install scripts
  run_update
fi
__printf_green "Installer has been initialized"
git config --show-scope user.name 2>/dev/null | grep -q '^' || git config --global user.name "$USER"
git config --show-scope user.email 2>/dev/null | grep -q '^' || git config --global user.email "$USER@$HOSTNAME"
##################################################################################################################
__printf_head "Disabling selinux"
##################################################################################################################
disable_selinux

##################################################################################################################
__printf_head "Configuring cores for compiling"
##################################################################################################################
numberofcores=$(grep -c ^processor /proc/cpuinfo)
__printf_yellow "Total cores avaliable: $numberofcores"
if [ -f /etc/makepkg.conf ]; then
  if [ $numberofcores -gt 1 ]; then
    sed -i 's/#MAKEFLAGS="-j2"/MAKEFLAGS="-j'$(($numberofcores + 1))'"/g' /etc/makepkg.conf
    sed -i 's/COMPRESSXZ=(xz -c -z -)/COMPRESSXZ=(xz -c -T '"$numberofcores"' -z -)/g' /etc/makepkg.conf
  fi
fi
##################################################################################################################
__printf_head "Grabbing ssh key from github"
##################################################################################################################
ssh_key
##################################################################################################################
__printf_head "Configuring the system"
##################################################################################################################
run_update
__install_pkg vnstat
__system_service_enable vnstat
__install_pkg net-tools
__install_pkg wget
__install_pkg curl
__install_pkg git
__install_pkg e2fsprogs
__install_pkg lsb-release
__install_pkg unzip
run_external rm -Rf /tmp/dotfiles
run_external timedatectl set-timezone America/New_York
run_update
run_grub

##################################################################################################################
__printf_head "Installing the packages for $SCRIPT_DESCRIBE"
##################################################################################################################__install_pkg adduser
__install_pkg apt
__install_pkg apt-utils
__install_pkg at
__install_pkg awstats
__install_pkg base-files
__install_pkg base-passwd
__install_pkg bash
__install_pkg bash-completion
__install_pkg bc
__install_pkg bcache-tools
__install_pkg bind9
__install_pkg bind9-dnsutils
__install_pkg bind9-host
__install_pkg bind9-libs
__install_pkg bind9-utils
__install_pkg binutils
__install_pkg binutils-common
__install_pkg bolt
__install_pkg bsdmainutils
__install_pkg bsdutils
__install_pkg btrfs-progs
__install_pkg build-essential
__install_pkg byobu
__install_pkg bzip2
__install_pkg ca-certificates
__install_pkg certbot
__install_pkg clamav
__install_pkg clamav-base
__install_pkg clamav-daemon
__install_pkg clamav-docs
__install_pkg clamav-freshclam
__install_pkg clamav-testfiles
__install_pkg clamdscan
__install_pkg console-setup
__install_pkg console-setup-linux
__install_pkg coreutils
__install_pkg cpio
__install_pkg cpp
__install_pkg cron
__install_pkg cryptsetup
__install_pkg cryptsetup-bin
__install_pkg cryptsetup-initramfs
__install_pkg cryptsetup-run
__install_pkg curl
__install_pkg db-util
__install_pkg debconf
__install_pkg debconf-i18n
__install_pkg debianutils
__install_pkg device-tree-compiler
__install_pkg devio
__install_pkg dialog
__install_pkg dict
__install_pkg diffutils
__install_pkg dirmngr
__install_pkg dmeventd
__install_pkg dmidecode
__install_pkg dmsetup
__install_pkg dns-root-data
__install_pkg dosfstools
__install_pkg dpkg
__install_pkg dpkg-dev
__install_pkg e2fsprogs
__install_pkg ed
__install_pkg eject
__install_pkg ethtool
__install_pkg expect
__install_pkg fakeroot
__install_pkg fcgiwrap
__install_pkg fdisk
__install_pkg file
__install_pkg finalrd
__install_pkg findutils
__install_pkg fish
__install_pkg fish-common
__install_pkg flash-kernel
__install_pkg fontconfig
__install_pkg fontconfig-config
__install_pkg fonts-dejavu-core
__install_pkg fonts-lato
__install_pkg fonts-ubuntu-console
__install_pkg friendly-recovery
__install_pkg fuse
__install_pkg g++
__install_pkg gawk
__install_pkg gcc
__install_pkg gdisk
__install_pkg geoip-database
__install_pkg gettext-base
__install_pkg gir1.2-gdkpixbuf-2.0
__install_pkg gir1.2-glib-2.0
__install_pkg gir1.2-nm-1.0
__install_pkg gir1.2-packagekitglib-1.0
__install_pkg git
__install_pkg git-man
__install_pkg glib-networking
__install_pkg glib-networking-common
__install_pkg glib-networking-services
__install_pkg gnupg
__install_pkg gnupg-l10n
__install_pkg gnupg-utils
__install_pkg gpg
__install_pkg gpg-agent
__install_pkg gpgconf
__install_pkg grep
__install_pkg groff-base
__install_pkg gzip
__install_pkg hdparm
__install_pkg hostname
__install_pkg html2text
__install_pkg htop
__install_pkg iftop
__install_pkg info
__install_pkg init
__install_pkg init-system-helpers
__install_pkg initramfs-tools
__install_pkg initramfs-tools-bin
__install_pkg initramfs-tools-core
__install_pkg install-info
__install_pkg iotop
__install_pkg iperf
__install_pkg iproute2
__install_pkg ipset
__install_pkg iptables
__install_pkg iputils-ping
__install_pkg iputils-tracepath
__install_pkg irqbalance
__install_pkg isc-dhcp-client
__install_pkg isc-dhcp-common
__install_pkg iso-codes
__install_pkg iw
__install_pkg jailkit
__install_pkg javascript-common
__install_pkg jq
__install_pkg kbd
__install_pkg keyboard-configuration
__install_pkg keyutils
__install_pkg klibc-utils
__install_pkg kmod
__install_pkg kpartx
__install_pkg krb5-locales
__install_pkg landscape-common
__install_pkg language-selector-common
__install_pkg less
__install_pkg libacl1
__install_pkg libaio1
__install_pkg libalgorithm-c3-perl
__install_pkg libalgorithm-diff-perl
__install_pkg libalgorithm-diff-xs-perl
__install_pkg libalgorithm-merge-perl
__install_pkg libapparmor1
__install_pkg libappstream4
__install_pkg libapt-pkg6.0
__install_pkg libarchive13
__install_pkg libargon2-1
__install_pkg libasan5
__install_pkg libasn1-8-heimdal
__install_pkg libassuan0
__install_pkg libatasmart4
__install_pkg libatm1
__install_pkg libatomic1
__install_pkg libattr1
__install_pkg libaudit-common
__install_pkg libaudit1
__install_pkg libauthen-oath-perl
__install_pkg libauthen-pam-perl
__install_pkg libauthen-sasl-perl
__install_pkg libb-hooks-endofscope-perl
__install_pkg libb-hooks-op-check-perl
__install_pkg libberkeleydb-perl
__install_pkg libbinutils
__install_pkg libblkid1
__install_pkg libblockdev-crypto2
__install_pkg libblockdev-fs2
__install_pkg libblockdev-loop2
__install_pkg libblockdev-part-err2
__install_pkg libblockdev-part2
__install_pkg libblockdev-swap2
__install_pkg libblockdev-utils2
__install_pkg libblockdev2
__install_pkg libbrotli1
__install_pkg libbsd0
__install_pkg libbytes-random-secure-perl
__install_pkg libbz2-1.0
__install_pkg libc-bin
__install_pkg libc-dev-bin
__install_pkg libc6
__install_pkg libc6-dev
__install_pkg libcairo2
__install_pkg libcanberra0
__install_pkg libcap-ng0
__install_pkg libcap2
__install_pkg libcap2-bin
__install_pkg libcbor0.6
__install_pkg libcc1-0
__install_pkg libcgi-fast-perl
__install_pkg libcgi-pm-perl
__install_pkg libclass-c3-perl
__install_pkg libclass-c3-xs-perl
__install_pkg libclass-data-inheritable-perl
__install_pkg libclass-method-modifiers-perl
__install_pkg libclass-xsaccessor-perl
__install_pkg libcom-err2
__install_pkg libcommon-sense-perl
__install_pkg libconfig-inifiles-perl
__install_pkg libcrypt-dev
__install_pkg libcrypt-openssl-bignum-perl
__install_pkg libcrypt-openssl-random-perl
__install_pkg libcrypt-openssl-rsa-perl
__install_pkg libcrypt-random-seed-perl
__install_pkg libcrypt-ssleay-perl
__install_pkg libcrypt1
__install_pkg libcryptsetup12
__install_pkg libctf-nobfd0
__install_pkg libctf0
__install_pkg libcurl3-gnutls
__install_pkg libcurl4
__install_pkg libdata-optlist-perl
__install_pkg libdatrie1
__install_pkg libdb5.3
__install_pkg libdbd-mysql-perl
__install_pkg libdbi-perl
__install_pkg libdbus-1-3
__install_pkg libdconf1
__install_pkg libdebconfclient0
__install_pkg libdevel-callchecker-perl
__install_pkg libdevel-caller-perl
__install_pkg libdevel-globaldestruction-perl
__install_pkg libdevel-lexalias-perl
__install_pkg libdevel-stacktrace-perl
__install_pkg libdevmapper-event1.02.1
__install_pkg libdevmapper1.02.1
__install_pkg libdigest-bubblebabble-perl
__install_pkg libdigest-hmac-perl
__install_pkg libdist-checkconflicts-perl
__install_pkg libdns-export1109
__install_pkg libdpkg-perl
__install_pkg libdrm-common
__install_pkg libdrm2
__install_pkg libdynaloader-functions-perl
__install_pkg libeatmydata1
__install_pkg libedit2
__install_pkg libefiboot1
__install_pkg libefivar1
__install_pkg libelf1
__install_pkg libemail-date-format-perl
__install_pkg libencode-locale-perl
__install_pkg liberror-perl
__install_pkg libestr0
__install_pkg libeval-closure-perl
__install_pkg libevent-2.1-7
__install_pkg libevent-core-2.1-7
__install_pkg libevent-pthreads-2.1-7
__install_pkg libexception-class-perl
__install_pkg libexpat1
__install_pkg libexpat1-dev
__install_pkg libexporter-tiny-perl
__install_pkg libext2fs2
__install_pkg libexttextcat-2.0-0
__install_pkg libexttextcat-data
__install_pkg libfakeroot
__install_pkg libfastjson4
__install_pkg libfcgi-bin
__install_pkg libfcgi-perl
__install_pkg libfcgi0ldbl
__install_pkg libfdisk1
__install_pkg libfdt1
__install_pkg libffi7
__install_pkg libfido2-1
__install_pkg libfile-fcntllock-perl
__install_pkg libfl2
__install_pkg libfontconfig1
__install_pkg libfreetype6
__install_pkg libfribidi0
__install_pkg libfuse2
__install_pkg libfwupd2
__install_pkg libfwupdplugin1
__install_pkg libgcab-1.0-0
__install_pkg libgcc-9-dev
__install_pkg libgcc-s1
__install_pkg libgcrypt20
__install_pkg libgd3
__install_pkg libgdbm-compat4
__install_pkg libgdbm6
__install_pkg libgdk-pixbuf2.0-0
__install_pkg libgdk-pixbuf2.0-bin
__install_pkg libgdk-pixbuf2.0-common
__install_pkg libgeoip1
__install_pkg libgirepository-1.0-1
__install_pkg libglib2.0-0
__install_pkg libglib2.0-bin
__install_pkg libglib2.0-data
__install_pkg libgmp10
__install_pkg libgnutls30
__install_pkg libgomp1
__install_pkg libgpg-error0
__install_pkg libgpgme11
__install_pkg libgpm2
__install_pkg libgraphite2-3
__install_pkg libgssapi-krb5-2
__install_pkg libgssapi3-heimdal
__install_pkg libgstreamer1.0-0
__install_pkg libgudev-1.0-0
__install_pkg libgusb2
__install_pkg libharfbuzz0b
__install_pkg libhcrypto4-heimdal
__install_pkg libheimbase1-heimdal
__install_pkg libheimntlm0-heimdal
__install_pkg libhiredis0.14
__install_pkg libhogweed5
__install_pkg libhtml-parser-perl
__install_pkg libhtml-tagset-perl
__install_pkg libhtml-template-perl
__install_pkg libhttp-date-perl
__install_pkg libhttp-message-perl
__install_pkg libhx509-5-heimdal
__install_pkg libice6
__install_pkg libicu66
__install_pkg libidn11
__install_pkg libidn2-0
__install_pkg libimport-into-perl
__install_pkg libio-html-perl
__install_pkg libio-multiplex-perl
__install_pkg libio-pty-perl
__install_pkg libio-socket-inet6-perl
__install_pkg libio-socket-ssl-perl
__install_pkg libip4tc2
__install_pkg libip6tc2
__install_pkg libipc-shareable-perl
__install_pkg libipset13
__install_pkg libisc-export1105
__install_pkg libisl22
__install_pkg libisns0
__install_pkg libitm1
__install_pkg libjansson4
__install_pkg libjbig0
__install_pkg libjcat1
__install_pkg libjpeg-turbo8
__install_pkg libjpeg8
__install_pkg libjq1
__install_pkg libjs-jquery
__install_pkg libjson-c4
__install_pkg libjson-glib-1.0-0
__install_pkg libjson-glib-1.0-common
__install_pkg libjson-perl
__install_pkg libjson-xs-perl
__install_pkg libk5crypto3
__install_pkg libkeyutils1
__install_pkg libklibc
__install_pkg libkmod2
__install_pkg libkrb5-26-heimdal
__install_pkg libkrb5-3
__install_pkg libkrb5support0
__install_pkg libksba8
__install_pkg libldap-2.4-2
__install_pkg libldap-common
__install_pkg liblmdb0
__install_pkg liblocale-gettext-perl
__install_pkg liblog-dispatch-perl
__install_pkg liblog-log4perl-perl
__install_pkg liblsan0
__install_pkg libltdl7
__install_pkg liblua5.3-0
__install_pkg liblvm2cmd2.03
__install_pkg liblwp-mediatypes-perl
__install_pkg liblz1
__install_pkg liblz4-1
__install_pkg liblzma5
__install_pkg liblzo2-2
__install_pkg libmaa4
__install_pkg libmagic-mgc
__install_pkg libmagic1
__install_pkg libmail-authenticationresults-perl
__install_pkg libmail-dkim-perl
__install_pkg libmail-sendmail-perl
__install_pkg libmail-spf-perl
__install_pkg libmailtools-perl
__install_pkg libmath-random-isaac-perl
__install_pkg libmath-random-isaac-xs-perl
__install_pkg libmaxminddb0
__install_pkg libmecab2
__install_pkg libmemcached11
__install_pkg libmemcachedutil2
__install_pkg libmilter1.0.1
__install_pkg libmime-lite-perl
__install_pkg libmime-types-perl
__install_pkg libmnl0
__install_pkg libmodule-implementation-perl
__install_pkg libmodule-runtime-perl
__install_pkg libmoo-perl
__install_pkg libmount1
__install_pkg libmpc3
__install_pkg libmpdec2
__install_pkg libmpfr6
__install_pkg libmro-compat-perl
__install_pkg libmspack0
__install_pkg libmysqlclient21
__install_pkg libnamespace-autoclean-perl
__install_pkg libnamespace-clean-perl
__install_pkg libncurses6
__install_pkg libncursesw6
__install_pkg libnet-cidr-perl
__install_pkg libnet-dns-perl
__install_pkg libnet-dns-sec-perl
__install_pkg libnet-ip-perl
__install_pkg libnet-libidn-perl
__install_pkg libnet-rblclient-perl
__install_pkg libnet-server-perl
__install_pkg libnet-smtp-ssl-perl
__install_pkg libnet-ssleay-perl
__install_pkg libnet-xwhois-perl
__install_pkg libnetaddr-ip-perl
__install_pkg libnetfilter-conntrack3
__install_pkg libnetplan0
__install_pkg libnettle7
__install_pkg libnewt0.52
__install_pkg libnfnetlink0
__install_pkg libnfsidmap2
__install_pkg libnftables1
__install_pkg libnftnl11
__install_pkg libnghttp2-14
__install_pkg libnginx-mod-http-auth-pam
__install_pkg libnginx-mod-http-dav-ext
__install_pkg libnginx-mod-http-echo
__install_pkg libnginx-mod-http-geoip
__install_pkg libnginx-mod-http-geoip2
__install_pkg libnginx-mod-http-image-filter
__install_pkg libnginx-mod-http-subs-filter
__install_pkg libnginx-mod-http-upstream-fair
__install_pkg libnginx-mod-http-xslt-filter
__install_pkg libnginx-mod-mail
__install_pkg libnginx-mod-stream
__install_pkg libnl-3-200
__install_pkg libnl-genl-3-200
__install_pkg libnm0
__install_pkg libnpth0
__install_pkg libnspr4
__install_pkg libnss-systemd
__install_pkg libnss3
__install_pkg libntfs-3g883
__install_pkg libnuma1
__install_pkg libogg0
__install_pkg libonig5
__install_pkg libopendkim11
__install_pkg libp11-kit0
__install_pkg libpackage-stash-perl
__install_pkg libpackage-stash-xs-perl
__install_pkg libpackagekit-glib2-18
__install_pkg libpadwalker-perl
__install_pkg libpam-cap
__install_pkg libpam-modules
__install_pkg libpam-modules-bin
__install_pkg libpam-runtime
__install_pkg libpam-systemd
__install_pkg libpam0g
__install_pkg libpango-1.0-0
__install_pkg libpangocairo-1.0-0
__install_pkg libpangoft2-1.0-0
__install_pkg libparams-classify-perl
__install_pkg libparams-util-perl
__install_pkg libparams-validationcompiler-perl
__install_pkg libparse-syslog-perl
__install_pkg libparted-fs-resize0
__install_pkg libparted2
__install_pkg libpcap0.8
__install_pkg libpci3
__install_pkg libpcre2-32-0
__install_pkg libpcre2-8-0
__install_pkg libpcre3
__install_pkg libperl4-corelibs-perl
__install_pkg libperl-dev
__install_pkg libpipeline1
__install_pkg libpixman-1-0
__install_pkg libplymouth5
__install_pkg libpng16-16
__install_pkg libpolkit-agent-1-0
__install_pkg libpolkit-gobject-1-0
__install_pkg libpopt0
__install_pkg libprocps8
__install_pkg libproxy1v5
__install_pkg libpsl5
__install_pkg libpython2-stdlib
__install_pkg libpython2.7-minimal
__install_pkg libpython2.7-stdlib
__install_pkg libpython3-dev
__install_pkg libpython3-stdlib
__install_pkg libpython3.8
__install_pkg libpython3.8-dev
__install_pkg libpython3.8-stdlib
__install_pkg libqalculate20
__install_pkg libqalculate20-data
__install_pkg libqrencode4
__install_pkg libreadline5
__install_pkg libreadline8
__install_pkg libreadonly-perl
__install_pkg librecode0
__install_pkg libref-util-perl
__install_pkg libref-util-xs-perl
__install_pkg libroken18-heimdal
__install_pkg librole-tiny-perl
__install_pkg librtmp1
__install_pkg libruby2.7
__install_pkg libsasl2-2
__install_pkg libsasl2-modules
__install_pkg libsasl2-modules-db
__install_pkg libseccomp2
__install_pkg libselinux1
__install_pkg libsemanage-common
__install_pkg libsemanage1
__install_pkg libsepol1
__install_pkg libsgutils2-2
__install_pkg libsigsegv2
__install_pkg libslang2
__install_pkg libsm6
__install_pkg libsmartcols1
__install_pkg libsocket6-perl
__install_pkg libsodium23
__install_pkg libsoup2.4-1
__install_pkg libspecio-perl
__install_pkg libspf2-2
__install_pkg libsqlite3-0
__install_pkg libss2
__install_pkg libssh-4
__install_pkg libssl1.1
__install_pkg libstdc++-9-dev
__install_pkg libstdc++6
__install_pkg libstemmer0d
__install_pkg libstrictures-perl
__install_pkg libsub-exporter-perl
__install_pkg libsub-exporter-progressive-perl
__install_pkg libsub-identify-perl
__install_pkg libsub-install-perl
__install_pkg libsub-name-perl
__install_pkg libsub-quote-perl
__install_pkg libsys-hostname-long-perl
__install_pkg libsystemd0
__install_pkg libtasn1-6
__install_pkg libtcl8.6
__install_pkg libtdb1
__install_pkg libtext-charwidth-perl
__install_pkg libtext-iconv-perl
__install_pkg libtext-wrapi18n-perl
__install_pkg libtfm1
__install_pkg libthai-data
__install_pkg libthai0
__install_pkg libtiff5
__install_pkg libtimedate-perl
__install_pkg libtinfo6
__install_pkg libtirpc-common
__install_pkg libtirpc3
__install_pkg libtry-tiny-perl
__install_pkg libtsan0
__install_pkg libtss2-esys0
__install_pkg libtype-tiny-perl
__install_pkg libtype-tiny-xs-perl
__install_pkg libtypes-serialiser-perl
__install_pkg libubsan1
__install_pkg libuchardet0
__install_pkg libudev1
__install_pkg libudisks2-0
__install_pkg libunistring2
__install_pkg liburcu6
__install_pkg liburi-perl
__install_pkg libusb-1.0-0
__install_pkg libutempter0
__install_pkg libuuid1
__install_pkg libuv1
__install_pkg libvariable-magic-perl
__install_pkg libvolume-key1
__install_pkg libvorbis0a
__install_pkg libvorbisfile3
__install_pkg libwebp6
__install_pkg libwind0-heimdal
__install_pkg libwrap0
__install_pkg libx11-6
__install_pkg libx11-data
__install_pkg libxau6
__install_pkg libxcb-render0
__install_pkg libxcb-shm0
__install_pkg libxcb1
__install_pkg libxdmcp6
__install_pkg libxext6
__install_pkg libxft2
__install_pkg libxinerama1
__install_pkg libxml2
__install_pkg libxmlb1
__install_pkg libxmu6
__install_pkg libxmuu1
__install_pkg libxosd2
__install_pkg libxpm4
__install_pkg libxrandr2
__install_pkg libxrender1
__install_pkg libxslt1.1
__install_pkg libxss1
__install_pkg libxstring-perl
__install_pkg libxt6
__install_pkg libxtables12
__install_pkg libyaml-0-2
__install_pkg libzstd1
__install_pkg links
__install_pkg linux-base
__install_pkg linux-libc-dev
__install_pkg locales
__install_pkg locate
__install_pkg login
__install_pkg logrotate
__install_pkg logsave
__install_pkg lsb-base
__install_pkg lsb-release
__install_pkg lshw
__install_pkg lsof
__install_pkg ltrace
__install_pkg lvm2
__install_pkg lz4
__install_pkg make
__install_pkg man-db
__install_pkg manpages
__install_pkg manpages-dev
__install_pkg mawk
__install_pkg mdadm
__install_pkg mecab-ipadic
__install_pkg mecab-ipadic-utf8
__install_pkg mecab-utils
__install_pkg milter-greylist
__install_pkg mime-support
__install_pkg motd-news-config
__install_pkg mount
__install_pkg mtd-utils
__install_pkg mtr-tiny
__install_pkg multipath-tools
__install_pkg mysql-client
__install_pkg mysql-common
__install_pkg nano
__install_pkg ncurses-base
__install_pkg ncurses-bin
__install_pkg ncurses-term
__install_pkg net-tools
__install_pkg netbase
__install_pkg netcat-openbsd
__install_pkg nfs-common
__install_pkg nginx-common
__install_pkg nginx-full
__install_pkg ntfs-3g
__install_pkg ntpdate
__install_pkg openssh-client
__install_pkg openssh-server
__install_pkg openssh-sftp-server
__install_pkg openssl
__install_pkg overlayroot
__install_pkg p7zip
__install_pkg packagekit
__install_pkg packagekit-tools
__install_pkg parted
__install_pkg pass
__install_pkg passwd
__install_pkg pastebinit
__install_pkg patch
__install_pkg pci.ids
__install_pkg pciutils
__install_pkg perl
__install_pkg perl-base
__install_pkg perl-modules-5.*
__install_pkg perl-openssl-defaults
__install_pkg php-cgi
__install_pkg php-common
__install_pkg php-fpm
__install_pkg php-mbstring
__install_pkg php-mysql
__install_pkg php-pear
__install_pkg php-xml
__install_pkg php-cgi
__install_pkg php-cli
__install_pkg php-common
__install_pkg php-fpm
__install_pkg php-json
__install_pkg php-mbstring
__install_pkg php-mysql
__install_pkg php-opcache
__install_pkg php-readline
__install_pkg php-xml
__install_pkg pinentry-curses
__install_pkg plymouth
__install_pkg plymouth-theme-ubuntu-text
__install_pkg policykit-1
__install_pkg pollinate
__install_pkg popularity-contest
__install_pkg postfix
__install_pkg postfix-pcre
__install_pkg powermgmt-base
__install_pkg procmail
__install_pkg procps
__install_pkg proftpd-basic
__install_pkg proftpd-doc
__install_pkg psmisc
__install_pkg publicsuffix
__install_pkg python-apt-common
__install_pkg python-is-python2
__install_pkg python-pip-whl
__install_pkg python3
__install_pkg python3-acme
__install_pkg python3-apport
__install_pkg python3-apt
__install_pkg python3-attr
__install_pkg python3-automat
__install_pkg python3-blinker
__install_pkg python3-certbot
__install_pkg python3-certbot-dns-rfc2136
__install_pkg python3-certifi
__install_pkg python3-cffi-backend
__install_pkg python3-chardet
__install_pkg python3-click
__install_pkg python3-colorama
__install_pkg python3-commandnotfound
__install_pkg python3-configargparse
__install_pkg python3-configobj
__install_pkg python3-constantly
__install_pkg python3-cryptography
__install_pkg python3-dbus
__install_pkg python3-debconf
__install_pkg python3-debian
__install_pkg python3-decorator
__install_pkg python3-dev
__install_pkg python3-distro
__install_pkg python3-distro-info
__install_pkg python3-distupgrade
__install_pkg python3-distutils
__install_pkg python3-dnspython
__install_pkg python3-entrypoints
__install_pkg python3-firewall
__install_pkg python3-future
__install_pkg python3-gdbm
__install_pkg python3-gi
__install_pkg python3-hamcrest
__install_pkg python3-httplib2
__install_pkg python3-hyperlink
__install_pkg python3-icu
__install_pkg python3-idna
__install_pkg python3-importlib-metadata
__install_pkg python3-incremental
__install_pkg python3-jinja2
__install_pkg python3-josepy
__install_pkg python3-json-pointer
__install_pkg python3-jsonpatch
__install_pkg python3-jsonschema
__install_pkg python3-jwt
__install_pkg python3-keyring
__install_pkg python3-launchpadlib
__install_pkg python3-lazr.restfulclient
__install_pkg python3-lazr.uri
__install_pkg python3-lib2to3
__install_pkg python3-markupsafe
__install_pkg python3-minimal
__install_pkg python3-mock
__install_pkg python3-more-itertools
__install_pkg python3-nacl
__install_pkg python3-netifaces
__install_pkg python3-newt
__install_pkg python3-nftables
__install_pkg python3-oauthlib
__install_pkg python3-openssl
__install_pkg python3-parsedatetime
__install_pkg python3-pbr
__install_pkg python3-pexpect
__install_pkg python3-pip
__install_pkg python3-pkg-resources
__install_pkg python3-ply
__install_pkg python3-problem-report
__install_pkg python3-ptyprocess
__install_pkg python3-pyasn1
__install_pkg python3-pyasn1-modules
__install_pkg python3-pyinotify
__install_pkg python3-pymacaroons
__install_pkg python3-pyrsistent
__install_pkg python3-requests
__install_pkg python3-requests-toolbelt
__install_pkg python3-requests-unixsocket
__install_pkg python3-rfc3339
__install_pkg python3-secretstorage
__install_pkg python3-selinux
__install_pkg python3-serial
__install_pkg python3-service-identity
__install_pkg python3-setuptools
__install_pkg python3-simplejson
__install_pkg python3-six
__install_pkg python3-slip
__install_pkg python3-slip-dbus
__install_pkg python3-software-properties
__install_pkg python3-systemd
__install_pkg python3-twisted
__install_pkg python3-twisted-bin
__install_pkg python3-tz
__install_pkg python3-update-manager
__install_pkg python3-urllib3
__install_pkg python3-wadllib
__install_pkg python3-wheel
__install_pkg python3-yaml
__install_pkg python3-zipp
__install_pkg python3-zope.component
__install_pkg python3-zope.event
__install_pkg python3-zope.hookable
__install_pkg python3-zope.interface
__install_pkg python3.9-full
__install_pkg python3.9-dev
__install_pkg qalc
__install_pkg qrencode
__install_pkg quota
__install_pkg rake
__install_pkg re2c
__install_pkg readline-common
__install_pkg recode
__install_pkg ri
__install_pkg rpcbind
__install_pkg rsync
__install_pkg rsyslog
__install_pkg ruby
__install_pkg ruby-minitest
__install_pkg ruby-net-telnet
__install_pkg ruby-power-assert
__install_pkg ruby-test-unit
__install_pkg ruby-xmlrpc
__install_pkg ruby-dev
__install_pkg rubygems-integration
__install_pkg run-one
__install_pkg sa-compile
__install_pkg sasl2-bin
__install_pkg screen
__install_pkg sed
__install_pkg sensible-utils
__install_pkg sg3-utils
__install_pkg sg3-utils-udev
__install_pkg shared-mime-info
__install_pkg software-properties-common
__install_pkg sosreport
__install_pkg sound-theme-freedesktop
__install_pkg spamassassin
__install_pkg spamc
__install_pkg speedtest-cli
__install_pkg ssh-import-id
__install_pkg ssl-cert
__install_pkg strace
__install_pkg suckless-tools
__install_pkg sudo
__install_pkg systemd
__install_pkg systemd-sysv
__install_pkg systemd-timesyncd
__install_pkg sysvinit-utils
__install_pkg tar
__install_pkg tcl-expect
__install_pkg tcl-dev
__install_pkg tcpdump
__install_pkg telnet
__install_pkg tf
__install_pkg thin-provisioning-tools
__install_pkg time
__install_pkg tmux
__install_pkg tpm-udev
__install_pkg tor
__install_pkg tree
__install_pkg tzdata
__install_pkg u-boot-tools
__install_pkg ubuntu-advantage-tools
__install_pkg ubuntu-keyring
__install_pkg ubuntu-minimal
__install_pkg ubuntu-release-upgrader-core
__install_pkg ubuntu-server
__install_pkg ubuntu-standard
__install_pkg ucf
__install_pkg udev
__install_pkg udisks2
__install_pkg ufw
__install_pkg unattended-upgrades
__install_pkg unrar
__install_pkg unzip
__install_pkg update-manager-core
__install_pkg update-notifier-common
__install_pkg usb.ids
__install_pkg usbutils
__install_pkg util-linux
__install_pkg uuid-runtime
__install_pkg vim-nox
__install_pkg vim-common
__install_pkg vim-runtime
__install_pkg vim-tiny
__install_pkg webalizer
__install_pkg wget
__install_pkg whiptail
__install_pkg whois
__install_pkg wireless-regdb
__install_pkg x11-common
__install_pkg xauth
__install_pkg xclip
__install_pkg xdg-user-dirs
__install_pkg xfsprogs
__install_pkg xkb-data
__install_pkg xsel
__install_pkg xxd
__install_pkg xz-utils
__install_pkg zip
__install_pkg zlib1g
__install_pkg zlib1g-dev
__install_pkg zsh
__install_pkg zsh-common
__install_pkg apache2
__install_pkg libapache2-mod-fcgid
__install_pkg libapache2-mod-geoip
__install_pkg libapache2-mod-php
__install_pkg libapache2-mod-proxy-uwsgi
__install_pkg bsd-mailx
__install_pkg libnet-dns-perl
__install_pkg libmail-spf-perl
__install_pkg pyzor
__install_pkg razor
__install_pkg arj
__install_pkg bzip2
__install_pkg cabextract
__install_pkg cpio
__install_pkg file
__install_pkg gzip
__install_pkg nomarch
__install_pkg pax
__install_pkg unrar
__install_pkg unzip
__install_pkg zip

##################################################################################################################
__printf_head "Fixing packages"
##################################################################################################################
run_grub
rm -Rf /etc/named* /var/named/* /etc/ntp* /etc/cron*/0* /etc/cron*/dailyjobs
rm -Rf /var/ftp/uploads /etc/httpd/conf.d/ssl.conf /tmp/configs

##################################################################################################################
__printf_head "setting up config files"
##################################################################################################################
run_post "systemmgr install scripts"
run_post "systemmgr install ssl"
run_post "systemmgr install ssh"
run_post "systemmgr install tor"

run_post "dfmgr install bash"
run_post "dfmgr install htop"
run_post "dfmgr install misc"
run_post "dfmgr install vifm"
run_post "dfmgr install vim"

##################################################################################################################
__printf_head "Setting up services"
##################################################################################################################
sudo a2enmod access_compat fcgid expires userdir asis autoindex brotli cgid cgi charset_lite data deflate dir env geoip headers http2 lbmethod_bybusyness lua php7.4 proxy proxy_http2 request rewrite session_dbd speling ssl status vhost_alias xml2enc &>/dev/null
run_external git clone "https://github.com/casjay-base/ubuntu" "/tmp/ubuntu-repo"
run_external cp -Rf /tmp/ubuntu-repo/etc/. /etc/
run_external cp -Rf /tmp/ubuntu-repo/var/. /var/
__system_service_enable tor.service
__system_service_enable nginx
__system_service_enable apache2

##################################################################################################################
__printf_head "Cleaning up"
##################################################################################################################
/root/bin/changeip.sh >/dev/null 2>&1
mkdir -p /mnt/backups /var/www/html/.well-known /etc/letsencrypt/live
run_external rm -Rf /tmp/ubuntu-repo
remove_pkg snap*
remove_pkg lockfile-progs
remove_pkg sendmail-base
remove_pkg sendmail-cf
remove_pkg sensible-mda

##################################################################################################################
__printf_info "Installer version: $(retrieve_version_file)"
##################################################################################################################
mkdir -p /etc/casjaysdev/updates/versions
echo "$VERSION" >/etc/casjaysdev/updates/versions/configs.txt
chmod -Rf 664 /etc/casjaysdev/updates/versions/configs.txt

##################################################################################################################
__printf_head "Finished installing for $SCRIPT_DESCRIBE"
echo ""
##################################################################################################################
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
set --
exit
# end
