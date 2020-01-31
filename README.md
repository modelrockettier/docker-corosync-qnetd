## Dockerized Corosync QNet Daemon

Sets up a Corosync v2 QNet Daemon for use with Proxmox v5.

This allows you to deploy an external voter on a server that is not running
Proxmox (e.g. a NAS).  The external voter mainly serves to break ties (e.g. if
the cluster has an even number of nodes).

See
<https://pve.proxmox.com/wiki/Cluster_Manager#_corosync_external_vote_support>
for more information.
