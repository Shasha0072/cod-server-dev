#!/bin/bash
# Deploy code-server pod for a user
# Usage: ./deploy-user.sh username [port] [password]

USERNAME=$1
PORT=${2:-30000}  # Default port is 30000 if not specified
PASSWORD=${3:-password}  # Default password is "password"

# Ensure required directories exist
mkdir -p /home/$USERNAME/.config/code-server
mkdir -p /home/$USERNAME/.local/share/code-server
mkdir -p /mnt/syncstore/$USERNAME

# Set correct ownership
chown -R $USERNAME:$USERNAME /home/$USERNAME/.config/code-server
chown -R $USERNAME:$USERNAME /home/$USERNAME/.local/share/code-server
chown -R $USERNAME:$USERNAME /mnt/syncstore/$USERNAME

# Get user's UID and GID
USER_UID=$(id -u $USERNAME)
USER_GID=$(id -g $USERNAME)

# Create pod definition
cat > ~/k8s-code-server/pod-$USERNAME.yaml << EOF2
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
    hostPath:
      path: /mnt/syncstore/$USERNAME
      type: Directory
  - name: certificates
    hostPath:
      path: /opt/code-server/certificates
      type: Directory
EOF2

# Create service definition
cat > ~/k8s-code-server/service-$USERNAME.yaml << EOF2
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
EOF2

# Apply the kubernetes resources
kubectl apply -f ~/k8s-code-server/pod-$USERNAME.yaml
kubectl apply -f ~/k8s-code-server/service-$USERNAME.yaml

echo "Deployed code-server for $USERNAME"
echo "URL: https://$(hostname -I | awk '{print $1}'):$PORT"
echo "Password: $PASSWORD"