#!/bin/bash

# Get your WAN IP and fetch detailed information (country, city, ISP, ASN, etc.)
# Usage: ./fetchipisp.sh

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo -e "\033[31mError: jq is not installed.\033[0m"
    echo "Please install jq to run this script."
    echo "On Debian/Ubuntu: sudo apt-get install jq"
    echo "On RHEL/CentOS: sudo yum install jq"
    echo "On macOS: brew install jq"
    exit 1
fi

# --- Functions ---

get_public_ip() {
    # Try multiple reliable sources for your WAN IP
    local ip_sources=(
        "https://api.ipify.org?format=json"
        "https://ipinfo.io/json"
        "https://ifconfig.me/all.json"
    )

    for source in "${ip_sources[@]}"; do
        local ip_data
        ip_data=$(curl -s --max-time 10 "$source" 2>/dev/null)

        if [ -n "$ip_data" ]; then
            local ip
            ip=$(echo "$ip_data" | jq -r '.ip // empty')
            if [ -n "$ip" ]; then
                echo "$ip"
                return 0
            fi
        fi
    done
    echo "Error: Could not determine your public IP" >&2
    return 1
}

get_ip_details() {
    local ip="$1"
    local combined_info

    # Try multiple sources for detailed information
    local detail_sources=(
        "http://ip-api.com/json/$ip"
        "https://ipinfo.io/$ip/json"
    )

    for source in "${detail_sources[@]}"; do
        local ip_info
        ip_info=$(curl -s --max-time 10 "$source" 2>/dev/null)

        if [ -n "$ip_info" ]; then
            # Combine information from both sources
            combined_info=$(echo "$ip_info" | jq -s '.[0] * .[1] // .[0]' \
                <(echo '{"source1": "ip-api.com"}') \
                <(echo '{"source2": "ipinfo.io"}') \
                <(echo "$ip_info") | jq -c .)

            # Format the output with colors and structure
            echo -e "\n\033[1;34m=== IP Details ===\033[0m"
            echo -e "\033[1mIP Address:\033[0m $(echo "$combined_info" | jq -r '.ip')"
            echo -e "\033[1mCountry:\033[0m $(echo "$combined_info" | jq -r '.country // "Unknown"')"
            echo -e "\033[1mCountry Code:\033[0m $(echo "$combined_info" | jq -r '.country_code // "Unknown"')"
            echo -e "\033[1mRegion:\033[0m $(echo "$combined_info" | jq -r '.region // "Unknown"')"
            echo -e "\033[1mCity:\033[0m $(echo "$combined_info" | jq -r '.city // "Unknown"')"
            echo -e "\033[1mZIP Code:\033[0m $(echo "$combined_info" | jq -r '.zip // "Unknown"')"
            echo -e "\033[1mCoordinates:\033[0m $(echo "$combined_info" | jq -r '.latitude // "Unknown"'), $(echo "$combined_info" | jq -r '.longitude // "Unknown"')"
            echo -e "\033[1mTimezone:\033[0m $(echo "$combined_info" | jq -r '.timezone // "Unknown"')"
            echo -e "\033[1mISP:\033[0m $(echo "$combined_info" | jq -r '.isp // "Unknown"')"
            echo -e "\033[1mOrganization:\033[0m $(echo "$combined_info" | jq -r '.org // "Unknown"')"
            echo -e "\033[1mASN:\033[0m $(echo "$combined_info" | jq -r '.asn // "Unknown"')"
            echo -e "\033[1mSource:\033[0m $(echo "$combined_info" | jq -r '.source1 // .source2 // "Unknown"')"
            echo -e "\033[1mTimestamp:\033[0m $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
            return 0
        fi
    done

    echo -e "\033[31mError: Could not fetch IP details\033[0m" >&2
    return 1
}

# --- Main Function ---
main() {
    echo -e "\033[1;32mFetching your public IPv4 address and details...\033[0m"
    local ip
    ip=$(get_public_ip) || exit 1

    echo -e "\033[1;32mYour WAN IP: \033[1;33m$ip\033[0m"
    echo "--------------------------------"
    get_ip_details "$ip"
}

# --- Script Execution ---
main
