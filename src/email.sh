#!/bin/bash
# CHECK FOR UPDATES: https://github.com/maxstoyanov/bashup

source ./backup.settings.sh
source ./backup.functions.sh

unit="email"

START
FOLDER "/srv/mail/" "files"
END
