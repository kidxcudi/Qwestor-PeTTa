#!/bin/bash
#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# run-tests.sh — MeTTa/PeTTa test runner for Qwestor-PeTTa
# ─────────────────────────────────────────────────────────────────────────────
#
# USAGE:
#   ./run-tests.sh [OPTIONS]
#
# OPTIONS:
#   (none)         Default mode. Runs all test files found under */test/*.metta
#                  and prints only pass/fail results and mismatches.
#
#   --verbose      Full output mode. Prints everything including PeTTa's
#                  internal transpiler output, Prolog goals, and all println!
#                  debug lines. Useful for deep debugging.
#
#   --clean        Clean output mode. Strips transpiler noise and Prolog goals,
#                  but still shows debug println! lines alongside pass/fail.
#                  Useful when you want to trace values without full verbosity.
#
#   --file <path>  Single file mode. Runs only the specified test file instead
#                  of discovering all test files. Path can be relative or absolute.
#                  Example: ./run-tests.sh --file operators/test/decision_test.metta
#
# EXAMPLES:
#   ./run-tests.sh                                        # run all tests
#   ./run-tests.sh --verbose                              # run all, full output
#   ./run-tests.sh --clean                                # run all, clean output
#   ./run-tests.sh --file operators/test/routing_test.metta  # run one file
#   ./run-tests.sh --file operators/test/routing_test.metta --clean  # one file, clean
# ─────────────────────────────────────────────────────────────────────────────

# Source bashrc to get the petta function
source ~/.bashrc 2>/dev/null

echo "🚀 Starting PeTTa-Qwestor Transpiled Tests..."

# ─────────────────────────────────────────────
# CONFIG
# ─────────────────────────────────────────────
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "📁 Project root: $PROJECT_ROOT"

# ─────────────────────────────────────────────
# FLAGS
# ─────────────────────────────────────────────
VERBOSE=false
CLEAN=false
SINGLE_FILE=""

for arg in "$@"; do
    case "$arg" in
        --verbose) VERBOSE=true ;;
        --clean)   CLEAN=true ;;
        --file)    shift; SINGLE_FILE="$1" ;;
    esac
done

filter_output() {
    if $VERBOSE; then
        cat
    elif $CLEAN; then
        sed 's/\x1b\[[0-9;]*m//g' | \
        sed '/^--> metta runnable/,/^\^\+$/d' | \
        sed '/^--> metta function -->/,/^\^\+$/d' | \
        sed '/^true$/d' | \
        grep -E '(✅ Passed:|❌ Failed:|is .*, should .*\.|^ERROR:|^".*")'
    else
        sed 's/\x1b\[[0-9;]*m//g' | \
        grep -E '(✅ Passed:|❌ Failed:|is .*, should .*\. ❌|^ERROR:)'
    fi
}

# ─────────────────────────────────────────────
# Run one test file from its own directory
# ─────────────────────────────────────────────
# ─────────────────────────────────────────────
# Run one test file from its own directory
# ─────────────────────────────────────────────
run_test() {
    local abs_file="$1"
    local file_dir file_name TEMP OUTPUT

    file_dir="$(dirname "$abs_file")"
    file_name="$(basename "$abs_file")"
    TEMP=$(mktemp "$file_dir/petta_tmp_XXXXXX.metta")

    cat "$abs_file" > "$TEMP"

    # Capture filtered output to a variable
    OUTPUT=$( (cd "$file_dir" && petta "$(basename "$TEMP")" 2>&1) | filter_output )
    
    # Print the output so you can see it in the terminal
    if [[ -n "$OUTPUT" ]]; then
        echo "$OUTPUT"
    fi

    rm -f "$TEMP"

    # Explicitly fail if the text contains a mismatch indicator
    if echo "$OUTPUT" | grep -q "❌"; then
        return 1
    else
        return 0
    fi
}

# ─────────────────────────────────────────────
# --file mode
# ─────────────────────────────────────────────
if [[ -n "$SINGLE_FILE" ]]; then
    ABS_FILE="$(cd "$(dirname "$SINGLE_FILE")" && pwd)/$(basename "$SINGLE_FILE")"
    if [[ ! -f "$ABS_FILE" ]]; then
        echo "❌ File not found: $SINGLE_FILE"
        exit 1
    fi
    echo "▶ Running: $SINGLE_FILE"
    run_test "$ABS_FILE"
    EXIT=$?
    [[ $EXIT -eq 0 ]] && echo "✅ Passed" || echo "❌ Failed (exit $EXIT)"
    exit $EXIT
fi

# ─────────────────────────────────────────────
# Collect test files
# ─────────────────────────────────────────────
mapfile -t ALL_FILES < <(find "$PROJECT_ROOT" -path "*/test/*.metta" | sort -u)

TEST_FILES=()
for f in "${ALL_FILES[@]}"; do
        TEST_FILES+=("$f")
done

if [ ${#TEST_FILES[@]} -eq 0 ]; then
    echo "⚠️  No test files found."
    exit 0
fi

echo "Found ${#TEST_FILES[@]} test file(s)."

FAILED=0
FAILED_FILES=()
COUNT=0

# ─────────────────────────────────────────────
# Run all tests
# ─────────────────────────────────────────────
for file in "${TEST_FILES[@]}"; do
    DISPLAY="${file#$PROJECT_ROOT/}"
    echo "================================================"
    echo "▶ $DISPLAY"
    echo "------------------------------------------------"

    run_test "$file"
    EXIT=$?

    if [[ $EXIT -eq 0 ]]; then
        echo "✅ Passed: $DISPLAY"
    else
        echo "❌ Failed: $DISPLAY (exit $EXIT)"
        FAILED=$((FAILED + 1))
        FAILED_FILES+=("$DISPLAY")
    fi

    COUNT=$((COUNT + 1))
done

# ─────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────
echo "================================================"
echo "Ran $COUNT file(s). Passed: $((COUNT - FAILED)). Failed: $FAILED."

if [ $FAILED -ne 0 ]; then
    echo ""
    echo "Failed files:"
    for f in "${FAILED_FILES[@]}"; do
        echo "  ✗ $f"
    done
    exit 1
fi

echo "✨ All tests passed!"