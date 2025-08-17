#!/bin/bash

# OxlVPN - Simple, Free CLI VPN Tool
# Made for devs and cybersec enthusiasts who just want things to work

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/src/main.sh"

main "$@"