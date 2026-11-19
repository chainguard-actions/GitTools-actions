#!/usr/bin/env bash
# Installs the .NET SDK (the execute action needs a `dotnet` executable on PATH)
# and the GitVersion.Tool dotnet tool into a tool-path directory, the same way
# gitversion/setup does. The tool directory goes into GITVERSION_PATH and PATH.
set -euo pipefail
VERSION="${GITVERSION_VERSION:-6.3.0}"
DOTNET_DIR="${HOME}/.dotnet"
TOOL_DIR="${RUNNER_TEMP:-/tmp}/gitversion-${VERSION}"
INSTALLER="${RUNNER_TEMP:-/tmp}/dotnet-install.sh"

if ! command -v dotnet >/dev/null 2>&1; then
  echo "Installing .NET SDK 8.0 into $DOTNET_DIR"
  curl -fsSL https://dot.net/v1/dotnet-install.sh -o "$INSTALLER"
  bash "$INSTALLER" --channel 8.0 --install-dir "$DOTNET_DIR"
  export PATH="$DOTNET_DIR:$PATH"
  export DOTNET_ROOT="$DOTNET_DIR"
  echo "DOTNET_ROOT=$DOTNET_DIR" >> "$GITHUB_ENV"
  echo "$DOTNET_DIR" >> "$GITHUB_PATH"
fi

export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
export DOTNET_CLI_TELEMETRY_OPTOUT=true
export DOTNET_NOLOGO=true
dotnet --info | head -n 20

rm -rf "$TOOL_DIR"
mkdir -p "$TOOL_DIR"
echo "Installing GitVersion.Tool $VERSION into $TOOL_DIR"
dotnet tool install GitVersion.Tool --version "$VERSION" --tool-path "$TOOL_DIR"
"$TOOL_DIR/dotnet-gitversion" /version

echo "GITVERSION_PATH=$TOOL_DIR" >> "$GITHUB_ENV"
echo "DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1" >> "$GITHUB_ENV"
echo "$TOOL_DIR" >> "$GITHUB_PATH"
