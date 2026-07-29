#!/usr/bin/env bash
# Build Flutter web (release) and deploy to Firebase Hosting.
# Run from repo root: bash scripts/firebase_deploy_web.sh
#
# Required / optional environment:
#   FIREBASE_ACCOUNT     Google account for Firebase CLI (firebase login:use).
#                        Required unless firebase CLI already has an active account
#                        that can be detected — set explicitly for CI/scripts.
#   FIREBASE_PROJECT     Firebase / GCP project ID for deploy --project
#                        default: oral-check-assist (maintainer hosting; not required for local runs)
#   GCLOUD_ACCOUNT       Expected active gcloud account (see verify below)
#                        default: same as FIREBASE_ACCOUNT
#   GCLOUD_PROJECT       Expected gcloud config project (informational check)
#                        default: same as FIREBASE_PROJECT
#   APP_VERSION_TOKEN    Version token embedded into main.dart.js for web
#                        update detection. Defaults to pubspec.yaml version.
#   GCLOUD_APPLY_CONFIG  default: 1 — run `gcloud config set account/project` when they
#                        differ from GCLOUD_* (mutates global gcloud config). Set to 0 to
#                        only verify and fail / warn without changing gcloud config.
#   GCLOUD_STRICT_PROJECT if set to 1, exit with error when gcloud project is set
#                        but differs from GCLOUD_PROJECT (default: warn only)
#
# Flags:
#   --skip-clean        Skip flutter clean (faster repeat deploys)
#   --skip-gcloud-check Skip active-account / project alignment checks

set -e
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

echo "=== verify model assets ==="
bash scripts/verify_model_assets.sh

FIREBASE_PROJECT="${FIREBASE_PROJECT:-oral-check-assist}"
GCLOUD_APPLY_CONFIG="${GCLOUD_APPLY_CONFIG:-1}"
SKIP_CLEAN=0
SKIP_GCLOUD_CHECK=0

for arg in "$@"; do
  case "$arg" in
    --skip-clean) SKIP_CLEAN=1 ;;
    --skip-gcloud-check) SKIP_GCLOUD_CHECK=1 ;;
    *)
      echo "Unknown option: $arg" >&2
      echo "Usage: FIREBASE_ACCOUNT=you@example.com bash scripts/firebase_deploy_web.sh [--skip-clean] [--skip-gcloud-check]" >&2
      exit 1
      ;;
  esac
done

if [[ -z "${FIREBASE_ACCOUNT:-}" ]]; then
  if command -v firebase >/dev/null 2>&1; then
    FIREBASE_ACCOUNT="$(firebase login:list 2>/dev/null | sed -n 's/.*logged in as \([^ ]*\).*/\1/p' | head -n1 || true)"
  fi
fi
if [[ -z "${FIREBASE_ACCOUNT:-}" ]]; then
  echo "error: set FIREBASE_ACCOUNT to the Google account used with Firebase CLI." >&2
  echo "Example: FIREBASE_ACCOUNT=you@example.com bash scripts/firebase_deploy_web.sh" >&2
  exit 1
fi

GCLOUD_ACCOUNT="${GCLOUD_ACCOUNT:-$FIREBASE_ACCOUNT}"
GCLOUD_PROJECT="${GCLOUD_PROJECT:-$FIREBASE_PROJECT}"

verify_gcloud_context() {
  if [[ "$SKIP_GCLOUD_CHECK" -eq 1 ]]; then
    echo "=== gcloud check skipped (--skip-gcloud-check) ==="
    return 0
  fi
  if ! command -v gcloud >/dev/null 2>&1; then
    echo "=== gcloud not in PATH (skipping account/project verification) ==="
    return 0
  fi

  echo "=== gcloud context (expected account: $GCLOUD_ACCOUNT, project: $GCLOUD_PROJECT) ==="
  gcloud auth list

  local active_account
  active_account="$(gcloud auth list --filter=status:ACTIVE --format='value(account)' 2>/dev/null | head -n1)"
  if [[ -z "$active_account" ]]; then
    echo "error: no active gcloud account. Run: gcloud auth login" >&2
    exit 1
  fi
  if [[ "$active_account" != "$GCLOUD_ACCOUNT" ]]; then
    if [[ "$GCLOUD_APPLY_CONFIG" != "0" ]]; then
      echo "=== gcloud config set account $GCLOUD_ACCOUNT (GCLOUD_APPLY_CONFIG default/on) ==="
      gcloud config set account "$GCLOUD_ACCOUNT"
      active_account="$GCLOUD_ACCOUNT"
    else
      echo "error: gcloud active account is '$active_account' but this deploy expects '$GCLOUD_ACCOUNT'." >&2
      echo "Fix:  gcloud config set account $GCLOUD_ACCOUNT" >&2
      echo "Or:   GCLOUD_ACCOUNT='$active_account' bash scripts/firebase_deploy_web.sh   (override)" >&2
      echo "Or:   unset GCLOUD_APPLY_CONFIG or omit it (default applies account). GCLOUD_APPLY_CONFIG=0 skips applying." >&2
      exit 1
    fi
  fi

  local cfg_project
  cfg_project="$(gcloud config get-value project 2>/dev/null | tr -d '\n' || true)"
  if [[ -z "$cfg_project" || "$cfg_project" == "(unset)" ]]; then
    echo "gcloud project is unset (OK for Firebase if you use --project; optional: gcloud config set project $GCLOUD_PROJECT)"
  elif [[ "$cfg_project" != "$GCLOUD_PROJECT" ]]; then
    if [[ "$GCLOUD_APPLY_CONFIG" != "0" ]]; then
      echo "=== gcloud config set project $GCLOUD_PROJECT (GCLOUD_APPLY_CONFIG default/on) ==="
      gcloud config set project "$GCLOUD_PROJECT"
    elif [[ "${GCLOUD_STRICT_PROJECT:-0}" == "1" ]]; then
      echo "error: gcloud project is '$cfg_project' but this script expects '$GCLOUD_PROJECT' (GCLOUD_STRICT_PROJECT=1)." >&2
      echo "Fix:  gcloud config set project $GCLOUD_PROJECT" >&2
      exit 1
    else
      echo "warning: gcloud project is '$cfg_project' (expected '$GCLOUD_PROJECT'). Deploy still uses FIREBASE_PROJECT via firebase --project." >&2
    fi
  else
    echo "gcloud project matches: $cfg_project"
  fi
}

verify_gcloud_context

if [[ "$SKIP_CLEAN" -eq 0 ]]; then
  echo "=== flutter clean ==="
  flutter clean
fi

echo "=== flutter pub get ==="
flutter pub get

APP_VERSION_TOKEN="${APP_VERSION_TOKEN:-$(python3 - <<'PY'
from pathlib import Path
import re

match = re.search(r'^version:\s*(\S+)\s*$', Path('pubspec.yaml').read_text(), re.MULTILINE)
if not match:
    raise SystemExit('pubspec.yaml version not found')
print(match.group(1))
PY
)}"

echo "=== flutter build web --release (APP_VERSION_TOKEN=$APP_VERSION_TOKEN) ==="
flutter build web --release --dart-define=APP_VERSION_TOKEN="$APP_VERSION_TOKEN"

echo "=== verify build/web ==="
if [[ ! -f build/web/index.html ]]; then
  echo "error: build/web/index.html missing; build failed?" >&2
  exit 1
fi
ls -lh build/web/

echo "=== firebase login (current accounts) ==="
firebase login:list || true

echo "=== firebase login:use $FIREBASE_ACCOUNT ==="
set +e
login_use_out=$(firebase login:use "$FIREBASE_ACCOUNT" 2>&1)
login_use_ec=$?
set -e
printf '%s\n' "$login_use_out"
if [[ "$login_use_ec" -ne 0 ]]; then
  if printf '%s\n' "$login_use_out" | grep -q 'Already using account'; then
    echo "(already active for this directory — continuing)"
  else
    exit "$login_use_ec"
  fi
fi

echo "=== firebase deploy hosting ($FIREBASE_PROJECT) ==="
firebase deploy --only hosting --project "$FIREBASE_PROJECT"

echo "=== done ==="
