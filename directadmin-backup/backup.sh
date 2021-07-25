backupdir="/mnt/hdd/backups/"
export dstr=$(date +"%m-%d-%y")

gzip_user () {
	user="$1"
	echo "Running pigz for $user"
	tar --use-compress-program=pigz -cf $backupdir/$dstr/$user/$user.tar.gz "/home/$user/"
}

mysql_backup () {
	user="$1"
	userdbs=$(mysql -e 'show databases' -s --skip-column-names | grep -wE "${user}_.*.")

	for db in $userdbs; do
		echo "Backing up database $db"
		mysqldump $db | gzip > $backupdir/$dstr/$user/databases/$db.sql.gz
	done
}

rotate_backups () {
    # 7 day backup retention
	for dir in $(find /mnt/hdd/backups/ -type d -mtime +7); do
		echo "Purging $dir"
		rm -rf "$dir"
	done
}

for user in $(find /usr/local/directadmin/data/users/ -maxdepth 1 -mindepth 1 -type d -printf '%f\n'); do
	if [[ ! -d "$backupdir/$dstr/$user/databases/" ]]; then
		mkdir -p "$backupdir/$dstr/$user/databases/"
	fi
	
	gzip_user "$user"
	mysql_backup "$user"
done

rotate_backups