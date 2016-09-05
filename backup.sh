#!/bin/bash
#
# Author Name:      Nitin Madhok
# Author Email:     nmadhok@clemson.edu
# Date Created:     Friday, March 18, 2016
# Last Modified:    Friday, March 18, 2016
#


############################
## User defined variables ##
############################

MYSQL_DB_NAME="test-db"                     # MySQL database name to backup
MYSQL_ROOT_PASSWORD="badpassword"           # MySQL root user password
PATH_TO_BACKUP_DIR=/mnt/backups/mysql       # Path to backup directory on mount
PATH_TO_BACKUP_LOGDIR=/var/log/backup       # Path to backup log directory
DAYS_TO_KEEP_BACKUP=42                      # No. of days to retain the backup for
REMOVE_OLD_BACKUP_AND_LOGS=1                # Boolean flag for removing old backups and logs files. Set this to 1 to enable this functionality


##############################
## Auto populated variables ##
##############################

DATE_TODAY=`date -I`                        # Today's date in ISO-8601 format
TIME_NOW=`date +%H:%M:%S`


###############
## Functions ##
###############

# Check if backup directory exists. Exit if it doesn't exist
check_backup_directory_existence () {
  if [ ! -d $1 ]
  then
    echo "Backup Target Directory '$1' does not exist."
    echo "Exiting..."
    exit
  fi
}

# Check if backup log directory exists. Create if it doesn't exist
check_backup_logdir_existence () {
  if [ ! -d $1 ]
  then
    echo "Creating Backup Log Directory: $1"
    mkdir -p $1
fi
}

# Check if date stamped daily backup log file exists. Create file if it
# doesn't exist
check_backup_logfile_existence () {
  if [ ! -f $1 ]
  then
    echo "Creating Backup Log File: $1"
    touch $1
fi
}

# Set the path for backup and logs
set_path () {
  TARGET=$PATH_TO_BACKUP_DIR/$MYSQL_DB_NAME-$DATE_TODAY-$TIME_NOW.sql
  PATH_TO_BACKUP_LOGFILE=$PATH_TO_BACKUP_LOGDIR/$DATE_TODAY.log
}

# Check if backup directory exists. Exit if it doesn't exist
# Check if backup log directory exists. Create directory if it doesn't exist
# Check if date stamped backup log file exists. Create file if it doesn't
# exist
pre_command_check () {
  check_backup_directory_existence $1
  check_backup_logdir_existence $2
  check_backup_logfile_existence $3
}

# Create symlink to the latest backup 
create_latest_symlink () {
  if [ -L $PATH_TO_BACKUP_DIR/latest ]
  then
    # Symbolic link exists. Need to remove it
    echo "Symlink $PATH_TO_BACKUP_DIR/latest exists. Deleting it."
    rm -rf $PATH_TO_BACKUP_DIR/latest
  fi
  # Create a new symbolic link pointing to the backup just created
  ln -s $1 $PATH_TO_BACKUP_DIR/latest
  echo "Creating symlink $PATH_TO_BACKUP_DIR/latest to $1"
}

# Remove all old backups and logs which are older than $DAYS_TO_KEEP_BACKUP
# days
remove_old_backups_and_logs () {
  output=$(find $PATH_TO_BACKUP_DIR -maxdepth 1 -mtime +$DAYS_TO_KEEP_BACKUP
-type f -exec echo '{}' \;)
  if [ "$output" ]; then
    echo -e "\nDeleting following backups older than $DAYS_TO_KEEP_BACKUP
days:"
    echo $output
    find $PATH_TO_BACKUP_DIR -maxdepth 1 -mtime +$DAYS_TO_KEEP_BACKUP -type f
-exec rm -rf '{}' +
  fi
  output=$(find $PATH_TO_BACKUP_LOGDIR -maxdepth 1 -mtime
+$DAYS_TO_KEEP_BACKUP -type f -exec echo '{}' \;)
  if [ "$output" ]; then
    echo -e "\nDeleting following backup logs older than $DAYS_TO_KEEP_BACKUP
days:"
    echo $output
    find $PATH_TO_BACKUP_LOGDIR -maxdepth 1 -mtime +$DAYS_TO_KEEP_BACKUP -type
f -exec rm -f '{}' +
  fi
}

# Do pre command checks, run the mysqldump command, create symlink to latest
run_mysqldump_command () {
  pre_command_check $PATH_TO_BACKUP_DIR $PATH_TO_BACKUP_LOGDIR
$PATH_TO_BACKUP_LOGFILE
  echo "Creating backup"
  backup=$(/usr/bin/mysqldump --single-transaction -hlocalhost -uroot
-p$MYSQL_ROOT_PASSWORD $MYSQL_DB_NAME > $TARGET)
  create_latest_symlink $TARGET
  echo -e "\n" >> $PATH_TO_BACKUP_LOGFILE

  if [ $REMOVE_OLD_BACKUP_AND_LOGS  -eq 1 ]
  then
    # Remove old backups and log files
    remove_old_backups_and_logs
  fi
}


# Main Script Begins
set_path
run_mysqldump_command
