cat > ~/k8s-code-server/cleanup-user.sh << 'EOF'
#!/bin/bash
# Clean up all code-server resources for a user
# Usage: ./cleanup-user.sh username

USERNAME=$1

if [ -z "$USERNAME" ]; then
    echo "Error: Username is required"
    echo "Usage: $0 username"
    exit 1
fi

# Delete the pod
kubectl delete pod code-server-$USERNAME

# Delete the service
kubectl delete service code-server-$USERNAME

echo "Cleaned up all Kubernetes resources for $USERNAME"
EOF

chmod +x ~/k8s-code-server/cleanup-user.sh