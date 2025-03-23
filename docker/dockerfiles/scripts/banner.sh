#!/bin/bash

generate_infocyph_header() {
  local title="${1:-LOCALDOCK}"
  local describe="${2:-DESCRIBE}"

  # Generate figlet output for the title
  local figlet_output
  figlet_output=$(figlet -f standard "$title")

  # Compute maximum length of figlet output lines
  local figlet_width=0
  while IFS= read -r line; do
    local len=${#line}
    (( len > figlet_width )) && figlet_width=$len
  done <<< "$figlet_output"

  #### Prepare Credit Information ####
  local credits=(
    "© Infocyph. Innovation at its core."
    "© Infocyph. Powered by passion."
    "© Infocyph. Crafting excellence."
    "© Infocyph. Unleashing creativity."
    "© Infocyph. Where ideas come to life."
  )
  local selected_credit="${credits[$RANDOM % ${#credits[@]}]}"
  local credit_length=${#selected_credit}

  #### Prepare DESCRIBE Box ####
  local box_text="$describe"
  local box_text_length=${#box_text}
  local box_width=$(( box_text_length + 2 ))  # plus vertical borders

  #### Determine Overall Width ####
  # Overall width is the maximum of figlet_width, credit_length, and box_width.
  local overall_width=$figlet_width
  (( credit_length > overall_width )) && overall_width=$credit_length
  (( box_width > overall_width )) && overall_width=$box_width

  #### Center-align Figlet Output ####
  local centered_figlet=""
  while IFS= read -r line; do
    local line_length=${#line}
    local pad_total=$(( overall_width - line_length ))
    local left_pad=$(( pad_total / 2 ))
    local right_pad=$(( pad_total - left_pad ))
    local left_spaces
    left_spaces=$(printf '%*s' "$left_pad" "")
    local right_spaces
    right_spaces=$(printf '%*s' "$right_pad" "")
    centered_figlet+="${left_spaces}${line}${right_spaces}\n"
  done <<< "$figlet_output"

  #### Build DESCRIBE Box with Dash Padding ####
  local box_top=""
  local box_mid=""
  local box_bot=""
  if (( box_width > overall_width )); then
    # If the box is wider than the overall width, just use plain text.
    box_mid="$box_text"
  else
    local left_padding_box=$(( (overall_width - box_width) / 2 ))
    local right_padding_box=$(( overall_width - box_width - left_padding_box ))
    local dash_pad_left
    dash_pad_left=$(printf '%*s' "$left_padding_box" "" | tr ' ' '-')
    local dash_pad_right
    dash_pad_right=$(printf '%*s' "$right_padding_box" "" | tr ' ' '-')
    local horizontal_line
    horizontal_line=$(printf '%*s' "$box_text_length" "" | tr ' ' '-')
    box_top="${dash_pad_left}+${horizontal_line}+${dash_pad_right}"
    box_mid="${dash_pad_left}|${box_text}|${dash_pad_right}"
    box_bot="${dash_pad_left}+${horizontal_line}+${dash_pad_right}"
  fi

  #### Center-align the Credit ####
  local centered_credit=""
  if (( credit_length >= overall_width )); then
    centered_credit="$selected_credit"
  else
    local left_spaces=$(( (overall_width - credit_length) / 2 ))
    local right_spaces=$(( overall_width - credit_length - left_spaces ))
    local left_pad
    left_pad=$(printf '%*s' "$left_spaces" "")
    local right_pad
    right_pad=$(printf '%*s' "$right_spaces" "")
    centered_credit="${left_pad}${selected_credit}${right_pad}"
  fi

  #### Assemble Final Output ####
  # Use the if/else condition to check if the box was built
  if [ -n "$box_top" ] && [ -n "$box_mid" ] && [ -n "$box_bot" ]; then
    printf "%b\n%s\n%s\n%s\n%s\n" \
      "$centered_figlet" \
      "$box_top" \
      "$box_mid" \
      "$box_bot" \
      "$centered_credit"
  else
    printf "%b\n%s\n%s\n" \
      "$centered_figlet" \
      "$box_mid" \
      "$centered_credit"
  fi | boxes -d parchment -a hcvc | lolcat
}

generate_infocyph_header "$@"
