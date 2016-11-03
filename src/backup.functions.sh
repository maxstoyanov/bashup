#!/bin/bash
# CHECK FOR UPDATES: https://github.com/maxstoyanov/bashup

ssh_pathprefix=$1

touch $logpath

function START {
local date=$(date)
echo "[$date] [INFO]   Start backup unit $unit" >> $logpath
echo "[$date] [INFO]   Start backup unit $unit"
}

function END {
local date=$(date)
echo "[$date] [INFO]   End backup unit $unit" >> $logpath
echo "[$date] [INFO]   End backup unit $unit"
}

function DEBUG {
if [ $debug ]
then
local message="$1"
local date=$(date)
echo "[$date] [DEBUG]  $message" >> $logpath
echo "[$date] [DEBUG]  $message"
fi
}

function INFO {
local message="$1"
date=$(date)
echo "[$date] [INFO]   $message" >> $logpath
echo "[$date] [INFO]   $message"
}

function ERROR {
local message="$1"
date=$(date)
echo "[$date] [ERROR]  $message" >> $logpath
echo "[$date] [ERROR]  $message"
}

function TRANSFER {
local outputfile=$1
local source=$2

DEBUG "Transfer ${outputfile} to backup server (source=$source)"

scp -B -P ${ssh_port} ${temporary_backup}/${outputfile} ${ssh_user}@${ssh_server}:/${ssh_pathprefix}/

case $? in
   0)	DEBUG "SCP: Operation successful" ;;
   1)	ERROR "SCP: General error in file copy" ;;
   2)	ERROR "SCP: Destination is not directory, but it should be" ;;
   3)	ERROR "SCP: Maximum symlink level exceeded" ;;
   4)	ERROR "SCP: Connecting to host failed" ;;
   5)	ERROR "SCP: Connection broken" ;;
   6)	ERROR "SCP: File does not exist" ;;
   7)	ERROR "SCP: No permission to access file" ;;
   8)	ERROR "SCP: General error in sftp protocol" ;;
   9)	ERROR "SCP: File transfer protocol mismatch" ;;
   10)	ERROR "SCP: No file matches a given criteria" ;;
   65)	ERROR "SCP: Host not allowed to connect" ;;
   66)	ERROR "SCP: General error in ssh protocol" ;;
   67)	ERROR "SCP: Key exchange failed" ;;
   68)	ERROR "SCP: Reserved" ;;
   69)	ERROR "SCP: MAC error" ;;
   70)	ERROR "SCP: Compression error" ;;
   71)	ERROR "SCP: Service not available" ;;
   72)	ERROR "SCP: Protocol version not supported" ;;
   73)	ERROR "SCP: Host key not verifiable" ;;
   74)	ERROR "SCP: Connection failed" ;;
   75)	ERROR "SCP: Disconnected by application" ;;
   76)	ERROR "SCP: Too many connections" ;;
   77)	ERROR "SCP: Authentication cancelled by user" ;;
   78)	ERROR "SCP: No more authentication methods available" ;;
   79)	ERROR "SCP: Invalid user name" ;;
esac
}

function CLEAN {
local outputfile=$1

rm ${temporary_backup}/${outputfile}

if [ $? -eq 0 ]
then
DEBUG "Deleting temporary file (${temporary_backup})"
else
ERROR "Deleting temporary file (${temporary_backup})"
fi
}

function FOLDER {
local source=$1
local subunit=$2
local outputfile=${timestamp}_${unit}_${subunit}.tar.gz.gpg

local error=false

cd ${source}

if [ $? -eq 0 ]
then
DEBUG "Changed directory to ${source}"
else
ERROR "Changing to ${source}"
fi

tar --create --gzip --to-stdout * | gpg --encrypt --trust-model always --recipient ${gpgkeyid} --batch --quiet --output ${temporary_backup}/${outputfile}

IFS=' ' read -ra STATUS <<< "${PIPESTATUS[*]}"

if [ ${STATUS[0]} -eq 0 ]
then
DEBUG "tar to stoud (within pipe) successful"
else
ERROR "tar command within pipe failed (code=${STATUS[0]}, path=${source})"
fi

if [ ${STATUS[1]} -eq 0 ]
then
DEBUG "gpg command (within pipe) successful"
else
ERROR "gpg command within pipe failed (code=${STATUS[1]}, path=${source})"
fi

if [ "$error" = false ]
then
TRANSFER "${outputfile}" "$source"
CLEAN "${outputfile}"
else
CLEAN "${outputfile}"
fi
}

function MYSQL {
local user=$1
local password=$2
local db=$3
local outputfile=${timestamp}_${unit}_${db}.sql.gz.gpg
local error=false

INFO "MySQL database (general) backup started (source=$db)"
mysqldump --opt -h localhost -u$user -p$password $db | gzip | gpg --encrypt --trust-model always --recipient ${gpgkeyid} --batch --quiet --output ${temporary_backup}/${outputfile}

IFS=' ' read -ra STATUS <<< "${PIPESTATUS[*]}"

if [ ${STATUS[0]} -eq 0 ]
then
DEBUG "mysqldump to stoud (within pipe) successful"
else
ERROR "Could not stream mysqldump to stout (code=${STATUS[0]}, db=${db})"
error=true
fi

if [ ${STATUS[1]} -eq 0 ]
then
DEBUG "gzip command (within pipe) successful"
else
ERROR "Could not stream gzip command (code=${STATUS[1]}, db=${db})"
error=true
fi

if [ ${STATUS[2]} -eq 0 ]
then
DEBUG "gpg command (within pipe) successful"
else
ERROR "Could not stream gpg to file (code=${STATUS[2]}, path=${source})"
error=true
fi

if [ "$error" = false ]
then
TRANSFER "${outputfile}" "$db"
CLEAN "${outputfile}"
else
CLEAN "${outputfile}"
fi
}

function INNODB {
local user=$1
local password=$2
local db=$3
local outputfile=${timestamp}_${unit}_${db}.sql.gz.gpg
local error=false

INFO "MySQL database (InnoDB) backup started (source=$db)"
mysqldump -u$user -p$password --single-transaction --routines --triggers $db | gzip | gpg --encrypt --trust-model always --recipient ${gpgkeyid} --batch --quiet --output ${temporary_backup}/${outputfile}

IFS=' ' read -ra STATUS <<< "${PIPESTATUS[*]}"

if [ ${STATUS[0]} -eq 0 ]
then
DEBUG "mysqldump to stoud (within pipe) successful"
else
ERROR "Could not stream mysqldump to stout (code=${STATUS[0]}, db=${db})"
error=true
fi

if [ ${STATUS[1]} -eq 0 ]
then
DEBUG "gzip command (within pipe) successful"
else
ERROR "Could not stream gzip command (code=${STATUS[1]}, db=${db})"
error=true
fi

if [ ${STATUS[2]} -eq 0 ]
then
DEBUG "gpg command (within pipe) successful"
else
ERROR "Could not stream gpg to file (code=${STATUS[2]}, path=${source})"
error=true
fi

if [ "$error" = false ]
then
TRANSFER "${outputfile}" "$db"
CLEAN "${outputfile}"
else
CLEAN "${outputfile}"
fi
}
