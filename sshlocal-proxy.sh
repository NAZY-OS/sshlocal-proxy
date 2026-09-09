#!/bin/bash
#
# SSH SOCKS Proxy Starter - Version 1.2 RC II
# Copyright (C) 2026 nazy-os
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

# =============================================
# SSH SOCKS Proxy Starter
# Creates an SSH SOCKS proxy on a specified port
# Supports config file (~/.ssh/proxyssh.conf) and interactive prompts
# =============================================

# Default values (can be overridden)
DEFAULT_PORT=10800
DEFAULT_BIND_IP="10.0.0.1"
DEFAULT_USER="$USER"
DEFAULT_SERVER=""

# Config file path
CONFIG_FILE="$HOME/.ssh/proxyssh.conf"

# =============================================
# Functions
# =============================================

# Ensure .ssh directory exists
ensure_ssh_dir() {
    if [[ ! -d "$HOME/.ssh" ]]; then
        echo "Creating .ssh directory..."
        mkdir -p "$HOME/.ssh" || {
            echo "Error: Failed to create .ssh directory!" >&2
            exit 1
        }
        chmod 700 "$HOME/.ssh"
    fi
}

# Display help in GNU style
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Starts an SSH SOCKS proxy on a specified port."
    echo
    echo "Options:"
    echo "  -h, --help       Show this help message"
    echo "  -c, --config     Use values from ~/.ssh/proxyssh.conf"
    echo "  -s, --server     SSH server address (required)"
    echo "  -u, --user       SSH username"
    echo "  -p, --port       SOCKS proxy port (default: 10800)"
    echo "  -b, --bind       Bind IP address (default: 10.0.0.1)"
    echo
    echo "Examples:"
    echo "  $0 -s example.com -u myuser -p 9050 -b 10.0.1.1"
    echo "  $0 --server vps.example.com --user admin --port 1080"
    exit 0
}

# Load config file if it exists
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        echo "Found config file at $CONFIG_FILE. Load values? (y/n)"
        read -p "> " -r
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if ! source "$CONFIG_FILE"; then
                echo "Error: Failed to load config file!" >&2
                exit 1
            fi
            echo "Config loaded successfully."
        fi
    fi
}

# Validate IP address (IPv4)
validate_ip() {
    local ip="$1"
    if [[ ! "$ip" =~ ^10\.0\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo "Error: Invalid IP address! Must be in 10.0.x.x format." >&2
        return 1
    fi
    return 0
}

# Prompt for user input with defaults
prompt_for_values() {
    # Prompt for server (required)
    while [[ -z "$DEFAULT_SERVER" ]]; do
        read -p "Enter SSH server address (e.g., example.com): " DEFAULT_SERVER
        if [[ -z "$DEFAULT_SERVER" ]]; then
            echo "Error: Server address cannot be empty!" >&2
        fi
    done

    # Prompt for port (optional)
    read -p "Enter SOCKS port [${DEFAULT_PORT}]: " input_port
    if [[ -n "$input_port" ]]; then
        DEFAULT_PORT="$input_port"
    fi

    # Prompt for bind IP (optional)
    read -p "Enter bind IP [${DEFAULT_BIND_IP}]: " input_bind_ip
    if [[ -n "$input_bind_ip" ]]; then
        if ! validate_ip "$input_bind_ip"; then
            exit 1
        fi
        DEFAULT_BIND_IP="$input_bind_ip"
    fi

    # Prompt for user (optional)
    read -p "Enter SSH username [${DEFAULT_USER}]: " input_user
    if [[ -n "$input_user" ]]; then
        DEFAULT_USER="$input_user"
    fi
}

# Start the SSH SOCKS proxy
start_proxy() {
    echo "Starting SSH SOCKS proxy on port $DEFAULT_PORT (Bind IP: $DEFAULT_BIND_IP)..."
    ssh -D "$DEFAULT_PORT" \
        -N -f -C -T \
        -o ServerAliveInterval=60 \
        -o ExitOnForwardFailure=yes \
        -o BindAddress="$DEFAULT_BIND_IP" \
        "$DEFAULT_USER@$DEFAULT_SERVER"

    if [ $? -ne 0 ]; then
        echo "Error: Failed to start SSH proxy!" >&2
        exit 1
    fi

    echo "Success! SSH SOCKS proxy is running on port $DEFAULT_PORT."
    echo "Proxy address: SOCKS5://$DEFAULT_BIND_IP:$DEFAULT_PORT"
}

# Save config to file
save_config() {
    echo "Saving configuration to $CONFIG_FILE..."
    cat > "$CONFIG_FILE" <<EOF
# SSH SOCKS Proxy Configuration - Version 1.2 RC II
DEFAULT_PORT=$DEFAULT_PORT
DEFAULT_BIND_IP="$DEFAULT_BIND_IP"
DEFAULT_USER="$DEFAULT_USER"
DEFAULT_SERVER="$DEFAULT_SERVER"
EOF
    chmod 600 "$CONFIG_FILE"
    echo "Configuration saved successfully."
}

# =============================================
# Main Function
# =============================================
main() {
    # Ensure .ssh directory exists
    ensure_ssh_dir

    # Parse command-line arguments with getopts
    while getopts ":hc-:s:u:p:b:" opt; do
        case $opt in
            h) show_help ;;
            c) load_config ;;
            s) DEFAULT_SERVER="$OPTARG" ;;
            u) DEFAULT_USER="$OPTARG" ;;
            p) DEFAULT_PORT="$OPTARG" ;;
            b)
                if ! validate_ip "$OPTARG"; then
                    exit 1
                fi
                DEFAULT_BIND_IP="$OPTARG" ;;
            -)  # Handle long options
                case "${OPTARG}" in
                    help) show_help ;;
                    config) load_config ;;
                    server) DEFAULT_SERVER="${!OPTIND}"; OPTIND=$((OPTIND + 1)) ;;
                    user) DEFAULT_USER="${!OPTIND}"; OPTIND=$((OPTIND + 1)) ;;
                    port) DEFAULT_PORT="${!OPTIND}"; OPTIND=$((OPTIND + 1)) ;;
                    bind)
                        if ! validate_ip "${!OPTIND}"; then
                            exit 1
                        fi
                        DEFAULT_BIND_IP="${!OPTIND}"; OPTIND=$((OPTIND + 1)) ;;
                    *) echo "Unknown option: --${OPTARG}" >&2; exit 1 ;;
                esac ;;
            \?) echo "Invalid option: -$OPTARG" >&2; exit 1 ;;
            :) echo "Option -$OPTARG requires an argument." >&2; exit 1 ;;
        esac
    done

    # Load config if no arguments were provided
    if [[ $OPTIND -eq 1 ]]; then
        load_config
    fi

    # Prompt for values if not set
    if [[ -z "$DEFAULT_SERVER" ]]; then
        prompt_for_values
    fi

    # Ask to save config
    read -p "Save these values to $CONFIG_FILE? (y/n) " -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        save_config
    fi

    # Start the proxy
    start_proxy
}

# =============================================
# Execute Main Function
# =============================================
main "$@"
