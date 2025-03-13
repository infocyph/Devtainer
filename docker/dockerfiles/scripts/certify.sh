#!/bin/bash

# Output directory for certificates
CERT_DIR="/etc/mkcert"

# Ensure mkcert is installed
command -v mkcert &> /dev/null || { echo "❌ mkcert not found! Please install it first."; exit 1; }

# Create certificate directory if it doesn't exist
mkdir -p "$CERT_DIR"

# Functions
get_domains_from_dirs() {
    local domains=()
    local dir
    local file

    # Iterate over all provided directories
    for dir in "$@"; do
        [[ -d "$dir" ]] || continue
        for file in "$dir"/*.conf; do
            [[ -f "$file" ]] || continue
            local domain
            domain=$(basename "$file" .conf)
            [[ -n "$domain" ]] && domains+=("$domain" "*.$domain")
        done
    done
    domains+=("localhost" "127.0.0.1" "::1")
    echo "${domains[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '
}

run_mkcert() {
    mkcert "$@" &> /dev/null
}

# Directories to check
DIRS=(
    "/etc/share/vhosts/apache"
    "/etc/share/vhosts/nginx"
)

# Get unique domains from provided directories
CERT_DOMAINS=$(get_domains_from_dirs "${DIRS[@]}")

# Display domains in a list format
echo "🔹 Generating ECDSA certificates for the following domains:"
echo "$CERT_DOMAINS" | tr ' ' '\n' | sort -u | awk '{print "   - "$0}'

# Generate Certificates using a loop
declare -A CERT_FILES=(
    ["nginx-server"]="nginx-server.pem nginx-server-key.pem"
    ["nginx-proxy"]="nginx-proxy.pem nginx-proxy-key.pem"
    ["nginx-client"]="nginx-client.pem nginx-client-key.pem --client"
    ["apache-server"]="apache-server.pem apache-server-key.pem"
    ["apache-client"]="apache-client.pem apache-client-key.pem --client"
)
for cert in "${!CERT_FILES[@]}"; do
    IFS=' ' read -r cert_file key_file client_flag <<< "${CERT_FILES[$cert]}"
    run_mkcert --ecdsa $client_flag -cert-file "$CERT_DIR/$cert_file" -key-file "$CERT_DIR/$key_file" $CERT_DOMAINS
done
run_mkcert -install

echo "✅ ECDSA Certificates successfully generated!"
