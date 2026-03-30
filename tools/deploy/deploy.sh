#!/bin/bash
# Deploy server scripts, configs and messages to PZ server
# Usage: ./deploy.sh [scripts|config|messages|all]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$SCRIPT_DIR/deploy.env"

if [ ! -f "$ENV_FILE" ]; then
    echo "ERROR: $ENV_FILE not found. Copy deploy.env.example to deploy.env and fill in your values."
    exit 1
fi
source "$ENV_FILE"

SERVER="$SERVER_USER@$SERVER_HOST"
TARGET="${1:-all}"

deploy_scripts() {
    echo ">>> Deploying server scripts..."
    scp "$SCRIPTS_DIR"/*.lua "$SERVER:$REMOTE_LUA_DIR/SafeZone_scripts/"
    echo "    Done."
}

deploy_config() {
    echo ">>> Deploying server config..."
    scp "$CONFIG_DIR/server/servertest.ini" "$SERVER:$REMOTE_SERVER_DIR/"
    scp "$CONFIG_DIR/server/servertest_SandboxVars.lua" "$SERVER:$REMOTE_SERVER_DIR/"
    echo "    Done."
}

deploy_messages() {
    echo ">>> Deploying message files..."
    scp "$CONFIG_DIR/SafeZone_event_messages.example.txt" "$SERVER:$REMOTE_LUA_DIR/SafeZone_event_messages.txt"
    scp "$CONFIG_DIR/SafeZone_radio_messages.example.txt" "$SERVER:$REMOTE_LUA_DIR/SafeZone_radio_messages.txt"
    echo "    Done."
}

fix_permissions() {
    echo ">>> Fixing permissions..."
    ssh $SERVER "chown -R $PZ_USER:$PZ_USER /home/$PZ_USER/Zomboid/"
}

case "$TARGET" in
    scripts)  deploy_scripts && fix_permissions ;;
    config)   deploy_config && fix_permissions ;;
    messages) deploy_messages && fix_permissions ;;
    all)      deploy_scripts && deploy_config && deploy_messages && fix_permissions ;;
    *)        echo "Usage: $0 [scripts|config|messages|all]"; exit 1 ;;
esac

echo ">>> Deploy complete!"