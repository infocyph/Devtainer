# .bashrc

# Fetch the container name (from env or default)
container_name=${CONTAINER_NAME:-$(hostname)}

# Generate the main logo with animation
logo=$(toilet -f big "$container_name" | lolcat -a -d 2 -s 100)

# Right-align "by LocalDock"
localdock="by LocalDock"
padded_localdock=$(printf "%*s" "$(tput cols)" "$localdock")  # Right-align to terminal width

# Combine the logo and the right-aligned "by LocalDock"
logo_with_localdock=$(echo -e "$logo\n$padded_localdock" | lolcat -a -d 2)

# Select a message source (fortune or custom quotes file)
if [ -f /usr/local/bin/custom_quotes.txt ]; then
  fortune_msg=$(shuf -n 1 /usr/local/bin/custom_quotes.txt | lolcat -a -d 1 -s 80)
else
  fortune_msg=$(fortune | lolcat -a -d 1 -s 80)
fi

# Calculate max length for the box
max_length=$(echo -e "$logo_with_localdock\n$fortune_msg" | wc -L)

# Draw the box around the content
echo "┌─$(head -c "$max_length" < /dev/zero | tr '\0' '─')─┐" | lolcat
echo "$logo_with_localdock" | while IFS= read -r line; do printf "│ %-*s │\n" "$max_length" "$line"; done | lolcat
echo "├─$(head -c "$max_length" < /dev/zero | tr '\0' '─')─┤" | lolcat
echo "$fortune_msg" | while IFS= read -r line; do printf "│ %-*s │\n" "$max_length" "$line"; done | lolcat
echo "└─$(head -c "$max_length" < /dev/zero | tr '\0' '─')─┘" | lolcat

# Original bash prompt
PS1='\u@\h:\w\$ '
