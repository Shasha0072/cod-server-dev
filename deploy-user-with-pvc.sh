#!/bin/bash
# Deploy code-server pod for a user using existing PVC
# Usage: ./deploy-user.sh username [port] [password] [cpu_limit] [memory_limit]

USERNAME=$1
PORT=${2:-30000}  # Default port is 30000 if not specified
PASSWORD=${3:-password}  # Default password is "password"
CPU_LIMIT=${4:-"1"}  # Default CPU limit is 1 core
MEMORY_LIMIT=${5:-"2Gi"}  # Default memory limit is 2GB

# Check if PVC exists, create if not
kubectl get pvc pvc-$USERNAME-workspace &>/dev/null || {
  echo "PVC for $USERNAME not found. Creating storage..."
  ~/k8s-code-server/create-storage.sh $USERNAME
}

# Get the node name from PV nodeAffinity
NODE_NAME=$(kubectl get pv pv-$USERNAME-workspace -o jsonpath='{.spec.nodeAffinity.required.nodeSelectorTerms[0].matchExpressions[0].values[0]}')

# Ensure required directories exist
mkdir -p /home/$USERNAME/.config/code-server
mkdir -p /home/$USERNAME/.local/share/code-server

# Set correct ownership
chown -R $USERNAME:$USERNAME /home/$USERNAME/.config/code-server
chown -R $USERNAME:$USERNAME /home/$USERNAME/.local/share/code-server

# Get user's UID and GID
USER_UID=$(id -u $USERNAME)
USER_GID=$(id -g $USERNAME)

# Create pod definition using the existing PVC
cat > ~/k8s-code-server/pod-$USERNAME.yaml << EOF
apiVersion: v1
kind: Pod
metadata:
  name: code-server-$USERNAME
  labels:
    app: code-server
    user: $USERNAME
spec:
  containers:
  - name: code-server
    image: shasha0072/code-server-custom-extension:latest
    imagePullPolicy: IfNotPresent
    command: ["/usr/bin/entrypoint.sh"]
    args:
    - --cert=/certificates/cert.pem
    - --cert-key=/certificates/key.pem
    - --bind-addr=0.0.0.0:8443
    - --auth=password
    - /home/coder/workspace
    ports:
    - containerPort: 8443
    env:
    - name: PASSWORD
      value: "$PASSWORD"
    resources:
      limits:
        cpu: "$CPU_LIMIT"
        memory: "$MEMORY_LIMIT"
      requests:
        cpu: "$CPU_LIMIT"
        memory: "$MEMORY_LIMIT"
    volumeMounts:
    - name: config
      mountPath: /home/coder/.config
    - name: local-share
      mountPath: /home/coder/.local/share/code-server
    - name: workspace
      mountPath: /home/coder/workspace
    - name: certificates
      mountPath: /certificates
      readOnly: true
    securityContext:
      runAsUser: $USER_UID
      runAsGroup: $USER_GID
  volumes:
  - name: config
    hostPath:
      path: /home/$USERNAME/.config/code-server
      type: Directory
  - name: local-share
    hostPath:
      path: /home/$USERNAME/.local/share/code-server
      type: Directory
  - name: workspace
    persistentVolumeClaim:
      claimName: pvc-$USERNAME-workspace
  - name: certificates
    hostPath:
      path: /opt/code-server/certificates
      type: Directory
  nodeSelector:
    kubernetes.io/hostname: $NODE_NAME
EOF

# Create service definition
cat > ~/k8s-code-server/service-$USERNAME.yaml << EOF
apiVersion: v1
kind: Service
metadata:
  name: code-server-$USERNAME
  labels:
    app: code-server
    user: $USERNAME
spec:
  type: NodePort
  ports:
  - port: 8443
    targetPort: 8443
    nodePort: $PORT
  selector:
    app: code-server
    user: $USERNAME
EOF

# Apply the kubernetes resources
kubectl apply -f ~/k8s-code-server/pod-$USERNAME.yaml
kubectl apply -f ~/k8s-code-server/service-$USERNAME.yaml

echo "Deployed code-server for $USERNAME"
echo "URL: https://$(hostname -I | awk '{print $1}'):$PORT"
echo "Password: $PASSWORD"
echo "Resources: CPU=$CPU_LIMIT, Memory=$MEMORY_LIMIT"
echo "Using PVC: pvc-$USERNAME-workspace"