# Dockerized Corosync QNet Daemon

Sets up a Corosync v3 QNet Daemon for use with Proxmox v6.

This allows you to deploy an external voter on a server that is not running
Proxmox (e.g. a NAS).  The external voter mainly serves to break ties (e.g. if
the cluster has an even number of nodes).

See
<https://pve.proxmox.com/wiki/Cluster_Manager#_corosync_external_vote_support>
for more information.

**NOTE: This container does not have an SSH server installed, so setting it up
        is a bit more involved than a simple `pvecm qdevice setup`.**

## Getting Started

### Prerequisites

This assumes that you have at least 2 proxmox nodes and a separate docker
server.

### Instructions

1. On all Proxmox nodes, install the corosync-qdevice package:
   ```
   apt-get install corosync-qdevice
   ```

2. On all Proxmox nodes, start and enable the corosync-qdevice service:
   ```
   systemctl start corosync-qdevice
   systemctl enable corosync-qdevice
   ```

   * NOTE: if enable fails, first remove `/etc/init.d/corosync-qdevice` and try again.
     See <https://forum.proxmox.com/threads/setting-up-qdevice-fails.56061/>

3. Create and start the docker corosync-qnetd container:
   ```
   docker run -d --name=qnetd --cap-drop=ALL -p 5403:5403 \
      -v /etc/corosync:/etc/corosync
   ```

4. Copy the QNetd CA certificate to all Proxmox nodes:
   ```
   scp /etc/corosync-data/qnetd/nssdb/qnetd-cacert.crt \
        user@proxmox-node:/etc/pve/corosync/qdevice/net/nssdb/
   ```
    * NOTE: Since the Proxmox cluster already synchronizes everything in the
      `/etc/pve` directory, it's easiest to just copy the CA certificate there
      on 1 node, and it'll automatically propogate to all other nodes.
    * However you can also manually copy it to every Proxmox node.

5. On one Proxmox node, initialize the database by running:
   ```
   corosync-qdevice-net-certutil -i \
      -c /etc/pve/corosync/qdevice/net/nssdb/qnetd-cacert.crt
   ```

6. On that same Proxmox node, generate a certificate request:
   ```
   corosync-qdevice-net-certutil -r -n cluster_name
   ```
    * NOTE: The Cluster name must match `cluster_name` key in the
      `corosync.conf`.

7. Copy the certificate request to the qnet config directory:
   ```
   scp user@proxmox-node:/etc/corosync/qdevice/net/nssdb/qdevice-net-node.crq \
      /etc/corosync-data/qnetd/nssdb/qnetd-cacert.crt
   ```

8. Sign the certificate from the qnet container:
   ```
   corosync-qnetd-certutil -s -n cluster_name \
      -c /etc/corosync/qnetd/nssdb/qdevice-net-node.crq
   ```
    * Note the path to the .crq is from inside the container.

9. Copy the newly generated certificate back to the Proxmox node that created
   the request:
   ```
   scp /etc/corosync-data/qnetd/nssdb/cluster-cluster_name.crt \
      user@proxmox-node:/etc/pve/corosync/qdevice/net/nssdb/
   ```

10. Import the certificate on the first Proxmox node:
    ```
    corosync-qdevice-net-certutil -M -c cluster-cluster_name.crt
    ```

11. Copy the output qdevice-net-node.p12 to all other Proxmox nodes:
    ```
    cp -v /etc/corosync/qdevice/net/nssdb/qdevice-net-node.p12 \
       /etc/pve/corosync/qdevice/net/nssdb/
    ```
    * Using the `/etc/pve` synchronization discussed in step 4.

12. Import the cluster certificate on all other nodes in cluster:
    1. Initialize the qdevice database:
       ```
       corosync-qdevice-net-certutil -i \
          -c /etc/pve/corosync/qdevice/net/nssdb/qnetd-cacert.crt
       ```
    2. Import the cluster certificate and key:
       ```
       corosync-qdevice-net-certutil -m \
          -c /etc/pve/corosync/qdevice/net/nssdb/qdevice-net-node.p12
       ```
13. Add qdevice config to corosync.conf:
	 * Edit `/etc/pve/corosync.conf` (See <https://pve.proxmox.com/pipermail/pve-devel/2017-July/027732.html>):
	 * Replace:
		```
		quorum {
			provider: corosync_votequorum
		}
		```
	 * With:
		```
		quorum {
     		provider: corosync_votequorum
     		device {
         		model: net
         		votes: 1
         		net {
           		tls: on
           		host: <ip address of your corosync-qnetd container>
           		algorithm: ffsplit
         		}
     		}
		}
		```
		
14. On all Proxmox nodes, restart the corosync-qdevice service if needed:
   ```
   systemctl restart corosync-qdevice
   ```

## Quick Setup (untested/unsupported)

### Prerequisites

Your docker host **must** have an SSH server installed and at least 1
Proxmox node **must** be able to SSH into your docker server.

### Instructions

1. On all Proxmox nodes, install the corosync-qdevice package:
   ```
   apt-get install corosync-qdevice
   ```

2. On all Proxmox nodes, start and enable the corosync-qdevice service:
   ```
   systemctl start corosync-qdevice
   systemctl enable corosync-qdevice
   ```

3. Create and start the docker corosync-qnetd container:
   ```
   docker run -d --name=qnetd --cap-drop=ALL -p 5403:5403 \
      -v /etc/corosync:/etc/corosync
   ```
    * NOTE: The path on the docker host **must** be `/etc/corosync`.

4. Copy the QNetd utilities to the docker host's `$PATH`:
   ```
   sudo docker cp qnetd:/usr/bin/corosync-qnetd-tool     /usr/local/bin/
   sudo docker cp qnetd:/usr/bin/corosync-qnetd-certutil /usr/local/bin/
   ```

5. From a Proxmox node, run the Proxmox cluster qdevice setup or the
   `corosync-qdevice-net-certutil` quick setup.

    a. `pvecm qdevice setup docker-server`

    b. `corosync-qdevice-net-certutil -Q -n cluster_name
          docker-server proxmox1 proxmox2 ...`
    * NOTE: The Cluster name must match `cluster_name` key in the
          `corosync.conf`.

## Check on a running Corosync QNet Daemon

```
docker exec qnetd corosync-qnetd-tool -s
```

#### Example output

```
QNetd address:                  *:5403
TLS:                            Supported (client certificate required)
Connected clients:              2
Connected clusters:             1
```
