FROM debian:stretch-slim

LABEL description="Corosync Qdevice Network daemon"
LABEL documentation="man:corosync-qnetd"

# Install the proxmox repository signing key.
ADD "https://git.proxmox.com/?p=proxmox-ve.git;a=blob_plain;f=debian/proxmox-ve-release-5.x.gpg;hb=refs/heads/master" \
	/etc/apt/trusted.gpg.d/proxmox-ve-release-5.x.gpg

# Create the coroqnetd user and group, set the sticky bit on /var/run so
# corosync-qnetd can create its runtime directory, and install the proxmox
# corosync2 repository.  Don't create the runtime directory yet since the user
# may want to run with a different uid/gid.
#
# Then install corosync-qnetd from the proxmox repos.
RUN addgroup --system --quiet --gid=903 "coroqnetd" \
	&& adduser --system --quiet --home "/etc/corosync/qnetd" --no-create-home --disabled-login --uid=903 --gid=903 "coroqnetd" \
	&& chmod 1777 /var/run \
	&& echo "deb http://download.proxmox.com/debian/pve stretch pve-no-subscription" > /etc/apt/sources.list.d/corosync2.list \
	&& chmod a+r /etc/apt/trusted.gpg.d/proxmox-ve-release-5.x.gpg \
	&& apt-get update \
	&& apt-get install --no-install-recommends -y corosync-qnetd \
	&& rm -rf /etc/corosync /var/lib/apt/lists/*

# Run this command periodically to make sure everything is working
HEALTHCHECK CMD corosync-qnetd-tool -s

# The Corosync user and group to run as (change with docker run -u)
USER 903:903

# Corosync settings
VOLUME /etc/corosync

# Runtime info for corosync, you shouldn't need to mount this
# (but it'll fail to start without this)
VOLUME /var/run

# The Corosync port (TCP)
EXPOSE 5403

# The umask to use when creating new files/directories (default: 022)
ENV UMASK=

# The arguments to pass to corosync-qnetd (-f is always passed).
# E.g. -s required -m 1
CMD []
ENTRYPOINT ["start-coroqnetd"]

COPY start-coroqnetd.sh /usr/local/bin/start-coroqnetd
