#!/bin/bash

set -eux

# Set the local repository path
REPO_DIR="$(readlink -f "${1:-$(dirname "$0")/debian}")"
DISTRIBUTION="${2:-ubuntu}"
SUITE="${3:-jammy}"
GPG_KEY_ID="${4:-473F57D3A9534D53F0128E9DFF0244C9D7E28146}"

# Create a temporary directory to store the new .deb files
TEMP_DIR=$(mktemp -d)

YA_INSTALLER_CORE="${YA_INSTALLER_CORE:-pre-rel-v0.13.0-rc18}"
YA_INSTALLER_WASI=${YA_INSTALLER_WASI:-0.2.3}
YA_INSTALLER_VM=${YA_INSTALLER_VM:-0.3.0}

# Function to download .deb files using curl
download_deb_files() {
    for url in "$@"; do
        curl -L -o "$TEMP_DIR/$(basename "$url")" "$url"
    done
}

# Function to add .deb files to the local repository
create_local_repository() {
    mkdir -p "$REPO_DIR/conf"

    cat << EOF > "${REPO_DIR}/conf/distributions"
Origin: GOLEM $DISTRIBUTION
Label: GOLEM $DISTRIBUTION
Codename: $SUITE
Architectures: amd64
Components: main
Description: APT repository with GOLEM components
Tracking: all
EOF

    # Add new .deb files to the local repository
    reprepro -S misc -b "$REPO_DIR" includedeb "$SUITE" "$TEMP_DIR"/*.deb

    # Sign the repository metadata
    rm -rf "$REPO_DIR/dists/$SUITE/Release.gpg" "$REPO_DIR/dists/$SUITE/InRelease"
    gpg --detach-sign --armor --local-user "$GPG_KEY_ID" --batch --no-tty --output "$REPO_DIR/dists/$SUITE/Release.gpg" "$REPO_DIR/dists/jammy/Release"
    gpg --clearsign --armor --local-user "$GPG_KEY_ID" --batch --no-tty --output "$REPO_DIR/dists/$SUITE/InRelease" "$REPO_DIR/dists/jammy/Release"
}

#
# Main script execution
#

# Download and add new .deb files to the local repository
#download_deb_files \
#  "https://github.com/golemfactory/yagna/releases/download/${YA_INSTALLER_CORE}/golem-provider_${YA_INSTALLER_CORE}_amd64.deb" \
#  "https://github.com/golemfactory/ya-runtime-wasi/releases/download/v${YA_INSTALLER_WASI}/ya-runtime-wasi-cli_${YA_INSTALLER_WASI}_amd64.deb" \
#  "https://github.com/golemfactory/ya-runtime-vm/releases/download/${YA_INSTALLER_VM}/ya-runtime-vm_${YA_INSTALLER_VM}_amd64.deb"

download_deb_files \
    https://github.com/golemfactory/yagna/releases/download/pre-rel-v0.13.0-rc18/golem-provider_pre-rel-v0.13.0-rc18_amd64.deb \
    https://github.com/golemfactory/ya-runtime-wasi/releases/download/pre-rel-v0.2.4/ya-runtime-wasi-cli_0.2.3_amd64.deb \
    https://github.com/golemfactory/ya-runtime-vm/releases/download/pre-rel-v0.4.0-rc4/ya-runtime-vm_pre-rel-v0.4.0-rc4_amd64.deb \
    https://launchpad.net/~fepitre/+archive/ubuntu/golem-nvidia-kernel/+files/golem-nvidia-kernel_5.10.188-1_amd64.deb

# Add the new .deb files to the local repository and sign the repository metadata
create_local_repository

# Clean up the temporary directory
rm -rf "$TEMP_DIR"
