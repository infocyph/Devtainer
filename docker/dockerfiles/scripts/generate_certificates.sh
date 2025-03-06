#!/bin/bash

# Set username, defaulting to 'dockery' if not set
USERNAME=${USERNAME:-dockery}

# Directories containing config files
DIR1="/home/$USERNAME/.local/share/apache"
DIR2="/home/$USERNAME/.local/share/nginx"

# Output directory for certificates
CERT_DIR="/etc/mkcert"

# Additional default domains
EXTRA_DOMAINS="localhost 127.0.0.1 ::1"

# Create certificate directory if it doesn't exist
mkdir -p "$CERT_DIR"

# Function to extract domains from filenames
get_domains_from_files() {
    local dir="$1"
    local domains=()
    [[ -d "$dir" ]] || return
    local file
    for file in "$dir"/*.conf; do
        [[ -f "$file" ]] || continue
        local domain
        domain=$(basename "$file" .conf)  # Extract domain from filename
        domains+=("$domain" "*.$domain") # Include wildcard
    done
    echo "${domains[@]}" # Return as space-separated list
}

# Get all domains from both directories
DOMAINS=$(get_domains_from_files "$DIR1")
DOMAINS+=" $(get_domains_from_files "$DIR2")"
DOMAINS+=" $EXTRA_DOMAINS"

# Convert domain list to a mkcert-compatible format
CERT_DOMAINS=$(echo "$DOMAINS" | tr ' ' '\n' | sort -u | tr '\n' ' ')

echo "🔹 Generating certificates for domains: $CERT_DOMAINS"

# Generate certificates for Nginx (Directly Serving PHP-FPM)
mkcert -cert-file "$CERT_DIR/nginx-server.pem" -key-file "$CERT_DIR/nginx-server-key.pem" "$CERT_DOMAINS"

# Generate certificates for Nginx as Reverse Proxy
mkcert -cert-file "$CERT_DIR/nginx-proxy.pem" -key-file "$CERT_DIR/nginx-proxy-key.pem" "$CERT_DOMAINS"

# Generate Client Certificate for Nginx (To Authenticate Apache)
mkcert -client -cert-file "$CERT_DIR/nginx-client.pem" -key-file "$CERT_DIR/nginx-client-key.pem" "$CERT_DOMAINS"

# Generate certificates for Apache-PHP (Server)
mkcert -cert-file "$CERT_DIR/apache-server.pem" -key-file "$CERT_DIR/apache-server-key.pem" "$CERT_DOMAINS"

# Generate Client Certificate for Apache-PHP (To Authenticate Nginx Proxy)
mkcert -client -cert-file "$CERT_DIR/apache-client.pem" -key-file "$CERT_DIR/apache-client-key.pem" "$CERT_DOMAINS"

echo "✅ Certificates successfully generated in $CERT_DIR"
