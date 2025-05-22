# Code-Server Multi-Node Kubernetes Setup

## Prerequisites

- Kubernetes cluster with control-plane and worker nodes
- NFS mounted at `/mnt/syncstore` on all nodes
- Docker image: `shasha0072/code-server-custom-extension:latest`

## Directory Structure

```
~/k8s-code-server/
├── create-storage.sh       # Creates PV/PVC for users
├── deploy-user.sh          # Deploys code-server pods
├── setup-all-nodes.sh      # Sets up certificates on all nodes
└── Generated files:
    ├── pv-{user}-workspace.yaml
    ├── pvc-{user}-workspace.yaml
    ├── pod-{user}.yaml
    └── service-{user}.yaml
```

## Initial Setup (One-time)

### 1. Create Directory and Scripts

On control-plane node (e.g., `sync-ai-lab`):

```bash
mkdir -p ~/k8s-code-server
cd ~/k8s-code-server
# Create your scripts: create-storage.sh, deploy-user.sh, setup-all-nodes.sh
chmod +x *.sh
```

### 2. Setup SSL Certificates

Ensure certificates exist in `/opt/code-server/certificates/`:

```bash
mkdir -p /opt/code-server/certificates
# Copy your cert.pem and key.pem files to this directory
```

### 3. Configure All Nodes

Run once to set up certificates on all nodes:

```bash
./setup-all-nodes.sh
```

---

## Deploy a User

### Step 1: Create Storage (if first time for user)

```bash
./create-storage.sh username [storage_size]
# Example:
./create-storage.sh shashwat 10Gi
```

### Step 2: Deploy Code-Server

```bash
./deploy-user.sh username [port] [password] [cpu] [memory]
# Example:
./deploy-user.sh shashwat 30443 qwerty 2 4Gi
```

### Step 3: Access Code-Server

```bash
echo "URL: https://$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}'):PORT"
```

---

## Manage Users

### List Active Users

```bash
kubectl get pods -l app=code-server -o wide
kubectl get services -l app=code-server
```

### Delete User Pod (Keep Storage)

```bash
kubectl delete pod code-server-username
kubectl delete service code-server-username
```

### Delete User Storage

```bash
kubectl delete pvc pvc-username-workspace
kubectl delete pv pv-username-workspace
```

---

## Quick Commands

```bash
# Deploy user with defaults
./deploy-user.sh john

# Deploy with custom resources
./deploy-user.sh jane 30444 jane123 1 2Gi

# Check pod location
kubectl get pod code-server-john -o wide

# Get service ports
kubectl get svc -l app=code-server
```

---

## File Locations

- **User Workspace:** `/mnt/syncstore/{username}/` (NFS shared)
- **User Config:** `/mnt/syncstore/{username}/.config/code-server/` (NFS shared)
- **SSL Certificates:** `/opt/code-server/certificates/` (on all nodes)

---

## Troubleshooting

```bash
# Check NFS mounts
mount | grep syncstore

# Check pod logs
kubectl logs code-server-username

# Check node resources
kubectl describe node sync-ai-lab00
```
