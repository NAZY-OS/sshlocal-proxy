root@37648:~# cat fetchipisp.sh
#!/bin/bash# Get your WAN IP and fetch country/ISP (no
 hostname resolution)
# Usage: ./get_my_ip_info.sh

# Check if jq is installed
if ! command -v jq &> /dev/null; then    echo "Error: jq is not installed. Pleas
e install jq to run this script."    echo "On Debian/Ubuntu: sudo apt-get in
stall jq"    echo "On RHEL/CentOS: sudo yum install
jq"
    echo "On macOS: brew install jq"
    exit 1
fi

# --- Functions ---

get_public_ip() {    # Try multiple reliable sources for you
r WAN IP
    local ip_sources=(
        "https://api.ipify.org?format=json"
        "https://ipinfo.io/json"
        "https://ifconfig.me/all.json"
    )

    for source in "${ip_sources[@]}"; do
        local ip_data        ip_data=$(curl -s --max-time 10 "$s
ource" 2>/dev/null)

        if [ -n "$ip_data" ]; then
            local ip            ip=$(echo "$ip_data" | jq -r '.
ip // empty')
            if [ -n "$ip" ]; then
                echo "$ip"
                return 0
            fi
        fi
    done
    echo "Error: Could not determine your p
ublic IP" >&2
    return 1
}

get_ip_details() {
    local ip="$1"
    local country isp

    # Try multiple sources for country/ISP
    local detail_sources=(
        "http://ip-api.com/json/$ip"
        "https://ipinfo.io/$ip/json"
    )
    for source in "${detail_sources[@]}"; d
o
        local ip_info        ip_info=$(curl -s --max-time 10 "$s
ource" 2>/dev/null)

        if [ -n "$ip_info" ]; then            country=$(echo "$ip_info" | jq
-r '.country // .country_name // empty')
            isp=$(echo "$ip_info" | jq -r '.isp // .org // empty')

            if [ -n "$country" ]; then
                echo "Country: $country"
                echo "ISP: ${isp:-Unknown}"
                return 0
            fi
        fi
    done

    echo "Country: Unknown"
    echo "ISP: Unknown"
    return 1
}

# --- Main Function ---
main() {
    echo "Fetching your public IPv4 address..."
    local ip
    ip=$(get_public_ip) || exit 1

    echo "Your WAN IP: $ip"
    echo "--------------------------------"
    get_ip_details "$ip"
}

# --- Script Execution ---
main
