#!/bin/bash
# CHECK FOR UPDATES: https://github.com/maxstoyanov/bashup

source ./backup.settings.sh
source ./backup.functions.sh

unit="internet"

START
FOLDER "/var/www/" "files"
MYSQL "user" "password" "db"
END
