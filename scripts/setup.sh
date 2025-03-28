#!/bin/sh -e

DEBIAN_FRONTEND=noninteractive
DEBCONF_NONINTERACTIVE_SEEN=true

echo 'tzdata tzdata/Areas select Etc' | debconf-set-selections
echo 'tzdata tzdata/Zones/Etc select UTC' | debconf-set-selections
echo "locales locales/default_environment_locale select en_US.UTF-8" | debconf-set-selections
echo "locales locales/locales_to_be_generated multiselect en_US.UTF-8 UTF-8" | debconf-set-selections
rm -f "/etc/locale.gen"

apt update -qqy
apt upgrade -qqy
apt autoremove -qqy
apt install -qqy --no-install-recommends \
    bash-completion \
    bc \
    bridge-utils \
    dnsmasq \
    hostapd \
    iptables \
    libconfig9 \
    locales \
    mobile-broadband-provider-info \
    modemmanager \
    netcat-traditional \
    network-manager \
    openssh-server \
    qrtr-tools \
    rmtfs \
    sudo \
    systemd-timesyncd \
    tzdata \
    wireguard-tools \
    wpasupplicant \
    zram-tools
apt clean
rm -rf /var/lib/apt/lists/*

# strip per-image identity so each device generates its own
rm /etc/machine-id
rm /var/lib/dbus/machine-id
rm /etc/ssh/ssh_host_*
find /var/log -type f -delete

# lock the root account; log in as the unprivileged user instead
passwd -dl root

adduser --disabled-password --comment "" user
passwd user << EOD
1
1
EOD
usermod -aG sudo user

cat <<EOF >> /etc/bash.bashrc

alias l='ls --color=auto -lah'
alias ls='ls --color=auto'
alias ll='ls --color=auto -lh'
alias la='ls --color=auto -lAh'
alias cl='clear'
alias ip='ip --color'
alias bridge='bridge -color'
alias free='free -h'
alias df='df -h'
alias du='du -hs'

EOF

# cap journal disk usage on the small eMMC
cat <<EOF >> /etc/systemd/journald.conf
SystemMaxUse=300M
SystemKeepFree=1G
EOF

# prevent accidental shutdown from the power button
sed -i 's/^#HandlePowerKey=poweroff/HandlePowerKey=ignore/' /etc/systemd/logind.conf
