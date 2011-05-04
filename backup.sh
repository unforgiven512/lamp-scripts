#!/bin/bash
FIND_PATH="/srv/www/*"
AWK_DB_POS="4"
AWK_DOMAIN_POS="4"


source ./options.conf


function ask_interval {

echo "Select an interval"
echo "1. Daily"
echo "2. Weekly"
echo "3. Monthly"

SELECTINTERVAL="a"
until  [[ "$SELECTINTERVAL" =~ [0-9]+ ]] && [ $SELECTINTERVAL -gt 0 ] && [ $SELECTINTERVAL -le 3 ]; do
    echo -n "Selection (integer) : "
    read SELECTINTERVAL
done

if [ $SELECTINTERVAL -eq 1 ]; then
    INTERVAL="daily"
elif [ $SELECTINTERVAL -eq 2 ]; then
    INTERVAL="weekly"
elif [ $SELECTINTERVAL -eq 3 ]; then
    INTERVAL="monthly"
fi
}

function find_available_domains {

DOMAINS_AVAILABLE=0
find $FIND_PATH -maxdepth 0 &> /dev/null
#First check to see if there are domains available. Suppress exit status.
if [ $? -eq 0 ]; then 
    find $FIND_PATH -maxdepth 0 > /tmp/domain.txt
    DOMAINS_AVAILABLE=`cat /tmp/domain.txt | wc -l`
#Remove fcgi-bin directory as available domain
    sed -i '/\/srv\/www\/fcgi-bin.d/ d' /tmp/domain.txt
fi

if [ $DOMAINS_AVAILABLE -eq 0 ]; then
    echo "No domains available for backup. Please add a domain first."
    exit
fi

}

function find_available_databases {

DATABASES_AVAILABLE=0
find /var/lib/mysql/* -maxdepth 0 -type d > /tmp/database.txt

#Remove mysql and phpmyadmin as available databases
sed -i '/\/var\/lib\/mysql\/mysql/ d' /tmp/database.txt
sed -i '/\/var\/lib\/mysql\/phpmyadmin/ d' /tmp/database.txt
DATABASES_AVAILABLE=`cat /tmp/database.txt | wc -l`


if [ $DATABASES_AVAILABLE -eq 0 ]; then
    echo "No databases available for backup. Please add a database first."
    exit
fi

}


function create_backup_directory {

if [ -d "/home/$USER" ]; then
    mkdir -p /home/$USER/backup/{database,domain}
    chown -R $USER:$USER /home/$USER/backup
    echo -e "\033[35;1mBackup folders created in /home/$USER/backup.\033[0m"
else
    echo -e "\033[35;1mERROR: User /home/$USER doesn't exist.\033[0m"
fi
}

function cron_backupdb {

if [ ! -d "/home/$USER/backup/database" ]; then
   echo -e "\033[35;1mERROR: Database folder /home/$USER/backup/database doesn't exist, please create it first.\033[0m"
    exit
fi

counter=1
DB_AVAILABLE=`cat /tmp/database.txt | wc -l`

#Print out available databases
echo ""
echo "Select the database you want to backup, 1 to $DB_AVAILABLE"
while read LINE; do
    data=`echo $LINE | awk -F"/" '{ print $5 }'`
    echo "$counter. $data"
    let counter+=1
done < "/tmp/database.txt"

#Reduce counter by 1
let counter-=1

#Ensure that the user inputs a valid integer
SELECTDB="a"
until  [[ "$SELECTDB" =~ [0-9]+ ]] && [ $SELECTDB -gt 0 ] && [ $SELECTDB -le $counter ]; do
echo -n "Selection (integer) : "
read SELECTDB
done

#Capture database name from its full path
DATABASE=`cat /tmp/database.txt | awk NR==$SELECTDB | awk -F"/" '{ print $5 }'`
rm -rf /tmp/database.txt
  
#Check to see if database is already backed up under cronjobs
crontab -l > /tmp/tmpcron.txt
tmp=`grep -w "@$INTERVAL mysqldump -hlocalhost -uroot -p$MYSQL_ROOT_PASSWORD $DATABASE" /tmp/tmpcron.txt | wc -l`
command rm /tmp/tmpcron.txt

if [ $tmp -gt 0 ]; then
	echo -e "\033[35;1mERROR: Database backup already exists, please remove it from crontab -e before entering again.\033[0m"
    exit
fi

#If not, then append a cronjob for it
crontab -l > /tmp/tmpcron.txt
cat >> /tmp/tmpcron.txt <<EOF
@$INTERVAL mysqldump -hlocalhost -uroot -p$MYSQL_ROOT_PASSWORD $DATABASE > /home/$USER/backup/database/$DATABASE.\`/bin/date +\%Y\%m\%d\`.sql; chown $USER:$USER /home/$USER/backup/database/*
EOF
crontab /tmp/tmpcron.txt
command rm /tmp/tmpcron.txt
echo -e "\033[35;1mDatabase $DATABASE will be backed up to /home/$USER/backup/database/$DATABASE $INTERVAL.\033[0m"
echo -e "\033[35;1mTo verify, enter crontab -e.\033[0m"
}


function cron_backupdomain {

if [ ! -d "/home/$USER/backup/domain" ]; then
    echo -e "\033[35;1mERROR: Backup folder /home/$USER/backup/domain doesn't exist, please create it first.\033[0m"
    exit
fi

#Print out available domains and
#Ensure that the user inputs a valid integer
counter=1
DOMAINS_AVAILABLE=`cat /tmp/domain.txt | wc -l`
echo ""
echo "Select the domain you want to backup, 1 to $DOMAINS_AVAILABLE"
while read LINE; do
data=`echo $LINE | awk -F"/" '{ print $'${AWK_DOMAIN_POS}' }'`
    echo "$counter. $data"
    let counter+=1
done < "/tmp/domain.txt"
let counter-=1

SELECTDOMAIN="a"
until  [[ "$SELECTDOMAIN" =~ [0-9]+ ]] && [ $SELECTDOMAIN -gt 0 ] && [ $SELECTDOMAIN -le $counter ]; do
echo -n "Selection (integer) : "
read SELECTDOMAIN
done

#Get full path to domain e.g /srv/www/domain.com
DOMAIN=`cat /tmp/domain.txt | awk NR==$SELECTDOMAIN`
#Remove first forward slash so that tar doesn't output anything during backup
DOMAIN=`echo $DOMAIN | cut -c2-`
#Get domain without its system path
DOMAIN_URL=`cat /tmp/domain.txt | awk NR==$SELECTDOMAIN | awk -F"/" '{ print $'${AWK_DOMAIN_POS}' }'`
rm -rf /tmp/domain.txt

#Check to see if cronjob already exists
crontab -l > /tmp/tmpcron.txt
tmp=`grep -w "$DOMAIN" /tmp/tmpcron.txt | wc -l`
command rm /tmp/tmpcron.txt

if [ $tmp -gt 0 ]; then
    echo -e "\033[35;1mERROR: Domain backup cronjob already exists, please remove it from crontab -e before trying again.\033[0m"
    return 1
fi

#Dump out contents of crontab, and add new line to it
crontab -l > /tmp/tmpcron.txt
cat >> /tmp/tmpcron.txt <<EOF
@$INTERVAL tar -czf /home/$USER/backup/domain/$DOMAIN_URL.\`/bin/date +\%Y\%m\%d\`.tar.gz -C / $DOMAIN; chown $USER:$USER /home/$USER/backup/domain/*
EOF

crontab /tmp/tmpcron.txt
command rm /tmp/tmpcron.txt
echo -e "\033[35;1mDomain $DOMAIN_URL will be backed up to /home/$USER/backup/domain/$DOMAIN_URL $INTERVAL.\033[0m"
echo -e "\033[35;1mTo verify, enter crontab -e.\033[0m"
}

function cron_cleanbackup {

if [ ! -d "/home/$USER" ]; then
    echo -e "\033[35;1mERROR: Folder /home/$USER/backup doesn't exist, type in a valid system user.\033[0m"
    return 1
fi

if ! [[ "$DAYS" =~ ^[0-9]+$ ]]; then
    echo -e "\033[35;1mERROR: Please enter a valid \"Days\" integer.\033[0m"
    return 1
fi

#Dump out contents of crontab, and add new line to it
crontab -l > /tmp/tmpcron.txt
cat >> /tmp/tmpcron.txt <<EOF
@$INTERVAL find /home/$USER/backup/* -mtime +$DAYS -exec rm -rfv {} \; > /home/$USER/cleanbackup.log
EOF
crontab /tmp/tmpcron.txt
command rm /tmp/tmpcron.txt
echo -e "\033[35;1mBackup files older than $DAYS days will be removed from /home/$USER/backup.\033[0m"
echo -e "\033[35;1mTo verify, enter crontab -e.\033[0m"
}



if [ ! -n "$1" ]; then
    echo ""
    echo -n  "$0"
    echo -ne "\033[36m backupdir User\033[0m"
    echo     " - Create backup /home/User/backup/{domain,database} directories to store backup files from cronjob."

	echo -n  "$0"
    echo -ne "\033[36m backupdb User\033[0m"
    echo     " - Set up cronjob to mysqldump DB_Name to USER's backup directory."

	echo -n  "$0"
    echo -ne "\033[36m backupsite User\033[0m"
    echo     " - Set up cronjob to tar.gz Domain.tld to User's backup directory."

	echo -n  "$0"
    echo -ne "\033[36m cleanbackup Old User\033[0m"
    echo     " - Set up cronjob to remove backups files that are older than \"Old\"(integer) days from User's backup directory."

    echo ""
    exit
fi


case $1 in
backupdir)
    if [ ! $# -eq 2 ]; then
        echo -e "\033[35;1mPlease enter all required parameters\033[0m"
        exit
    else
        USER=$2
        create_backup_directory
    fi
  ;;
backupdb)
    if [ ! $# -eq 2 ]; then
        echo -e "\033[35;1mPlease enter all required parameters\033[0m"
        exit
    else
        USER=$2
		ask_interval
        find_available_databases
        cron_backupdb
    fi
  ;;
backupsite)
    if [ ! $# -eq 2 ]; then
        echo -e "\033[35;1mPlease enter all required parameters\033[0m"
        exit
    else
        USER=$2
        find_available_domains
		ask_interval
        cron_backupdomain
    fi
  ;;
cleanbackup)
    if [ ! $# -eq 3 ]; then
        echo -e "\033[35;1mPlease enter all required parameters\033[0m"
        exit
    else
        USER=$3
		DAYS=$2
		ask_interval
        cron_cleanbackup
    fi
  ;;
esac
