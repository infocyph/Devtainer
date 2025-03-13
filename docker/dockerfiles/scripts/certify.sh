#!/bin/bash

# Output directory for certificates
CERT_DIR="/etc/mkcert"

# Ensure mkcert is installed
command -v mkcert &> /dev/null || { echo "[✖] mkcert not found! Please install it first."; exit 1; }

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
    echo "${domains[@]}" | tr ' ' '\n' | sort -u
}

run_mkcert() {
    mkcert "$@" &> /dev/null
}

generate_certificates() {
    declare -A CERT_FILES=(
        ["Nginx (Server)"]="nginx-server.pem nginx-server-key.pem"
        ["Nginx (Proxy)"]="nginx-proxy.pem nginx-proxy-key.pem"
        ["Nginx (Client)"]="nginx-client.pem nginx-client-key.pem --client"
        ["Apache (Server)"]="apache-server.pem apache-server-key.pem"
        ["Apache (Client)"]="apache-client.pem apache-client-key.pem --client"
    )

    local output=""
    local cert
    for cert in "${!CERT_FILES[@]}"; do
        IFS=' ' read -r cert_file key_file client_flag <<< "${CERT_FILES[$cert]}"
        output+=" - $cert -> $cert_file & $key_file"$'\n'
        run_mkcert --ecdsa $client_flag -cert-file "$CERT_DIR/$cert_file" -key-file "$CERT_DIR/$key_file" $CERT_DOMAINS
    done

    # Install certificates
    run_mkcert -install

    echo "$output"
}

# Directories to check
DIRS=(
    "/etc/share/vhosts/apache"
    "/etc/share/vhosts/nginx"
)

# Get unique domains from provided directories
CERT_DOMAINS=$(get_domains_from_dirs "${DIRS[@]}")

# Generate output content and pipe it properly into boxes & lolcat
{
    echo "[~] List of domains:"
    echo ""
    echo "$CERT_DOMAINS" | awk '{print " - "$0}'
    echo ""
    echo "--------------------------------------------------------------"
    echo "[*] Generating Certificates..."
    echo ""
    generate_certificates
    echo ""
    echo "--------------------------------------------------------------"
    echo "[OK] Certificates generated successfully!"
} | boxes -d diamonds -a hcvc | lolcat
