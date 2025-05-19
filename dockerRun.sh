docker run -d \
  --name code-server \
  -p 8443:8443 \
  -v "/home/shashwat/.config/code-server:/home/coder/.config" \
  -v "/home/shashwat/.config/code-server/certificates:/home/coder/certificates" \
  -v "/home/shashwat/.local/share/code-server:/home/coder/.local/share/code-server" \
  -v "/mnt/syncstore/shashwat:/home/coder/workspace" \
  -u "$(id -u shashwat):$(id -g shashwat)" \
  -e "PASSWORD=qwerty" \
  --restart=always \
  code-server-custom-extension \
  --cert=/home/coder/certificates/cert.pem \
  --cert-key=/home/coder/certificates/key.pem \
  --bind-addr=0.0.0.0:8443 \
  --auth=password