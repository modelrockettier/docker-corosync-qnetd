#!/bin/bash

dir=/etc/corosync/qnetd
db="$dir/nssdb"

set -e

umask ${UMASK:-022}

if [ ! -d "$db" ]; then
	echo "Creating corosync database dir: $db"
	mkdir -p "$db"
fi

## Generate the corosync certificates
## (taken from the corosync-qnetd v3 debian postinst script)
if [ ! -f "$db/cert9.db" ]; then
	if [ -f "$db/cert8.db" ]; then
		echo "Upgrading corosync certificate database"
		# if the password file is empty, add a newline so it's accepted
		if [ -f "$db/pwdfile.txt" -a ! -s "$db/pwdfile.txt" ]; then
			echo > "$db/pwdfile.txt"
		fi

		# upgrade to SQLite database
		certutil -N -d "sql:$db" -f "$db/pwdfile.txt" -@ "$db/pwdfile.txt"
		# Make cert9.db and key4.db permissions the same as cert8.db's perms
		chmod --reference="$db/cert8.db" "$db/cert9.db" "$db/key4.db"
	else
		echo "Creating corosync certificates"
		corosync-qnetd-certutil -i -G
	fi
fi

if [ -n "$COROSYNC_QNETD_OPTIONS$*" ]; then
	echo "Starting corosync-qnetd with args: $COROSYNC_QNETD_OPTIONS $*"
else
	echo "Starting corosync-qnetd"
fi
error=0
exec /usr/bin/corosync-qnetd -f $COROSYNC_QNETD_OPTIONS "$@" || error=$?

echo "Failed to start corosync-qnetd: $error" >&2
# exec somehow failed, return the error code
exit $error

## Original systemd service:
#[Service]
#EnvironmentFile=-/etc/default/corosync-qnetd
#ExecStart=/usr/bin/corosync-qnetd -f $COROSYNC_QNETD_OPTIONS
#Type=notify
#StandardError=null
#Restart=on-abnormal
#User=coroqnetd
#RuntimeDirectory=corosync-qnetd
#RuntimeDirectoryMode=0770
#PrivateTmp=yes
