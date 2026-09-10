#!/bin/bash
# Version: 1.2 RC
# Author: nazy-os
# Scriptname: sshproxy-tool.sh
# License: MIT

# Default values
DEFAULT_PORT=10800
DEFAULT_SSH_PORT=22
CONFIG_FILE="$HOME/.ssh/sshproxy.conf"
SSH_KEY_FILE="$HOME/.ssh/id_ed25519"
RSA_PASSWORD=""

# Function to display usage information
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -u, --user USER        Specify SSH username"
    echo "  -s, --server SERVER    Specify SSH server"
    echo "  -p, --port PORT        Specify SOCKS proxy port (default: $DEFAULT_PORT)"
    echo "  -c, --configfile FILE  Specify config file (default: $CONFIG_FILE)"
    echo "  -r, --rsapass          Prompt for SSH password (RSA fallback)"
    echo "  --help                 Show this help message"
    exit 1
}

# Function to generate Ed25519 SSH key if none exists
generate_ssh_key() {
    if [ ! -f "$SSH_KEY_FILE" ]; then
        echo "No SSH key found at $SSH_KEY_FILE"
        read -p "Generate a new Ed25519 key? (y/n): " choice
        case "$choice" in
            y|Y)
                echo "Generating new Ed25519 SSH key..."
                ssh-keygen -t ed25519 -a 100 -f "$SSH_KEY_FILE" -C "sshproxy"
                if [ $? -ne 0 ]; then
                    echo "Error: Failed to generate SSH key!" >&2
                    exit 1
                fi
                chmod 600 "$SSH_KEY_FILE"
                echo "SSH key generated at $SSH_KEY_FILE"
                ;;
            *)
                echo "Using existing SSH key or no key authentication"
                ;;
        esac
    fi
}

# Function to load existing configuration
load_config() {
    if [ -f "$config_file" ]; then
        read -p "Load existing configuration from $config_file? (y/n): " choice
        case "$choice" in
            y|Y)
                if source "$config_file"; then
                    echo "Configuration loaded:"
                    echo "User: $user"
                    echo "Server: $server"
                    echo "Port: $port"
                    return 0
                else
                    echo "Error: Failed to load configuration!" >&2
                    return 1
                fi
                ;;
            *)
                echo "Please enter new configuration:"
                ;;
        esac
    fi
    return 1
}

# Function to get user input
get_user_input() {
    read -p "Enter username: " user
    read -p "Enter server: " server
    read -p "Enter port [default $DEFAULT_PORT]: " port_input
    port=${port_input:-$DEFAULT_PORT}
}

# Function to save configuration
save_config() {
    mkdir -p "$(dirname "$config_file")"
    {
        echo "user=\"$user\""
        echo "server=\"$server\""
        echo "port=\"$port\""
    } > "$config_file"
    echo "Configuration saved to $config_file"
}

# Function to prompt for RSA password (only once)
prompt_rsa_password() {
    if [[ "$use_rsapass" == "true" && -z "$RSA_PASSWORD" ]]; then
        read -s -p "Enter SSH password for $user@$server: " RSA_PASSWORD
        echo
    fi
}

# Function to start SSH proxy
start_ssh_proxy() {
    echo "Starting SSH SOCKS proxy on port $port..."

    # Check if SSH key exists
    if [ -f "$SSH_KEY_FILE" ]; then
        ssh_key_option="-i $SSH_KEY_FILE"
    else
        ssh_key_option=""
    fi

    # Use stored RSA password if available
    if [[ -n "$RSA_PASSWORD" ]]; then
        sshpass -p "$RSA_PASSWORD" ssh -D "$port" \
            -N -f -C -T \
            $ssh_key_option \
            -o ServerAliveInterval=60 \
            -o ExitOnForwardFailure=yes \
            "$user@$server"
    else
        ssh -D "$port" \
            -N -f -C -T \
            $ssh_key_option \
            -o ServerAliveInterval=60 \
            -o ExitOnForwardFailure=yes \
            "$user@$server"
    fi

    if [ $? -ne 0 ]; then
        echo "Error: Failed to start SSH proxy!" >&2
        return 1
    fi
    echo "SSH SOCKS proxy is running on port $port"
    return 0
}

# Main function
main() {
    # Initialize variables
    local user=""
    local server=""
    local port=""
    local config_file="$CONFIG_FILE"
    local use_rsapass=false

    # Parse command line options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -u|--user)
                user="$2"
                shift 2
                ;;
            -s|--server)
                server="$2"
                shift 2
                ;;
            -p|--port)
                port="$2"
                shift 2
                ;;
            -c|--configfile)
                config_file="$2"
                shift 2
                ;;
            -r|--rsapass)
                use_rsapass=true
                shift
                ;;
            --help)
                usage
                ;;
            *)
                echo "Error: Unknown option $1" >&2
                usage
                ;;
        esac
    done

    # Generate SSH key if needed
    generate_ssh_key

    # If no arguments provided, prompt for all values
    if [[ $# -eq 0 ]]; then
        echo "No arguments provided. Starting interactive mode..."
        if ! load_config; then
            get_user_input
        fi
    else
        # Use provided values (with defaults)
        port=${port:-$DEFAULT_PORT}
    fi

    # Validate required values
    if [[ -z "$user" || -z "$server" ]]; then
        echo "Error: Missing required configuration values!" >&2
        exit 1
    fi

    # Save configuration
    save_config

    # Source the configuration
    source "$config_file"
    echo "Configuration active:"
    echo "User: $user"
    echo "Server: $server"
    echo "Port: $port"

    # Prompt for RSA password if needed (only once)
    prompt_rsa_password

    # Ask to start SSH proxy
    read -p "Start SSH SOCKS proxy now? (y/n): " choice
    case "$choice" in
        y|Y)
            start_ssh_proxy
            ;;
        *)
            echo "Proxy not started. You can start it later with:"
            if [ -f "$SSH_KEY_FILE" ]; then
                echo "ssh -D $port -N -f -C -T -i $SSH_KEY_FILE -o ServerAliveInterval=60 -o ExitOnForwardFailure=yes $user@$server"
            else
                echo "ssh -D $port -N -f -C -T -o ServerAliveInterval=60 -o ExitOnForwardFailure=yes $user@$server"
            fi
            ;;
    esac
}

# Execute main function with all arguments
main "$@"
