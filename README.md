# Dockerized Corosync QNet Daemon

Sets up a Corosync v3 QNet Daemon for use with Proxmox.

[Docker Hub](https://hub.docker.com/r/modelrockettier/corosync-qnetd)

This allows you to deploy an external voter on a server that is not running Proxmox (e.g. a NAS).
The external voter mainly serves to break ties (e.g. if the cluster has an even number of nodes).

See <https://pve.proxmox.com/wiki/Cluster_Manager#_corosync_external_vote_support>
for more information.

**NOTE: This container does not have an SSH server installed, so setting it up is a bit more
involved than a simple `pvecm qdevice setup`.**

## Getting Started

### Prerequisites

This assumes that you have at least 2 Proxmox nodes and a separate docker server.

You will also need to set a few environment variables (or manually replace them with the
appropriate values in the commands below):

* `CLUSTER_NAME`: The name of your Proxmox cluster (must match the `cluster_name` key in
  `/etc/corosync/corosync.conf` on your Proxmox nodes.

  E.g.
  ```
  CLUSTER_NAME=cluster1
  ```

* `PROXMOX_NODE`: The credentials to ssh into your first Proxmox node (usually user@host or
  user@ip).

  E.g.
  ```
  PROXMOX_NODE=root@proxmox1
  ```

* `QNETD_DATA`: Where to store the corosync-qnetd config data on the docker host.

  E.g.
  ```
  QNETD_DATA=/etc/corosync-data
  ```

### Instructions

The general flow is to set up the qnet device with 1 Proxmox node, then to add the rest of the
Proxmox nodes afterwards.

You will need to run some commands on the docker host and some on the initial Proxmox node.
Instructions below are prefixed with **\[docker\]** and **\[proxmox\]** respectively depending on
where they need to be run.

It makes no difference which Proxmox node you pick for the initial set up, but being able to
directly transfer files (e.g. via scp) between it and the docker host will make it easier.

1. **\[docker\]** Pull the docker corosync-qnetd container (or build it from this repo)
   ```
   docker pull modelrockettier/corosync-qnetd
   ```

2. **\[docker\]** Create and start the docker corosync-qnetd container:
   ```
   docker run -d --name=qnetd --cap-drop=ALL -p 5403:5403 \
      -v ${QNETD_DATA}:/etc/corosync modelrockettier/corosync-qnetd
   ```

3. **\[docker\]** Copy the QNetd CA certificate to the first Proxmox node:
   ```
   scp ${QNETD_DATA}/qnetd/nssdb/qnetd-cacert.crt \
        ${PROXMOX_NODE}:/etc/pve/corosync/qdevice/net/nssdb/
   ```
    * NOTE: Since the Proxmox cluster already synchronizes everything in the `/etc/pve` directory,
      it's easiest to just copy the CA certificate there on 1 node, and it'll automatically
      propogate to all other nodes. This way you won't need to copy it over to the other nodes
      individually.
      - If the directory `/etc/pve/corosync/qdevice/net/nssdb` is missing, run `mkdir -p /etc/pve/corosync/qdevice/net/nssdb` on the Proxmox node.

4. **\[proxmox\]** Install the corosync-qdevice package on the first Proxmox node:
   ```
   apt-get install corosync-qdevice
   ```

5. **\[proxmox\]** Start and enable the corosync-qdevice service on the first Proxmox node:
   ```
   systemctl start corosync-qdevice
   systemctl enable corosync-qdevice
   ```

   * NOTE: if enable fails, try deleting `/etc/init.d/corosync-qdevice` and try again.
     See <https://forum.proxmox.com/threads/setting-up-qdevice-fails.56061/>
     - The `corosync-qdevice` service will fail to start as step 14 has not been done yet. It should not fail to start after doing step 14.

6. **\[proxmox\]** Initialize the corosync-qdevice certificate database on the first Proxmox node:
   ```
   corosync-qdevice-net-certutil -i \
      -c /etc/pve/corosync/qdevice/net/nssdb/qnetd-cacert.crt
   ```

7. **\[proxmox\]** Generate a certificate signing request on the first Proxmox node:
   ```
   corosync-qdevice-net-certutil -r -n ${CLUSTER_NAME}
   ```

8. **\[docker\]** Copy the certificate signing request to the corosync config directory:
   ```
   scp ${PROXMOX_NODE}:/etc/corosync/qdevice/net/nssdb/qdevice-net-node.crq \
      ${QNETD_DATA}/qnetd/nssdb/
   ```

9. **\[docker\]** Sign the certificate from the corosync-qnetd container:
   ```
   docker exec qnetd \
      corosync-qnetd-certutil -s -n ${CLUSTER_NAME} \
         -c /etc/corosync/qnetd/nssdb/qdevice-net-node.crq
   ```
    * Note the path to the .crq is from inside the container.

10. **\[docker\]** Copy the newly generated certificate back to the first Proxmox node:
    ```
    scp ${QNETD_DATA}/qnetd/nssdb/cluster-${CLUSTER_NAME}.crt \
       ${PROXMOX_NODE}:/etc/pve/corosync/qdevice/net/nssdb/
    ```

11. **\[proxmox\]** Import the certificate on the first Proxmox node:
    ```
    corosync-qdevice-net-certutil -M -c cluster-${CLUSTER_NAME}.crt
    ```

12. **\[proxmox\]** Copy the output qdevice-net-node.p12 to all other Proxmox nodes:
    ```
    cp -v /etc/corosync/qdevice/net/nssdb/qdevice-net-node.p12 \
       /etc/pve/corosync/qdevice/net/nssdb/
    ```
    * NOTE: We're again using the `/etc/pve` synchronization discussed in step 3.

13. **\[proxmox\]** Set up all other Proxmox nodes
    1. Repeat steps 4-6 above
       1. Install the corosync-qdevice package

       2. Start and enable the corosync-qdevice service

       3. Initialize the corosync-qdevice certificate database
          ```
          corosync-qdevice-net-certutil -i \
             -c /etc/pve/corosync/qdevice/net/nssdb/qnetd-cacert.crt
          ```

    2. Import the corosync cluster certificate and key:
       ```
       corosync-qdevice-net-certutil -m \
          -c /etc/pve/corosync/qdevice/net/nssdb/qdevice-net-node.p12
       ```

14. **\[proxmox\]** Add qdevice config to `/etc/pve/corosync.conf` on the first Proxmox node:

    Edit `/etc/pve/corosync.conf`:
    * Replace:
      ```
      quorum {
          provider: corosync_votequorum
      }
      ```
    * With the following (and change `${DOCKER_HOST}` to the hostname or IP of your docker host):
      ```
      quorum {
          provider: corosync_votequorum
          device {
              model: net
              votes: 1
              net {
                  tls: on
                  host: ${DOCKER_HOST}
                  algorithm: ffsplit
              }
          }
      }
      ```
    See <https://pve.proxmox.com/pipermail/pve-devel/2017-July/027732.html> for more info.

15. **\[proxmox\]** Restart the corosync-qdevice service **on all Proxmox nodes**:
   ```
   systemctl restart corosync-qdevice
   ```

16. **\[docker\]** [Ensure corosync-qnetd is working properly]

   The number of connected clients should be equal to the number of proxmox nodes online.

## Quick Setup (untested/unsupported)

This should work and be a bit quicker and easier than the above quick start guide, but it hasn't
been tested and requires your proxmox nodes to be able to SSH into your docker host.

### Prerequisites

Your docker host **must** have an SSH server installed and the Proxmox node used in step 5
**must** be able to SSH into your docker server.

You will also need to set a few environment variables (or manually replace them with the
appropriate values in the commands below):

* `CLUSTER_NAME`: The name of your Proxmox cluster (must match the `cluster_name` key in
  `/etc/corosync/corosync.conf` on your Proxmox nodes.

  E.g.
  ```
  CLUSTER_NAME=pm-cluster-1
  ```

* `DOCKER_HOST`: The hostname or IP address of your docker host

  E.g.
  ```
  DOCKER_HOST=docker1
  ```

* `PROXMOX_NODES`: The hostnames or IP addresses of your proxmox nodes

  E.g.
  ```
  PROXMOX_NODES=( proxmox1 proxmox2 )
  ```

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

3. On the docker host, create and start the docker corosync-qnetd container:
   ```
   docker run -d --name=qnetd --cap-drop=ALL -p 5403:5403 \
      -v /etc/corosync:/etc/corosync modelrockettier/corosync-qnetd
   ```
    * NOTE: The corosync-qnetd data **must** be stored in `/etc/corosync` on the docker host.

4. On the docker host, copy the QNetd tools into the `$PATH`:
   ```
   sudo docker cp qnetd:/usr/bin/corosync-qnetd-tool     /usr/local/bin/
   sudo docker cp qnetd:/usr/bin/corosync-qnetd-certutil /usr/local/bin/
   ```

5. From a Proxmox node, run the Proxmox cluster qdevice setup
   ```
   pvecm qdevice setup ${DOCKER_HOST}
   ```

   - The `corosync-qdevice-net-certutil` quick setup may also work (again, this is untested).
     ```
     corosync-qdevice-net-certutil -Q -n ${CLUSTER_NAME}
            ${DOCKER_HOST} ${PROXMOX_NODES[@]}
     ```

6. On the docker host, [Ensure corosync-qnetd is working properly]

   The number of connected clients should be equal to the number of proxmox nodes online.

[Ensure corosync-qnetd is working properly]: <#check-on-a-running-corosync-qnet-daemon>

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
