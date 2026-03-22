#!/usr/bin/env bash
# scripts/setup-auth.sh
# meeting-iOS
#
# Sets up the authentication environment for development and CI.
# Validates configuration, installs required tools, and runs sanity checks.
#
# Usage:
#   ./scripts/setup-auth.sh [--ci] [--verbose]

set -euo pipefail

# ── Colour helpers ─────────────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

info()    { echo -e "${BLUE}[setup-auth]${RESET} $*"; }
success() { echo -e "${GREEN}[setup-auth] ✓${RESET} $*"; }
warn()    { echo -e "${YELLOW}[setup-auth] ⚠${RESET} $*"; }
error()   { echo -e "${RED}[setup-auth] ✗${RESET} $*" >&2; }

# ── Argument parsing ──────────────────────────────────────────────────────────

CI_MODE=false
VERBOSE=false

for arg in "$@"; do
  case "$arg" in
    --ci)      CI_MODE=true ;;
    --verbose) VERBOSE=true ;;
    --help|-h)
      echo "Usage: $0 [--ci] [--verbose]"
      exit 0
      ;;
    *)
      error "Unknown argument: $arg"
      exit 1
      ;;
  esac
done

# ── Repository root ───────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
APP_CONFIG="${REPO_ROOT}/LeanIOS/appConfig.json"

$VERBOSE && info "Repository root: ${REPO_ROOT}"

# ── Check appConfig.json ──────────────────────────────────────────────────────

info "Checking appConfig.json…"

if [[ ! -f "${APP_CONFIG}" ]]; then
  error "appConfig.json not found at ${APP_CONFIG}"
  exit 1
fi

if ! python3 -m json.tool "${APP_CONFIG}" > /dev/null 2>&1; then
  error "appConfig.json is not valid JSON"
  exit 1
fi

success "appConfig.json is valid JSON"

# ── Validate auth keys in appConfig.json ──────────────────────────────────────

info "Validating auth configuration…"

LOGIN_URL=$(python3 -c "
import json, sys
with open('${APP_CONFIG}') as f:
    cfg = json.load(f)
val = cfg.get('login', {}).get('loginDetectionURL', '') or ''
print(val)
" 2>/dev/null || true)

if [[ -z "${LOGIN_URL}" ]]; then
  warn "loginDetectionURL is not set — login detection will be disabled"
else
  success "loginDetectionURL: ${LOGIN_URL}"
fi

SIGNUP_URL=$(python3 -c "
import json, sys
with open('${APP_CONFIG}') as f:
    cfg = json.load(f)
val = cfg.get('login', {}).get('signupURL', '') or ''
print(val)
" 2>/dev/null || true)

if [[ -z "${SIGNUP_URL}" ]]; then
  warn "signupURL is not set — signup sheet will fall back to initialURL"
else
  success "signupURL: ${SIGNUP_URL}"
fi

# ── Run Ruby auth-config validation ──────────────────────────────────────────

AUTH_CONFIG_SCRIPT="${REPO_ROOT}/build/auth-config.rb"

if command -v ruby > /dev/null 2>&1 && [[ -f "${AUTH_CONFIG_SCRIPT}" ]]; then
  info "Running Ruby auth-config validation…"
  ruby "${AUTH_CONFIG_SCRIPT}" && success "Ruby auth-config validation passed"
else
  $VERBOSE && warn "ruby not found or auth-config.rb missing — skipping Ruby validation"
fi

# ── Check for required auth HTML assets ──────────────────────────────────────

info "Checking auth HTML assets…"
ASSETS=(
  "${REPO_ROOT}/LeanIOS/login.html"
  "${REPO_ROOT}/LeanIOS/signup.html"
  "${REPO_ROOT}/LeanIOS/pricing.html"
  "${REPO_ROOT}/LeanIOS/auth-bridge.js"
)

ALL_ASSETS_OK=true
for asset in "${ASSETS[@]}"; do
  if [[ -f "${asset}" ]]; then
    $VERBOSE && success "Found: $(basename "${asset}")"
  else
    warn "Missing auth asset: ${asset}"
    ALL_ASSETS_OK=false
  fi
done

$ALL_ASSETS_OK && success "All auth HTML assets present"

# ── CI-specific checks ────────────────────────────────────────────────────────

if $CI_MODE; then
  info "Running CI-specific checks…"

  # Ensure no sensitive credentials appear in auth files.
  SENSITIVE_PATTERNS=(
    'password\s*='
    'secret\s*='
    'api_key\s*='
    'ANTHROPIC_API_KEY'
  )

  FOUND_SENSITIVE=false
  for pattern in "${SENSITIVE_PATTERNS[@]}"; do
    if grep -rqiE "${pattern}" \
          "${REPO_ROOT}/LeanIOS/auth-bridge.js" \
          "${REPO_ROOT}/LeanIOS/login.html" \
          "${REPO_ROOT}/LeanIOS/signup.html" \
          "${REPO_ROOT}/LeanIOS/pricing.html" \
          2>/dev/null; then
      error "Possible sensitive value matched pattern '${pattern}' in auth assets"
      FOUND_SENSITIVE=true
    fi
  done

  if $FOUND_SENSITIVE; then
    $CI_MODE && exit 1
  else
    success "No sensitive credentials found in auth assets"
  fi
fi

# ── Done ──────────────────────────────────────────────────────────────────────

echo ""
success "Auth environment setup complete."
