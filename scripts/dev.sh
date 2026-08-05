#!/usr/bin/env bash
#
# Run the app against the local backend from a terminal.
#
# The IDE does the same thing through .vscode/launch.json, whose preLaunchTask
# runs the same dev-env.sh. Keeping one script for both is the point: a fix
# applied in a terminal that does not reach the IDE launch path is how
# "Connection refused" kept coming back.
#
# Usage:  ./scripts/dev.sh [extra flutter run args]

set -euo pipefail
cd "$(dirname "$0")/.."

./scripts/dev-env.sh

DEFINES=(--dart-define-from-file=mapbox.json)
[ -f .dev-env.json ] && DEFINES+=(--dart-define-from-file=.dev-env.json)

echo
exec flutter run "${DEFINES[@]}" "$@"
