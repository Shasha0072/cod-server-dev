from flask import Flask, request, jsonify
import subprocess
import os
import logging

app = Flask(__name__)

# Configure logging
logging.basicConfig(level=logging.INFO, 
                    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
                    handlers=[logging.StreamHandler()])
logger = logging.getLogger(__name__)

# Base directory for scripts
SCRIPT_DIR = os.path.expanduser("~/k8s-code-server")

# Ensure script directory exists
os.makedirs(SCRIPT_DIR, exist_ok=True)

@app.route('/health', methods=['GET'])
def health_check():
    """Simple health check endpoint"""
    return jsonify({"status": "healthy"})

@app.route('/api/deploy-user', methods=['POST'])
def deploy_user():
    """Deploy a code-server instance for a user"""
    data = request.json
    
    # Validate required parameters
    if not data or 'username' not in data:
        return jsonify({"error": "Username is required"}), 400
    
    username = data.get('username')
    port = data.get('port', 30000)
    password = data.get('password', 'password')
    cpu_limit = data.get('cpu_limit', '1')
    memory_limit = data.get('memory_limit', '2Gi')
    
    # Log the request
    logger.info(f"Deploying code-server for user: {username}, port: {port}")
    
    try:
        # Create command to execute
        cmd = [f"{SCRIPT_DIR}/deploy-user.sh", username, str(port), password, str(cpu_limit), memory_limit]
        
        # Execute the deployment script
        process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        stdout, stderr = process.communicate()
        
        # Check if deployment was successful
        if process.returncode != 0:
            logger.error(f"Deployment failed for {username}: {stderr.decode()}")
            return jsonify({
                "status": "error",
                "message": f"Deployment failed for {username}",
                "details": stderr.decode()
            }), 500
        
        # Return success response
        return jsonify({
            "status": "success",
            "message": f"Deployed code-server for {username}",
            "details": stdout.decode(),
            "access_url": f"https://{get_server_ip()}:{port}"
        })
        
    except Exception as e:
        logger.exception(f"Error deploying code-server for {username}")
        return jsonify({
            "status": "error",
            "message": str(e)
        }), 500

@app.route('/api/cleanup-user', methods=['POST'])
def cleanup_user():
    """Clean up a code-server instance for a user"""
    data = request.json
    
    # Validate required parameters
    if not data or 'username' not in data:
        return jsonify({"error": "Username is required"}), 400
    
    username = data.get('username')
    delete_storage = data.get('delete_storage', False)
    
    # Log the request
    logger.info(f"Cleaning up code-server for user: {username}, delete_storage: {delete_storage}")
    
    try:
        # Create cleanup script if it doesn't exist
        cleanup_script = os.path.join(SCRIPT_DIR, "cleanup-user.sh")
        if not os.path.exists(cleanup_script):
            create_cleanup_script(cleanup_script)
        
        # Make script executable
        os.chmod(cleanup_script, 0o755)
        
        # Execute the cleanup script
        cmd = [cleanup_script, username]
        if delete_storage:
            cmd.append("--delete-storage")
            
        process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        stdout, stderr = process.communicate()
        
        # Check if cleanup was successful
        if process.returncode != 0:
            logger.error(f"Cleanup failed for {username}: {stderr.decode()}")
            return jsonify({
                "status": "error",
                "message": f"Cleanup failed for {username}",
                "details": stderr.decode()
            }), 500
        
        # Return success response
        return jsonify({
            "status": "success",
            "message": f"Cleaned up code-server for {username}",
            "details": stdout.decode()
        })
        
    except Exception as e:
        logger.exception(f"Error cleaning up code-server for {username}")
        return jsonify({
            "status": "error",
            "message": str(e)
        }), 500

@app.route('/api/list-users', methods=['GET'])
def list_users():
    """List all code-server instances"""
    try:
        # Execute kubectl to get pods
        cmd = ["kubectl", "get", "pods", "-l", "app=code-server", "-o", "custom-columns=NAME:.metadata.name,USER:.metadata.labels.user,STATUS:.status.phase,NODE:.spec.nodeName"]
        process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        stdout, stderr = process.communicate()
        
        # Return the list of users
        return jsonify({
            "status": "success",
            "instances": stdout.decode()
        })
        
    except Exception as e:
        logger.exception("Error listing code-server instances")
        return jsonify({
            "status": "error",
            "message": str(e)
        }), 500

def create_cleanup_script(script_path):
    """Create the cleanup script if it doesn't exist"""
    with open(script_path, 'w') as f:
        f.write('''#!/bin/bash
# Script to clean up code-server resources for a user
# Usage: ./cleanup-user.sh username [--delete-storage]

USERNAME=$1
DELETE_STORAGE=false

# Check if --delete-storage flag is provided
if [ "$2" == "--delete-storage" ]; then
  DELETE_STORAGE=true
fi

# Delete pod and service
echo "Deleting pod and service for $USERNAME"
kubectl delete pod code-server-$USERNAME
kubectl delete service code-server-$USERNAME

# Delete storage if requested
if [ "$DELETE_STORAGE" = true ]; then
  echo "Deleting PVC and PV for $USERNAME"
  kubectl delete pvc pvc-$USERNAME-workspace
  kubectl delete pv pv-$USERNAME-workspace
else
  echo "Storage (PV/PVC) preserved for $USERNAME"
fi

echo "Cleanup completed for $USERNAME"
''')

def get_server_ip():
    """Get the server's IP address"""
    try:
        process = subprocess.Popen(["hostname", "-I"], stdout=subprocess.PIPE)
        output, _ = process.communicate()
        ip = output.decode().strip().split()[0]
        return ip
    except Exception:
        return "server-ip"

if __name__ == '__main__':
    # Create necessary scripts if they don't exist
    cleanup_script = os.path.join(SCRIPT_DIR, "cleanup-user.sh")
    if not os.path.exists(cleanup_script):
        create_cleanup_script(cleanup_script)
        os.chmod(cleanup_script, 0o755)
    
    # Run the Flask app
    app.run(host='0.0.0.0', port=5000, debug=False)