#!/bin/bash

# Script to copy modified ObjectModel-Airbrush files to @duet3d/objectmodel
# This replaces the JavaScript version with a native shell script

set -e  # Exit on any error

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

SOURCE_DIR="$PROJECT_ROOT/ObjectModel-Airbrush"
TARGET_DIR="$PROJECT_ROOT/node_modules/@duet3d/objectmodel"

echo "=================================="
echo "Copying modified ObjectModel-Airbrush to @duet3d/objectmodel"
echo "=================================="
echo "Source: $SOURCE_DIR"
echo "Target: $TARGET_DIR"
echo ""

# Check if source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
    echo "ERROR: Source directory does not exist: $SOURCE_DIR"
    echo "Make sure ObjectModel-Airbrush is cloned in the project root"
    exit 1
fi

# Create target directory if it doesn't exist
if [ ! -d "$TARGET_DIR" ]; then
    echo "Creating target directory: $TARGET_DIR"
    mkdir -p "$TARGET_DIR"
fi

# Copy all files using rsync if available, otherwise use cp
if command -v rsync &> /dev/null; then
    echo "Using rsync to copy files..."
    rsync -av --delete "$SOURCE_DIR/" "$TARGET_DIR/"
else
    echo "Using cp to copy files..."
    # Remove existing files in target directory
    rm -rf "$TARGET_DIR/"*

    # Copy all files recursively
    cp -r "$SOURCE_DIR/"* "$TARGET_DIR/"
fi

echo ""
echo "✓ Copy complete!"
echo "Modified ObjectModel-Airbrush has been copied to @duet3d/objectmodel"
echo ""
