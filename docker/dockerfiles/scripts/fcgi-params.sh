#!/bin/bash

FASTCGI_PARAMS_FILE="/etc/nginx/fastcgi_params"

# Declare required headers
declare -A fastcgi_params=(
    ["HTTP_CLIENT_IP"]='$http_client_ip'
    ["HTTP_X_FORWARDED_FOR"]='$http_x_forwarded_for'
    ["HTTP_CF_CONNECTING_IP"]='$http_cf_connecting_ip'
    ["HTTP_FASTLY_CLIENT_IP"]='$http_fastly_client_ip'
    ["HTTP_TRUE_CLIENT_IP"]='$http_true_client_ip'
    ["HTTP_AKAMAI_EDGE_CLIENT_IP"]='$http_akamai_edge_client_ip'
    ["HTTP_X_AZURE_CLIENTIP"]='$http_x_azure_clientip'
    ["HTTP_X_APPENGINE_USER_IP"]='$http_x_appengine_user_ip'
    ["HTTP_X_REAL_IP"]='$http_x_real_ip'
    ["HTTP_X_CLUSTER_CLIENT_IP"]='$http_x_cluster_client_ip'
#    ["HTTP_X_FLY_CLIENT_IP"]='$fly_client_ip'
    ["HTTP_ALI_CLIENT_IP"]='$http_ali_client_ip'
    ["HTTP_X_ORACLE_CLIENT_IP"]='$http_x_oracle_client_ip'
    ["HTTP_X_STACKPATH_EDGE_IP"]='$http_x_stackpath_edge_ip'
    ["HTTP_USER_AGENT"]='$http_user_agent'
    ["HTTP_ACCEPT"]='$http_accept'
    ["HTTP_ACCEPT_LANGUAGE"]='$http_accept_language'
    ["HTTP_REFERER"]='$http_referer'
    ["SERVER_ADDR"]='$server_addr'
    ["SERVER_PORT"]='$server_port'
    ["SERVER_PROTOCOL"]='$server_protocol'
    ["SERVER_NAME"]='$server_name'
    ["DOCUMENT_ROOT"]='$document_root'
    ["REQUEST_SCHEME"]='$scheme'
    ["REQUEST_METHOD"]='$request_method'
    ["REQUEST_URI"]='$request_uri'
    ["QUERY_STRING"]='$query_string'
    ["REMOTE_ADDR"]='$remote_addr'
    ["REMOTE_PORT"]='$remote_port'
    ["REMOTE_USER"]='$remote_user'
)

# Check and append missing headers in fastcgi_params
for key in "${!fastcgi_params[@]}"; do
    if ! grep -q "^fastcgi_param $key " "$FASTCGI_PARAMS_FILE"; then
        echo "Adding missing FastCGI param: $key"
        echo "fastcgi_param $key ${fastcgi_params[$key]};" >> "$FASTCGI_PARAMS_FILE"
    fi
done

echo "✅ FastCGI parameters updated"
rm -f -- "$0"
