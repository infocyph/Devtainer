#!/bin/bash

# Set username, defaulting to 'dockery' if not set
USERNAME=${USERNAME:-dockery}

# Output directory for certificates
CERT_DIR="/etc/mkcert"

# Create certificate directory if it doesn't exist
mkdir -p "$CERT_DIR"

# Functions
get_domains_from_files() {
    local dir="$1"
    local domains=()
    [[ -d "$dir" ]] || return
    for file in "$dir"/*.conf; do
        [[ -f "$file" ]] || continue
        local domain
        domain=$(basename "$file" .conf)  # Extract domain from filename
        domains+=("$domain" "*.$domain") # Include wildcard
    done
    echo "${domains[@]}" # Return as space-separated list
}
run_mkcert() {
    mkcert "$@" &> /dev/null
}

# Get domains from directories, ensuring no empty values are appended
DOMAINS=""

DIR1_DOMAINS=$(get_domains_from_files "/home/$USERNAME/.local/share/apache")
[[ -n "$DIR1_DOMAINS" ]] && DOMAINS+="$DIR1_DOMAINS "

DIR2_DOMAINS=$(get_domains_from_files "/home/$USERNAME/.local/share/nginx")
[[ -n "$DIR2_DOMAINS" ]] && DOMAINS+="$DIR2_DOMAINS "

# Always add extra default domains
DOMAINS+="localhost 127.0.0.1 ::1"

# Remove leading/trailing whitespace and ensure unique values
CERT_DOMAINS=$(echo "$DOMAINS" | tr ' ' '\n' | sort -u)

# Display domains in a list format
echo "🔹 Generating ECDSA certificates for the following domains:"
echo "$CERT_DOMAINS" | awk '{print "   - "$0}'

# Convert domain list back to space-separated format for mkcert
CERT_DOMAINS=$(echo "$CERT_DOMAINS" | tr '\n' ' ')

# Generate Certificates
run_mkcert --ecdsa -cert-file "$CERT_DIR/nginx-server.pem" -key-file "$CERT_DIR/nginx-server-key.pem" $CERT_DOMAINS
run_mkcert --ecdsa -cert-file "$CERT_DIR/nginx-proxy.pem" -key-file "$CERT_DIR/nginx-proxy-key.pem" $CERT_DOMAINS
run_mkcert --ecdsa -client -cert-file "$CERT_DIR/nginx-client.pem" -key-file "$CERT_DIR/nginx-client-key.pem" $CERT_DOMAINS
run_mkcert --ecdsa -cert-file "$CERT_DIR/apache-server.pem" -key-file "$CERT_DIR/apache-server-key.pem" $CERT_DOMAINS
run_mkcert --ecdsa -client -cert-file "$CERT_DIR/apache-client.pem" -key-file "$CERT_DIR/apache-client-key.pem" $CERT_DOMAINS
run_mkcert -install

echo "✅ ECDSA Certificates successfully generated in $CERT_DIR"
