VM-Setup (for CI)
=================

In the following instruction "this directory" refers to the directory (outside of the VM) where this README.md resides.

1. create a VM with network adapter
   - recommended more than 16GB HD and 1GB RAM
2. install debian (stretch) into this VM
   - with SSHD
   - recommended: default user, one partition, mostly default settings
3. create configuration for connecting to this vm
   - create an ssh-key (may have a passphrase) named "vm-key" in this directory
   - install the public key into the VMs authorized_keys-file (e.g. with `ssh-copy-id`)
   - create a file named `<myconfname>/config` containing `to=user@vm-connection-info`
4. connect to this VM and install CI-SSH-Key (generate one named vm-key in this directory)
   - (optional) disable SSH-Password Auth (in the VM)
   - (optional; required for CI) disable sudo requiring a password. (in the VM)
5. Place the NRE archives in `nre-results/*.tar.gz`. You can generate them by running `./all root $(date +%Y)` in the NRE repository, which will place the archives in the `generated/` folder there.
6. (optional) install some packages for CI speedup (in the VM)
7. (optional) Now may be a good time to poweroff the VM, take a snapshot and power it back on.
8. run `./setup <myconfname> [fresh]`
   - `fresh` instructs the script to reset the VM before installing

(Steps 4 and 6 can be guided by the script "init-vm".)

Creating a tricks script
------

You may create a script named `tricks` in this directory. This script will be executed after initial bootstrap is completed but before bootstrap-user is invoked. This script may therefore apply some site-local patches to the system to get everything ready for initializing gigi's database. Things to do here would be:
- setting up additional tunnels
- patching gigi's public suffix list to accept your domain
- other stuff your site requires

Here are some useful snippets that you might want to include in your tricks file:


### Adding your own domain as public suffix

The bootstrap procedure requires Gigi’s domain to be exactly one level below a *public suffix*,
for example `someca.de` or `someca.co.uk`.
If you do not have many such domains to spare,
you can edit Gigi’s public suffix list to add a domain controlled by you to it (for example `gigi.yourname.com`),
and then run Gigi instances under `test1.gigi.yourname.com`, `test2.gigi.yourname.com` etc.
In this example, `YOUR.PUBLIC.SUFFIX` below would be `gigi.yourname.com`.

```
if ! sudo lxc-attach -n gigi -- unzip -c /usr/share/java/gigi.jar club/wpia/gigi/util/effective_tld_names.dat | grep "YOUR.PUBLIC.SUFFIX" > /dev/null; then
    echo "patching public suffixes"
    sudo lxc-attach -n gigi -- apt-get update
    sudo lxc-attach -n gigi -- apt-get install --no-install-recommends -y unzip zip
    sudo lxc-attach -n gigi bash <<EOF
cd /tmp
rm -fR club
unzip /usr/share/java/gigi.jar club/wpia/gigi/util/effective_tld_names.dat
printf 'YOUR.PUBLIC.SUFFIX\n' >> club/wpia/gigi/util/effective_tld_names.dat
zip /usr/share/java/gigi.jar club/wpia/gigi/util/effective_tld_names.dat
rm -fR club
EOF
fi
```

### Forwarding IPv6 traffic to nginx

All containers inside the VM have an IP address in the private 10.0.0.0/8 block,
and we set up iptables rules to NAT IPv4 traffic from the VM to the nginx container
(which then proxies to Gigi).
This doesn't work if your VM only has a public IPv6 address, for example because its host system is on a residential connection.
In this case, you can set up another server (with an IPv4 address) to proxy to your system via IPv6,
and then run services in the VM that forward that IPv6 traffic back to nginx' IPv4 address.
(You will have to use that server's domain name in your configuration,
and possibly adjust the public suffix list as described elsewhere in this document.)

```
if ! [[ -f /etc/systemd/system/forward-to-nginx@.socket ]]; then
    sudo tee /etc/systemd/system/forward-to-nginx@.socket > /dev/null << 'EOF'
[Unit]
Description=Listen on port %i and forward it to the nginx container

[Socket]
ListenStream=%i

[Install]
WantedBy=sockets.target
EOF
    sudo systemctl daemon-reload
fi
if ! [[ -f /etc/systemd/system/forward-to-nginx@.service ]]; then
    sudo tee /etc/systemd/system/forward-to-nginx@.service > /dev/null << 'EOF'
[Unit]
Description=Forward port %i to the nginx container
Documentation=man:systemd-socket-proxyd(8)

[Service]
ExecStart=/lib/systemd/systemd-socket-proxyd 10.0.3.13:%i

DynamicUser=yes
PrivateUsers=yes
PrivateTmp=yes
PrivateDevices=yes
ProtectSystem=strict
ProtectHome=yes
NoNewPrivileges=yes
SystemCallArchitectures=native
RestrictAddressFamilies=AF_INET
ProtectKernelModules=yes
MemoryDenyWriteExecute=yes
RestrictRealtime=yes
EOF
    sudo systemctl daemon-reload
fi
sudo systemctl enable forward-to-nginx@{80,443}.socket
sudo systemctl start forward-to-nginx@{80,443}.socket
```


Other snippets
--------------

### Restarting the user-bootstrap procedure

If you entered wrong bootstrap users or something went wrong during the final phase of bootstrapping
(the actual initialization of Gigi’s database with the first administrative accounts)
you can kill the script and then wipe the database with the following one-liner (run in the VM):

```bash
sudo lxc-attach -n gigi -- systemctl stop gigi-proxy.{service,socket} cassiopeia-client && sudo lxc-attach -n postgres-primary -- su -c "psql" postgres <<< "DROP DATABASE gigi; CREATE DATABASE gigi;"
```

Afterwards, you can run `./bootstrap-user` in the VM again.
