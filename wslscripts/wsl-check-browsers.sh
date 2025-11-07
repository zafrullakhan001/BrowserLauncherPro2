#!/bin/bash

# Function to print messages in green
print_green() {
  echo -e "\e[32m$1\e[0m"
}

# Function to print usage
print_usage() {
  echo "Usage: $0 [--output <format>] [--export <file>] [--version] [--table-format]"
  echo "  --output: Specify output format (normal, json, or both). Default is both."
  echo "  --export: Export output to a file."
  echo "  --version: Include version information for installed applications."
  echo "  --table-format: Display normal output in a formatted table."
}

# Parse command line arguments
output_format="both"
output_file=""
check_version=false
table_format=false
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --output) output_format="$2"; shift ;;
    --export) output_file="$2"; shift ;;
    --version) check_version=true ;;
    --table-format) table_format=true ;;
    -h|--help) print_usage; exit 0 ;;
    *) echo "Unknown parameter: $1"; print_usage; exit 1 ;;
  esac
  shift
done

# Validate output format
if [[ ! "$output_format" =~ ^(normal|json|both)$ ]]; then
  echo "Invalid output format. Use 'normal', 'json', or 'both'."
  exit 1
fi

# Arrays to store paths and versions of installed applications
installed_paths=()
json_output=()

# Function to get version
get_version() {
  local app=$1
  local version=""
  case $app in
    google-chrome|google-chrome-beta|google-chrome-unstable|microsoft-edge|microsoft-edge-beta|microsoft-edge-dev|opera|brave-browser)
      version=$($app --version 2>/dev/null | awk '{print $NF}' | tr -d '\n')
      ;;
    firefox)
      version=$($app --version 2>/dev/null | awk '{print $3}' | tr -d '\n')
      ;;
    code)
      version=$($app --version 2>/dev/null | awk '{print $1}' | tr -d '\n')
      ;;
    konsole)
      version=$(konsole --version 2>/dev/null | grep "Konsole" | awk '{print $2}' | tr -d '\n')
      ;;
    pulseaudio)
      version=$(pulseaudio --version 2>/dev/null | awk '{print $2}' | tr -d '\n')
      ;;
    dos2unix)
      version=$(dos2unix --version 2>/dev/null | awk 'NR==1{print $2}' | tr -d '\n')
      ;;
  esac
  echo "${version:-Unknown}"
}

# Confirm installations
[[ "$output_format" != "json" ]] && echo "Confirming installations..."
declare -A browser_commands=(
  ["google-chrome-stable"]="google-chrome"
  ["google-chrome-beta"]="google-chrome-beta"
  ["google-chrome-unstable"]="google-chrome-unstable"
  ["microsoft-edge-stable"]="microsoft-edge"
  ["microsoft-edge-beta"]="microsoft-edge-beta"
  ["microsoft-edge-dev"]="microsoft-edge-dev"
  ["opera"]="opera"
  ["brave-browser"]="brave-browser"
  ["firefox"]="firefox"
  ["code"]="code"
  ["konsole"]="konsole"
  ["pulseaudio"]="pulseaudio"
  ["dos2unix"]="dos2unix"
)

table_data=()
for browser in "${!browser_commands[@]}"; do
  command_name="${browser_commands[$browser]}"
  if command_path=$(command -v "$command_name"); then
    version="Unknown"
    if $check_version; then
      version=$(timeout 5s bash -c "$(declare -f get_version); get_version '$command_name'" 2>/dev/null || echo "Unknown")
      json_output+=("  \"$browser\": {\"path\": \"$command_path\", \"version\": \"$version\"}")
    else
      json_output+=("  \"$browser\": \"$command_path\"")
    fi
    status="Installed"
    table_data+=("$browser|$status|$version|$command_path")
    [[ "$output_format" != "json" && ! $table_format ]] && print_green "$browser installed successfully. (version: $version)"
  else
    status="Not Installed"
    table_data+=("$browser|$status||")
    [[ "$output_format" != "json" && ! $table_format ]] && echo "$browser is not installed."
    json_output+=("  \"$browser\": null")
  fi
done

# Function to create a formatted table
create_table() {
  local -n data=$1
  local check_version=$2
  local no_color=$3
  local max_app=20 max_status=12 max_version=20 max_path=40

  # Calculate maximum lengths
  for row in "${data[@]}"; do
    IFS='|' read -r app status version path <<< "$row"
    ((${#app} > max_app)) && max_app=${#app}
    ((${#status} > max_status)) && max_status=${#status}
    ((${#version} > max_version)) && max_version=${#version}
    ((${#path} > max_path)) && max_path=${#path}
  done

  # Create separator line
  local total_width=$((max_app + max_status + max_path + 10))
  [[ "$check_version" == "true" ]] && total_width=$((total_width + max_version + 3))
  local separator=$(printf '+%*s+' "$total_width" | tr ' ' '-')

  # Print header
  printf "$separator\n"
  printf "| %-*s | %-*s |" "$max_app" "Application" "$max_status" "Status"
  [[ "$check_version" == "true" ]] && printf " %-*s |" "$max_version" "Version"
  printf " %-*s |\n" "$max_path" "Path"
  printf "$separator\n"

  # Print data rows
  for row in "${data[@]}"; do
    IFS='|' read -r app status version path <<< "$row"
    printf "| %-*s |" "$max_app" "$app"
    if [[ "$status" == "Installed" && "$no_color" != "no_color" ]]; then
      printf " \e[42m%-*s\e[0m |" "$max_status" "$status"
    else
      printf " %-*s |" "$max_status" "$status"
    fi
    [[ "$check_version" == "true" ]] && printf " %-*s |" "$max_version" "$version"
    printf " %-*s |\n" "$max_path" "$path"
  done

  # Print footer
  printf "$separator\n"
}

# Show paths of installed applications
if [[ "$output_format" != "json" ]]; then
  if $table_format; then
    create_table table_data "$check_version"
  else
    echo ""
    echo "Paths of installed applications:"
    for row in "${table_data[@]}"; do
      IFS='|' read -r app status version path <<< "$row"
      if [[ $status == "Installed" ]]; then
        echo "$app path: $path $(if $check_version; then echo "(version: $version)"; fi)"
      fi
    done
  fi
fi

# Export output to file if specified
if [[ -n "$output_file" ]]; then
  if [[ "$output_format" == "json" || "$output_format" == "both" ]]; then
    echo "{" > "$output_file"
    (IFS=$',\n'; echo "${json_output[*]}") >> "$output_file"
    echo "}" >> "$output_file"
  fi
  if [[ "$output_format" == "normal" || "$output_format" == "both" ]]; then
    if $table_format; then
      create_table table_data "$check_version" "no_color" > "$output_file"
    else
      echo "Paths of installed applications:" > "$output_file"
      for row in "${table_data[@]}"; do
        IFS='|' read -r app status version path <<< "$row"
        if [[ $status == "Installed" ]]; then
          echo "$app path: $path $(if $check_version; then echo "(version: $version)"; fi)" >> "$output_file"
        fi
      done
    fi
  fi
  echo "Output exported to $output_file"
fi

# Generate formatted JSON output
if [[ "$output_format" != "normal" ]]; then
  [[ "$output_format" == "both" ]] && echo ""
  echo "{"
  (IFS=$',\n'; echo "${json_output[*]}")
  echo "}"
fi
