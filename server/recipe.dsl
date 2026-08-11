#!/bin/bash

# Server configuration 

# CLIENT-ONLY
#
# or use tailscale directly?
# 
# generate keys if not exists
ssh-keygen
# definitions
KEY=   # private key file
IP=    # host's public IP address
# add key to ssh-agent
ssh-add $KEY
# connect to host 'root', enter 'yes' at prompt
ssh root@$IP

# SERVER START *****************************************************************************************

## PROMPT USER FOR INFORMATION THEN STORE IN
## ~/host/id.yaml
# IDEA: SET ARGUMENT __ or XX or any other symbol TO AUTOMATICALLY LAUNCH PROMPT

# run alj.cx/<host config script>: create directories, pulls axjab/exe, axjab/dotfiles, axjab/secrets, etc.
# then
# run ~/env/server/setup

# update system
sudo apt update && sudo apt upgrade -y && reboot # cache

# install security
sudo apt install -y curl wget ufw fail2an ca-certificates gnupg

# create user ash
sudo adduser ash # MISSING OPTIONS
sudo usermod -aG sudo ash

# ssh key should be copied here from client via rsync

# harden ssh tunnel
copy template server/sshd_hardening.conf to /etc/ssh/sshd_config.d/
# HARDENING ********************************
# This is for ethernet
# Port xxxx
# # This is for wifi (temporary)
# Port xxxx
# Protocol 2
# PermitRootLogin no
# PubkeyAuthentication yes
# PasswordAuthentication no
# ChallengeResponseAuthentication no
# KbdInteractiveAuthentication no
# UsePAM yes
# X11Forwarding no
# AllowUsers ash solaire
# MaxAuthTries 3
# LoginGraceTime 30
# HARDENING *********************************

# very ssh config
sudo sshd -t && sudo systemctl reload ssh

# log out and log in again at this point

# Configure firewall
sudo ufw default deny incoming  # idempotent?
sudo ufw default allow outgoing # idempotent?
# sudo ufw allow PROMPT_PORT/tcp
allow port   25 for SMTP
allow port   53 for DNS
allow port   80 for HTTP
allow port  443 for HTTPS
allow port XXXX for SSH
allow port XXXX from [192.168.0.0/24, 100.64.0.0/10] for NFS
# sudo ufw enable
activate firewall
# Disable IPv6 in UFW and apply kernel settings
sudo sed -i 's/IPV6=yes/IPV6=no/' /etc/default/ufw    # check idem
echo "net.ipv6.conf.all.disable_ipv6 = 1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
sudo ufw reload

# enable fail2ban
sudo systemctl enable --now fail2ban
# check /etc/fail2ban/jail.local
# need a copy directive here, example:
copy template server/jail.local /etc/fail2ban/jail.local # or a *.d
sudo systemctl restart fail2ban

# security updates
sudo apt install -y unattended-upgrades
sudo dpkg-reconfigure unattended-upgrades
ensure security origin is enabled
# /etc/apt/apt.conf.d/50unattended-upgrades
# "${distro_id}:${distro_codename}-security";
# may need a copy directive here

# time?
sudo timedatectl set-timezone UTC # why not America?
sudo systemctl enable --now systemd-timesyncd

# what?
sudo apt install -y haveged

# VPN, hold if we're gonna use Tailscale for SSH, should this be at the top?
curl -fsSL https://tailscale.com/install.sh | sh
# login flow
sudo tailscale up
sudo tailscale status
# some additional tests, etc...
# directive could be
start VPN
