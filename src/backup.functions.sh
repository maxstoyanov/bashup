#!/bin/bash
# CHECK FOR UPDATES: https://github.com/maxstoyanov/bashup

# Assign commandline params to vars.
# Since every unit.sh 'source' this file, we can directly ask for parameters.
# There are $1 to $9 commandline variables availible. Default: Only ask for
# ssh_pathprefix.
ssh_pathprefix=$1


# We have to touch our logpath to ensure a writable file...
touch $logpath
if [ $? -ne 0 ]; then
  ERROR "Could not touch logfile (path=${logpath})"
fi


################################################################################
# Now we initiate several loggign functions. Those are only availible when this
# file is included with 'source' and a relative or absolute path.

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
  if [ $debug ]; then
    local message="$1"
    local date=$(date)
    echo "[$date] [DEBUG]  $message" >> $logpath
    echo "[$date] [DEBUG]  $message"
  fi
}

function INFO {
  local message="$1"
  local date=$(date)
  echo "[$date] [INFO]   $message" >> $logpath
  echo "[$date] [INFO]   $message"
}

function ERROR {
  local message="$1"
  local date=$(date)
  echo "[$date] [ERROR]  $message" >> $logpath
  echo "[$date] [ERROR]  $message"
}


################################################################################
# Now, several internal functions are defined. Those are not to be used outside
# of this file.

# Transfers the file with scp to it's destination.
# Usage: TRANSFER /path/to/local/file
function TRANSFER {
  local outputfile=$1

  DEBUG "scp -B -P ${ssh_port} ${temporary_backup}/${outputfile} ${ssh_user}@${ssh_server}:/${ssh_pathprefix}/"
  scp -B -P ${ssh_port} ${temporary_backup}/${outputfile} ${ssh_user}@${ssh_server}:/${ssh_pathprefix}/

  local scp=$?
  case $scp in
     0)	DEBUG "SCP: Operation successful ($scp)" ;;
     1)	ERROR "SCP: General error in file copy ($scp)" ;;
     2)	ERROR "SCP: Destination is not directory, but it should be ($scp)" ;;
     3)	ERROR "SCP: Maximum symlink level exceeded ($scp)" ;;
     4)	ERROR "SCP: Connecting to host failed ($scp)" ;;
     5)	ERROR "SCP: Connection broken ($scp)" ;;
     6)	ERROR "SCP: File does not exist ($scp)" ;;
     7)	ERROR "SCP: No permission to access file ($scp)" ;;
     8)	ERROR "SCP: General error in sftp protocol ($scp)" ;;
     9)	ERROR "SCP: File transfer protocol mismatch ($scp)" ;;
     10)	ERROR "SCP: No file matches a given criteria ($scp)" ;;
     65)	ERROR "SCP: Host not allowed to connect ($scp)" ;;
     66)	ERROR "SCP: General error in ssh protocol ($scp)" ;;
     67)	ERROR "SCP: Key exchange failed ($scp)" ;;
     68)	ERROR "SCP: Reserved ($scp)" ;;
     69)	ERROR "SCP: MAC error ($scp)" ;;
     70)	ERROR "SCP: Compression error ($scp)" ;;
     71)	ERROR "SCP: Service not available ($scp)" ;;
     72)	ERROR "SCP: Protocol version not supported ($scp)" ;;
     73)	ERROR "SCP: Host key not verifiable ($scp)" ;;
     74)	ERROR "SCP: Connection failed ($scp)" ;;
     75)	ERROR "SCP: Disconnected by application ($scp)" ;;
     76)	ERROR "SCP: Too many connections ($scp)" ;;
     77)	ERROR "SCP: Authentication cancelled by user ($scp)" ;;
     78)	ERROR "SCP: No more authentication methods available ($scp)" ;;
     79)	ERROR "SCP: Invalid user name ($scp)" ;;
     *)   ERROR "SCP: Unknow response code ($scp)" ;;
  esac
}


# Removes the local file after every run
# Usage: CLEAN file.tar.gz.gpg
function CLEAN {
  local outputfile=$1

  DEBUG "Deleting temporary file (${temporary_backup})"

  rm ${temporary_backup}/${outputfile}

  if [ $? -ne 0 ]; then
    ERROR "Deleting temporary file (${temporary_backup})"
  fi
}

################################################################################
# Public backup functions...

# Create tar.gz.gpg backup file from folder
# Usage: FOLDER /path/to/folder myunit
function FOLDER {
  local source=$1
  local subunit=$2
  local outputfile=${timestamp}_${unit}_${subunit}.tar.gz.gpg

  local error=false

  DEBUG "Changed directory to ${source}"
  cd ${source}

  if [ $? -ne 0 ]; then
    ERROR "Changing to ${source}"
  fi

  # Very important is '--trust-model always' for gpg since this enforces that we
  # can use a public key regardless of its trust settings in the keyring
  DEBUG "tar --create --gzip --to-stdout * | gpg --encrypt --trust-model always --recipient ${gpgkeyid} --batch --quiet --output ${temporary_backup}/${outputfile}"
  tar --create --gzip --to-stdout * | gpg --encrypt --trust-model always --recipient ${gpgkeyid} --batch --quiet --output ${temporary_backup}/${outputfile}

  # Split PIPESTATUS as an array.
  # See http://unix.stackexchange.com/a/209184
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
      TRANSFER "${outputfile}"
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

  DEBUG "mysqldump --opt -h localhost -u$user -p$password $db | gzip | gpg --encrypt --trust-model always --recipient ${gpgkeyid} --batch --quiet --output ${temporary_backup}/${outputfile}"
  mysqldump --opt -h localhost -u$user -p$password $db | gzip | gpg --encrypt --trust-model always --recipient ${gpgkeyid} --batch --quiet --output ${temporary_backup}/${outputfile}

  # Split PIPESTATUS as an array.
  # See http://unix.stackexchange.com/a/209184
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
      TRANSFER "${outputfile}"
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
  DEBUG "mysqldump -u$user -p$password --single-transaction --routines --triggers $db | gzip | gpg --encrypt --trust-model always --recipient ${gpgkeyid} --batch --quiet --output ${temporary_backup}/${outputfile}"
  mysqldump -u$user -p$password --single-transaction --routines --triggers $db | gzip | gpg --encrypt --trust-model always --recipient ${gpgkeyid} --batch --quiet --output ${temporary_backup}/${outputfile}

  # Split PIPESTATUS as an array.
  # See http://unix.stackexchange.com/a/209184
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
      TRANSFER "${outputfile}"
      CLEAN "${outputfile}"
    else
      CLEAN "${outputfile}"
  fi
}
