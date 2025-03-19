#!/bin/bash

# Output directory for certificates
CERT_DIR="/etc/mkcert"

# Ensure mkcert is installed
command -v mkcert &> /dev/null || { echo "[✖] mkcert not found! Please install it first."; exit 1; }

# Create certificate directory if it doesn't exist
mkdir -p "$CERT_DIR"

##############################################
# Function: get_domains_from_dirs
#   Returns unique domains (one per line) based on *.conf filenames
##############################################
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

##############################################
# Function: run_mkcert
#   Wrapper for mkcert command
##############################################
run_mkcert() {
    mkcert "$@" &> /dev/null
}

##############################################
# Function: validate_certificate
#   Checks if a certificate file exists, is in valid PEM format, not expired,
#   and that all domains in CERT_DOMAINS are present in its SAN.
#   Returns 0 if valid; nonzero otherwise.
##############################################
validate_certificate() {
    local cert_file="$1"
    if [ ! -f "$cert_file" ]; then
        return 1
    fi

    # Check expiration date
    local expiry
    expiry=$(openssl x509 -in "$cert_file" -noout -enddate 2>/dev/null | cut -d= -f2)
    if [ -z "$expiry" ]; then
        return 1
    fi

    local expiry_epoch current_epoch
    expiry_epoch=$(date -d "$expiry" +%s 2>/dev/null)
    if [ $? -ne 0 ]; then
        return 1
    fi
    current_epoch=$(date +%s)
    if [ $expiry_epoch -le $current_epoch ]; then
        return 1
    fi

    # Get the certificate's SAN data
    local san
    san=$(openssl x509 -in "$cert_file" -noout -ext subjectAltName 2>/dev/null)
    if [ -z "$san" ]; then
        return 1
    fi

    # Extract DNS and IP Address entries from SAN
    local dns_entries ip_entries all_san
    dns_entries=$(echo "$san" | grep -oP 'DNS:\K[^,]+' | tr '\n' ' ')
    ip_entries=$(echo "$san" | grep -oP 'IP Address:\K[^,]+' | tr '\n' ' ')
    all_san=$(echo "$dns_entries $ip_entries")

    # Check that all non-empty domains in CERT_DOMAINS are present in the certificate's SAN.
    if [ -n "$CERT_DOMAINS" ]; then
        for domain in $CERT_DOMAINS; do
            domain=$(echo "$domain" | xargs)  # trim spaces
            if [ -z "$domain" ]; then
                continue
            fi
            if [ "$domain" = "::1" ]; then
                if ! echo "$all_san" | grep -qw "0:0:0:0:0:0:0:1"; then
                    return 1
                fi
            else
                if ! echo "$all_san" | grep -qw "$domain"; then
                    return 1
                fi
            fi
        done
    fi

    return 0
}


##############################################
# Function: generate_certificates
#   Loops over a set of certificate definitions.
#   For each, checks if the certificate file exists and is valid.
#   If not, uses mkcert to generate it.
#   For client certificates, a .p12 bundle is created using OpenSSL.
##############################################
generate_certificates() {
    declare -A CERT_FILES=(
        ["Nginx (Server)"]="nginx-server.pem nginx-server-key.pem"
        ["Nginx (Proxy)"]="nginx-proxy.pem nginx-proxy-key.pem"
        ["Nginx (Client)"]="nginx-client.pem nginx-client-key.pem --client"
        ["Apache (Server)"]="apache-server.pem apache-server-key.pem"
        ["Apache (Client)"]="apache-client.pem apache-client-key.pem --client"
    )

    local output=""
    local count_total=0
    local count_regenerated=0
    local count_valid=0
    local cert cert_file key_file client_flag p12_name full_cert_path

    for cert in "${!CERT_FILES[@]}"; do
        count_total=$((count_total + 1))
        IFS=' ' read -r cert_file key_file client_flag <<< "${CERT_FILES[$cert]}"
        full_cert_path="$CERT_DIR/$cert_file"
        if validate_certificate "$full_cert_path"; then
            output+=" - $cert: Valid and up-to-date; regeneration skipped"$'\n'
            count_valid=$((count_valid + 1))
        else
            # Generate the certificate if missing, expired, or missing domains.
            if [[ "$client_flag" == "--client" ]]; then
                run_mkcert --ecdsa $client_flag \
                  -cert-file "$CERT_DIR/$cert_file" \
                  -key-file "$CERT_DIR/$key_file" \
                  $CERT_DOMAINS
                # Generate the p12 bundle manually using OpenSSL
                p12_name="${cert_file%.pem}.p12"
                openssl pkcs12 -export \
                  -in "$CERT_DIR/$cert_file" \
                  -inkey "$CERT_DIR/$key_file" \
                  -out "$CERT_DIR/$p12_name" \
                  -name "${cert_file%.pem} Certificate" \
                  -passout pass:""
            else
                run_mkcert --ecdsa $client_flag \
                  -cert-file "$CERT_DIR/$cert_file" \
                  -key-file "$CERT_DIR/$key_file" \
                  $CERT_DOMAINS
            fi
            output+=" - $cert: Generated and configured for secure connections"$'\n'
            count_regenerated=$((count_regenerated + 1))
        fi
    done

    # Install certificates into the system trust store
    run_mkcert -install

    # Build summary message
    output+=$'\n'"--------------------------------------------------------------"$'\n'
    if [ $count_regenerated -eq 0 ]; then
         output+="[OK] All ($count_total) certificates are valid; no regeneration required."
    elif [ $count_valid -eq 0 ]; then
         output+="[OK] All ($count_total) certificates were regenerated."
    else
         output+="[OK] Certificate validation complete; Regenerated: $count_regenerated, Valid: $count_valid."
    fi

    echo "$output"
}


##############################################
# Main Script Execution
##############################################

# Directories to check for .conf files (to build domain list)
DIRS=(
    "/etc/share/vhosts/apache"
    "/etc/share/vhosts/nginx"
)

# Get unique domains from provided directories
CERT_DOMAINS=$(get_domains_from_dirs "${DIRS[@]}")

# Generate output content and pipe it into boxes & lolcat for pretty output
{
    echo ""
    echo "[~] List of domains:"
    echo ""
    echo "$CERT_DOMAINS" | awk '{print " - "$0}'
    echo ""
    echo "--------------------------------------------------------------"
    echo "[*] Generating Certificates..."
    echo ""
    generate_certificates
    echo ""
} | boxes -d diamonds -a hcvc | lolcat
