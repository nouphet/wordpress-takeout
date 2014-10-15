#!/usr/bin/env bash

# wordpress-takeout.sh
#
#    "Take out WordPress database and files fully"
#
# Usage
#
# $ /path/to/wordpress-takeout.sh </path/to/wp-config.php> </path/to/export/directory>
#
# Website
#
#    https://github.com/nouphet/wordpress-takeout
#    Based on https://github.com/suin/xoops-takeout
#    Thx Suin.
#

PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin

SCRIPT_NAME=$0
# Set remote backup server as nfs mount
#MOUNT_TGT="192.168.1.1:/backup"

#
# Show help and usages
#
help(){
	echo "Take out WordPress database and files fully"
	echo ""
	echo "Usage:"
	echo "  \$ $SCRIPT_NAME <path/to/wp-config.php> <export-directory>"
	echo "  \$ $SCRIPT_NAME <path/to/wp-config.php> <export-directory> <rotate-limit>"
}

#
# mount backup directory
#
#mount -t nfs $MOUNT_TGT /backup

#
# Export XOOPS information
#
export_wp_info() {
	mainfile="$1"
	php -r "
		error_reporting(0);
		require '$mainfile';
		echo 'export DB_USER=',          DB_USER,          PHP_EOL;
		echo 'export DB_PASS=',          DB_PASSWORD,      PHP_EOL;
		echo 'export DB_HOST=',          DB_HOST,          PHP_EOL;
		echo 'export DB_NAME=',          DB_NAME,          PHP_EOL;
		"
}

#
# Make MySQL dump
#
make_mysql_dump() {
	[ $# -eq 5 ] || return 1

	host="$1"
	user="$2"
	pass="$3"
	database="$4"
	filename="$5"
	
	if [ -z "$pass" ]
	then
		mysqldump "-h$host" "-u$user" "-p$pass" $database > "$filename"
		#mysqldump "-h$host" "-u$user"           $database > "$filename"
	else
		mysqldump "-h$host" "-u$user" "-p$pass" $database > "$filename"
	fi
}

#
# Compress files
#
compress_files() {
	directory="$1"
	name="$2"
	basename=$(basename $directory)
	base=$(dirname $directory)
	[ -d "$directory" ] || return 1
	[ -z "$name" ] && name=$basename.tgz
	tar czf $name -C $base $basename
}

#
# Do backup rotation
#
do_rotate() {
	backup_directory=$1
	name=$2
	rotate_limit=$3

	while [ $(ls $backup_directory/$name.*.tgz 2> /dev/null | wc -l) -gt $rotate_limit ]
	do
		rm -f $(ls $backup_directory/$name.*.tgz | head -1)
	done
}


#
# Main function
#
main() {

	if [ $# -lt 2 ]
	then
		help
		return 1
	fi
	
	mainfile="$1"
	backup_directory="$2"
	date=$(date "+%y%m%d.%H%M")
	do_rotate=0
	root_path=$(cd $(dirname $1); pwd)
	
	if [ $# -gt 2 ]
	then
		if [ $3 -gt 0 ]
		then
			do_rotate=1
			rotate_limit=$3
		else
			echo "Rotate limit must be more than or equals to 1"
			return 1
		fi
	fi

	if [ ! -f "$mainfile" ]
	then
		echo "wp-config.php not found: $mainfile"
		return 1
	fi
	
	if [ ! -r "$mainfile" ]
	then
		echo "wp-config.php not readable: $mainfile"
		return 1
	fi

	if [ ! -d "$backup_directory" ]
	then
		echo "Back up directory not found: $backup_directory"
		return 1
	fi
	
	if [ ! -w "$backup_directory" ]
	then
		echo "Back up directory not writable: $backup_directory"
		return 1
	fi

	$(export_wp_info $mainfile)
	
	mysql_backup_filename="/tmp/$DB_NAME.sql"

	make_mysql_dump "$DB_HOST" "$DB_USER" "$DB_PASS" "$DB_NAME" "$mysql_backup_filename" 
	tar cjf "$backup_directory/$DB_NAME.$date.tar.bz2" \
		-C $(dirname "$mysql_backup_filename") $(basename "$mysql_backup_filename") \
		-C $(dirname "$root_path") $(basename "$root_path") --exclude .git
	rm -f "$mysql_backup_filename"

	if [ $do_rotate -eq 1 ]
	then
		do_rotate $backup_directory $DB_NAME $rotate_limit
	fi
}

main $@

#
# unmount backup directory
#
#umount /backup

exit 0

