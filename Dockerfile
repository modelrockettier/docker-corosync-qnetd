FROM arm64v8/debian:buster-slim

LABEL description="Corosync Qdevice Network daemon"
LABEL documentation="man:corosync-qnetd"

# Create the coroqnetd user and group, set the sticky bit on /var/run so
# corosync-qnetd can create its runtime directory.  Don't create the runtime
# directory yet since the user may want to run with a different uid/gid.
#
# Then install corosync-qnetd from the debian repos.
# Also prevent the post-install script from generating certs since
# it will fail in the container, so we'll do it at runtime.
RUN addgroup --system --quiet --gid=903 "coroqnetd" \
	&& adduser --system --quiet --home "/etc/corosync/qnetd" --no-create-home --disabled-login --uid=903 --gid=903 "coroqnetd" \
	&& chmod 1777 /var/run \
	&& mkdir -p /etc/corosync/qnetd/nssdb \
	&& touch /etc/corosync/qnetd/nssdb/cert9.db \
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
# VOLUME /var/run

# The Corosync port (TCP)
EXPOSE 5403

# The umask to use when creating new files/directories (default: 022)
ENV UMASK=

# The arguments to pass to corosync-qnetd (-f is always passed).
# E.g. -s required -m 1
CMD []
ENTRYPOINT ["start-coroqnetd"]

COPY start-coroqnetd.sh /usr/local/bin/start-coroqnetd
