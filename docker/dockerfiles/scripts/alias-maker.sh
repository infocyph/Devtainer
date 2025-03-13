#!/bin/bash

CONTAINER_NAME="$1"
USERNAME="$2"
ALIASES=()

# Define aliases based on container name
case "$CONTAINER_NAME" in
  tools)
    ALIASES=(
      'alias certify="/usr/local/bin/certify"'
    )
    ;;
  *)
    echo "Unknown container type: $CONTAINER_NAME. No aliases will be added."
    ;;
esac

# Run the for loop only if ALIASES is not empty
if [[ ${#ALIASES[@]} -gt 0 ]]; then
  for alias in "${ALIASES[@]}"; do
    echo "$alias" >> "/home/${USERNAME}/.bashrc"
  done
  echo "Aliases added successfully!"
fi

# Self-remove script after execution
rm -f -- "$0"
