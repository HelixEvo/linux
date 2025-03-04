#!/bin/bash

# Variables
REPO="ergoplatform/ergo"
INSTALL_DIR="/home/ERGO"
CURRENT_VERSION_FILE="$INSTALL_DIR/current_version.txt"
JAR_FILE="$INSTALL_DIR/ergo.jar"
SERVICE_NAME="ergonodestart.service"

# Get current version (if file doesn’t exist, assume no version)
if [ -f "$CURRENT_VERSION_FILE" ]; then
    CURRENT_VERSION=$(cat "$CURRENT_VERSION_FILE")
else
    CURRENT_VERSION="v0.0.0"
    echo "No version file found. Assuming $CURRENT_VERSION as initial version."
fi

# Fetch latest release tag from GitHub API
LATEST_RELEASE=$(curl -s "https://api.github.com/repos/$REPO/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

echo "Fetched latest release: $LATEST_RELEASE"

# Check if curl failed
if [ -z "$LATEST_RELEASE" ]; then
    echo "Failed to fetch latest release from GitHub. Exiting."
    exit 1
fi

# Compare versions
if [ "$LATEST_RELEASE" != "$CURRENT_VERSION" ]; then
    echo "New version found: $LATEST_RELEASE (current: $CURRENT_VERSION)"

    # Strip 'v' from the version for the filename
    VERSION_NO_V=$(echo "$LATEST_RELEASE" | sed 's/^v//')

    # Construct the correct download URL
    JAR_URL="https://github.com/$REPO/releases/download/$LATEST_RELEASE/ergo-$VERSION_NO_V.jar"
    echo "Downloading from: $JAR_URL"

    # Stop the service
    systemctl stop "$SERVICE_NAME" || { echo "Failed to stop $SERVICE_NAME"; exit 1; }

    # Change to install directory
    cd "$INSTALL_DIR" || { echo "Failed to cd to $INSTALL_DIR"; exit 1; }

    # Download the jar file
    curl -L "$JAR_URL" -o "ergo-$VERSION_NO_V.jar" || { echo "Download failed from $JAR_URL"; exit 1; }

    # Check file size (expect > 10MB)
    FILE_SIZE=$(stat -c%s "ergo-$VERSION_NO_V.jar")
    echo "Downloaded file size: $FILE_SIZE bytes"
    if [ "$FILE_SIZE" -lt 10000000 ]; then
        echo "Downloaded file is too small ($FILE_SIZE bytes). Aborting."
        exit 1
    fi

    # Rename the file
    mv "ergo-$VERSION_NO_V.jar" "$JAR_FILE" || { echo "Failed to rename .jar file"; exit 1; }

    # Update the version file (keep the 'v' in the version file for consistency)
    echo "$LATEST_RELEASE" > "$CURRENT_VERSION_FILE" || { echo "Failed to update version file"; exit 1; }

    # Start the service
    systemctl start "$SERVICE_NAME" || { echo "Failed to start $SERVICE_NAME"; exit 1; }

    echo "Updated to $LATEST_RELEASE"
else
    echo "No update needed. Current version: $CURRENT_VERSION"
fi
