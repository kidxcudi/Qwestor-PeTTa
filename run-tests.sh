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
#                  EXCLUDES the evaluation tests (main/test/sessions_test.metta
#                  and main/test/sessions_test_smoke.metta) -- see --eval below.
#
#   --verbose      Full output mode. Prints everything including PeTTa's
#                  internal transpiler output, Prolog goals, and all println!
#                  debug lines. Useful for deep debugging.
#
#   --full         Full output, transpiler stripped. Prints every println!/
#                  DEBUG/result line (the actual execution trace) but removes
#                  the PeTTa transpiler noise — the "--> metta runnable -->"
#                  and "--> metta function -->" blocks along with their
#                  "--> prolog goal -->" / "--> prolog clause -->" translations.
#                  Use this when you want the full trace without wading through
#                  the transpiled Prolog.
#
#   --clean        Clean output mode. Strips transpiler noise (same as --full)
#                  and then narrows down further to only pass/fail lines,
#                  assertion mismatches, errors, and quoted println! output.
#                  Useful when you want to trace values without full verbosity.
#
#   --file <path>  Single file mode. Runs only the specified test file instead
#                  of discovering all test files. Path can be relative or absolute.
#                  Naming an evaluation test file directly here always runs it,
#                  regardless of --eval/--eval-smoke/--eval-full.
#                  Example: ./run-tests.sh --file operators/test/decision_test.metta
#
#   --eval         Also run BOTH evaluation tests (smoke + full) alongside the
#                  regular suite. These make real Gemini API calls (network,
#                  API cost, and much slower -- the full one runs 136 turns).
#                  Shorthand for --eval-smoke --eval-full.
#
#   --eval-smoke   Also run main/test/sessions_test_smoke.metta (10-turn eval,
#                  real Gemini calls) alongside the regular suite.
#
#   --eval-full    Also run main/test/sessions_test.metta (136-turn eval,
#                  real Gemini calls) alongside the regular suite.
#
# EXAMPLES:
#   ./run-tests.sh                                        # run all tests
#   ./run-tests.sh --verbose                              # run all, full output
#   ./run-tests.sh --full                                 # run all, full trace, no transpiler
#   ./run-tests.sh --clean                                # run all, clean output
#   ./run-tests.sh --file operators/test/routing_test.metta  # run one file
#   ./run-tests.sh --file operators/test/routing_test.metta --clean  # one file, clean
#   ./run-tests.sh --eval                                 # regular suite + both eval tests
#   ./run-tests.sh --eval-smoke --clean                   # regular suite + smoke eval, clean output
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
FULL=false
SINGLE_FILE=""
EVAL_SMOKE=false
EVAL_FULL=false

for arg in "$@"; do
    case "$arg" in
        --verbose)   VERBOSE=true ;;
        --full)      FULL=true ;;
        --clean)     CLEAN=true ;;
        --file)      shift; SINGLE_FILE="$1" ;;
        --eval)      EVAL_SMOKE=true; EVAL_FULL=true ;;
        --eval-smoke) EVAL_SMOKE=true ;;
        --eval-full)  EVAL_FULL=true ;;
    esac
done

# The evaluation tests make real Gemini API calls -- slow, costs API
# usage, and sessions_test.metta alone runs 136 turns. Opt-in only
# (--eval / --eval-smoke / --eval-full), never picked up by the
# default bulk discovery below.
EVAL_SMOKE_FILE="$PROJECT_ROOT/main/test/sessions_test_smoke.metta"
EVAL_FULL_FILE="$PROJECT_ROOT/main/test/sessions_test.metta"

# Strips ANSI color codes and deletes every PeTTa transpiler block:
#   "--> metta runnable -->" ... up through the closing "^^^^^^^^^^" line
#   "--> metta function -->" ... up through the closing "^^^^^^^^^^" line
# (this covers the "--> prolog goal -->" / "--> prolog clause -->" sections
# too, since those live inside those same blocks, right before the caret line)
strip_transpiler() {
    sed 's/\x1b\[[0-9;]*m//g' | \
    sed '/^--> metta runnable/,/^\^\+$/d' | \
    sed '/^--> metta function -->/,/^\^\+$/d' | \
    sed '/^true$/d'
}

filter_output() {
    if $VERBOSE; then
        cat
    elif $FULL; then
        strip_transpiler
    elif $CLEAN; then
        strip_transpiler | \
        grep -E '(✅ Passed:|❌ Failed:|is .*, should .*\.|^ERROR:|^".*")'
    else
        sed 's/\x1b\[[0-9;]*m//g' | \
        grep -E '(✅ Passed:|❌ Failed:|is .*, should .*\. ❌|^ERROR:)'
    fi
}

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
SKIPPED_EVAL=()
for f in "${ALL_FILES[@]}"; do
    if [[ "$f" == "$EVAL_SMOKE_FILE" ]]; then
        if $EVAL_SMOKE; then
            TEST_FILES+=("$f")
        else
            SKIPPED_EVAL+=("$f")
        fi
    elif [[ "$f" == "$EVAL_FULL_FILE" ]]; then
        if $EVAL_FULL; then
            TEST_FILES+=("$f")
        else
            SKIPPED_EVAL+=("$f")
        fi
    else
        TEST_FILES+=("$f")
    fi
done

if [ ${#TEST_FILES[@]} -eq 0 ]; then
    echo "⚠️  No test files found."
    exit 0
fi

echo "Found ${#TEST_FILES[@]} test file(s)."
if [ ${#SKIPPED_EVAL[@]} -gt 0 ]; then
    echo "⏭️  Skipped ${#SKIPPED_EVAL[@]} evaluation test(s) (real Gemini calls, opt-in only):"
    for f in "${SKIPPED_EVAL[@]}"; do
        echo "     - ${f#$PROJECT_ROOT/}  (use --eval, or --eval-smoke/--eval-full)"
    done
fi

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