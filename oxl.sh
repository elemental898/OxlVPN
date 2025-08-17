#!/bin/bash

# OxlVPN - Simple, Free CLI VPN Tool
# Made for devs and cybersec enthusiasts who just want things to work

# Note: Removed 'set -e' to prevent auto-exit on function returns

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/src/main.sh"

main "$@"