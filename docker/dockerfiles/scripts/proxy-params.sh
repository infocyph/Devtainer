#!/bin/bash

# Define the output file location
PROXY_PARAMS_FILE="/etc/nginx/proxy_params"

# Backup existing file if it exists
if [[ -f "$PROXY_PARAMS_FILE" ]]; then
    cp "$PROXY_PARAMS_FILE" "${PROXY_PARAMS_FILE}.bak"
fi

# Write the proxy parameters to the file
cat <<EOF > "$PROXY_PARAMS_FILE"
# Essential Proxy Headers
proxy_set_header Host \$host;
proxy_set_header X-Real-IP \$remote_addr;
proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto \$scheme;

# Forwarding Additional Headers
proxy_set_header HTTP_CLIENT_IP \$http_client_ip;
proxy_set_header HTTP_X_FORWARDED_FOR \$http_x_forwarded_for;
proxy_set_header HTTP_CF_CONNECTING_IP \$http_cf_connecting_ip;
proxy_set_header HTTP_FASTLY_CLIENT_IP \$http_fastly_client_ip;
proxy_set_header HTTP_TRUE_CLIENT_IP \$http_true_client_ip;
proxy_set_header HTTP_AKAMAI_EDGE_CLIENT_IP \$http_akamai_edge_client_ip;
proxy_set_header HTTP_X_AZURE_CLIENTIP \$http_x_azure_clientip;
proxy_set_header HTTP_X_APPENGINE_USER_IP \$http_x_appengine_user_ip;
proxy_set_header HTTP_X_REAL_IP \$http_x_real_ip;
proxy_set_header HTTP_X_CLUSTER_CLIENT_IP \$http_x_cluster_client_ip;
proxy_set_header HTTP_ALI_CLIENT_IP \$http_ali_client_ip;
proxy_set_header HTTP_X_ORACLE_CLIENT_IP \$http_x_oracle_client_ip;
proxy_set_header HTTP_X_STACKPATH_EDGE_IP \$http_x_stackpath_edge_ip;
proxy_set_header HTTP_USER_AGENT \$http_user_agent;
proxy_set_header HTTP_ACCEPT \$http_accept;
proxy_set_header HTTP_ACCEPT_LANGUAGE \$http_accept_language;
proxy_set_header HTTP_REFERER \$http_referer;

# Essential Server Headers
proxy_set_header SERVER_ADDR \$server_addr;
proxy_set_header SERVER_PORT \$server_port;
proxy_set_header SERVER_NAME \$server_name;
proxy_set_header REMOTE_ADDR \$remote_addr;
proxy_set_header REMOTE_PORT \$remote_port;
proxy_set_header REMOTE_USER \$remote_user;
EOF

# Display confirmation message
echo "✅ Proxy parameters successfully written to $PROXY_PARAMS_FILE"
rm -f -- "$0"
