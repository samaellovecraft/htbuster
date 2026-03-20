# ==============================================================================
# HTBuster v1.0.0
#
# Description:  Lab directory management and navigation for Hack The Box.
# Repository:   https://github.com/samaellovecraft/HTBuster
# Usage:        DO NOT EXECUTE. Source this file in your .zshrc or .bashrc.
# Standard:     POSIX / Zsh / Bash compatible.
# License:      MIT
# ==============================================================================
export HTB_ROOT="${LAB:-$HOME}/HTB"

_htb_scaffold() {
    local category=$1  # Machines | Challenges | Sherlocks
    local state=$2     # Active | Retired
    local target=$3

    local base_dir="$HTB_ROOT/$category/$state"
    local alt_state_dir="$HTB_ROOT/$category/$([[ "$state" == "Active" ]] && echo "Retired" || echo "Active")"

    # 1. Traversal only
    if [[ -z "$target" ]]; then
        mkdir -p "$base_dir"
        cd "$base_dir" || return 1
        return 0
    fi

    # 2. Check if it already exists in the target state
    if [[ -d "$base_dir/$target" ]]; then
        cd "$base_dir/$target" || return 1
        return 0
    fi

    # 3. Check if it exists in the alternate state 
    if [[ -d "$alt_state_dir/$target" ]]; then
        echo "[!] '$target' already exists in $alt_state_dir. Jumping there instead."
        cd "$alt_state_dir/$target" || return 1
        return 0
    fi
    
    # 4. Scaffolding & Confirmation Guard
    local full_path="$base_dir/$target"
    printf "[?] Creating %s. Proceed? [Y/n] " "$full_path"
    
    read -r response < /dev/tty
    
    if [[ "$response" =~ ^[Nn] ]]; then
        echo "[-] Aborted."
        return 1
    fi

    echo "[+] Initializing $target in $category/$state..."
    mkdir -p "$full_path"
    cd "$full_path" || return 1

    # Apply global structure
    mkdir -p attachments artifacts

    # Apply category-specific structure
    if [[ "$category" == "Machines" ]]; then
        mkdir -p enumeration
        cat <<EOF >"README.md"
# $target

## Network Enumeration

### TCP Scan

### UDP Scan

## Web Enumeration

### Vhost Discovery

### Walking an Application

### Web Content Discovery

## Foothold

## PrivEsc

EOF
    else
        echo "# $target" > "README.md"
    fi
    echo "[+] Ready."
}

# The Shortcuts
htbma()  { _htb_scaffold "Machines" "Active" "$1" }
htbmr()  { _htb_scaffold "Machines" "Retired" "$1" }
htbcha() { _htb_scaffold "Challenges" "Active" "$1" }
htbchr() { _htb_scaffold "Challenges" "Retired" "$1" }
htbsha() { _htb_scaffold "Sherlocks" "Active" "$1" }
htbshr() { _htb_scaffold "Sherlocks" "Retired" "$1" }

# The Retirement Function
htbretire() {
    if [[ -z "$1" ]]; then
        echo "[-] Error: Missing target argument."
        echo "[-] Usage: htbretire <box> (or '.' for current directory)"
        return 1
    fi

    local raw_target="$1"
    local target=""

    # Input Sanitization
    if [[ "$raw_target" == "." ]]; then
        target=$(basename "$PWD")
    else
        # Strips trailing slashes from tab-completion or extracts name from a full path
        target=$(basename "$raw_target")
    fi

    local current_path=$PWD
    local found=0

    for category in Machines Challenges Sherlocks; do
        local active_path="$HTB_ROOT/$category/Active/$target"
        local retired_path="$HTB_ROOT/$category/Retired"

        if [[ -d "$active_path" ]]; then
            # Prevent nested overwrites if target already exists in Retired
            if [[ -d "$retired_path/$target" ]]; then
                echo "[-] Fatal: '$target' already exists in $retired_path. Aborting to prevent overwrite."
                return 1
            fi

            # Confirmation Guard
            printf "[?] Retiring '%s' to %s. Proceed? [Y/n] " "$target" "$retired_path/"
            read -r response < /dev/tty

            if [[ "$response" =~ ^[Nn] ]]; then
                echo "[-] Aborted."
                return 1
            fi

            echo "[+] Retiring $target from $category..."
            mkdir -p "$retired_path"
            mv "$active_path" "$retired_path/"
            found=1

            # If we were inside the active directory, update our shell's PWD to the new location
            if [[ "$current_path" == "$active_path"* ]]; then
                cd "${current_path/Active/Retired}" || return 1
            fi
            break
        fi
    done

    if [[ $found -eq 0 ]]; then
        echo "[-] Could not find an Active lab named '$target'."
        return 1
    fi
}
# vim: set ft=sh :
