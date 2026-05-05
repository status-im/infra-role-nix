#!/usr/bin/env bash
# This script removes all Nix files.

# Colors
export YLW='\033[1;33m'
export RED='\033[0;31m'
export GRN='\033[0;32m'
export BLU='\033[0;34m'
export BLD='\033[1m'
export RST='\033[0m'

# Clear line
export CLR='\033[2K'

# Checking group ownership to identify installation type.
file_group() {
    UNAME=$(uname -s)
    if [[ "${UNAME}" == "Linux" ]]; then
        stat -Lc "%G" "${1}" 2>/dev/null
    elif [[ "${UNAME}" == "Darwin" ]]; then
        # Avoid using Nix GNU stat when in Nix shell.
        /usr/bin/stat -Lf "%Sg" "${1}" 2>/dev/null
    fi
}

os_name() {
    source /etc/os-release 2>/dev/null
    echo "${NAME}"
}

nix_install_type() {
    NIX_STORE_DIR_GROUP=$(file_group /nix/store)
    if [[ "$(os_name)" =~ NixOS ]]; then
        echo "nixos"
    else
        USER=$(id -un) # Missing in Docker.
        case "${NIX_STORE_DIR_GROUP}" in
            "nixbld")   echo "multi";;
            "30000")    echo "multi";;
            "(30000)")  echo "multi";;
            "wheel")    echo "single";;
            "users")    echo "single";;
            "${USER}")  echo "single";;
            "${UID}")   echo "single";;
            "(${UID})") echo "single";;
            "")         echo "none";
                        echo "No Nix installation detected!" >&2;;
            *)          echo "Unknown Nix installation type!" >&2; exit 1;;
        esac
    fi
}

nix_root() {
    NIX_ROOT="/nix"
    if [[ $(uname -s) == "Darwin" ]]; then
        # Special case due to read-only root on MacOS Catalina
        NIX_ROOT="/opt/nix"
    fi
    echo "${NIX_ROOT}"
}

nix_purge_linux_multi_user_service() {
    NIX_SERVICES=(nix-daemon.service nix-daemon.socket)
    for NIX_SERVICE in "${NIX_SERVICES[@]}"; do
        sudo systemctl stop "${NIX_SERVICE}"
        sudo systemctl disable "${NIX_SERVICE}"
    done
    sudo systemctl daemon-reload
}

nix_purge_linux_multi_user_users() {
    for NIX_USER in $(awk -F: '/nixbld/{print $1}' /etc/passwd); do
        sudo userdel "${NIX_USER}"
    done
    sudo groupdel nixbld
}

nix_purge_darwin_multi_user_service() {
    sudo launchctl unload /Library/LaunchDaemons/org.nixos.nix-daemon.plist
    sudo rm /Library/LaunchDaemons/org.nixos.nix-daemon.plist
    sudo launchctl unload /Library/LaunchDaemons/org.nixos.darwin-store.plist
    sudo rm /Library/LaunchDaemons/org.nixos.darwin-store.plist
}

nix_purge_darwin_multi_user_users() {
    for NIX_USER in $(dscl . list /Users | grep nixbld); do
        sudo dscl . -delete "/Users/${NIX_USER}"
    done
    sudo dscl . -delete /Groups/nixbld
}

# This still leaves an empty /nix, which will disappear after reboot.
nix_purge_darwin_multi_user_volumes() {
    sudo sed -i.bkp '/nix/d' /etc/synthetic.conf
    sudo sed -i.bkp '/nix/d' /etc/fstab

    # Attempt to delete the volume
    if ! sudo diskutil apfs deleteVolume /nix; then
        echo "Failed to unmount /nix because it is in use."

        # Identify the process using the volume
        local pid=$(lsof +D /nix | awk 'NR==2{print $2}')
        if [[ -n "$pid" ]]; then
            echo "The volume /nix is in use by process ID $pid."
            sudo kill "${pid}"
        else
            echo "No process found using /nix. Manual intervention required."
            return 1
        fi
    fi

    echo -e "${YLW}You will need to reboot your system!${RST}" >&2
}

nix_purge_multi_user() {
    if [[ $(uname -s) == "Darwin" ]]; then
        nix_purge_darwin_multi_user_service
        nix_purge_darwin_multi_user_users
        nix_purge_darwin_multi_user_volumes
    else
        nix_purge_linux_multi_user_service
        nix_purge_linux_multi_user_users
    fi

    sudo rm -fr /etc/nix
    sudo rm -f /etc/profile.d/nix.sh*

    # Restore old shell profiles
    NIX_PROFILE_FILES=(
        /etc/bash.bashrc /etc/bashrc /etc/bash/bashrc
        /etc/zsh.zshhrc /etc/zshrc /etc/zsh/zshrc
    )
    for NIX_FILE in "${NIX_PROFILE_FILES[@]}"; do
        if [[ -f "${NIX_FILE}.backup-before-nix" ]]; then
            sudo mv -f "${NIX_FILE}.backup-before-nix" "${NIX_FILE}"
        fi
    done
}

nix_purge_user_profile() {
    sudo rm -rf ~/.nix-* ~/.cache/nix ~/.config/nixpkgs
}

nix_purge_root() {
    NIX_ROOT=$(nix_root)
    if [[ -z "${NIX_ROOT}" ]]; then
        echo -e "${RED}Unable to identify Nix root!${RST}" >&2
        exit 1
    fi
    sudo rm -fr "${NIX_ROOT}"
}

# Don't run anything if script is just sourced.
if (return 0 2>/dev/null); then
    echo -e "${YLW}Script sourced, not running purge.${RST}"
    return
fi

NIX_INSTALL_TYPE=$(nix_install_type)
# Purging /nix on NixOS would be disastrous.
if [[ "${NIX_INSTALL_TYPE}" == "nixos" ]]; then
    echo -e "${RED}You should not purge Nix files on NixOS!${RST}" >&2
    exit
elif [[ "${NIX_INSTALL_TYPE}" == "none" ]] && [[ "${1}" != "--force" ]]; then
    echo -e "${YLW}Nothing to remove, Nix not installed.${RST}" >&2
    exit
elif [[ "${NIX_INSTALL_TYPE}" == "multi" ]] || [[ "${1}" == "--force" ]]; then
    echo -e "${YLW}Detected multi-user Nix installation.${RST}" >&2
    nix_purge_multi_user
elif [[ "${NIX_INSTALL_TYPE}" == "single" ]] || [[ "${1}" == "--force" ]]; then
    echo -e "${YLW}Detected single-user Nix installation.${RST}" >&2
    nix_purge_user_profile
fi
nix_purge_root

echo -e "${GRN}Purged all Nix files from your system.${RST}" >&2
