#!/bin/bash
# Script to create PVs and PVCs for code-server users
# Usage: ./create-storage.sh username [storage_size]

USERNAME=$1
STORAGE_SIZE=${2:-"10Gi"}  # Default storage size is 10GB

if [ -z "$USERNAME" ]; then
  echo "Error: Username is required"
  echo "Usage: $0 username [storage_size]"
  exit 1
fi

# Get the node name - assumes deployment on the current node
NODE_NAME=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')

# Ensure required directory exists
mkdir -p /mnt/syncstore/$USERNAME
chown -R $USERNAME:$USERNAME /mnt/syncstore/$USERNAME

# Create StorageClass if it doesn't exist
kubectl get storageclass code-server-storage &>/dev/null || {
  echo "Creating storage class code-server-storage"
  cat > ~/k8s-code-server/storage-class.yaml << EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: code-server-storage
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
EOF
  kubectl apply -f ~/k8s-code-server/storage-class.yaml
}

# Create PV for the user's workspace
echo "Creating PV pv-$USERNAME-workspace"
cat > ~/k8s-code-server/pv-$USERNAME-workspace.yaml << EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-$USERNAME-workspace
spec:
  capacity:
    storage: $STORAGE_SIZE
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: code-server-storage
  local:
    path: /mnt/syncstore/$USERNAME
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - $NODE_NAME
EOF

# Create PVC for the user's workspace
echo "Creating PVC pvc-$USERNAME-workspace"
cat > ~/k8s-code-server/pvc-$USERNAME-workspace.yaml << EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-$USERNAME-workspace
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: code-server-storage
  resources:
    requests:
      storage: $STORAGE_SIZE
  volumeName: pv-$USERNAME-workspace
EOF

# Apply the PV and PVC
kubectl apply -f ~/k8s-code-server/pv-$USERNAME-workspace.yaml
kubectl apply -f ~/k8s-code-server/pvc-$USERNAME-workspace.yaml

# Check if PV and PVC are created
PV_STATUS=$(kubectl get pv pv-$USERNAME-workspace -o jsonpath='{.status.phase}')
PVC_STATUS=$(kubectl get pvc pvc-$USERNAME-workspace -o jsonpath='{.status.phase}')

echo "Storage setup for $USERNAME:"
echo "- PV: pv-$USERNAME-workspace ($PV_STATUS)"
echo "- PVC: pvc-$USERNAME-workspace ($PVC_STATUS)"
echo "- Size: $STORAGE_SIZE"
echo "- Node: $NODE_NAME"