#!/bin/bash
# CHECK FOR UPDATES: https://github.com/maxstoyanov/bashup

# Timestamp
timestamp=$(date +'%y%m%d')

# SCP (SFTP) server with public key authentication
ssh_server="10.10.10.10"
ssh_port="22"
ssh_user="backup"

# GPG public key identifier for encrypting backup (see gpg manpage for formats)
gpgkeyid="CA1E5719"

# Local temporary folder (no trailing slash)
temporary_backup="/srv/backup"

logpath="/srv/script/backup.log"

# debug=true
