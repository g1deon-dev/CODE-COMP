#!/bin/bash

# ============================================================
#  11 Days Coding Challenge — Automated Checker v3 (FAIR)
#  Tests: Todo List | Student Record | Inventory | Grade Calc
# ============================================================
#
#  FAIRNESS PRINCIPLES:
#   - Tests only what the rules explicitly require
#   - Exit option auto-detected (not assumed to be 0)
#   - Search option auto-detected (not assumed to be 3)
#   - TC26: uses detected search option, never hardcoded 3
#   - TC28: padded blank newlines flush any extra add fields
#   - "Doesn't crash" = exit code only, no content check
#   - Optional features never counted as FAIL
#   - Advisories shown separately, never scored
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

SOURCE="solution.c"
BINARY="./solution_test_bin"
PASS=0
FAIL=0
TOTAL=0
WARNINGS=()

# ── Helpers ──────────────────────────────────────────────────

log_pass()    { echo -e "  ${GREEN}[PASS]${RESET} $1"; ((PASS++)); ((TOTAL++)); }
log_fail()    { echo -e "  ${RED}[FAIL]${RESET} $1"; ((FAIL++)); ((TOTAL++)); }
log_section() { echo -e "\n${CYAN}${BOLD}▶ $1${RESET}"; }

run_with_input() {
    echo -e "$1" | timeout 5s "$BINARY" 2>&1
}

contains() {
    echo "$1" | grep -qi "$2"
}

# Auto-detect exit menu option (e.g. "0. Exit" -> 0)
detect_exit_option() {
    local opt
    opt=$(grep -ioE "[0-9]+[.):] *(exit|quit|bye|end|stop)" "$SOURCE" \
        | grep -oE "^[0-9]+" | head -1)
    echo "${opt:-0}"
}

# Auto-detect search menu option (e.g. "3. Search" -> 3)
detect_search_option() {
    local opt
    opt=$(grep -ioE "[0-9]+[.):] *(search|find|lookup)" "$SOURCE" \
        | grep -oE "^[0-9]+" | head -1)
    echo "${opt:-3}"
}

EXIT_OPT=""
SEARCH_OPT=""

# ── Detect System Type ────────────────────────────────────────
detect_system() {
    local src
    src=$(tr '[:upper:]' '[:lower:]' < "$SOURCE")
    if echo "$src" | grep -qE "\btodo\b|\btask\b"; then
        echo "todolist"
    elif echo "$src" | grep -qE "\bstudent\b|\benrollment\b"; then
        echo "student"
    elif echo "$src" | grep -qE "\binventor|\bstock\b|\bproduct\b|\bquantity\b"; then
        echo "inventory"
    elif echo "$src" | grep -qE "\bgrade\b|\bscore\b|\bsubject\b|\bgwa\b|\bgpa\b"; then
        echo "grade"
    else
        echo "unknown"
    fi
}

# ── PRE-FLIGHT (TC01-TC05) ────────────────────────────────────
preflight() {
    log_section "PRE-FLIGHT CHECKS"

    # Guard: abort silently before any scored test if file is missing entirely
    if [[ ! -f "$SOURCE" ]]; then
        echo -e "${RED}Error: $SOURCE not found. Place solution.c in the same folder as this script.${RESET}"
        exit 1
    fi

    # TC01: source file contains actual C code (has at least one #include)
    # Checking file existence is not a test — the script already exits above if missing.
    # This catches empty stubs, placeholder files, or non-C content.
    if grep -q "#include" "$SOURCE"; then
        log_pass "TC01: Source file contains C code (#include directive found)"
    else
        log_fail "TC01: No #include found — file may not be valid C source"
    fi

    if [[ -s "$SOURCE" ]]; then
        log_pass "TC02: Source file is non-empty"
    else
        log_fail "TC02: Source file is empty"
        exit 1
    fi

    gcc -o "$BINARY" "$SOURCE" -lm 2>/tmp/compile_err
    if [[ $? -eq 0 ]]; then
        log_pass "TC03: Compiles successfully with gcc"
    else
        log_fail "TC03: Compilation failed"
        echo -e "${RED}--- Compiler errors ---${RESET}"
        cat /tmp/compile_err
        echo -e "${RED}Cannot run runtime tests.${RESET}"
        exit 1
    fi

    EXIT_OPT=$(detect_exit_option)
    SEARCH_OPT=$(detect_search_option)

    BAD=0
    while IFS= read -r h; do
        case "$h" in
            stdio.h|stdlib.h|string.h|math.h|ctype.h|time.h|stdbool.h|\
            limits.h|float.h|stdint.h|assert.h|errno.h|stdarg.h|stddef.h|\
            inttypes.h|iso646.h|signal.h|setjmp.h|locale.h|wchar.h|wctype.h)
                ;;
            *)
                log_fail "TC04: Non-standard/external header used: <$h>"
                BAD=1
                ;;
        esac
    done < <(grep -oP '#include\s*<\K[^>]+' "$SOURCE")
    [[ $BAD -eq 0 ]] && log_pass "TC04: Only C Standard Library headers used"

    if [[ "$SOURCE" == *.c ]]; then
        log_pass "TC05: File submitted as .c source"
    else
        log_fail "TC05: File is not a .c source file"
    fi
}

# ── STATIC ANALYSIS (TC06-TC15) ──────────────────────────────
static_checks() {
    log_section "STATIC CODE ANALYSIS"

    grep -qE "int\s+main\s*\(" "$SOURCE" \
        && log_pass "TC06: main() function present" \
        || log_fail "TC06: main() function not found"

    grep -qE "\bwhile\b|\bdo\b|\bfor\b" "$SOURCE" \
        && log_pass "TC07: Loop construct present (required for continuous menu)" \
        || log_fail "TC07: No loop found — menu must run continuously until exit"

    grep -qE "\bscanf\b|\bfgets\b|\bgetchar\b" "$SOURCE" \
        && log_pass "TC08: Standard input function used (scanf/fgets/getchar)" \
        || log_fail "TC08: No stdin input function found (need scanf/fgets/getchar)"

    grep -qE "\bprintf\b|\bputs\b|\bputchar\b" "$SOURCE" \
        && log_pass "TC09: Standard output function used (printf/puts)" \
        || log_fail "TC09: No stdout function found (need printf/puts)"

    grep -qE "\bstruct\b|\btypedef\b|\[[0-9]+\]|\[MAX\b|\[SIZE\b|\[N\b|\[LIMIT\b|\[CAP\b|\[max\b|\[size\b" "$SOURCE" \
        && log_pass "TC10: Data structure or array for record storage detected" \
        || log_fail "TC10: No data structure or array found for storing records"

    if grep -qE "#define\s+\w+\s+[1-9][0-9]{2,}" "$SOURCE" || \
       grep -qE "\[[1-9][0-9]{2,}\]" "$SOURCE"; then
        log_pass "TC11: Record capacity of >= 100 defined"
    else
        log_fail "TC11: Could not confirm capacity >= 100 (use #define MAX 100 or arr[100])"
    fi

    grep -qiE "\bexit\b|\bquit\b|\bbye\b" "$SOURCE" \
        && log_pass "TC12: Exit/Quit option present in source" \
        || log_fail "TC12: No exit/quit keyword found — program must have an exit option"

    grep -qiE "\badd\b|\binsert\b|\bnew\b|\bcreate\b|\bappend\b" "$SOURCE" \
        && log_pass "TC13: Add/Insert record feature detected" \
        || log_fail "TC13: No add/insert feature found (required)"

    grep -qiE "\bview\b|\bdisplay\b|\blist\b|\bshow\b|\bprint.*all\b|\ball.*record\b" "$SOURCE" \
        && log_pass "TC14: View/Display records feature detected" \
        || log_fail "TC14: No view/display feature found (required)"

    grep -qiE "\bsearch\b|\bfind\b|\blookup\b|\bstrcmp\b|\bstrstr\b" "$SOURCE" \
        && log_pass "TC15: Search/Find feature detected" \
        || log_fail "TC15: No search feature found (required)"
}

# ── RUNTIME GENERIC (TC16-TC22) ──────────────────────────────
runtime_generic() {
    log_section "RUNTIME — CORE MENU BEHAVIOR"

    OUT=$(run_with_input "$EXIT_OPT")
    [[ -n "$OUT" ]] \
        && log_pass "TC16: Program produces output on startup" \
        || log_fail "TC16: Program produced no output at all"

    OUT=$(run_with_input "$EXIT_OPT")
    if echo "$OUT" | grep -qE "[1-9][.)]\s*\w" || contains "$OUT" "menu\|option\|choice\|select"; then
        log_pass "TC17: Numbered menu options displayed"
    else
        log_fail "TC17: No numbered menu options found in output"
    fi

    run_with_input "$EXIT_OPT" > /dev/null 2>&1
    EC=$?
    if [[ $EC -lt 2 ]]; then
        log_pass "TC18: Program exits cleanly (exit code $EC)"
    elif [[ $EC -eq 124 ]]; then
        log_fail "TC18: Program timed out — exit option detected as '$EXIT_OPT', verify it is correct"
    else
        log_fail "TC18: Program exited with unexpected error code $EC"
    fi

    OUT=$(run_with_input "9999\n$EXIT_OPT"); EC=$?
    [[ $EC -lt 124 ]] \
        && log_pass "TC19: Invalid menu choice (9999) does not crash" \
        || log_fail "TC19: Program crashed or hung on invalid menu choice"

    OUT=$(run_with_input "9999\n$EXIT_OPT")
    contains "$OUT" "invalid\|error\|wrong\|try again\|unknown\|not.*valid\|please\|choose\|option" \
        && log_pass "TC20: Invalid menu choice shows error/feedback message" \
        || log_fail "TC20: No feedback shown for invalid menu choice (must handle gracefully)"

    OUT=$(run_with_input "9999\n$EXIT_OPT")
    COUNT=$(echo "$OUT" | grep -cEi "[1-9][.)]\s*\w|menu|option|choice")
    [[ $COUNT -ge 2 ]] \
        && log_pass "TC21: Menu re-displays after invalid input (continuous loop confirmed)" \
        || log_fail "TC21: Menu does not re-display — program may not loop continuously"

    OUT=$(run_with_input "hello\n$EXIT_OPT"); EC=$?
    [[ $EC -lt 124 ]] \
        && log_pass "TC22: Non-numeric menu input does not crash" \
        || log_fail "TC22: Program crashed on non-numeric menu input"
}

# ── SYSTEM-SPECIFIC TESTS (TC23-TC34) ────────────────────────
runtime_specific() {
    SYSTEM=$(detect_system)
    echo -e "\n${YELLOW}${BOLD}  Detected System Type : ${SYSTEM^^}${RESET}"
    echo -e "  ${YELLOW}Exit option detected  : ${EXIT_OPT}${RESET}"
    echo -e "  ${YELLOW}Search option detected: ${SEARCH_OPT}${RESET}"

    case "$SYSTEM" in
        todolist)   test_todolist ;;
        student)    test_student ;;
        inventory)  test_inventory ;;
        grade)      test_grade ;;
        *)
            log_section "SYSTEM-SPECIFIC TESTS (Undetected — Generic CRUD)"
            echo -e "  ${YELLOW}System type could not be auto-detected. Running generic tests.${RESET}"
            test_generic_crud
            ;;
    esac
}

# ── GENERIC CRUD FALLBACK ─────────────────────────────────────
test_generic_crud() {
    log_section "GENERIC FUNCTIONAL TESTS (TC23-TC34)"
    local E="$EXIT_OPT"
    local S="$SEARCH_OPT"

    # TC23
    OUT=$(printf "1\nTestRecord\n\n\n\n%s\n" "$E" | timeout 5s "$BINARY" 2>&1); EC=$?
    [[ $EC -lt 124 ]] && log_pass "TC23: Add operation does not crash" || log_fail "TC23: Add operation crashed/timed out"

    # TC24
    OUT=$(printf "1\nTestRecord\n\n\n\n2\n%s\n" "$E" | timeout 5s "$BINARY" 2>&1)
    contains "$OUT" "TestRecord\|record\|list\|data\|view\|result" \
        && log_pass "TC24: View shows data after add" \
        || log_fail "TC24: View shows no data after add"

    # TC25
    OUT=$(printf "1\nTestRecord\n\n\n\n%s\nTestRecord\n%s\n" "$S" "$E" | timeout 5s "$BINARY" 2>&1); EC=$?
    [[ $EC -lt 124 ]] && log_pass "TC25: Search does not crash" || log_fail "TC25: Search crashed"

    # TC26 — uses detected search option on empty list, no assumed menu number
    OUT=$(printf "%s\nZZZNoSuchRecord\n%s\n" "$S" "$E" | timeout 5s "$BINARY" 2>&1)
    contains "$OUT" "not found\|no result\|empty\|none\|0 record\|does not\|no match" \
        && log_pass "TC26: Search for missing record shows appropriate message (search option: $S)" \
        || log_fail "TC26: No message for a missing record (search option used: $S)"

    # TC27
    OUT=$(run_with_input "2\n$E"); EC=$?
    [[ $EC -lt 124 ]] && log_pass "TC27: View empty list does not crash" || log_fail "TC27: View empty list crashed"

    # TC28 — padded blank newlines flush any extra add fields, safe for all systems
    OUT=$(printf "1\nAlphaRecord\n\n\n\n1\nBetaRecord\n\n\n\n2\n%s\n" "$E" | timeout 5s "$BINARY" 2>&1)
    contains "$OUT" "Alpha\|Beta\|record\|list\|data" \
        && log_pass "TC28: Multiple records visible in view after adding two" \
        || log_fail "TC28: Records not visible after adding two"

    # TC29
    OUT=$(run_with_input "4\n$E"); EC=$?
    [[ $EC -lt 124 ]] && log_pass "TC29: Computation option does not crash" || log_fail "TC29: Computation option crashed"

    # TC30
    OUT=$(run_with_input "5\n999\n$E"); EC=$?
    [[ $EC -lt 124 ]] && log_pass "TC30: Invalid ID for operation does not crash" || log_fail "TC30: Invalid ID caused crash"

    # TC31
    OUT=$(printf "1\nFindMe\n\n\n\n%s\nFindMe\n%s\n" "$S" "$E" | timeout 5s "$BINARY" 2>&1)
    contains "$OUT" "FindMe\|found\|result\|match\|record" \
        && log_pass "TC31: Search returns a matching record" \
        || log_fail "TC31: Search did not return expected match"

    # TC32
    OUT=$(run_with_input "\-1\n$E"); EC=$?
    [[ $EC -lt 124 ]] && log_pass "TC32: Negative menu choice does not crash" || log_fail "TC32: Negative menu choice crashed"

    # TC33
    OUT=$(run_with_input "2.5\n$E"); EC=$?
    [[ $EC -lt 124 ]] && log_pass "TC33: Decimal menu choice does not crash" || log_fail "TC33: Decimal menu choice crashed"

    # TC34
    OUT=$(printf "1\nLongNameAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\n\n\n\n%s\n" "$E" | timeout 5s "$BINARY" 2>&1); EC=$?
    [[ $EC -lt 124 ]] && log_pass "TC34: Long name input does not crash" || log_fail "TC34: Long name caused crash"
}

# ── TODO LIST ─────────────────────────────────────────────────
test_todolist() {
    log_section "TODO LIST — FUNCTIONAL TESTS (TC23-TC34)"
    local E="$EXIT_OPT"
    local S="$SEARCH_OPT"

    # TC23 — padded blank lines flush any extra fields (status, priority, due date, etc.)
    OUT=$(printf "1\nBuy groceries\n\n\n\n%s\n" "$E" | timeout 5s "$BINARY" 2>&1); EC=$?
    [[ $EC -lt 124 ]] && log_pass "TC23: Add task does not crash" || log_fail "TC23: Add task crashed/timed out"

    # TC24 — padded blank lines after name before triggering view
    OUT=$(printf "1\nBuy groceries\n\n\n\n2\n%s\n" "$E" | timeout 5s "$BINARY" 2>&1)
    contains "$OUT" "Buy groceries\|task\|record\|list\|item" \
        && log_pass "TC24: View all shows the added task" \
        || log_fail "TC24: Added task not visible in view all"

    # TC25 — uses detected search option, padded blank lines after add
    OUT=$(printf "1\nBuy groceries\n\n\n\n%s\nBuy\n%s\n" "$S" "$E" | timeout 5s "$BINARY" 2>&1)
    contains "$OUT" "Buy\|found\|result\|match\|task" \
        && log_pass "TC25: Search returns a result for an existing task (search option: $S)" \
        || log_fail "TC25: Search did not find existing task (search option used: $S)"

    # TC26 — uses detected search option on empty list, never assumes option 3
    OUT=$(printf "%s\nZZZNoSuchTask999\n%s\n" "$S" "$E" | timeout 5s "$BINARY" 2>&1)
    contains "$OUT" "not found\|no result\|empty\|none\|no task\|does not\|no match\|0" \
        && log_pass "TC26: Search for missing task shows appropriate message (search option: $S)" \
        || log_fail "TC26: No message shown for missing task (search option used: $S)"

    # TC27
    OUT=$(run_with_input "2\n$E"); EC=$?
    [[ $EC -lt 124 ]] \
        && log_pass "TC27: View empty task list does not crash" \
        || log_fail "TC27: Viewing empty list crashed"

    # TC28 — each add padded with blank lines so extra prompts (status/priority/date)
    # don't consume the second task name as a field value
    OUT=$(printf "1\nTask Alpha\n\n\n\n1\nTask Beta\n\n\n\n2\n%s\n" "$E" | timeout 5s "$BINARY" 2>&1)
    contains "$OUT" "Alpha" && contains "$OUT" "Beta" \
        && log_pass "TC28: Both tasks visible in view after adding two" \
        || log_fail "TC28: Not all tasks visible — extra field prompts may have consumed task names"

    # TC29
    OUT=$(printf "1\nSample Task\n\n\n\n4\n%s\n" "$E" | timeout 5s "$BINARY" 2>&1); EC=$?
    [[ $EC -lt 124 ]] \
        && log_pass "TC29: Computation option does not crash" \
        || log_fail "TC29: Computation option crashed"

    # TC30
    OUT=$(printf "1\nTask1\n\n\n\n1\nTask2\n\n\n\n4\n%s\n" "$E" | timeout 5s "$BINARY" 2>&1)
    contains "$OUT" "[0-9]\|total\|count\|number\|statistic\|record" \
        && log_pass "TC30: Computation produces visible output" \
        || log_fail "TC30: Computation output not visible — must display a result"

    # TC31
    OUT=$(printf "1\nTemp Task\n\n\n\n5\n1\n%s\n" "$E" | timeout 5s "$BINARY" 2>&1); EC=$?
    [[ $EC -lt 124 ]] \
        && log_pass "TC31: Delete task option does not crash" \
        || log_fail "TC31: Delete task crashed"

    # TC32
    OUT=$(run_with_input "5\n9999\n$E"); EC=$?
    [[ $EC -lt 124 ]] \
        && log_pass "TC32: Invalid task ID for delete does not crash" \
        || log_fail "TC32: Invalid task ID caused crash"

    # TC33
    OUT=$(run_with_input "\-1\n$E"); EC=$?
    [[ $EC -lt 124 ]] \
        && log_pass "TC33: Negative menu choice does not crash" \
        || log_fail "TC33: Negative menu choice caused crash"

    # TC34
    LONGNAME="ThisIsAVeryLongTaskNameForTestingPurposes1234"
    OUT=$(printf "1\n%s\n\n\n\n%s\n" "$LONGNAME" "$E" | timeout 5s "$BINARY" 2>&1); EC=$?
    [[ $EC -lt 124 ]] \
        && log_pass "TC34: Long task name does not crash" \
        || log_fail "TC34: Long task name caused crash/timeout"
}

# ── STUDENT RECORD ────────────────────────────────────────────
test_student() {
    log_section "STUDENT RECORD SYSTEM — FUNCTIONAL TESTS (TC23-TC34)"
    local E="$EXIT_OPT"
    local S="$SEARCH_OPT"

    # TC23
    OUT=$(run_with_input "1\nJuan Dela Cruz\n2021-0001\n$E"); EC=$?
    [[ $EC -lt 124 ]] && log_pass "TC23: Add student does not crash" || log_fail "TC23: Add student crashed/timed out"

    # TC24
    OUT=$(run_with_input "1\nJuan Dela Cruz\n2021-0001\n2\n$E")
    contains "$OUT" "Juan\|Dela Cruz\|2021-0001\|student\|record" \
        && log_pass "TC24: View all shows added student" \
        || log_fail "TC24: Added student not visible in view"

    # TC25 — uses detected search option
    OUT=$(printf "1\nJuan Dela Cruz\n2021-0001\n%s\nJuan\n%s\n" "$S" "$E" | timeout 5s "$BINARY" 2>&1)
    contains "$OUT" "Juan\|found\|result\|match\|record" \
        && log_pass "TC25: Search returns result for existing student (search option: $S)" \
        || log_fail "TC25: Search did not find existing student (search option used: $S)"

    # TC26 — uses detected search option on empty list, never hardcoded 3
    OUT=$(printf "%s\nZZZFakeName999\n%s\n" "$S" "$E" | timeout 5s "$BINARY" 2>&1)
    contains "$OUT" "not found\|no result\|empty\|none\|does not\|no match\|0" \
        && log_pass "TC26: Search for missing student shows appropriate message (search option: $S)" \
        || log_fail "TC26: No message shown for missing student (search option used: $S)"

    # TC27
    OUT=$(run_with_input "2\n$E"); EC=$?
    [[ $EC -lt 124 ]] && log_pass "TC27: View empty student list does not crash" || log_fail "TC27: View empty list crashed"

    # TC28 — padded blank lines for safety even though student add is 2-field
    OUT=$(printf "1\nAnna Santos\n2021-0002\n\n\n1\nCarlos Reyes\n2021-0003\n\n\n2\n%s\n" "$E" | timeout 5s "$BINARY" 2>&1)
    contains "$OUT" "Anna\|Santos" && contains "$OUT" "Carlos\|Reyes" \
        && log_pass "TC28: Both students visible in view after adding two" \
        || log_fail "TC28: Not all students shown after adding two"

    # TC29
    OUT=$(run_with_input "1\nTest Student\n2021-0099\n4\n$E"); EC=$?
    [[ $EC -lt 124 ]] \
        && log_pass "TC29: Computation option does not crash" \
        || log_fail "TC29: Computation option crashed"

    # TC30
    OUT=$(run_with_input "1\nStudentA\n2021-001\n1\nStudentB\n2021-002\n4\n$E")
    contains "$OUT" "[0-9]\|average\|total\|gpa\|gwa\|mean\|count\|record\|compute" \
        && log_pass "TC30: Computation produces visible output" \
        || log_fail "TC30: Computation shows no recognizable result"

    # TC31
    OUT=$(run_with_input "1\nTemp Student\n2021-0099\n5\n2021-0099\n$E"); EC=$?
    [[ $EC -lt 124 ]] && log_pass "TC31: Delete student does not crash" || log_fail "TC31: Delete student crashed"

    # TC32
    OUT=$(run_with_input "5\n9999-9999\n$E"); EC=$?
    [[ $EC -lt 124 ]] && log_pass "TC32: Invalid student ID for delete does not crash" || log_fail "TC32: Invalid ID caused crash"

    # TC33
    OUT=$(run_with_input "\-5\n$E"); EC=$?
    [[ $EC -lt 124 ]] && log_pass "TC33: Negative menu choice does not crash" || log_fail "TC33: Negative menu choice crashed"

    # TC34
    LONGNAME="Maria Cristina dela Fuente-Villanueva"
    OUT=$(run_with_input "1\n$LONGNAME\n2021-LONG\n$E"); EC=$?
    [[ $EC -lt 124 ]] && log_pass "TC34: Long student name does not crash" || log_fail "TC34: Long student name caused crash"
}

# ── INVENTORY ─────────────────────────────────────────────────
test_inventory() {
    log_section "INVENTORY SYSTEM — FUNCTIONAL TESTS (TC23-TC34)"
    local E="$EXIT_OPT"
    local S="$SEARCH_OPT"

    # TC23 — padded blank lines handle unknown field order (name/qty/price or name/price/qty)
    OUT=$(printf "1\nApple\n50\n25.50\n\n\n%s\n" "$E" | timeout 5s "$BINARY" 2>&1); EC=$?
    [[ $EC -lt 124 ]] && log_pass "TC23: Add item does not crash" || log_fail "TC23: Add item crashed/timed out"

    # TC24
    OUT=$(printf "1\nApple\n50\n25.50\n\n\n2\n%s\n" "$E" | timeout 5s "$BINARY" 2>&1)
    contains "$OUT" "Apple\|item\|product\|inventory\|record\|stock" \
        && log_pass "TC24: View all shows added item" \
        || log_fail "TC24: Added item not visible in view"

    # TC25 — uses detected search option
    OUT=$(printf "1\nApple\n50\n25.50\n\n\n%s\nApple\n%s\n" "$S" "$E" | timeout 5s "$BINARY" 2>&1)
    contains "$OUT" "Apple\|found\|result\|match\|item" \
        && log_pass "TC25: Search returns result for existing item (search option: $S)" \
        || log_fail "TC25: Search did not find existing item (search option used: $S)"

    # TC26 — uses detected search option on empty list, never hardcoded 3
    OUT=$(printf "%s\nZZZNoSuchItem999\n%s\n" "$S" "$E" | timeout 5s "$BINARY" 2>&1)
    contains "$OUT" "not found\|no result\|empty\|none\|does not\|no match\|0" \
        && log_pass "TC26: Search for missing item shows appropriate message (search option: $S)" \
        || log_fail "TC26: No message shown for missing item (search option used: $S)"

    # TC27
    OUT=$(run_with_input "2\n$E"); EC=$?
    [[ $EC -lt 124 ]] && log_pass "TC27: View empty inventory does not crash" || log_fail "TC27: View empty inventory crashed"

    # TC28 — padded blank lines handle unknown field order across both adds
    OUT=$(printf "1\nApple\n50\n25.50\n\n\n1\nBanana\n30\n10.00\n\n\n2\n%s\n" "$E" | timeout 5s "$BINARY" 2>&1)
    contains "$OUT" "Apple" && contains "$OUT" "Banana" \
        && log_pass "TC28: Both items visible in view after adding two" \
        || log_fail "TC28: Not all items shown — field order mismatch may have consumed item names"

    # TC29
    OUT=$(printf "1\nApple\n50\n25.50\n\n\n4\n%s\n" "$E" | timeout 5s "$BINARY" 2>&1); EC=$?
    [[ $EC -lt 124 ]] && log_pass "TC29: Computation option does not crash" || log_fail "TC29: Computation option crashed"

    # TC30
    OUT=$(printf "1\nApple\n10\n100\n\n\n1\nBanana\n20\n50\n\n\n4\n%s\n" "$E" | timeout 5s "$BINARY" 2>&1)
    contains "$OUT" "[0-9]\|total\|value\|worth\|sum\|inventory\|compute\|average" \
        && log_pass "TC30: Computation produces visible output" \
        || log_fail "TC30: Computation shows no recognizable result"

    # TC31
    OUT=$(printf "1\nApple\n50\n25.50\n\n\n5\nApple\n30\n%s\n" "$E" | timeout 5s "$BINARY" 2>&1); EC=$?
    [[ $EC -lt 124 ]] && log_pass "TC31: Update item does not crash" || log_fail "TC31: Update item crashed"

    # TC32
    OUT=$(printf "1\nTempItem\n5\n10.00\n\n\n6\nTempItem\n%s\n" "$E" | timeout 5s "$BINARY" 2>&1); EC=$?
    [[ $EC -lt 124 ]] && log_pass "TC32: Delete item does not crash" || log_fail "TC32: Delete item crashed"

    # TC33
    OUT=$(run_with_input "\-1\n$E"); EC=$?
    [[ $EC -lt 124 ]] && log_pass "TC33: Negative menu choice does not crash" || log_fail "TC33: Negative menu choice crashed"

    # TC34
    OUT=$(printf "1\nZeroItem\n0\n10.00\n\n\n%s\n" "$E" | timeout 5s "$BINARY" 2>&1); EC=$?
    [[ $EC -lt 124 ]] && log_pass "TC34: Zero quantity input does not crash" || log_fail "TC34: Zero quantity input caused crash"
}

# ── GRADE CALCULATOR ──────────────────────────────────────────
test_grade() {
    log_section "GRADE CALCULATOR — FUNCTIONAL TESTS (TC23-TC34)"
    local E="$EXIT_OPT"
    local S="$SEARCH_OPT"

    # TC23 — padded blank lines flush any extra fields (units, semester, etc.)
    OUT=$(printf "1\nMathematics\n90\n\n\n%s\n" "$E" | timeout 5s "$BINARY" 2>&1); EC=$?
    [[ $EC -lt 124 ]] && log_pass "TC23: Add subject/grade does not crash" || log_fail "TC23: Add subject crashed/timed out"

    # TC24
    OUT=$(printf "1\nMathematics\n90\n\n\n2\n%s\n" "$E" | timeout 5s "$BINARY" 2>&1)
    contains "$OUT" "Mathematics\|Math\|subject\|grade\|record\|list" \
        && log_pass "TC24: View all shows added subject" \
        || log_fail "TC24: Added subject not visible in view"

    # TC25 — uses detected search option
    OUT=$(printf "1\nMathematics\n90\n\n\n%s\nMath\n%s\n" "$S" "$E" | timeout 5s "$BINARY" 2>&1)
    contains "$OUT" "Math\|found\|result\|match\|subject\|grade" \
        && log_pass "TC25: Search returns result for existing subject (search option: $S)" \
        || log_fail "TC25: Search did not find existing subject (search option used: $S)"

    # TC26 — uses detected search option on empty list, never hardcoded 3
    OUT=$(printf "%s\nZZZFakeSubject999\n%s\n" "$S" "$E" | timeout 5s "$BINARY" 2>&1)
    contains "$OUT" "not found\|no result\|empty\|none\|does not\|no match\|0" \
        && log_pass "TC26: Search for missing subject shows appropriate message (search option: $S)" \
        || log_fail "TC26: No message shown for missing subject (search option used: $S)"

    # TC27
    OUT=$(run_with_input "2\n$E"); EC=$?
    [[ $EC -lt 124 ]] && log_pass "TC27: View empty grade list does not crash" || log_fail "TC27: View empty list crashed"

    # TC28 — padded blank lines after each add so extra field prompts
    # don't consume "Science" as a grade value or other field
    OUT=$(printf "1\nMath\n90\n\n\n1\nScience\n85\n\n\n2\n%s\n" "$E" | timeout 5s "$BINARY" 2>&1)
    contains "$OUT" "Math" && contains "$OUT" "Science" \
        && log_pass "TC28: Both subjects visible in view after adding two" \
        || log_fail "TC28: Not all subjects shown — extra field prompts may have consumed subject names"

    # TC29
    OUT=$(printf "1\nMath\n90\n\n\n1\nScience\n85\n\n\n4\n%s\n" "$E" | timeout 5s "$BINARY" 2>&1); EC=$?
    [[ $EC -lt 124 ]] && log_pass "TC29: Computation (average/GWA) does not crash" || log_fail "TC29: Computation crashed"

    # TC30
    OUT=$(printf "1\nMath\n90\n\n\n1\nScience\n80\n\n\n4\n%s\n" "$E" | timeout 5s "$BINARY" 2>&1)
    contains "$OUT" "[0-9][0-9]\|average\|gwa\|gpa\|mean\|total\|result\|compute" \
        && log_pass "TC30: Computation produces visible output" \
        || log_fail "TC30: Computation shows no recognizable output"

    # TC31
    OUT=$(printf "1\nTempSubject\n70\n\n\n5\n1\n%s\n" "$E" | timeout 5s "$BINARY" 2>&1); EC=$?
    [[ $EC -lt 124 ]] && log_pass "TC31: Delete subject does not crash" || log_fail "TC31: Delete subject crashed"

    # TC32
    OUT=$(run_with_input "5\n9999\n$E"); EC=$?
    [[ $EC -lt 124 ]] && log_pass "TC32: Invalid subject ID for delete does not crash" || log_fail "TC32: Invalid ID caused crash"

    # TC33
    OUT=$(printf "1\nMath\n110\n\n\n%s\n" "$E" | timeout 5s "$BINARY" 2>&1); EC=$?
    [[ $EC -lt 124 ]] && log_pass "TC33: Grade > 100 handled without crash" || log_fail "TC33: Grade > 100 caused crash"

    # TC34
    OUT=$(printf "1\nMath\n-5\n\n\n%s\n" "$E" | timeout 5s "$BINARY" 2>&1); EC=$?
    [[ $EC -lt 124 ]] && log_pass "TC34: Negative grade handled without crash" || log_fail "TC34: Negative grade caused crash"
}

# ── STRESS & CAPACITY TESTS (TC35-TC44) ──────────────────────
stress_tests() {
    log_section "STRESS & CAPACITY TESTS"
    local E="$EXIT_OPT"
    local S="$SEARCH_OPT"

    # TC35 — padded blank lines per record, system-agnostic
    INPUT=""
    for i in $(seq 1 10); do INPUT+="1\nRecord${i}\n\n\n\n"; done
    INPUT+="2\n${E}"
    OUT=$(echo -e "$INPUT" | timeout 15s "$BINARY" 2>&1); EC=$?
    [[ $EC -lt 124 ]] \
        && log_pass "TC35: 10 records added and viewed without crash" \
        || log_fail "TC35: Crashed or timed out adding 10 records"

    # TC36
    contains "$OUT" "Record\|record\|item\|student\|task\|subject\|data\|list" \
        && log_pass "TC36: View all with 10 records produces output" \
        || log_fail "TC36: View all with 10 records shows nothing"

    # TC37 — uses detected search option
    INPUT=""
    for i in $(seq 1 10); do INPUT+="1\nRecord${i}\n\n\n\n"; done
    INPUT+="${S}\nRecord5\n${E}"
    OUT=$(echo -e "$INPUT" | timeout 15s "$BINARY" 2>&1); EC=$?
    [[ $EC -lt 124 ]] \
        && log_pass "TC37: Search among 10 records does not crash (search option: $S)" \
        || log_fail "TC37: Search after 10 records crashed/timed out (search option used: $S)"

    # TC38 — apostrophe, padded blank lines, no assumed field count
    OUT=$(printf "1\nO'Brien\n\n\n\n\n%s\n" "$E" | timeout 5s "$BINARY" 2>&1); EC=$?
    [[ $EC -lt 124 ]] \
        && log_pass "TC38: Apostrophe in input does not crash" \
        || log_fail "TC38: Apostrophe in input caused crash"

    # TC39 — long name, padded blank lines, no assumed field count
    LONG50="AAAAAAAAAABBBBBBBBBBCCCCCCCCCCDDDDDDDDDDEEEEEEEEE1"
    OUT=$(printf "1\n%s\n\n\n\n\n%s\n" "$LONG50" "$E" | timeout 5s "$BINARY" 2>&1); EC=$?
    [[ $EC -lt 124 ]] \
        && log_pass "TC39: 50-character name does not crash" \
        || log_fail "TC39: 50-character name caused crash"

    # TC40
    OUT=$(printf ' \n \n%s\n' "$E" | timeout 5s "$BINARY" 2>&1); EC=$?
    [[ $EC -lt 124 ]] \
        && log_pass "TC40: Whitespace-only menu input does not crash or hang" \
        || log_fail "TC40: Whitespace input caused crash or infinite loop"

    # TC41
    OUT=$(run_with_input "2\n2\n2\n$E"); EC=$?
    [[ $EC -lt 124 ]] \
        && log_pass "TC41: Repeated view selections do not crash" \
        || log_fail "TC41: Repeated view selections caused crash"

    # TC42
    OUT=$(printf "1\nBigNum\n99999\n9999.99\n\n\n%s\n" "$E" | timeout 5s "$BINARY" 2>&1); EC=$?
    [[ $EC -lt 124 ]] \
        && log_pass "TC42: Large number as data value does not crash" \
        || log_fail "TC42: Large data value caused crash"

    # TC43
    OUT=$(run_with_input "2.5\n$E"); EC=$?
    [[ $EC -lt 124 ]] \
        && log_pass "TC43: Decimal menu choice does not crash" \
        || log_fail "TC43: Decimal menu choice caused crash"

    # TC44 — uses detected search option in sequence
    OUT=$(printf "1\nSeqTest\n10\n\n\n2\n%s\nSeqTest\n4\n%s\n" "$S" "$E" | timeout 5s "$BINARY" 2>&1); EC=$?
    [[ $EC -lt 124 ]] \
        && log_pass "TC44: Add → View → Search → Compute in sequence does not crash" \
        || log_fail "TC44: Sequential operations caused crash/timeout"
}

# ── CODE STRUCTURE CHECKS (TC45-TC50) ────────────────────────
structure_checks() {
    log_section "CODE STRUCTURE CHECKS"
    local S="$SEARCH_OPT"
    local E="$EXIT_OPT"
    SYSTEM=$(detect_system)

    # TC45
    FUNC_COUNT=$(grep -cE "^(void|int|float|double|char|bool|long)\s+[a-zA-Z_][a-zA-Z0-9_]*\s*\(" "$SOURCE" 2>/dev/null || echo 0)
    [[ "$FUNC_COUNT" -ge 2 ]] \
        && log_pass "TC45: $FUNC_COUNT functions defined — code is modular" \
        || log_fail "TC45: Less than 2 functions found — logic should not all be in main()"

    # TC46
    OUT=$(run_with_input "$E")
    contains "$OUT" "system\|todo\|inventory\|student\|grade\|record\|management\|calculator\|welcome\|program" \
        && log_pass "TC46: Program displays a title or system name on startup" \
        || log_fail "TC46: No title or system name shown — add a welcome/header message"

    # TC47 — uses padded blank lines per system
    case "$SYSTEM" in
        todolist)   COMP_IN=$(printf "1\nAlpha\n\n\n\n1\nBeta\n\n\n\n4\n%s\n" "$E") ;;
        student)    COMP_IN=$(printf "1\nStudentA\n2021-001\n\n\n1\nStudentB\n2021-002\n\n\n4\n%s\n" "$E") ;;
        inventory)  COMP_IN=$(printf "1\nApple\n10\n100\n\n\n1\nBanana\n5\n50\n\n\n4\n%s\n" "$E") ;;
        grade)      COMP_IN=$(printf "1\nMath\n90\n\n\n1\nScience\n80\n\n\n4\n%s\n" "$E") ;;
        *)          COMP_IN=$(printf "1\nA\n\n\n\n1\nB\n\n\n\n4\n%s\n" "$E") ;;
    esac
    OUT=$(echo -e "$COMP_IN" | timeout 5s "$BINARY" 2>&1)
    contains "$OUT" "[0-9][0-9]\|total\|average\|sum\|count\|gwa\|gpa\|value\|result" \
        && log_pass "TC47: Computation feature outputs a visible numeric result" \
        || log_fail "TC47: Computation result not visible — must display result to user"

    # TC48
    OUT=$(run_with_input "4\n$E"); EC=$?
    [[ $EC -lt 124 ]] \
        && log_pass "TC48: Computation on empty data does not crash" \
        || log_fail "TC48: Computation on empty data crashed"

    # TC49 — uses detected search option + padded blank lines per system
    case "$SYSTEM" in
        todolist)   FIND_IN=$(printf "1\nFindableTask\n\n\n\n%s\nFindable\n%s\n" "$S" "$E") ;;
        student)    FIND_IN=$(printf "1\nFindable Student\n2021-FIND\n\n\n%s\nFindable\n%s\n" "$S" "$E") ;;
        inventory)  FIND_IN=$(printf "1\nFindableItem\n10\n5.00\n\n\n%s\nFindable\n%s\n" "$S" "$E") ;;
        grade)      FIND_IN=$(printf "1\nFindableSubject\n88\n\n\n%s\nFindable\n%s\n" "$S" "$E") ;;
        *)          FIND_IN=$(printf "1\nFindableRecord\n\n\n\n%s\nFindable\n%s\n" "$S" "$E") ;;
    esac
    OUT=$(echo -e "$FIND_IN" | timeout 5s "$BINARY" 2>&1)
    contains "$OUT" "Findable\|found\|result\|match" \
        && log_pass "TC49: Add then search — record is findable by name (search option: $S)" \
        || log_fail "TC49: Added record not returned by search (search option used: $S)"

    # TC50
    HAS_ADD=0;    grep -qiE "\badd\b|\binsert\b|\bnew\b"     "$SOURCE" && HAS_ADD=1
    HAS_VIEW=0;   grep -qiE "\bview\b|\blist\b|\bdisplay\b"  "$SOURCE" && HAS_VIEW=1
    HAS_SEARCH=0; grep -qiE "\bsearch\b|\bfind\b|\bstrcmp\b" "$SOURCE" && HAS_SEARCH=1
    HAS_COMP=0;   grep -qiE "\baverage\b|\btotal\b|\bsum\b|\bgwa\b|\bgpa\b|\bcount\b" "$SOURCE" && HAS_COMP=1
    HAS_EXIT=0;   grep -qiE "\bexit\b|\bquit\b"              "$SOURCE" && HAS_EXIT=1
    FEAT=$((HAS_ADD + HAS_VIEW + HAS_SEARCH + HAS_COMP + HAS_EXIT))
    [[ $FEAT -ge 5 ]] \
        && log_pass "TC50: All 5 required features present (Add, View, Search, Compute, Exit)" \
        || log_fail "TC50: Only $FEAT/5 required features — Add, View, Search, Compute, Exit all required"
}

# ── ADVISORIES (not scored) ───────────────────────────────────
print_warnings() {
    grep -q "\bgets\b" "$SOURCE" && \
        WARNINGS+=("gets() is unsafe — consider fgets() instead (advisory, not scored)")
    grep -qE "//|/\*" "$SOURCE" || \
        WARNINGS+=("No comments found — adding comments improves readability (advisory, not scored)")

    if [[ ${#WARNINGS[@]} -gt 0 ]]; then
        echo -e "\n${YELLOW}${BOLD}⚠  ADVISORIES (informational only — not counted in score)${RESET}"
        for w in "${WARNINGS[@]}"; do
            echo -e "  ${YELLOW}[NOTE]${RESET} $w"
        done
    fi
}

# ── SUMMARY ───────────────────────────────────────────────────
print_summary() {
    echo -e "\n${BOLD}════════════════════════════════════════════${RESET}"
    echo -e "${BOLD}            TEST SUMMARY REPORT             ${RESET}"
    echo -e "${BOLD}════════════════════════════════════════════${RESET}"
    echo -e "  Total Test Cases : ${BOLD}$TOTAL${RESET}"
    echo -e "  ${GREEN}Passed           : $PASS${RESET}"
    echo -e "  ${RED}Failed           : $FAIL${RESET}"
    PERCENT=0
    [[ $TOTAL -gt 0 ]] && PERCENT=$(( PASS * 100 / TOTAL ))
    echo -e "  Score            : ${BOLD}$PASS / $TOTAL  (${PERCENT}%)${RESET}"
    echo -e "${BOLD}════════════════════════════════════════════${RESET}"
    if   [[ $PERCENT -ge 90 ]]; then echo -e "${GREEN}${BOLD}  Excellent — Fully meets the challenge criteria.${RESET}"
    elif [[ $PERCENT -ge 75 ]]; then echo -e "${YELLOW}${BOLD}  Good — Minor issues to address.${RESET}"
    elif [[ $PERCENT -ge 50 ]]; then echo -e "${YELLOW}  Needs improvement — Review failed tests above.${RESET}"
    else                              echo -e "${RED}  Does not meet criteria — Significant fixes required.${RESET}"
    fi
    echo ""
    rm -f "$BINARY"
}

# ── MAIN ──────────────────────────────────────────────────────
main() {
    echo -e "${BOLD}${CYAN}"
    echo "╔════════════════════════════════════════════╗"
    echo "║   IT DAYS CODING COMPETITION — CHECKER v3  ║"
    echo "╚════════════════════════════════════════════╝"
    echo -e "${RESET}"

    preflight          # TC01-TC05  : Compilation & library rules
    static_checks      # TC06-TC15  : Required features in source
    runtime_generic    # TC16-TC22  : Core menu behavior
    runtime_specific   # TC23-TC34  : System-specific functional tests
    stress_tests       # TC35-TC44  : Capacity & edge cases
    structure_checks   # TC45-TC50  : Code structure & completeness

    print_warnings
    print_summary
}

main