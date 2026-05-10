#!/usr/bin/env bash
# npm_offline_install.sh — Build a self-contained offline npm install bundle.
#
# Online side:
#   ./npm_offline_install.sh [options] <pkg>[@version] [<pkg>[@version] ...]
#
# Offline side:
#   tar -xzf npm-offline-bundle.tar.gz
#   cd npm-offline-bundle && ./install.sh
#   npm install --registry=http://localhost:4873 <pkg>
#
# Requires (online): node, npm, curl, tar
# Requires (offline): node, npm, verdaccio (npm i -g verdaccio)

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: npm_offline_install.sh [options] <pkg>[@version] [<pkg>[@version] ...]

Resolves the full dependency tree of the requested packages, downloads every
tarball, and produces a tar.gz bundle plus an offline install.sh that publishes
the tarballs into a local verdaccio registry on the target machine.

Options:
  -o, --output DIR     Output directory (default: ./dist)
  -n, --name NAME      Bundle name (default: npm-offline-bundle)
  -r, --registry URL   Source registry (default: https://registry.npmjs.org)
      --no-verdaccio   Do not bundle a verdaccio runtime (default: bundle it,
                       so install.sh works on hosts without verdaccio installed)
  -h, --help           Show this help

Examples:
  ./npm_offline_install.sh lodash
  ./npm_offline_install.sh react@18 react-dom@18
  ./npm_offline_install.sh -n my-bundle -o /tmp/out @babel/core express
EOF
}

OUTPUT_DIR="./dist"
BUNDLE_NAME="npm-offline-bundle"
REGISTRY="https://registry.npmjs.org"
BUNDLE_VERDACCIO=1
PKGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -o|--output)    OUTPUT_DIR="$2"; shift 2 ;;
    -n|--name)      BUNDLE_NAME="$2"; shift 2 ;;
    -r|--registry)  REGISTRY="$2"; shift 2 ;;
    --no-verdaccio) BUNDLE_VERDACCIO=0; shift ;;
    -h|--help)      usage; exit 0 ;;
    --)             shift; while [[ $# -gt 0 ]]; do PKGS+=("$1"); shift; done ;;
    -*)             echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
    *)              PKGS+=("$1"); shift ;;
  esac
done

if [[ ${#PKGS[@]} -eq 0 ]]; then
  echo "Error: no packages specified." >&2
  usage >&2
  exit 2
fi

for cmd in node npm curl tar; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: required command not found: $cmd" >&2
    exit 1
  fi
done

WORK_DIR="$(mktemp -d -t npm-offline.XXXXXX)"
trap 'rm -rf "$WORK_DIR"' EXIT

# STAGE_DIR is persistent under OUTPUT_DIR so partial downloads survive
# interruptions and can be resumed on rerun. Only resolve/urls are throwaway.
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR_ABS="$(cd "$OUTPUT_DIR" && pwd)"
STAGE_DIR="$OUTPUT_DIR_ABS/$BUNDLE_NAME"
TARBALLS_DIR="$STAGE_DIR/tarballs"
RESOLVE_DIR="$WORK_DIR/resolve"
mkdir -p "$TARBALLS_DIR" "$RESOLVE_DIR"

# Detect curl capabilities once. --retry-all-errors landed in curl 7.71.
CURL_RETRY_ARGS=(--retry 5 --retry-delay 2 --retry-connrefused)
if curl --help all 2>/dev/null | grep -q -- '--retry-all-errors'; then
  CURL_RETRY_ARGS+=(--retry-all-errors)
fi

# Step 1: resolve full dependency tree via a throwaway project + lockfile.
cat > "$RESOLVE_DIR/package.json" <<'JSON'
{
  "name": "_npm_offline_resolver",
  "version": "0.0.0",
  "private": true
}
JSON

echo ">> Resolving dependency tree for: ${PKGS[*]}"
(
  cd "$RESOLVE_DIR"
  npm install \
    --registry="$REGISTRY" \
    --package-lock-only \
    --legacy-peer-deps \
    --no-audit --no-fund --silent \
    "${PKGS[@]}"
)

# Step 2: extract every resolved http(s) tarball URL from the lockfile.
echo ">> Extracting tarball URLs"
node - "$RESOLVE_DIR/package-lock.json" >"$WORK_DIR/urls.txt" <<'NODE'
const fs = require('fs');
const lock = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const urls = new Set();
for (const [path, info] of Object.entries(lock.packages || {})) {
  if (path === '') continue;
  if (info && typeof info.resolved === 'string' && /^https?:\/\//.test(info.resolved)) {
    urls.add(info.resolved);
  }
}
for (const u of urls) console.log(u);
NODE

URL_COUNT="$(wc -l <"$WORK_DIR/urls.txt" | tr -d ' ')"
if [[ "$URL_COUNT" -eq 0 ]]; then
  echo "Error: no tarball URLs resolved (only git/file/link deps?)." >&2
  exit 1
fi

# Step 3: download every tarball. Preserve scope as a subdirectory so
# `@a/util` and `@b/util` cannot collide on identical basenames. Use a
# .part suffix during transfer so a half-downloaded file from a prior aborted
# run will not be mistaken for complete on rerun.
echo ">> Downloading $URL_COUNT tarballs"
i=0
while IFS= read -r url; do
  [[ -n "$url" ]] || continue
  i=$((i + 1))
  fname="$(basename "$url")"
  rel="${url#http*://}"
  rel="${rel#*/}"
  if [[ "$rel" == @*/* ]]; then
    scope="${rel%%/*}"
    out="$TARBALLS_DIR/$scope/$fname"
  else
    out="$TARBALLS_DIR/$fname"
  fi
  mkdir -p "$(dirname "$out")"
  if [[ -f "$out" ]]; then
    printf '  [%d/%d] cache %s\n' "$i" "$URL_COUNT" "${out#"$TARBALLS_DIR/"}"
    continue
  fi
  curl -fSL "${CURL_RETRY_ARGS[@]}" --max-time 120 -o "$out.part" "$url"
  mv "$out.part" "$out"
  printf '  [%d/%d] %s\n' "$i" "$URL_COUNT" "${out#"$TARBALLS_DIR/"}"
done <"$WORK_DIR/urls.txt"

# Sanity: every entry in urls.txt should now resolve to a non-empty file.
missing=0
while IFS= read -r url; do
  [[ -n "$url" ]] || continue
  fname="$(basename "$url")"
  rel="${url#http*://}"; rel="${rel#*/}"
  if [[ "$rel" == @*/* ]]; then
    out="$TARBALLS_DIR/${rel%%/*}/$fname"
  else
    out="$TARBALLS_DIR/$fname"
  fi
  if [[ ! -s "$out" ]]; then
    echo "Error: missing or empty tarball: $out" >&2
    missing=$((missing + 1))
  fi
done <"$WORK_DIR/urls.txt"
[[ "$missing" -eq 0 ]] || { echo "$missing tarball(s) missing; rerun to resume." >&2; exit 1; }

# Step 3.5: bundle a portable verdaccio runtime so install.sh works even when
# the offline host has no verdaccio installed. Independent dependency tree —
# does NOT pollute tarballs/. Skip with --no-verdaccio.
VERDACCIO_BOOTSTRAP_DIR="$STAGE_DIR/verdaccio-bootstrap"
if [[ "$BUNDLE_VERDACCIO" -eq 1 ]]; then
  if [[ -x "$VERDACCIO_BOOTSTRAP_DIR/node_modules/.bin/verdaccio" ]]; then
    echo ">> Reusing cached verdaccio runtime at $VERDACCIO_BOOTSTRAP_DIR"
  else
    echo ">> Bundling verdaccio runtime"
    rm -rf "$VERDACCIO_BOOTSTRAP_DIR"
    mkdir -p "$VERDACCIO_BOOTSTRAP_DIR"
    cat > "$VERDACCIO_BOOTSTRAP_DIR/package.json" <<'JSON'
{
  "name": "_npm_offline_verdaccio_bootstrap",
  "version": "0.0.0",
  "private": true,
  "dependencies": {
    "verdaccio": "^5"
  }
}
JSON
    (
      cd "$VERDACCIO_BOOTSTRAP_DIR"
      npm install \
        --registry="$REGISTRY" \
        --no-audit --no-fund --silent \
        --ignore-scripts \
        --legacy-peer-deps
    )
  fi
else
  rm -rf "$VERDACCIO_BOOTSTRAP_DIR"
fi

# Step 4: write the offline install.sh.
cat > "$STAGE_DIR/install.sh" <<'INSTALL_EOF'
#!/usr/bin/env bash
# Offline npm bundle installer — spins up a local verdaccio registry and
# publishes the bundled tarballs into it. Re-runs are safe (already-published
# versions are skipped).

# Self-heal the invocation: if started as `sh install.sh` (or by a bash that
# entered POSIX mode), process substitution and other bashisms are disabled.
# Re-exec under a real bash with POSIX mode cleared.
if [ -z "${BASH_VERSION:-}" ] || (shopt -qo posix 2>/dev/null); then
  exec env -u POSIXLY_CORRECT bash "$0" "$@"
fi

set -euo pipefail

# Parse install-action flags. Default action is decided after publish:
# interactive prompt on a tty, otherwise skip.
INSTALL_ACTION="ask"
while [[ $# -gt 0 ]]; do
  case "$1" in
    -i|--install)         INSTALL_ACTION="local";  shift ;;
    -G|--install-global)  INSTALL_ACTION="global"; shift ;;
    --no-install)         INSTALL_ACTION="skip";   shift ;;
    -h|--help)
      cat <<EOF
Usage: $(basename "$0") [option]
  -i, --install         install requested packages locally (in CWD) after publish
  -G, --install-global  install requested packages globally after publish
      --no-install      publish only, do not install
  -h, --help            show this help
With no flag: prompt on a tty, skip on non-tty.
EOF
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

HERE="$(cd "$(dirname "$0")" && pwd)"
TARBALLS_DIR="$HERE/tarballs"
REGISTRY_URL="${REGISTRY_URL:-http://localhost:4873}"
VERDACCIO_HOME="${VERDACCIO_HOME:-$HERE/.verdaccio}"
LOG_FILE="$VERDACCIO_HOME/verdaccio.log"
PID_FILE="$VERDACCIO_HOME/verdaccio.pid"

# Top-level packages requested when this bundle was built.
BUNDLE_PKGS=()
if [[ -f "$HERE/bundle.env" ]]; then
  # shellcheck disable=SC1091
  source "$HERE/bundle.env"
fi

for cmd in node npm curl; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "missing: $cmd" >&2; exit 1; }
done

# Prefer a system verdaccio; fall back to the bundled runtime if present.
BUNDLED_VERDACCIO="$HERE/verdaccio-bootstrap/node_modules/.bin/verdaccio"
if command -v verdaccio >/dev/null 2>&1; then
  VERDACCIO_BIN="$(command -v verdaccio)"
  echo ">> Using system verdaccio: $VERDACCIO_BIN"
elif [[ -x "$BUNDLED_VERDACCIO" ]]; then
  VERDACCIO_BIN="$BUNDLED_VERDACCIO"
  echo ">> Using bundled verdaccio: $VERDACCIO_BIN"
else
  cat >&2 <<'MSG'
verdaccio is not installed and this bundle does not contain a bundled runtime.
Either:
  - install verdaccio on this host:  npm install -g verdaccio
  - or rebuild the bundle without --no-verdaccio.
MSG
  exit 1
fi

mkdir -p "$VERDACCIO_HOME"
cat > "$VERDACCIO_HOME/config.yaml" <<'YAML'
storage: ./storage
auth:
  htpasswd:
    file: ./htpasswd
    max_users: -1
uplinks: {}
packages:
  '**':
    access: $all
    publish: $all
    unpublish: $all
log:
  type: stdout
  format: pretty
  level: warn
listen: 0.0.0.0:4873
YAML

# Reuse a running verdaccio if already up.
if curl -fsS "$REGISTRY_URL/-/ping" >/dev/null 2>&1; then
  echo ">> Reusing running registry at $REGISTRY_URL"
else
  echo ">> Starting verdaccio at $REGISTRY_URL"
  (
    cd "$VERDACCIO_HOME"
    nohup "$VERDACCIO_BIN" --config config.yaml >"$LOG_FILE" 2>&1 &
    echo $! > "$PID_FILE"
  )
  cleanup_on_fail() {
    if [[ -f "$PID_FILE" ]]; then
      kill "$(cat "$PID_FILE")" 2>/dev/null || true
      rm -f "$PID_FILE"
    fi
  }
  trap cleanup_on_fail INT TERM
  ok=0
  for _ in $(seq 1 60); do
    if curl -fsS "$REGISTRY_URL/-/ping" >/dev/null 2>&1; then ok=1; break; fi
    sleep 0.5
  done
  if [[ "$ok" -ne 1 ]]; then
    echo "verdaccio did not become ready; see $LOG_FILE" >&2
    cleanup_on_fail
    exit 1
  fi
fi

NPMRC="$HERE/.npmrc.offline"
HOSTPORT="${REGISTRY_URL#http*://}"
cat > "$NPMRC" <<NPMRC_EOF
registry=$REGISTRY_URL
//$HOSTPORT/:_authToken=offlinetoken
always-auth=true
NPMRC_EOF

echo ">> Publishing tarballs"
published=0
skipped=0
failed=0
TARBALL_LIST="$HERE/.tarballs.list"
PUBLISH_LOG="$HERE/.publish.log"
: >"$PUBLISH_LOG"
find "$TARBALLS_DIR" -type f -name '*.tgz' >"$TARBALL_LIST"
while IFS= read -r tgz; do
  [[ -n "$tgz" ]] || continue
  short="${tgz#"$TARBALLS_DIR/"}"
  out=$(npm publish \
       --userconfig "$NPMRC" \
       --registry "$REGISTRY_URL" \
       --tag latest \
       --access public \
       "$tgz" 2>&1) && rc=0 || rc=$?
  if [[ "$rc" -eq 0 ]]; then
    published=$((published + 1))
    echo "  + $short"
  elif echo "$out" | grep -qiE 'EPUBLISHCONFLICT|cannot publish over|already exists|previously published'; then
    skipped=$((skipped + 1))
    echo "  . skip $short (already published)"
  else
    failed=$((failed + 1))
    echo "  ! FAIL $short"
    echo "----- npm publish output for $short -----" >>"$PUBLISH_LOG"
    echo "$out" >>"$PUBLISH_LOG"
    echo >>"$PUBLISH_LOG"
    # Inline a 1-line error hint for immediate visibility.
    echo "$out" | tail -n 3 | sed 's/^/      /'
  fi
done <"$TARBALL_LIST"
rm -f "$TARBALL_LIST"

trap - INT TERM

echo
echo "Done. Published: $published, skipped: $skipped, failed: $failed."
echo "Local registry:  $REGISTRY_URL"
if [[ "$failed" -gt 0 ]]; then
  echo "Publish log:     $PUBLISH_LOG"
  echo "!! $failed tarball(s) failed to publish — see log above for details."
fi

# Decide install action. Flags > tty prompt > non-tty default skip.
if [[ "$INSTALL_ACTION" == "ask" ]]; then
  if [[ ${#BUNDLE_PKGS[@]} -eq 0 ]]; then
    INSTALL_ACTION="skip"
  elif [[ -t 0 && -t 1 ]]; then
    echo
    echo "Top-level packages in this bundle: ${BUNDLE_PKGS[*]}"
    read -r -p "Install now? [l]ocal in $(pwd) / [g]lobal / [s]kip [s]: " ans || ans=""
    case "${ans:-s}" in
      l|L|local)  INSTALL_ACTION="local" ;;
      g|G|global) INSTALL_ACTION="global" ;;
      *)          INSTALL_ACTION="skip" ;;
    esac
  else
    INSTALL_ACTION="skip"
  fi
fi

case "$INSTALL_ACTION" in
  local)
    if [[ ${#BUNDLE_PKGS[@]} -eq 0 ]]; then
      echo "(--install requested but bundle.env has no packages; skipping.)"
    else
      if [[ ! -f package.json ]]; then
        echo ">> No package.json in $(pwd); running 'npm init -y'"
        npm init -y >/dev/null
      fi
      echo ">> npm install --registry=$REGISTRY_URL ${BUNDLE_PKGS[*]}"
      npm install --registry="$REGISTRY_URL" "${BUNDLE_PKGS[@]}"
      echo ">> Installed locally into $(pwd)"
    fi
    ;;
  global)
    if [[ ${#BUNDLE_PKGS[@]} -eq 0 ]]; then
      echo "(--install-global requested but bundle.env has no packages; skipping.)"
    else
      echo ">> npm install -g --registry=$REGISTRY_URL ${BUNDLE_PKGS[*]}"
      npm install -g --registry="$REGISTRY_URL" "${BUNDLE_PKGS[@]}"
      echo ">> Installed globally"
    fi
    ;;
  skip)
    if [[ ${#BUNDLE_PKGS[@]} -gt 0 ]]; then
      echo
      echo "Install manually with one of:"
      echo "  npm install --registry=$REGISTRY_URL ${BUNDLE_PKGS[*]}"
      echo "  npm install -g --registry=$REGISTRY_URL ${BUNDLE_PKGS[*]}"
    fi
    ;;
esac

cat <<DONE

Log file:        $LOG_FILE
PID file:        $PID_FILE

Stop the registry later:
  [[ -f "$PID_FILE" ]] && kill "\$(cat "$PID_FILE")" && rm "$PID_FILE"
DONE
INSTALL_EOF
chmod +x "$STAGE_DIR/install.sh"

# Embed the requested top-level packages so install.sh can offer to install
# exactly what the user asked for. Resolve each user spec (e.g. `react@18`,
# `@scope/pkg@beta`) to an exact `name@version` from the lockfile so
# auto-install does not depend on dist-tags that may not exist on the offline
# verdaccio. Use %q for safe shell quoting.
RESOLVED_PKGS_LIST="$(node - "$RESOLVE_DIR/package-lock.json" "${PKGS[@]}" <<'NODE'
const fs = require('fs');
const lock = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const specs = process.argv.slice(3);
function nameFromSpec(spec) {
  if (spec.startsWith('@')) {
    // @scope/name[@version]
    const slash = spec.indexOf('/');
    const at = spec.indexOf('@', slash);
    return at === -1 ? spec : spec.slice(0, at);
  }
  const at = spec.indexOf('@');
  return at === -1 ? spec : spec.slice(0, at);
}
const out = [];
for (const spec of specs) {
  const name = nameFromSpec(spec);
  const entry = (lock.packages || {})['node_modules/' + name];
  if (entry && entry.version) {
    out.push(name + '@' + entry.version);
  } else {
    // Fall back to the original spec if not found in lock.
    out.push(spec);
  }
}
console.log(out.join('\n'));
NODE
)"
{
  echo "# Original user input: ${PKGS[*]}"
  printf 'BUNDLE_PKGS=('
  while IFS= read -r p; do
    [[ -n "$p" ]] || continue
    printf '%q ' "$p"
  done <<<"$RESOLVED_PKGS_LIST"
  printf ')\n'
} > "$STAGE_DIR/bundle.env"

# Step 5: README.
{
  echo "# npm offline bundle"
  echo
  echo "Built: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "Source registry: $REGISTRY"
  echo "Requested packages: ${PKGS[*]}"
  echo "Tarballs: $URL_COUNT"
  if [[ "$BUNDLE_VERDACCIO" -eq 1 ]]; then
    echo "Bundled verdaccio: yes"
  else
    echo "Bundled verdaccio: no (target host must have verdaccio installed)"
  fi
  echo
  echo "## Layout"
  echo '- `tarballs/` — full transitive closure of npm tarballs'
  echo '- `install.sh` — starts a local verdaccio and publishes the tarballs'
  if [[ "$BUNDLE_VERDACCIO" -eq 1 ]]; then
    echo '- `verdaccio-bootstrap/` — portable verdaccio runtime (used if no system verdaccio)'
  fi
  echo
  echo "## Offline machine usage"
  echo '```bash'
  echo "tar -xzf $BUNDLE_NAME.tar.gz"
  echo "cd $BUNDLE_NAME"
  echo "./install.sh                 # publish + interactive install prompt"
  echo "./install.sh --install       # publish + install locally (no prompt)"
  echo "./install.sh -G              # publish + install globally"
  echo "./install.sh --no-install    # publish only"
  echo '```'
  echo
  echo "## Requirements on the offline machine"
  echo "- node (>= 14) + npm"
  if [[ "$BUNDLE_VERDACCIO" -eq 1 ]]; then
    echo "- verdaccio: bundled — no separate install needed"
  else
    echo "- verdaccio (\`npm install -g verdaccio\`)"
  fi
} > "$STAGE_DIR/README.md"

# Step 6: tar it up. Build to a temp file first because the output file lives
# in the same directory as STAGE_DIR and tar would otherwise see itself.
OUT_FILE="$OUTPUT_DIR_ABS/$BUNDLE_NAME.tar.gz"
TMP_TAR="$WORK_DIR/$BUNDLE_NAME.tar.gz"
( cd "$OUTPUT_DIR_ABS" && tar -czf "$TMP_TAR" "$BUNDLE_NAME" )
mv "$TMP_TAR" "$OUT_FILE"

BUNDLE_BYTES="$(wc -c <"$OUT_FILE" | tr -d ' ')"
echo
echo "Done."
echo "Bundle:    $OUT_FILE"
echo "Size:      $BUNDLE_BYTES bytes"
echo "Tarballs:  $URL_COUNT"
echo "Packages:  ${PKGS[*]}"
if [[ "$BUNDLE_VERDACCIO" -eq 1 ]]; then
  echo "Verdaccio: bundled"
else
  echo "Verdaccio: not bundled (--no-verdaccio)"
fi
