#!/bin/bash

# Set Variables
export PROJECT_ID=$(gcloud config get-value project)
export ZONE=us-central1-a

VM_PREFIX=abm
VM_WS=$VM_PREFIX-ws
VM_CP1=$VM_PREFIX-cp1
VM_CP2=$VM_PREFIX-cp2
VM_CP3=$VM_PREFIX-cp3
VM_W1=$VM_PREFIX-w1
VM_W2=$VM_PREFIX-w2

declare -a VMs=("$VM_WS" "$VM_CP1" "$VM_CP2" "$VM_CP3" "$VM_W1" "$VM_W2")
declare -a IPs=()

# Get IP Addresses
for vm in "${VMs[@]}"
do
IP=$(gcloud compute instances describe $vm --zone ${ZONE} --format='get(networkInterfaces[0].networkIP)')
IPs+=("$IP")
done

# Check that SSH is Setup
for vm in "${VMs[@]}"
do
    while ! gcloud compute ssh root@$vm --zone ${ZONE} --command "echo SSH to $vm succeeded"
    do
        echo "Trying to SSH into $vm failed. Sleeping for 5 seconds. zzzZZzzZZ"
        sleep  5
    done
done

# Create VXLAN
echo "Creating VXLANs"
i=2 # We start from 10.200.0.2/24
for vm in "${VMs[@]}"
do
    gcloud compute ssh root@$vm --zone ${ZONE} << EOF
        apt-get -qq update > /dev/null
        apt-get -qq install -y jq > /dev/null
        set -x
        ip link add vxlan0 type vxlan id 42 dev ens4 dstport 0
        current_ip=\$(ip --json a show dev ens4 | jq '.[0].addr_info[0].local' -r)
        echo "VM IP address is: \$current_ip"
        for ip in ${IPs[@]}; do
            if [ "\$ip" != "\$current_ip" ]; then
                bridge fdb append to 00:00:00:00:00:00 dst \$ip dev vxlan0
            fi
        done
        ip addr add 10.200.0.$i/24 dev vxlan0
        ip link set up dev vxlan0
        systemctl stop apparmor.service #Anthos clusters on bare metal does not support apparmor
        systemctl disable apparmor.service
EOF
    i=$((i+1))
done

# Install Workstation Tools
echo "Installing Workstation Tools"
gcloud compute ssh root@$VM_WS --zone ${ZONE} << EOF
set -x

export PROJECT_ID=\$(gcloud config get-value project)
gcloud iam service-accounts keys create bm-gcr.json \
--iam-account=baremetal-gcr@\${PROJECT_ID}.iam.gserviceaccount.com

curl -LO "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl"

chmod +x kubectl
mv kubectl /usr/local/sbin/
mkdir baremetal && cd baremetal
gsutil cp gs://anthos-baremetal-release/bmctl/1.7.0/linux-amd64/bmctl .
chmod a+x bmctl
mv bmctl /usr/local/sbin/

cd ~
echo "Installing docker"
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
EOF

# Validate VXLAN and Share SSH Key
echo "Validating VXLAN and Sharing SSH Key"
gcloud compute ssh root@$VM_WS --zone ${ZONE} << EOF
set -x
ssh-keygen -t rsa -N "" -f /root/.ssh/id_rsa
sed 's/ssh-rsa/root:ssh-rsa/' ~/.ssh/id_rsa.pub > ssh-metadata
for vm in ${VMs[@]}
do
    gcloud compute instances add-metadata \$vm --zone ${ZONE} --metadata-from-file ssh-keys=ssh-metadata
done
EOF

# Deploy Anthos
echo "Deploying Anthos"
gcloud compute ssh root@$VM_WS --zone ${ZONE} << EOF
set -x
export PROJECT_ID=$(gcloud config get-value project)
export clusterid=cluster-baremetal
bmctl create config -c \$clusterid
cat > bmctl-workspace/\$clusterid/\$clusterid.yaml << EOB
---
gcrKeyPath: /root/bm-gcr.json
sshPrivateKeyPath: /root/.ssh/id_rsa
gkeConnectAgentServiceAccountKeyPath: /root/bm-gcr.json
gkeConnectRegisterServiceAccountKeyPath: /root/bm-gcr.json
cloudOperationsServiceAccountKeyPath: /root/bm-gcr.json
---
apiVersion: v1
kind: Namespace
metadata:
  name: cluster-\$clusterid
---
apiVersion: baremetal.cluster.gke.io/v1
kind: Cluster
metadata:
  name: \$clusterid
  namespace: cluster-\$clusterid
spec:
  type: hybrid
  anthosBareMetalVersion: 1.7.0
  gkeConnect:
    projectID: \$PROJECT_ID
  controlPlane:
    nodePoolSpec:
      clusterName: \$clusterid
      nodes:
      - address: 10.200.0.3
      - address: 10.200.0.4
      - address: 10.200.0.5
  clusterNetwork:
    pods:
      cidrBlocks:
      - 192.168.0.0/16
    services:
      cidrBlocks:
      - 172.26.232.0/24
  loadBalancer:
    mode: bundled
    ports:
      controlPlaneLBPort: 443
    vips:
      controlPlaneVIP: 10.200.0.49
      ingressVIP: 10.200.0.50
    addressPools:
    - name: pool1
      addresses:
      - 10.200.0.50-10.200.0.70
  clusterOperations:
    # might need to be this location
    location: us-central1
    projectID: \$PROJECT_ID
  storage:
    lvpNodeMounts:
      path: /mnt/localpv-disk
      storageClassName: node-disk
    lvpShare:
      numPVUnderSharedPath: 5
      path: /mnt/localpv-share
      storageClassName: standard
  nodeConfig:
    podDensity:
      maxPodsPerNode: 250
    containerRuntime: containerd
---
apiVersion: baremetal.cluster.gke.io/v1
kind: NodePool
metadata:
  name: node-pool-1
  namespace: cluster-\$clusterid
spec:
  clusterName: \$clusterid
  nodes:
  - address: 10.200.0.6
  - address: 10.200.0.7
EOB

bmctl create cluster -c \$clusterid
EOF
