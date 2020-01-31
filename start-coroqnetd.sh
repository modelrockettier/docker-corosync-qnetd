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
## (taken from the corosync-qnetd v2 debian postinst script)
if [ ! -f "$db/cert8.db" ]; then
	echo "Creating corosync certificates"
	corosync-qnetd-certutil -i
fi

echo "Starting corosync-qnetd, args: $*"
exec /usr/bin/corosync-qnetd "$@" || error=$?

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
