#!/bin/bash

set -euo pipefail
directory="$(dirname -- "$(readlink -f -- "$0" || greadlink -f -- "$0")")"

# Define colors
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m' # No color

### Prevent "unbound array" issue
declare -A descriptions=()
declare -A options=()
declare -a positional=()
source "$directory/docker/utilities/profiles"

### ========== CORE ==========

check_required_commands() {
  local commands=("$@")
  for cmd in "${commands[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      echo -e "${RED}- Error: '$cmd' is not installed! Aborting.${NC}"
      exit 1
    fi
  done
}

update_env() {
  local env_file="$1"
  local var_name="$2"
  local var_value="$3"

  [ ! -f "$env_file" ] && {
    echo -e "${YELLOW}File '$env_file' not found. Creating one.${NC}"
    touch "$env_file"
  }

  local escaped_var_name
  escaped_var_name=$(echo "$var_name" | sed 's/[]\/$*.^|[]/\\&/g')
  if grep -qE "^[# ]*${escaped_var_name}=" "$env_file"; then
    sed -i -E "s|^[# ]*(${escaped_var_name}=).*|\1${var_value}|" "$env_file"
  else
    echo "${var_name}=${var_value}" >>"$env_file"
  fi
}

reload_http_containers() {
  echo -e "${GREEN}- Reloading HTTP...${NC}"
  if docker ps -q -f name=NGINX &>/dev/null; then
    docker exec NGINX nginx -s reload &>/dev/null || true
  fi
  if docker ps -q -f name=APACHE &>/dev/null; then
    docker exec APACHE apachectl graceful &>/dev/null || true
  fi
  echo -e "${GREEN}- HTTP Reloaded...${NC}"
}


docker_compose() {
  docker compose --project-directory "$directory" \
    -f "$directory/docker/compose/main.yaml" \
    --env-file "$directory/docker/.env" "$@"
}

check_file_existence() {
  local files=("$@")
  for file in "${files[@]}"; do
    local full_path="${directory}${file}"
    if [ ! -f "$full_path" ]; then
      echo -e "${RED}- Error: $full_path file is missing! Aborting.${NC}"
      exit 1
    fi
  done
}

ensure_files_exist() {
  local files=("$@")
  for file in "${files[@]}"; do
    local full_path="${directory}${file}"
    local dir
    dir=$(dirname "$full_path")
    if [ ! -d "$dir" ]; then
      echo -e "${YELLOW}- Creating directory $dir.${NC}"
      mkdir -p "$dir"
    fi
    if [ ! -f "$full_path" ]; then
      echo -e "${YELLOW}- Creating file $full_path.${NC}"
      touch "$full_path"
    fi
  done
}

launch_php_container() {
  local domain="$1"
  # Assuming $directory is defined globally.
  local nginx_conf="$directory/configuration/nginx/$domain.conf"
  local apache_conf="$directory/configuration/apache/$domain.conf"
  local doc_root=""
  local php_container=""

  [ ! -f "$nginx_conf" ] && {
    echo -e "${RED}No Nginx configuration found for $domain.${NC}"
    exit 1
  }

  if grep -q "fastcgi_pass" "$nginx_conf"; then
    php_container=$(grep -Eo 'fastcgi_pass ([^:]+):9000' "$nginx_conf" | awk '{print $2}' | sed 's/:9000$//')
    doc_root=$(grep -m1 -Eo 'root [^;]+' "$nginx_conf" | awk '{print $2}')
  elif grep -q "proxy_pass" "$nginx_conf"; then
    [ ! -f "$apache_conf" ] && {
      echo -e "${RED}No Apache configuration found for $domain.${NC}"
      exit 1
    }
    doc_root=$(grep -m1 -Eo 'DocumentRoot [^ ]+' "$apache_conf" | awk '{print $2}')
    php_container=$(grep -m1 'SetHandler "proxy:fcgi://' "$apache_conf" | sed -E 's/.*proxy:fcgi:\/\/([^:]+):9000".*/\1/')
  else
    echo -e "${RED}Could not determine the container setup for $domain.${NC}"
    exit 1
  fi

  [ -z "$php_container" ] && {
    echo -e "${RED}Failed to determine PHP container for $domain.${NC}"
    exit 1
  }

  [ -z "$doc_root" ] && {
    echo -e "${YELLOW}Document root not found for $domain. Defaulting to /app.${NC}"
    doc_root="/app"
  }

  docker exec -it "$php_container" bash --login -c "cd \"$doc_root\" && exec bash"
}

assign_permissions() {
  case "$(uname -s)" in
    *NT*|*Msys*|*Cygwin*) return ;;
  esac
  (( EUID == 0 )) || { echo -e "${RED}Please run with sudo.${NC}"; return; }

  chmod 755 "$directory"
  chmod 775 "$directory/configuration/"
  find "$directory/configuration/" -type f ! -perm 664 -exec chmod 664 {} \;
  chmod g+s "$directory/configuration/"

  chmod 755 "$directory/docker/"
  find "$directory/docker/" -type f ! -perm 644 -exec chmod 644 {} \;
#  find "$directory/docker/dockerfiles/scripts/" -type f ! -perm 755 -exec chmod 755 {} \;

  chmod 2777 "$directory/data"
  find "$directory/data" -mindepth 1 -maxdepth 1 -type d -exec chmod 2777 {} \;
  find "$directory/data" -type f -exec chmod 0666 {} \;

  chmod -R 777 "$directory/logs/"
  chown -R "$USER:docker" "$directory/logs/"

  chmod 755 "$directory/bin"
  find "$directory/bin" -type f ! -name '*.bat' ! -perm 744 -exec chmod 744 {} \;
  chmod 744 "$directory/server"

  ln -s "$directory/server" "/usr/local/bin/server"
}

modify_compose_profiles() {
  local env_file="$1"
  local var_name="$2"
  local action="$3"
  shift 3
  local profiles=("$@")

  # pull out existing, newline‑separated
  local existing_profiles=""
  if grep -q "^${var_name}=" "$env_file"; then
    existing_profiles=$(grep "^${var_name}=" "$env_file" |
      cut -d '=' -f 2 |
      tr ',' '\n')
  fi

  local updated_profiles=()

  case "$action" in
  add)
    # add any new ones
    for p in "${profiles[@]}"; do
      if ! grep -qx "$p" <<<"$existing_profiles"; then
        updated_profiles+=("$p")
      fi
    done
    # then re‑append the old ones
    while IFS= read -r old; do
      updated_profiles+=("$old")
    done <<<"$existing_profiles"
    ;;
  remove)
    for old in $existing_profiles; do
      [[ ! " ${profiles[*]} " =~ " ${old} " ]] && updated_profiles+=("$old")
    done
    ;;
  *)
    echo -e "${RED}Invalid action: $action${NC}"
    return 1
    ;;
  esac

  # join with commas
  local updated_profiles_str
  updated_profiles_str=$(
    IFS=,
    echo "${updated_profiles[*]}"
  )
  update_env "$env_file" "$var_name" "$updated_profiles_str"
}

install_root_ca() {
  local src="$directory/configuration/rootCA/rootCA.pem"
  local dest="/usr/local/share/ca-certificates/rootCA.crt"

  # must be root
  if ((EUID != 0)); then
    printf "%bError:%b must be run as root.\n" "$RED" "$NC"
    return 1
  fi

  # source file must exist
  if [[ ! -r $src ]]; then
    printf "%bError:%b certificate not found: %s\n" "$RED" "$NC" "$src"
    return 1
  fi

  printf "%bInstalling root CA certificate...%b\n" "$CYAN" "$NC"

  # copy with correct perms, then update trust store
  if install -m 644 "$src" "$dest"; then
    if command -v update-ca-certificates &>/dev/null; then
      update-ca-certificates
    elif command -v trust &>/dev/null; then
      trust extract-compat
    else
      printf "%bWarning:%b no CA-update tool found; skipping trust update.\n" "$YELLOW" "$NC"
    fi

    printf "%bSuccess:%b root CA installed to %s\n" "$GREEN" "$NC" "$dest"
    return 0
  else
    printf "%bError:%b failed to install root CA.\n" "$RED" "$NC"
    return 1
  fi
}

### ========== ARGUMENT PARSER ==========
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
    --*=*)
      key="${1%%=*}"
      val="${1#*=}"
      options["$key"]="$val"
      ;;
    --*) options["$1"]=true ;;
    -*)
      short="${1:1}"
      options["-$short"]=true
      ;;
    *) positional+=("$1") ;;
    esac
    shift
  done
}

### ========== DESCRIPTION PARSER ==========
get_description() {
  local fn="cmd_$1"
  local desc=""

  if declare -f "$fn" >/dev/null; then
    desc=$(declare -f "$fn" | grep -Eo '^#\s.*' | head -1 | sed 's/^# //' || true)
  fi

  # fallback gracefully, no "unbound" issue due to empty map
  echo "${desc:-${descriptions[$1]-}}"
}

### ========== USAGE ==========
print_usage() {
  printf "${CYAN}Usage:${NC}\n"
  printf "$0 <command> [options]\n\n"
  printf "${CYAN}Available Commands:${NC}\n"

  for cmd in $(declare -F | awk '{print $3}' | grep '^cmd_' | sed 's/^cmd_//'); do
    printf "  ${YELLOW}%-15s${NC} %s\n" "$cmd" "$(get_description "$cmd")"
  done
}

### ========== COMMAND DISPATCHER ==========
run_command() {
  local command="${1,,}"
  shift || true

  if declare -f "cmd_${command}" >/dev/null; then
    "cmd_${command}" "$@"
  else
    printf "${RED}Invalid command: %s${NC}\n" "$command"
    print_usage
    exit 1
  fi
}

### ========== INIT ==========
init() {
  check_required_commands "docker" "readlink"
  check_file_existence "/.env"
  ensure_files_exist "/docker/.env" "/configuration/php/php.ini"
  update_env "$directory/docker/.env" "WORKING_DIR" "$directory"
  update_env "$directory/docker/.env" "USER" "$(id -un)"
}

### ========== COMMANDS ==========

# Start Docker services (foreground)
cmd_up() { docker_compose up; }

# Start Docker services (background) + reload HTTP
cmd_start() {
  docker_compose up -d
  reload_http_containers
}

# Alias for start
cmd_reload() { cmd_start; }

# Stop Docker services
cmd_stop() { docker_compose down; }

# Alias for stop
cmd_down() { cmd_stop; }

# Stop & start Docker services
cmd_reboot() {
  cmd_stop
  cmd_start
}

# Alias for reboot
cmd_restart() { cmd_reboot; }

# Rebuild Docker images with no cache
cmd_rebuild() { docker_compose down && docker_compose build --no-cache --pull "${positional[@]:1}"; }

# Validate and show docker-compose config
cmd_config() { docker_compose config; }

# Access SERVER_TOOLS container
cmd_tools() { docker exec -it SERVER_TOOLS bash; }

# Launch LazyDocker in SERVER_TOOLS
cmd_lzd() { docker exec -it SERVER_TOOLS lazydocker; }
cmd_lazydocker() { cmd_lzd; }
cmd_lazy-docker() { cmd_lzd; }

# HTTP container management (e.g., reload)
cmd_http() {
  [[ "${positional[1]:-}" == "reload" ]] && reload_http_containers
}

# Access PHP container for a domain
cmd_core() {
  if [[ -z "${positional[1]:-}" ]]; then
    printf "${RED}Please provide a domain (e.g., $0 core test.com).${NC}\n"
    exit 1
  fi
  launch_php_container "${positional[1]}"
}

# Setup tasks (permissions, domain, profiles, env)
cmd_setup() {
  case "${positional[1]:-}" in
  permissions | perms | perm | permission)
    assign_permissions
    printf "${GREEN}Necessary Permissions have been assigned.${NC}\n"
    ;;
  domain)
    docker exec SERVER_TOOLS mkhost --RESET
    docker exec -it SERVER_TOOLS mkhost
    local pprofile=$(docker exec SERVER_TOOLS mkhost --ACTIVE_PHP_PROFILE)
    if [[ $? -eq 0 && -n "$pprofile" ]]; then
      modify_compose_profiles "$directory/docker/.env" "COMPOSE_PROFILES" "add" "$pprofile"
    fi
    local sprofile=$(docker exec SERVER_TOOLS mkhost --APACHE_ACTIVE)
    if [[ $? -eq 0 && -n "$sprofile" ]]; then
      modify_compose_profiles "$directory/docker/.env" "COMPOSE_PROFILES" "add" "$sprofile"
    fi
    docker exec SERVER_TOOLS mkhost --RESET
    ;;
  profiles | profile)
    process_all
    ;;
  env)
    local env_file="$directory/.env"
    [[ "${positional[2]:-}" == "docker" ]] && env_file="$directory/docker/.env"
    process_env_file "$env_file"
    ;;
  *)
    printf "${RED}Invalid setup command: %s${NC}\n" "${positional[1]:-}"
    ;;
  esac
}

# Install components (e.g., certificate)
cmd_install() {
  case "${positional[1]:-}" in
  certificate)
    install_root_ca
    ;;
  *)
    printf "${RED}Invalid install command: %s${NC}\n" "${positional[1]:-}"
    ;;
  esac
}

# Display this help message
cmd_help() { print_usage; }

### ========== MAIN ==========
main() {
  if [ $# -eq 0 ]; then
    printf "${RED}Error: No command provided.${NC}\n"
    print_usage
    exit 1
  fi
  local flag positional raw
  for flag in "${!options[@]}"; do
    positional+=("$flag")
  done

  parse_args "$@"
  init
  raw=("$@")
  case "${raw[0],,}" in
    php|mariadb|mariadb-dump|mysql|mysql-dump|psql|pg_dump|pg_restore|redis|composer)
      "$directory/bin/${raw[0]}" "${raw[@]:1}"
      return
      ;;
  esac
  run_command "${positional[0]}"
  unset directory
}

main "$@"
