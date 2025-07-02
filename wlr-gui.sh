#!/bin/bash

# Check wlr-randr availability
if ! command -v wlr-randr &> /dev/null; then
    zenity --error --text="wlr-randr not found. Please install it first."
    exit 1
fi

# Function to show current monitor status
show_current_status() {
    status_text="Current Monitor Status:\n\n"
    
    while IFS= read -r line; do
        # Detect monitor line
        if [[ "$line" =~ ^([^[:space:]]+)\ \"(.+)\" ]]; then
            monitor="${BASH_REMATCH[1]}"
            name="${BASH_REMATCH[2]}"
            status_text+="● $monitor\n   Name: $name\n"
        # Detect enabled status
        elif [[ "$line" =~ [[:space:]]+Enabled:\ (.+) ]]; then
            status_text+="   Status: ${BASH_REMATCH[1]}\n"
        # Detect current mode
        elif [[ "$line" =~ [[:space:]]+([0-9]+x[0-9]+)\ px,\ ([0-9.]+)\ Hz\ \(current\) ]]; then
            mode="${BASH_REMATCH[1]}"
            rate="${BASH_REMATCH[2]}"
            status_text+="   Current Mode: $mode @ $rate Hz\n\n"
        fi
    done < <(wlr-randr)
    
    zenity --info \
        --title="Current Monitor Status" \
        --text="$status_text" \
        --width=600 \
        --height=400
}

# Show current status first
show_current_status

# Parse wlr-randr output
declare -A monitor_names
declare -A monitor_modes

current_monitor=""
while IFS= read -r line; do
    # Detect new monitor
    if [[ "$line" =~ ^([^[:space:]]+)\ \"(.+)\" ]]; then
        current_monitor="${BASH_REMATCH[1]}"
        monitor_names["$current_monitor"]="${BASH_REMATCH[2]}"
        monitor_modes["$current_monitor"]=""
    # Detect modes
    elif [[ "$line" =~ [[:space:]]+([0-9]+x[0-9]+)\ px,\ ([0-9.]+)\ Hz ]]; then
        mode="${BASH_REMATCH[1]}"
        rate="${BASH_REMATCH[2]}"
        if [ -n "$current_monitor" ]; then
            monitor_modes["$current_monitor"]+="${mode}@${rate}|"
        fi
    fi
done < <(wlr-randr)

# Create monitor selection menu
monitor_options=()
for monitor in "${!monitor_names[@]}"; do
    monitor_options+=("$monitor" "${monitor_names[$monitor]}")
done

# Select monitor
selected_monitor=$(zenity --list \
    --title="Select Monitor" \
    --text="Choose monitor to configure:" \
    --column="ID" --column="Description" \
    --hide-column=1 \
    "${monitor_options[@]}" \
    --height=300 --width=600)

[ -z "$selected_monitor" ] && exit 0

# Create mode selection menu
IFS='|' read -ra modes <<< "${monitor_modes[$selected_monitor]}"
mode_options=()
for mode in "${modes[@]}"; do
    if [ -n "$mode" ]; then
        res="${mode%@*}"
        rate="${mode#*@}"
        mode_options+=("$mode" "${res} @ ${rate} Hz")
    fi
done

selected_mode=$(zenity --list \
    --title="Select Resolution Mode" \
    --text="Choose mode for ${monitor_names[$selected_monitor]}:" \
    --column="Raw" --column="Display" \
    --hide-column=1 \
    "${mode_options[@]}" \
    --height=400 --width=500)

[ -z "$selected_mode" ] && exit 0

# Create command
cmd="wlr-randr --output \"$selected_monitor\" --mode \"$selected_mode\""

# Save to config file
config_file="$HOME/.display.sh"
echo -e "#!/bin/bash\n# Created on: $(date)\n\n$cmd" > "$config_file"
chmod +x "$config_file"

# Show configuration summary
zenity --info \
  --title="Configuration Saved" \
  --text="Command saved to:\n$config_file\n\n\
Configuration Details:\n\
• Monitor: ${monitor_names[$selected_monitor]}\n\
• Mode: ${selected_mode%@*} @ ${selected_mode#*@} Hz\n\n\
Run with:\nbash $config_file" \
  --width=500

# Option to run now
zenity --question --text="Run command now?" --width=300
[ $? -eq 0 ] && eval "$cmd" && zenity --info --text="Command executed successfully!"
