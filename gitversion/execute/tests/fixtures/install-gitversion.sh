#!/usr/bin/env bash
# Installs the native GitVersion binary plus thin wrappers so the GitTools
# execute action (which expects the .NET SDK + dotnet-gitversion tool) can run
# on a runner image without the .NET SDK.
set -euo pipefail

VERSION="${GITVERSION_VERSION:-6.3.0}"
ROOT="${RUNNER_TEMP:-/tmp}"
REAL_DIR="$ROOT/gitversion-real"
DIR="$ROOT/gitversion"
DOTNET_DIR="$ROOT/fake-dotnet"
mkdir -p "$REAL_DIR" "$DIR" "$DOTNET_DIR"

git fetch --unshallow 2>/dev/null || true

curl -fsSL -o "$ROOT/gv.tar.gz" \
  "https://github.com/GitTools/GitVersion/releases/download/${VERSION}/gitversion-linux-x64-${VERSION}.tar.gz"
tar -xzf "$ROOT/gv.tar.gz" -C "$REAL_DIR"
BIN="$(find "$REAL_DIR" -type f -iname 'gitversion' | head -n1)"
[ -n "$BIN" ] || { echo "gitversion binary not found"; ls -laR "$REAL_DIR"; exit 1; }
chmod +x "$BIN"

# Wrapper that drops dotnet-host-only flags (e.g. --roll-forward Major)
cat > "$DIR/dotnet-gitversion" <<EOF
#!/usr/bin/env bash
args=()
skip=0
for a in "\$@"; do
  if [ "\$skip" = 1 ]; then skip=0; continue; fi
  case "\$a" in
    --roll-forward) skip=1; continue ;;
    --roll-forward=*) continue ;;
  esac
  args+=("\$a")
done
exec "$BIN" "\${args[@]}"
EOF
chmod +x "$DIR/dotnet-gitversion"
cp "$DIR/dotnet-gitversion" "$DIR/gitversion"

# Fake dotnet host: forwards "dotnet <tool> args" to the wrapper.
cat > "$DOTNET_DIR/dotnet" <<EOF
#!/usr/bin/env bash
args=()
skip=0
for a in "\$@"; do
  if [ "\$skip" = 1 ]; then skip=0; continue; fi
  case "\$a" in
    --roll-forward) skip=1; continue ;;
    --roll-forward=*) continue ;;
  esac
  args+=("\$a")
done
set -- "\${args[@]}"
case "\${1:-}" in
  --version) echo "8.0.100"; exit 0 ;;
  --info|--list-sdks|--list-runtimes) echo "8.0.100 [$DOTNET_DIR/sdk]"; exit 0 ;;
  *.dll|*gitversion*) shift; exec "$DIR/dotnet-gitversion" "\$@" ;;
  "") exit 0 ;;
  *)
    if [ -x "\$1" ]; then f="\$1"; shift; exec "\$f" "\$@"; fi
    exit 0 ;;
esac
EOF
chmod +x "$DOTNET_DIR/dotnet"

"$DIR/dotnet-gitversion" /version
"$DOTNET_DIR/dotnet" --version

echo "$DIR" >> "$GITHUB_PATH"
echo "$DOTNET_DIR" >> "$GITHUB_PATH"
echo "GITVERSION_PATH=$DIR" >> "$GITHUB_ENV"
echo "DOTNET_ROOT=$DOTNET_DIR" >> "$GITHUB_ENV"
