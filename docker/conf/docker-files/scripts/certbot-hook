#!/bin/bash

# Reload Nginx if running
if docker ps -q -f name=NGINX > /dev/null; then
  echo "Reloading Nginx..."
  docker exec -it NGINX nginx -s reload
fi

# Reload Apache if running
if docker ps -q -f name=APACHE > /dev/null; then
  echo "Reloading Apache..."
  docker exec -it APACHE apachectl graceful
fi
