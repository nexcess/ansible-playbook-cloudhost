# 🌐 Cloudhost Playbook Setup: Testing the Cloudhost Playbook on a Virtual Machine

These are instructions for testing the cloudhost playbook using a local virtual machine. We are currently deploying systems with **Rocky Linux 9**, and this guide walks you through setting up a basic VM instance that integrates seamlessly with our infrastructure.

> ✅ **Prerequisites**:
> - A running virtual machine (e.g., via `libvirt`, `Virtual Machine Manager`, `Hyper-HV`, `VirtualBox`, or `GNOME Boxes`) with **Rocky Linux 9** installed.
> - SSH access to the VM (root user with password authentication enabled).
> - A local environment with standard Unix tools and Docker. WSL on Windows should work, as well as standard Linux/MacOS.

---

## 📌 Step 1: Set VM Details

Update the following variables to match your setup. Copy this heredoc into your shell to set up the variables for subsequent heredoc runs:

```bash
: Set the VM IP address.
VM_IP=192.168.122.225
: Set the deployment user.
UNAME=deploy
: Set the path to the SSH key used, we will create it in a later step.
KEY_PATH=./deploy.key
```

> 🛠️ **Tip**: Use `ip a` or `hostname -I` on your VM to find the correct `VM_IP`.

Also build deployable vars using the test interworx license in our password management.

```bash
INTERWORX_LICENSE="THE_KEY_IN_MANAGEMENT"
cat > deployable-vars.yml <<EOF
---
nex_env_target: jarvis
eth0: eth0
eth1: eth1
kernelcare_included: false
server_update: false
server_selinux_enforcing: false
iw_license_key: $INTERWORX_LICENSE
packagetemplate: nc_large
environment:
    hardware: { servers: [{ role: cloudhost, image: rocky-9-x86_64-latest, flavor: n5s-sc-1.large, public_ip: true, aws_volume_size: 480 }] }
bigcommerce:
    addons: [{ id: 2984 }]
software:
    apps: [24, 25, 26, 11, 13, 15, 18, 21, 22, 23]
    wordpress: { caching-plugin: object-cache-pro }
location:
    14: { pricing: 25% }
    16: { pricing: 25% }
    17: { pricing: 25% }
is_flexible: true
resize:
    whitelist: [722, 898, 899, 900, 720, 721]
iw_master_email: nobody@nexcess.net
iw_master_password: FrostedWickTinsmith
EOF
```

---

## 🔧 Step 2: Create SSH Key for Deployment

Generate an SSH key pair using Ed25519, suitable for high security and performance.

```bash
: Create a key for ansible authentication.
ssh-keygen -t ed25519 -f $KEY_PATH -C deploy@cloudhost -N "" -q
```

---

## 📄 Step 3: Copy SSH Key to VM

Copy the public key to the VM’s root account, enabling passwordless SSH access for initial setup. You will be asked for your password.

```bash
: Copy the SSH key to the VMs root account.
ssh-copy-id -i $KEY_PATH root@$VM_IP
```

---

## 🚀 Step 4: Provision VM with Base Configuration

Run the following heredoc to configure the VM. This script performs the following tasks:

- Installs `sudo` for privilege management.
- Creates a non-root user (`deploy`) with home directory and shell.
- Sets up SSH access for the new user.
- Enables passwordless `sudo` for the `deploy` user.
- Sets the system timezone to UTC (as configured by default in Puppet).
- Generates a cloud-init instance ID for use in Puppet.

```bash
: Run update on VM.
ssh -i $KEY_PATH -q -t root@$VM_IP <<EOS
: Setup virtual machine to allow access via ssh/sudo.
yum -y install sudo

: Create the deploy user with home directory and bash shell.
useradd -m -s /bin/bash $UNAME

: Set up .ssh directory and copy roots authorized_keys.
mkdir -p /home/$UNAME/.ssh/
chown $UNAME: /home/$UNAME/.ssh/
cp /root/.ssh/authorized_keys /home/$UNAME/.ssh/
chown $UNAME: /home/$UNAME/.ssh/authorized_keys
chmod 600 /home/$UNAME/.ssh/authorized_keys

: Add user to wheel group for sudo access.
usermod -aG wheel $UNAME

: Create a sudoers file for the deploy user.
cat > /etc/sudoers.d/$UNAME <<EOF
$UNAME ALL=(ALL:ALL) NOPASSWD: ALL
EOF

: Set timezone to UTC.
timedatectl set-timezone UTC

: Ensure cloud-init has an instance-id used for Puppet birth certificate.
if ! [[ -f /var/lib/cloud/data/instance-id ]]; then
    mkdir -p /var/lib/cloud/data/
    uuidgen > /var/lib/cloud/data/instance-id
fi
EOS
```

---

## 📂 Step 5: Configure Ansible Inventory and Network Settings

Generate an Ansible inventory file (`hosts.ini`) and prepare configuration files for deployment.

```bash
: Setup local ansible environment.
cat > hosts.ini <<EOF
[all:vars]
ansible_ssh_user=$UNAME
puppet_project=nexcess
nex_project=virt-guest
nex_zone=us-midwest-1
nex_env=production

[cloudhost]
cloudhost-9999999.us-midwest-1.nxcli.net ansible_host=$VM_IP frontnet_addr=$VM_IP puppet_uuid=f3581a9b-5e75-4479-9fb9-e15ad0d93099 puppet_instance_id=9999999 puppet_hash=ZwZ7T8yWP8V7gRdqhFPYMCiv7OoqXo5UXKLK3RqUON4= public_addr=$VM_IP
EOF

: Copy over configuration files from your Puppet repo.
cp ../../puppet-config/data/common.d/network.yaml .
cp ../../puppet-config/data/common.d/interworx.yaml .
cp ../../puppet-config/data/common.d/apache.yaml .

: Extract the network portion and append /24.
NETWORK_ADDR=$(echo $VM_IP | sed 's/\([0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\)\.[0-9]\{1,3\}/\1/')
NETWORK_CIDR="${NETWORK_ADDR}.0/24"

: Update network.yaml to whitelist the VMs network for SSH.
sed -i "s|10\.255\.252\.0/24|$NETWORK_CIDR|g" network.yaml
```

---

## 🧼 Step 6: Create a Snapshot of the Machine

Before proceeding further, you may want to create a snapshot of the machine to quickly revert to this state for additional runs.

---

## 🧹 Step 7: Clean Prior Puppet Runs (1 of 2)

SSH into our puppet CA server and run the following to clean up any prior Puppet runs:

```bash
: Clean Puppet CA for the VM.
puppetserver ca clean --certname f3581a9b-5e75-4479-9fb9-e15ad0d93099
```

---

## 🧹 Step 8: Clean Prior Puppet Runs (2 of 2)

Visit FreeIPA Hosts list to find prior builds of `cloudhost-9999999.us-midwest-1.nxcli.net` and delete the machine to allow it to re-register.

---

## 🐳 Step 9: Run the Playbook Using Docker

Execute the playbook using a Docker image that includes Ansible and all required dependencies.

```bash
: Build the Docker image.
docker build -t playbook-runner .

: Run the playbook with your current playbook attached.
docker run --rm -v $(pwd)/../:/opt/playbook:ro playbook-runner
```

> Note: The Dockerfile runs Ansible with `ANSIBLE_CALLBACK_WHITELIST=profile_tasks,timer` to provide performance numbers on the playbook itself.

# 🧪 Unit Testing

This section provides an example of how to perform unit testing by checking Puppet for performance metrics. The script SSHs into the VM, copies the Puppet log, and runs a Python script to extract and display performance data.

```bash
: SSH and run the Python script.
ssh -i "$KEY_PATH" -q -t "$UNAME@$VM_IP" <<'EOSSH'
    sudo cp /root/puppet.log /tmp/puppet.log && \
    sudo chmod 644 /tmp/puppet.log && \
    python3 - <<'EOP'
import re
from datetime import datetime
import sys

log_file = "/tmp/puppet.log"
pattern = re.compile(r"^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}) [+-]\d{4} /Stage\[main\]/Nexcess_php_fpm::Install/Package\[([^\]]+)\]/ensure.*$")

first_time = None
last_time = None
entries = []

with open(log_file, "r") as f:
    for line in f:
        match = pattern.match(line)
        if match:
            timestamp = match.group(1)
            package = match.group(2)
            dt = datetime.strptime(timestamp, "%Y-%m-%d %H:%M:%S")
            entries.append((dt, package))
            if first_time is None or dt < first_time:
                first_time = dt
            if last_time is None or dt > last_time:
                last_time = dt

# Print CSV
print("Date,Package")
for dt, pkg in entries:
    print("{},{}".format(dt.strftime("%Y-%m-%d %H:%M:%S"), pkg))

# Print total time
if first_time and last_time:
    diff = last_time - first_time
    print()
    print("Total time: {}".format(diff))
EOP
EOSSH
```
