#!/bin/bash
# Upload SafeZone mod to Steam Workshop via remote server
# Usage: ./upload.sh [changenote]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$SCRIPT_DIR/deploy.env"

if [ ! -f "$ENV_FILE" ]; then
    echo "ERROR: $ENV_FILE not found. Copy deploy.env.example to deploy.env and fill in your values."
    exit 1
fi
source "$ENV_FILE"

SERVER="$SERVER_USER@$SERVER_HOST"
CHANGENOTE="${1:-update}"

echo ">>> Cleaning remote and syncing mod..."
ssh $SERVER "rm -rf $REMOTE_UPLOAD_DIR/Contents"
scp -r "$MOD_DIR/Contents" "$SERVER:$REMOTE_UPLOAD_DIR/"
scp "$MOD_DIR/preview.png" "$SERVER:$REMOTE_UPLOAD_DIR/preview.png"

echo ">>> Updating changenote: $CHANGENOTE"
ssh $SERVER "sed -i 's/\"changenote\".*$/\"changenote\"      \"$CHANGENOTE\"/' $REMOTE_UPLOAD_DIR/workshop_upload.vdf"

echo ">>> Fixing permissions..."
ssh $SERVER "chown -R $PZ_USER:$PZ_USER $REMOTE_UPLOAD_DIR"

echo ">>> Uploading to Steam Workshop..."
ssh $SERVER "su - $PZ_USER -c '$STEAMCMD_PATH +login $STEAM_USER +workshop_build_item $REMOTE_UPLOAD_DIR/workshop_upload.vdf +quit'" 2>&1 | tail -5

echo ">>> Done!"