#!/usr/bin/env bash
# Run E2E integration tests on Chrome.
# - Starts chromedriver (version-matched to Chrome)
# - Waits until ready
# - Runs flutter drive (use -v or --verbose for verbose output)
# - Stops chromedriver on exit

set -e

# Capture pipeline exit code correctly
set -o pipefail

VERBOSE=false
for arg in "$@"; do
  [[ "$arg" == "-v" || "$arg" == "--verbose" ]] && VERBOSE=true && break
done

PORT=4444
CHROMEDRIVER_PID=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cleanup() {
  if [[ -n "$CHROMEDRIVER_PID" ]] && kill -0 "$CHROMEDRIVER_PID" 2>/dev/null; then
    echo ""
    echo "Stopping chromedriver (PID $CHROMEDRIVER_PID)..."
    kill -9 "$CHROMEDRIVER_PID" 2>/dev/null || true
    echo "Chromedriver stopped."
  fi
}

trap cleanup EXIT

echo "=== E2E Test Runner (Chrome PWA) ==="
echo ""

# 1. Kill any existing chromedriver on port
echo "[1/4] Ensuring port $PORT is free..."
if lsof -ti ":$PORT" >/dev/null 2>&1; then
  lsof -ti ":$PORT" | xargs kill -9 2>/dev/null || true
  sleep 2
fi

# 2. Detect Chrome version and start matching chromedriver
CHROME_VER=""
if [[ -x "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" ]]; then
  CHROME_VER=$(/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1)
fi
CHROME_MAJOR="${CHROME_VER%%.*}"
if [[ -z "$CHROME_MAJOR" ]]; then
  CHROME_MAJOR="145"
  echo "Could not detect Chrome version, defaulting to chromedriver@$CHROME_MAJOR"
fi
echo "[2/4] Starting chromedriver@$CHROME_MAJOR (for Chrome $CHROME_VER) on port $PORT..."
cd "$PROJECT_ROOT"
npx --yes "chromedriver@$CHROME_MAJOR" --port="$PORT" > /tmp/chromedriver.log 2>&1 &
CHROMEDRIVER_PID=$!

# 3. Wait until chromedriver is ready
echo "[3/4] Waiting for chromedriver to be ready..."
for i in {1..30}; do
  if curl -s "http://localhost:$PORT/status" >/dev/null 2>&1; then
    echo "Chromedriver ready."
    break
  fi
  if ! kill -0 "$CHROMEDRIVER_PID" 2>/dev/null; then
    echo "Chromedriver failed to start. Log:"
    cat /tmp/chromedriver.log
    exit 1
  fi
  sleep 0.5
done

if ! curl -s "http://localhost:$PORT/status" >/dev/null 2>&1; then
  echo "Chromedriver did not become ready in time."
  cat /tmp/chromedriver.log
  exit 1
fi

# 4. Run E2E tests
echo "[4/4] Running E2E tests${VERBOSE:+ (verbose)}..."
echo ""
echo "----------------------------------------"

FLUTTER_ARGS=(
  --driver=test_driver/integration_test.dart
  --target=integration_test/screening_e2e_test.dart
  -d web-server
  --browser-name=chrome
)
[[ "$VERBOSE" == true ]] && FLUTTER_ARGS+=(-v)

TEST_EXIT=0
flutter drive "${FLUTTER_ARGS[@]}" \
  2>&1 | tee /tmp/e2e_test_output.txt || TEST_EXIT=$?

echo ""
echo "----------------------------------------"
echo ""

if [[ $TEST_EXIT -eq 0 ]]; then
  echo "✅ All E2E tests passed."
else
  echo "❌ E2E tests failed (exit code $TEST_EXIT)."
  echo ""
  if grep -iE "fail|error|exception" /tmp/e2e_test_output.txt 2>/dev/null | tail -20; then
    echo ""
  fi
  echo "Last 50 lines of output:"
  tail -50 /tmp/e2e_test_output.txt
fi

exit $TEST_EXIT
