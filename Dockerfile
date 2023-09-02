FROM debian:bookworm-slim

LABEL description="Corosync Qdevice Network daemon"
LABEL documentation="man:corosync-qnetd"

# Install the proxmox repository signing key.
ADD "https://enterprise.proxmox.com/debian/proxmox-release-bookworm.gpg" \
	/etc/apt/trusted.gpg.d/proxmox-release-bookworm.gpg

# Create the coroqnetd user and group, set the sticky bit on /var/run so
# corosync-qnetd can create its runtime directory, and install the proxmox
# corosync3 repository.  Don't create the runtime directory yet since the user
# may want to run with a different uid/gid.
#
# Then install corosync-qnetd from the Proxmox repos. Also don't generate
# the certs here and instead create them when the container is first run.
RUN adduser --quiet --system --disabled-login --no-create-home \
		--home /etc/corosync/qnetd --group --uid=903 coroqnetd \
	&& chmod 1777 /var/run \
	&& chmod a+r /etc/apt/trusted.gpg.d/proxmox-release-bookworm.gpg \
	&& echo "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" \
		> /etc/apt/sources.list.d/corosync3.list \
	&& mkdir -p /etc/corosync/qnetd/nssdb \
	&& touch /etc/corosync/qnetd/nssdb/cert9.db \
	&& apt-get update \
	&& apt-get install --no-install-recommends -y corosync-qnetd \
	&& rm -rf /etc/corosync /var/lib/apt/lists/*

# Run the status command periodically to make sure everything is working
# (This returns success if qnetd is running, even if nobody is connected)
HEALTHCHECK CMD corosync-qnetd-tool -s

# The Corosync user and group to run as (change with docker run -u)
USER 903:903

# Corosync settings
VOLUME /etc/corosync

# The Corosync qnet device port (TCP)
EXPOSE 5403

# The umask to use when creating new files/directories (default: 022)
ENV UMASK=

# You can also add qnetd arguments via this environment variable
ENV COROSYNC_QNETD_OPTIONS=

# The arguments to pass to corosync-qnetd (-f is always passed).
# E.g. -s required -m 1
CMD []
ENTRYPOINT ["start-coroqnetd"]

COPY start-coroqnetd.sh /usr/local/bin/start-coroqnetd
