#!/usr/bin/env bash
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version       : 202111041659-git
# @Author        : Jason Hempstead
# @Contact       : jason@casjaysdev.com
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
[[ "$1" == "--help" ]] && printf_exit "${GREEN}${SCRIPT_DESCRIBE} installer for $SCRIPT_OS"
cat /etc/*-release | grep -E 'ID=|ID_LIKE=' | grep -qwE "$SCRIPT_OS" &>/dev/null && true || printf_exit "This installer is meant to be run on a $SCRIPT_OS based system"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
system_service_exists() { systemctl status "$1" 2>&1 | grep -iq "$1" && return 0 || return 1; }
system_service_enable() { systemctl status "$1" 2>&1 | grep -iq 'inactive' && execute "systemctl enable $1" "Enabling service: $1" || return 1; }
system_service_disable() { systemctl status "$1" 2>&1 | grep -iq 'active' && execute "systemctl disable --now $1" "Disabling service: $1" || return 1; }
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
test_pkg() {
  dpkg --get-selections "$1" 2>/dev/null | grep -qw "$1" &&
    printf_success "$1 is installed" && return 0 || return 1
  setexitstatus
  set --
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
remove_pkg() {
  apt() { sudo DEBIAN_FRONTEND=noninteractive apt-get "$*" -yy; }
  test_pkg "$1" &>/dev/null &&
    execute "apt remove $1" "Removing: $1" ||
    printf_green "$1 is not installed"
  setexitstatus
  set --
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
install_pkg() {
  apt() { sudo DEBIAN_FRONTEND=noninteractive apt-get $1 $2 --ignore-missing -yy -qq --allow-unauthenticated --assume-yes; }
  test_pkg "$1" || execute "apt install $1" "Installing: $1"
  setexitstatus
  set --
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
run_update() {
  apt() { sudo DEBIAN_FRONTEND=noninteractive apt-get $1 $2 --ignore-missing -yy -qq --allow-unauthenticated --assume-yes; }
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
    printf_blue "Disabling selinux"
    devnull setenforce 0
  else
    printf_green "selinux is already disabled"
  fi
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
ssh_key() {
  printf_green "Grabbing $GITHUB_USER ssh key"
  [[ -d "/root/.ssh" ]] || mkdir -p "/root/.ssh"
  if urlverify "https://github.com/$GITHUB_USER.keys"; then
    curl -q -SLs "https://github.com/$GITHUB_USER.keys" | tee "/root/.ssh/authorized_keys" &>/dev/null &&
      printf_green "Successfully added github ssh key" || printf_return "Failed to add github ssh key"
  else
    printf_return "Can not get key from https://github.com/$GITHUB_USER.keys"
  fi
  return 0
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
run_external() { printf_green "Executing $*" && eval "$*" >/dev/null 2>&1 || return 1; }
grab_remote_file() { urlverify "$1" && curl -q -SLs "$1" || exit 1; }
save_remote_file() { urlverify "$1" && curl -q -SLs "$1" | tee "$2" &>/dev/null || exit 1; }
retrieve_version_file() { grab_remote_file "https://github.com/casjay-base/ubuntu/raw/main/version.txt" | head -n1 || echo "Unknown version"; }
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
run_grub() {
  printf_green "Setting up grub"
  local grub_cnf="/boot/grub/grub.cfg"
  local grub2_cnf="/boot/grub2/grub.cfg"
  rm -Rf /boot/*rescue*
  if cmd_exists grub2-mkconfig && [[ -f "$grub2_cnf" ]]; then
    devnull grub2-mkconfig -o "$grub2_cnf" &&
      printf_green "Updated $grub2_cnf"
    printf_return "Failed to update $grub2_cnf"
  elif cmd_exists grub-mkconfig && [[ -f "$grub_cnf" ]]; then
    devnull grub-mkconfig -o "$grub_cnf" &&
      printf_green "Updated $grub_cnf" ||
      printf_return "Failed to update $grub_cnf"
  fi
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
run_post() {
  local e="$*"
  local m="${e//devnull /}"
  execute "$e" "executing: $m"
  setexitstatus
  set --
}
##################################################################################################################
clear
ARGS="$*" && shift $#
##################################################################################################################
printf_head "Initializing the installer"
##################################################################################################################
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
if [ -f /etc/casjaysdev/updates/versions/default.txt ]; then
  printf_red "This has already been installed"
  printf_red "To reinstall please remove the version file in"
  printf_exit "/etc/casjaysdev/updates/versions/default.txt"
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
printf_green "Installer has been initialized"
git config --show-scope user.name 2>/dev/null | grep -q '^' || git config --global user.name "$USER"
git config --show-scope user.email 2>/dev/null | grep -q '^' || git config --global user.email "$USER@$HOSTNAME"
##################################################################################################################
printf_head "Disabling selinux"
##################################################################################################################
disable_selinux

##################################################################################################################
printf_head "Configuring cores for compiling"
##################################################################################################################
numberofcores=$(grep -c ^processor /proc/cpuinfo)
printf_yellow "Total cores avaliable: $numberofcores"
if [ -f /etc/makepkg.conf ]; then
  if [ $numberofcores -gt 1 ]; then
    sed -i 's/#MAKEFLAGS="-j2"/MAKEFLAGS="-j'$(($numberofcores + 1))'"/g' /etc/makepkg.conf
    sed -i 's/COMPRESSXZ=(xz -c -z -)/COMPRESSXZ=(xz -c -T '"$numberofcores"' -z -)/g' /etc/makepkg.conf
  fi
fi
##################################################################################################################
printf_head "Grabbing ssh key from github"
##################################################################################################################
ssh_key
##################################################################################################################
printf_head "Configuring the system"
##################################################################################################################
run_update
install_pkg vnstat
system_service_enable vnstat
install_pkg net-tools
install_pkg wget
install_pkg curl
install_pkg git
install_pkg e2fsprogs
install_pkg lsb-release
install_pkg unzip
run_external rm -Rf /tmp/dotfiles
run_external timedatectl set-timezone America/New_York
run_update
run_grub

##################################################################################################################
printf_head "Installing the packages for $SCRIPT_DESCRIBE"
##################################################################################################################install_pkg adduser
install_pkg apparmor
install_pkg apport
install_pkg apport-symptoms
install_pkg apt
install_pkg apt-utils
install_pkg at
install_pkg awstats
install_pkg base-files
install_pkg base-passwd
install_pkg bash
install_pkg bash-completion
install_pkg bc
install_pkg bcache-tools
install_pkg bind9
install_pkg bind9-dnsutils
install_pkg bind9-host
install_pkg bind9-libs
install_pkg bind9-utils
install_pkg binutils
install_pkg binutils-common
install_pkg bolt
install_pkg bsdmainutils
install_pkg bsdutils
install_pkg btrfs-progs
install_pkg build-essential
install_pkg byobu
install_pkg bzip2
install_pkg ca-certificates
install_pkg certbot
install_pkg clamav
install_pkg clamav-base
install_pkg clamav-daemon
install_pkg clamav-docs
install_pkg clamav-freshclam
install_pkg clamav-testfiles
install_pkg clamdscan
install_pkg cloud-guest-utils
install_pkg cloud-init
install_pkg cloud-initramfs-copymods
install_pkg cloud-initramfs-dyn-netconf
install_pkg console-setup
install_pkg console-setup-linux
install_pkg coreutils
install_pkg cpio
install_pkg cpp
install_pkg cron
install_pkg cryptsetup
install_pkg cryptsetup-bin
install_pkg cryptsetup-initramfs
install_pkg cryptsetup-run
install_pkg curl
install_pkg db-util
install_pkg debconf
install_pkg debconf-i18n
install_pkg debianutils
install_pkg device-tree-compiler
install_pkg devio
install_pkg dialog
install_pkg dict
install_pkg diffutils
install_pkg dirmngr
install_pkg distro-info
install_pkg distro-info-data
install_pkg dmeventd
install_pkg dmidecode
install_pkg dmsetup
install_pkg dns-root-data
install_pkg dosfstools
install_pkg dovecot-core
install_pkg dovecot-imapd
install_pkg dovecot-pop3d
install_pkg dpkg
install_pkg dpkg-dev
install_pkg e2fsprogs
install_pkg eatmydata
install_pkg ed
install_pkg eject
install_pkg etckeeper
install_pkg ethtool
install_pkg expect
install_pkg fail2ban
install_pkg fakeroot
install_pkg fcgiwrap
install_pkg fdisk
install_pkg file
install_pkg finalrd
install_pkg findutils
install_pkg fish
install_pkg fish-common
install_pkg flash-kernel
install_pkg fontconfig
install_pkg fontconfig-config
install_pkg fonts-dejavu-core
install_pkg fonts-lato
install_pkg fonts-ubuntu-console
install_pkg friendly-recovery
install_pkg fuse
install_pkg g++
install_pkg gawk
install_pkg gcc
install_pkg gdisk
install_pkg geoip-database
install_pkg gettext-base
install_pkg gir1.2-gdkpixbuf-2.0
install_pkg gir1.2-glib-2.0
install_pkg gir1.2-nm-1.0
install_pkg gir1.2-packagekitglib-1.0
install_pkg git
install_pkg git-man
install_pkg glib-networking
install_pkg glib-networking-common
install_pkg glib-networking-services
install_pkg gnupg
install_pkg gnupg-l10n
install_pkg gnupg-utils
install_pkg gpg
install_pkg gpg-agent
install_pkg gpgconf
install_pkg grep
install_pkg groff-base
install_pkg gzip
install_pkg hdparm
install_pkg hostname
install_pkg html2text
install_pkg htop
install_pkg iftop
install_pkg info
install_pkg init
install_pkg init-system-helpers
install_pkg initramfs-tools
install_pkg initramfs-tools-bin
install_pkg initramfs-tools-core
install_pkg install-info
install_pkg iotop
install_pkg iperf
install_pkg iproute2
install_pkg ipset
install_pkg iptables
install_pkg iputils-ping
install_pkg iputils-tracepath
install_pkg irqbalance
install_pkg isc-dhcp-client
install_pkg isc-dhcp-common
install_pkg iso-codes
install_pkg iw
install_pkg jailkit
install_pkg javascript-common
install_pkg jq
install_pkg kbd
install_pkg keyboard-configuration
install_pkg keyutils
install_pkg klibc-utils
install_pkg kmod
install_pkg kpartx
install_pkg krb5-locales
install_pkg landscape-common
install_pkg language-selector-common
install_pkg less
install_pkg libacl1
install_pkg libaio1
install_pkg libalgorithm-c3-perl
install_pkg libalgorithm-diff-perl
install_pkg libalgorithm-diff-xs-perl
install_pkg libalgorithm-merge-perl
install_pkg libapparmor1
install_pkg libappstream4
install_pkg libapt-pkg6.0
install_pkg libarchive13
install_pkg libargon2-1
install_pkg libasan5
install_pkg libasn1-8-heimdal
install_pkg libassuan0
install_pkg libatasmart4
install_pkg libatm1
install_pkg libatomic1
install_pkg libattr1
install_pkg libaudit-common
install_pkg libaudit1
install_pkg libauthen-oath-perl
install_pkg libauthen-pam-perl
install_pkg libauthen-sasl-perl
install_pkg libb-hooks-endofscope-perl
install_pkg libb-hooks-op-check-perl
install_pkg libberkeleydb-perl
install_pkg libbinutils
install_pkg libblkid1
install_pkg libblockdev-crypto2
install_pkg libblockdev-fs2
install_pkg libblockdev-loop2
install_pkg libblockdev-part-err2
install_pkg libblockdev-part2
install_pkg libblockdev-swap2
install_pkg libblockdev-utils2
install_pkg libblockdev2
install_pkg libbrotli1
install_pkg libbsd0
install_pkg libbytes-random-secure-perl
install_pkg libbz2-1.0
install_pkg libc-bin
install_pkg libc-dev-bin
install_pkg libc6
install_pkg libc6-dev
install_pkg libcairo2
install_pkg libcanberra0
install_pkg libcap-ng0
install_pkg libcap2
install_pkg libcap2-bin
install_pkg libcbor0.6
install_pkg libcc1-0
install_pkg libcgi-fast-perl
install_pkg libcgi-pm-perl
install_pkg libclass-c3-perl
install_pkg libclass-c3-xs-perl
install_pkg libclass-data-inheritable-perl
install_pkg libclass-method-modifiers-perl
install_pkg libclass-xsaccessor-perl
install_pkg libcom-err2
install_pkg libcommon-sense-perl
install_pkg libconfig-inifiles-perl
install_pkg libcrypt-dev
install_pkg libcrypt-openssl-bignum-perl
install_pkg libcrypt-openssl-random-perl
install_pkg libcrypt-openssl-rsa-perl
install_pkg libcrypt-random-seed-perl
install_pkg libcrypt-ssleay-perl
install_pkg libcrypt1
install_pkg libcryptsetup12
install_pkg libctf-nobfd0
install_pkg libctf0
install_pkg libcurl3-gnutls
install_pkg libcurl4
install_pkg libdata-optlist-perl
install_pkg libdatrie1
install_pkg libdb5.3
install_pkg libdbd-mysql-perl
install_pkg libdbi-perl
install_pkg libdbus-1-3
install_pkg libdconf1
install_pkg libdebconfclient0
install_pkg libdevel-callchecker-perl
install_pkg libdevel-caller-perl
install_pkg libdevel-globaldestruction-perl
install_pkg libdevel-lexalias-perl
install_pkg libdevel-stacktrace-perl
install_pkg libdevmapper-event1.02.1
install_pkg libdevmapper1.02.1
install_pkg libdigest-bubblebabble-perl
install_pkg libdigest-hmac-perl
install_pkg libdist-checkconflicts-perl
install_pkg libdns-export1109
install_pkg libdpkg-perl
install_pkg libdrm-common
install_pkg libdrm2
install_pkg libdynaloader-functions-perl
install_pkg libeatmydata1
install_pkg libedit2
install_pkg libefiboot1
install_pkg libefivar1
install_pkg libelf1
install_pkg libemail-date-format-perl
install_pkg libencode-locale-perl
install_pkg liberror-perl
install_pkg libestr0
install_pkg libeval-closure-perl
install_pkg libevent-2.1-7
install_pkg libevent-core-2.1-7
install_pkg libevent-pthreads-2.1-7
install_pkg libexception-class-perl
install_pkg libexpat1
install_pkg libexpat1-dev
install_pkg libexporter-tiny-perl
install_pkg libext2fs2
install_pkg libexttextcat-2.0-0
install_pkg libexttextcat-data
install_pkg libfakeroot
install_pkg libfastjson4
install_pkg libfcgi-bin
install_pkg libfcgi-perl
install_pkg libfcgi0ldbl
install_pkg libfdisk1
install_pkg libfdt1
install_pkg libffi7
install_pkg libfido2-1
install_pkg libfile-fcntllock-perl
install_pkg libfl2
install_pkg libfontconfig1
install_pkg libfreetype6
install_pkg libfribidi0
install_pkg libfuse2
install_pkg libfwupd2
install_pkg libfwupdplugin1
install_pkg libgcab-1.0-0
install_pkg libgcc-9-dev
install_pkg libgcc-s1
install_pkg libgcrypt20
install_pkg libgd3
install_pkg libgdbm-compat4
install_pkg libgdbm6
install_pkg libgdk-pixbuf2.0-0
install_pkg libgdk-pixbuf2.0-bin
install_pkg libgdk-pixbuf2.0-common
install_pkg libgeoip1
install_pkg libgirepository-1.0-1
install_pkg libglib2.0-0
install_pkg libglib2.0-bin
install_pkg libglib2.0-data
install_pkg libgmp10
install_pkg libgnutls30
install_pkg libgomp1
install_pkg libgpg-error0
install_pkg libgpgme11
install_pkg libgpm2
install_pkg libgraphite2-3
install_pkg libgssapi-krb5-2
install_pkg libgssapi3-heimdal
install_pkg libgstreamer1.0-0
install_pkg libgudev-1.0-0
install_pkg libgusb2
install_pkg libharfbuzz0b
install_pkg libhcrypto4-heimdal
install_pkg libheimbase1-heimdal
install_pkg libheimntlm0-heimdal
install_pkg libhiredis0.14
install_pkg libhogweed5
install_pkg libhtml-parser-perl
install_pkg libhtml-tagset-perl
install_pkg libhtml-template-perl
install_pkg libhttp-date-perl
install_pkg libhttp-message-perl
install_pkg libhx509-5-heimdal
install_pkg libice6
install_pkg libicu66
install_pkg libidn11
install_pkg libidn2-0
install_pkg libimport-into-perl
install_pkg libio-html-perl
install_pkg libio-multiplex-perl
install_pkg libio-pty-perl
install_pkg libio-socket-inet6-perl
install_pkg libio-socket-ssl-perl
install_pkg libip4tc2
install_pkg libip6tc2
install_pkg libipc-shareable-perl
install_pkg libipset13
install_pkg libisc-export1105
install_pkg libisl22
install_pkg libisns0
install_pkg libitm1
install_pkg libjansson4
install_pkg libjbig0
install_pkg libjcat1
install_pkg libjpeg-turbo8
install_pkg libjpeg8
install_pkg libjq1
install_pkg libjs-jquery
install_pkg libjson-c4
install_pkg libjson-glib-1.0-0
install_pkg libjson-glib-1.0-common
install_pkg libjson-perl
install_pkg libjson-xs-perl
install_pkg libk5crypto3
install_pkg libkeyutils1
install_pkg libklibc
install_pkg libkmod2
install_pkg libkrb5-26-heimdal
install_pkg libkrb5-3
install_pkg libkrb5support0
install_pkg libksba8
install_pkg libldap-2.4-2
install_pkg libldap-common
install_pkg liblmdb0
install_pkg liblocale-gettext-perl
install_pkg liblog-dispatch-perl
install_pkg liblog-log4perl-perl
install_pkg liblsan0
install_pkg libltdl7
install_pkg liblua5.3-0
install_pkg liblvm2cmd2.03
install_pkg liblwp-mediatypes-perl
install_pkg liblz1
install_pkg liblz4-1
install_pkg liblzma5
install_pkg liblzo2-2
install_pkg libmaa4
install_pkg libmagic-mgc
install_pkg libmagic1
install_pkg libmail-authenticationresults-perl
install_pkg libmail-dkim-perl
install_pkg libmail-sendmail-perl
install_pkg libmail-spf-perl
install_pkg libmailtools-perl
install_pkg libmath-random-isaac-perl
install_pkg libmath-random-isaac-xs-perl
install_pkg libmaxminddb0
install_pkg libmecab2
install_pkg libmemcached11
install_pkg libmemcachedutil2
install_pkg libmilter1.0.1
install_pkg libmime-lite-perl
install_pkg libmime-types-perl
install_pkg libmnl0
install_pkg libmodule-implementation-perl
install_pkg libmodule-runtime-perl
install_pkg libmoo-perl
install_pkg libmount1
install_pkg libmpc3
install_pkg libmpdec2
install_pkg libmpfr6
install_pkg libmro-compat-perl
install_pkg libmspack0
install_pkg libmysqlclient21
install_pkg libnamespace-autoclean-perl
install_pkg libnamespace-clean-perl
install_pkg libncurses6
install_pkg libncursesw6
install_pkg libnet-cidr-perl
install_pkg libnet-dns-perl
install_pkg libnet-dns-sec-perl
install_pkg libnet-ip-perl
install_pkg libnet-libidn-perl
install_pkg libnet-rblclient-perl
install_pkg libnet-server-perl
install_pkg libnet-smtp-ssl-perl
install_pkg libnet-ssleay-perl
install_pkg libnet-xwhois-perl
install_pkg libnetaddr-ip-perl
install_pkg libnetfilter-conntrack3
install_pkg libnetplan0
install_pkg libnettle7
install_pkg libnewt0.52
install_pkg libnfnetlink0
install_pkg libnfsidmap2
install_pkg libnftables1
install_pkg libnftnl11
install_pkg libnghttp2-14
install_pkg libnginx-mod-http-auth-pam
install_pkg libnginx-mod-http-dav-ext
install_pkg libnginx-mod-http-echo
install_pkg libnginx-mod-http-geoip
install_pkg libnginx-mod-http-geoip2
install_pkg libnginx-mod-http-image-filter
install_pkg libnginx-mod-http-subs-filter
install_pkg libnginx-mod-http-upstream-fair
install_pkg libnginx-mod-http-xslt-filter
install_pkg libnginx-mod-mail
install_pkg libnginx-mod-stream
install_pkg libnl-3-200
install_pkg libnl-genl-3-200
install_pkg libnm0
install_pkg libnpth0
install_pkg libnspr4
install_pkg libnss-systemd
install_pkg libnss3
install_pkg libntfs-3g883
install_pkg libnuma1
install_pkg libogg0
install_pkg libonig5
install_pkg libopendkim11
install_pkg libp11-kit0
install_pkg libpackage-stash-perl
install_pkg libpackage-stash-xs-perl
install_pkg libpackagekit-glib2-18
install_pkg libpadwalker-perl
install_pkg libpam-cap
install_pkg libpam-modules
install_pkg libpam-modules-bin
install_pkg libpam-runtime
install_pkg libpam-systemd
install_pkg libpam0g
install_pkg libpango-1.0-0
install_pkg libpangocairo-1.0-0
install_pkg libpangoft2-1.0-0
install_pkg libparams-classify-perl
install_pkg libparams-util-perl
install_pkg libparams-validationcompiler-perl
install_pkg libparse-syslog-perl
install_pkg libparted-fs-resize0
install_pkg libparted2
install_pkg libpcap0.8
install_pkg libpci3
install_pkg libpcre2-32-0
install_pkg libpcre2-8-0
install_pkg libpcre3
install_pkg libperl4-corelibs-perl
install_pkg libperl5.32
install_pkg libpipeline1
install_pkg libpixman-1-0
install_pkg libplymouth5
install_pkg libpng16-16
install_pkg libpolkit-agent-1-0
install_pkg libpolkit-gobject-1-0
install_pkg libpopt0
install_pkg libprocps8
install_pkg libproxy1v5
install_pkg libpsl5
install_pkg libpython2-stdlib
install_pkg libpython2.7-minimal
install_pkg libpython2.7-stdlib
install_pkg libpython3-dev
install_pkg libpython3-stdlib
install_pkg libpython3.8
install_pkg libpython3.8-dev
install_pkg libpython3.8-stdlib
install_pkg libqalculate20
install_pkg libqalculate20-data
install_pkg libqrencode4
install_pkg libreadline5
install_pkg libreadline8
install_pkg libreadonly-perl
install_pkg librecode0
install_pkg libref-util-perl
install_pkg libref-util-xs-perl
install_pkg libroken18-heimdal
install_pkg librole-tiny-perl
install_pkg librtmp1
install_pkg libruby2.7
install_pkg libsasl2-2
install_pkg libsasl2-modules
install_pkg libsasl2-modules-db
install_pkg libseccomp2
install_pkg libselinux1
install_pkg libsemanage-common
install_pkg libsemanage1
install_pkg libsepol1
install_pkg libsgutils2-2
install_pkg libsigsegv2
install_pkg libslang2
install_pkg libsm6
install_pkg libsmartcols1
install_pkg libsocket6-perl
install_pkg libsodium23
install_pkg libsoup2.4-1
install_pkg libspecio-perl
install_pkg libspf2-2
install_pkg libsqlite3-0
install_pkg libss2
install_pkg libssh-4
install_pkg libssl1.1
install_pkg libstdc++-9-dev
install_pkg libstdc++6
install_pkg libstemmer0d
install_pkg libstrictures-perl
install_pkg libsub-exporter-perl
install_pkg libsub-exporter-progressive-perl
install_pkg libsub-identify-perl
install_pkg libsub-install-perl
install_pkg libsub-name-perl
install_pkg libsub-quote-perl
install_pkg libsys-hostname-long-perl
install_pkg libsystemd0
install_pkg libtasn1-6
install_pkg libtcl8.6
install_pkg libtdb1
install_pkg libterm-spinner-color-perl
install_pkg libtext-charwidth-perl
install_pkg libtext-iconv-perl
install_pkg libtext-wrapi18n-perl
install_pkg libtfm1
install_pkg libthai-data
install_pkg libthai0
install_pkg libtiff5
install_pkg libtimedate-perl
install_pkg libtinfo6
install_pkg libtirpc-common
install_pkg libtirpc3
install_pkg libtry-tiny-perl
install_pkg libtsan0
install_pkg libtss2-esys0
install_pkg libtype-tiny-perl
install_pkg libtype-tiny-xs-perl
install_pkg libtypes-serialiser-perl
install_pkg libubsan1
install_pkg libuchardet0
install_pkg libudev1
install_pkg libudisks2-0
install_pkg libunistring2
install_pkg liburcu6
install_pkg liburi-perl
install_pkg libusb-1.0-0
install_pkg libutempter0
install_pkg libuuid1
install_pkg libuv1
install_pkg libvariable-magic-perl
install_pkg libvolume-key1
install_pkg libvorbis0a
install_pkg libvorbisfile3
install_pkg libwebp6
install_pkg libwind0-heimdal
install_pkg libwrap0
install_pkg libx11-6
install_pkg libx11-data
install_pkg libxau6
install_pkg libxcb-render0
install_pkg libxcb-shm0
install_pkg libxcb1
install_pkg libxdmcp6
install_pkg libxext6
install_pkg libxft2
install_pkg libxinerama1
install_pkg libxml2
install_pkg libxmlb1
install_pkg libxmu6
install_pkg libxmuu1
install_pkg libxosd2
install_pkg libxpm4
install_pkg libxrandr2
install_pkg libxrender1
install_pkg libxslt1.1
install_pkg libxss1
install_pkg libxstring-perl
install_pkg libxt6
install_pkg libxtables12
install_pkg libyaml-0-2
install_pkg libzstd1
install_pkg links
install_pkg linux-base
install_pkg linux-libc-dev
install_pkg locales
install_pkg locate
install_pkg login
install_pkg logrotate
install_pkg logsave
install_pkg lsb-base
install_pkg lsb-release
install_pkg lshw
install_pkg lsof
install_pkg ltrace
install_pkg lvm2
install_pkg lz4
install_pkg make
install_pkg man-db
install_pkg manpages
install_pkg manpages-dev
install_pkg mawk
install_pkg mdadm
install_pkg mecab-ipadic
install_pkg mecab-ipadic-utf8
install_pkg mecab-utils
install_pkg milter-greylist
install_pkg mime-support
install_pkg motd-news-config
install_pkg mount
install_pkg mtd-utils
install_pkg mtr-tiny
install_pkg multipath-tools
install_pkg mysql-client
install_pkg mysql-common
install_pkg nano
install_pkg ncurses-base
install_pkg ncurses-bin
install_pkg ncurses-term
install_pkg net-tools
install_pkg netbase
install_pkg netcat-openbsd
install_pkg netfilter-persistent
install_pkg nethogs
install_pkg networkd-dispatcher
install_pkg nfs-common
install_pkg nginx-common
install_pkg nginx-full
install_pkg ntfs-3g
install_pkg ntpdate
install_pkg openssh-client
install_pkg openssh-server
install_pkg openssh-sftp-server
install_pkg openssl
install_pkg overlayroot
install_pkg p7zip
install_pkg packagekit
install_pkg packagekit-tools
install_pkg parted
install_pkg pass
install_pkg passwd
install_pkg pastebinit
install_pkg patch
install_pkg pci.ids
install_pkg pciutils
install_pkg perl
install_pkg perl-base
install_pkg perl-modules-5.32
install_pkg perl-openssl-defaults
install_pkg php-cgi
install_pkg php-common
install_pkg php-fpm
install_pkg php-mbstring
install_pkg php-mysql
install_pkg php-pear
install_pkg php-xml
install_pkg php-cgi
install_pkg php-cli
install_pkg php-common
install_pkg php-fpm
install_pkg php-json
install_pkg php-mbstring
install_pkg php-mysql
install_pkg php-opcache
install_pkg php-readline
install_pkg php-xml
install_pkg pinentry-curses
install_pkg plymouth
install_pkg plymouth-theme-ubuntu-text
install_pkg policykit-1
install_pkg pollinate
install_pkg popularity-contest
install_pkg postfix
install_pkg postfix-pcre
install_pkg postgrey
install_pkg powermgmt-base
install_pkg procmail
install_pkg procps
install_pkg proftpd-basic
install_pkg proftpd-doc
install_pkg psmisc
install_pkg publicsuffix
install_pkg python-apt-common
install_pkg python-is-python2
install_pkg python-pip-whl
install_pkg python3
install_pkg python3-acme
install_pkg python3-apport
install_pkg python3-apt
install_pkg python3-attr
install_pkg python3-automat
install_pkg python3-blinker
install_pkg python3-certbot
install_pkg python3-certbot-dns-rfc2136
install_pkg python3-certifi
install_pkg python3-cffi-backend
install_pkg python3-chardet
install_pkg python3-click
install_pkg python3-colorama
install_pkg python3-commandnotfound
install_pkg python3-configargparse
install_pkg python3-configobj
install_pkg python3-constantly
install_pkg python3-cryptography
install_pkg python3-dbus
install_pkg python3-debconf
install_pkg python3-debian
install_pkg python3-decorator
install_pkg python3-dev
install_pkg python3-distro
install_pkg python3-distro-info
install_pkg python3-distupgrade
install_pkg python3-distutils
install_pkg python3-dnspython
install_pkg python3-entrypoints
install_pkg python3-firewall
install_pkg python3-future
install_pkg python3-gdbm
install_pkg python3-gi
install_pkg python3-hamcrest
install_pkg python3-httplib2
install_pkg python3-hyperlink
install_pkg python3-icu
install_pkg python3-idna
install_pkg python3-importlib-metadata
install_pkg python3-incremental
install_pkg python3-jinja2
install_pkg python3-josepy
install_pkg python3-json-pointer
install_pkg python3-jsonpatch
install_pkg python3-jsonschema
install_pkg python3-jwt
install_pkg python3-keyring
install_pkg python3-launchpadlib
install_pkg python3-lazr.restfulclient
install_pkg python3-lazr.uri
install_pkg python3-lib2to3
install_pkg python3-markupsafe
install_pkg python3-minimal
install_pkg python3-mock
install_pkg python3-more-itertools
install_pkg python3-nacl
install_pkg python3-netifaces
install_pkg python3-newt
install_pkg python3-nftables
install_pkg python3-oauthlib
install_pkg python3-openssl
install_pkg python3-parsedatetime
install_pkg python3-pbr
install_pkg python3-pexpect
install_pkg python3-pip
install_pkg python3-pkg-resources
install_pkg python3-ply
install_pkg python3-problem-report
install_pkg python3-ptyprocess
install_pkg python3-pyasn1
install_pkg python3-pyasn1-modules
install_pkg python3-pyinotify
install_pkg python3-pymacaroons
install_pkg python3-pyrsistent
install_pkg python3-requests
install_pkg python3-requests-toolbelt
install_pkg python3-requests-unixsocket
install_pkg python3-rfc3339
install_pkg python3-secretstorage
install_pkg python3-selinux
install_pkg python3-serial
install_pkg python3-service-identity
install_pkg python3-setuptools
install_pkg python3-simplejson
install_pkg python3-six
install_pkg python3-slip
install_pkg python3-slip-dbus
install_pkg python3-software-properties
install_pkg python3-systemd
install_pkg python3-twisted
install_pkg python3-twisted-bin
install_pkg python3-tz
install_pkg python3-update-manager
install_pkg python3-urllib3
install_pkg python3-wadllib
install_pkg python3-wheel
install_pkg python3-yaml
install_pkg python3-zipp
install_pkg python3-zope.component
install_pkg python3-zope.event
install_pkg python3-zope.hookable
install_pkg python3-zope.interface
install_pkg python3.9-full
install_pkg python3.9-dev
install_pkg qalc
install_pkg qrencode
install_pkg quota
install_pkg rake
install_pkg re2c
install_pkg readline-common
install_pkg recode
install_pkg ri
install_pkg rpcbind
install_pkg rsync
install_pkg rsyslog
install_pkg ruby
install_pkg ruby-minitest
install_pkg ruby-net-telnet
install_pkg ruby-power-assert
install_pkg ruby-test-unit
install_pkg ruby-xmlrpc
install_pkg ruby-dev
install_pkg rubygems-integration
install_pkg run-one
install_pkg sa-compile
install_pkg sasl2-bin
install_pkg screen
install_pkg sed
install_pkg sensible-utils
install_pkg sg3-utils
install_pkg sg3-utils-udev
install_pkg shared-mime-info
install_pkg software-properties-common
install_pkg sosreport
install_pkg sound-theme-freedesktop
install_pkg spamassassin
install_pkg spamc
install_pkg speedtest-cli
install_pkg ssh-import-id
install_pkg ssl-cert
install_pkg strace
install_pkg suckless-tools
install_pkg sudo
install_pkg systemd
install_pkg systemd-sysv
install_pkg systemd-timesyncd
install_pkg sysvinit-utils
install_pkg tar
install_pkg tcl-expect
install_pkg tcl-dev
install_pkg tcpdump
install_pkg telnet
install_pkg tf
install_pkg thin-provisioning-tools
install_pkg time
install_pkg tmux
install_pkg tpm-udev
install_pkg tor
install_pkg tree
install_pkg tzdata
install_pkg u-boot-tools
install_pkg ubuntu-advantage-tools
install_pkg ubuntu-keyring
install_pkg ubuntu-minimal
install_pkg ubuntu-release-upgrader-core
install_pkg ubuntu-server
install_pkg ubuntu-standard
install_pkg ucf
install_pkg udev
install_pkg udisks2
install_pkg ufw
install_pkg unattended-upgrades
install_pkg unrar
install_pkg unzip
install_pkg update-manager-core
install_pkg update-notifier-common
install_pkg usb.ids
install_pkg usbutils
install_pkg util-linux
install_pkg uuid-runtime
install_pkg vim-nox
install_pkg vim-common
install_pkg vim-runtime
install_pkg vim-tiny
install_pkg webalizer
install_pkg wget
install_pkg whiptail
install_pkg whois
install_pkg wireless-regdb
install_pkg x11-common
install_pkg xauth
install_pkg xclip
install_pkg xdg-user-dirs
install_pkg xfsprogs
install_pkg xkb-data
install_pkg xsel
install_pkg xxd
install_pkg xz-utils
install_pkg zip
install_pkg zlib1g
install_pkg zlib1g-dev
install_pkg zsh
install_pkg zsh-common
install_pkg apache2
install_pkg libapache2-mod-fcgid
install_pkg libapache2-mod-geoip
install_pkg libapache2-mod-php
install_pkg bsd-mailx
install_pkg dovecot
install_pkg postfix
install_pkg amavisd-new
install_pkg spamassassin
install_pkg clamav-daemon
install_pkg libnet-dns-perl
install_pkg libmail-spf-perl
install_pkg pyzor
install_pkg razor
install_pkg arj
install_pkg bzip2
install_pkg cabextract
install_pkg cpio
install_pkg file
install_pkg gzip
install_pkg lha
install_pkg nomarch
install_pkg pax
install_pkg rar
install_pkg unrar
install_pkg unzip
install_pkg unzoo
install_pkg zip
install_pkg zoo

##################################################################################################################
printf_head "Fixing packages"
##################################################################################################################
run_grub
rm -Rf /etc/named* /var/named/* /etc/ntp* /etc/cron*/0* /etc/cron*/dailyjobs
rm -Rf /var/ftp/uploads /etc/httpd/conf.d/ssl.conf /tmp/configs

##################################################################################################################
printf_head "setting up config files"
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
printf_head "Setting up services"
##################################################################################################################
run_external git clone "https://github.com/casjay-base/ubuntu" "/tmp/ubuntu-repo"
run_external cp -Rf /tmp/ubuntu-repo/etc/. /etc/
run_external cp -Rf /tmp/ubuntu-repo/var/. /var/
system_service_enable tor.service
system_service_enable nginx
system_service_enable apache2

##################################################################################################################
printf_head "Cleaning up"
##################################################################################################################
/root/bin/changeip.sh >/dev/null 2>&1
mkdir -p /mnt/backups /var/www/html/.well-known /etc/letsencrypt/live
run_external rm -Rf /tmp/ubuntu-repo
remove_pkg snap*

##################################################################################################################
printf_info "Installer version: $(retrieve_version_file)"
##################################################################################################################
mkdir -p /etc/casjaysdev/updates/versions
echo "$VERSION" >/etc/casjaysdev/updates/versions/configs.txt
chmod -Rf 664 /etc/casjaysdev/updates/versions/configs.txt

##################################################################################################################
printf_head "Finished installing for $SCRIPT_DESCRIBE"
echo ""
##################################################################################################################
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
set --
exit
# end
