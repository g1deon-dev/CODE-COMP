#!/bin/bash

# ============================================================
#  11 Days Coding Challenge — Automated Checker v4 (FAIR)
#  Tests: Todo List | Student Record | Inventory | Grade Calc
#  60 Test Cases — includes full input validation section
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
#   - TC51-TC60: input validation — bad data must be handled
#     gracefully AND show the user a message (per rules)
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

    # Guard: abort before any scored test if file is missing
    if [[ ! -f "$SOURCE" ]]; then
        echo -e "${RED}Error: $SOURCE not found. Place solution.c in the same folder as this script.${RESET}"
        exit 1
    fi

    # TC01: source file contains actual C code
    if grep -q "#include" "$SOURCE"; then
        log_pass "TC01: Source file contains C code (#include directive found)"
    else
        log_fail "TC01: No #include found — file may not be valid C source"
    fi

    # TC02: file is non-empty
    if [[ -s "$SOURCE" ]]; then
        log_pass "TC02: Source file is non-empty"
    else
        log_fail "TC02: Source file is empty"
        exit 1
    fi

    # TC03: compiles with gcc
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

    # TC04: only standard C library headers used
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

    # TC05: submitted as .c file
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

    OUT=$(printf "1\nTestRecord\n\n\n\n%s\n" "$E" | timeout 5s "$BINARY" 2>&1); EC=$?
    [[ $EC -lt 124 ]] && log_pass "TC23: Add operation does not crash" || log_fail "TC23: Add operation crashed/timed out"

    OUT=$(printf "1\nTestRecord\n\n\n\n2\n%s\n" "$E" | timeout 5s "$BINARY" 2>&1)
    contains "$OUT" "TestRecord\|record\|list\|data\|view\|result" \
        && log_pass "TC24: View shows data after add" \
        || log_fail "TC24: View shows no data after add"

    OUT=$(printf "1\nTestRecord\n\n\n\n%s\nTestRecord\n%s\n" "$S" "$E" | timeout 5s "$BINARY" 2>&1); EC=$?
    [[ $EC -lt 124 ]] && log_pass "TC25: Search does not crash" || log_fail "TC25: Search crashed"

    OUT=$(printf "%s\nZZZNoSuchRecord\n%s\n" "$S" "$E" | timeout 5s "$BINARY" 2>&1)
    contains "$OUT" "not found\|no result\|empty\|none\|0 record\|does not\|no match" \
        && log_pass "TC26: Search for missing record shows appropriate message (search option: $S)" \
        || log_fail "TC26: No message for a missing record (search option used: $S)"

    OUT=$(run_with_input "2\n$E"); EC=$?
    [[ $EC -lt 124 ]] && log_pass "TC27: View empty list does not crash" || log_fail "TC27: View empty list crashed"

    OUT=$(printf "1\nAlphaRecord\n\n\n\n1\nBetaRecord\n\n\n\n2\n%s\n" "$E" | timeout 5s "$BINARY" 2>&1)
    contains "$OUT" "Alpha\|Beta\|record\|list\|data" \
        && log_pass "TC28: Multiple records visible in view after adding two" \
        || log_fail "TC28: Records not visible after adding two"

    OUT=$(run_with_input "4\n$E"); EC=$?
    [[ $EC -lt 124 ]] && log_pass "TC29: Computation option does not crash" || log_fail "TC29: Computation option crashed"

    OUT=$(run_with_input "5\n999\n$E"); EC=$?
    [[ $EC -lt 124 ]] && log_pass "TC30: Invalid ID for operation does not crash" || log_fail "TC30: Invalid ID caused crash"

    OUT=$(printf "1\nFindMe\n\n\n\n%s\nFindMe\n%s\n" "$S" "$E" | timeout 5s "$BINARY" 2>&1)
    contains "$OUT" "FindMe\|found\|result\|match\|record" \
        && log_pass "TC31: Search returns a matching record" \
        || log_fail "TC31: Search did not return expected match"

    OUT=$(run_with_input "\-1\n$E"); EC=$?
    [[ $EC -lt 124 ]] && log_pass "TC32: Negative menu choice does not crash" || log_fail "TC32: Negative menu choice crashed"

    OUT=$(run_with_input "2.5\n$E"); EC=$?
    [[ $EC -lt 124 ]] && log_pass "TC33: Decimal menu choice does not crash" || log_fail "TC33: Decimal menu choice crashed"

    OUT=$(printf "1\nLongNameAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\n\n\n\n%s\n" "$E" | timeout 5s "$BINARY" 2>&1); EC=$?
    [[ $EC -lt 124 ]] && log_pass "TC34: Long name input does not crash" || log_fail "TC34: Long name caused crash"
}

# ── TODO LIST ─────────────────────────────────────────────────
test_todolist() {
    log_section "TODO LIST — FUNCTIONAL TESTS (TC23-TC34)"
    local E="$EXIT_OPT"
    local S="$SEARCH_OPT"

    OUT=$(printf "1\nBuy groceries\n\n\n\n%s\n" "$E" | timeout 5s "$BINARY" 2>&1); EC=$?
    [[ $EC -lt 124 ]] && log_pass "TC23: Add task does not crash" || log_fail "TC23: Add task crashed/timed out"

    OUT=$(printf "1\nBuy groceries\n\n\n\n2\n%s\n" "$E" | timeout 5s "$BINARY" 2>&1)
    contains "$OUT" "Buy groceries\|task\|record\|list\|item" \
        && log_pass "TC24: View all shows the added task" \
        || log_fail "TC24: Added task not visible in view all"

    OUT=$(printf "1\nBuy groceries\n\n\n\n%s\nBuy\n%s\n" "$S" "$E" | timeout 5s "$BINARY" 2>&1)
    contains "$OUT" "Buy\|found\|result\|match\|task" \
        && log_pass "TC25: Search returns a result for an existing task (search option: $S)" \
        || log_fail "TC25: Search did not find existing task (search option used: $S)"

    OUT=$(printf "%s\nZZZNoSuchTask999\n%s\n" "$S" "$E" | timeout 5s "$BINARY" 2>&1)
    contains "$OUT" "not found\|no result\|empty\|none\|no task\|does not\|no match\|0" \
        && log_pass "TC26: Search for missing task shows appropriate message (search option: $S)" \
        || log_fail "TC26: No message shown for missing task (search option used: $S)"

    OUT=$(run_with_input "2\n$E"); EC=$?
    [[ $EC -lt 124 ]] \
        && log_pass "TC27: View empty task list does not crash" \
        || log_fail "TC27: Viewing empty list crashed"

    OUT=$(printf "1\nTask Alpha\n\n\n\n1\nTask Beta\n\n\n\n2\n%s\n" "$E" | timeout 5s "$BINARY" 2>&1)
    contains "$OUT" "Alpha" && contains "$OUT" "Beta" \
        && log_pass "TC28: Both tasks visible in view after adding two" \
        || log_fail "TC28: Not all tasks visible — extra field prompts may have consumed task names"

    OUT=$(printf "1\nSample Task\n\n\n\n4\n%s\n" "$E" | timeout 5s "$BINARY" 2>&1); EC=$?
    [[ $EC -lt 124 ]] \
        && log_pass "TC29: Computation option does not crash" \
        || log_fail "TC29: Computation option crashed"

    OUT=$(printf "1\nTask1\n\n\n\n1\nTask2\n\n\n\n4\n%s\n" "$E" | timeout 5s "$BINARY" 2>&1)
    contains "$OUT" "[0-9]\|total\|count\|number\|statistic\|record" \
        && log_pass "TC30: Computation produces visible output" \
        || log_fail "TC30: Computation output not visible — must display a result"

    OUT=$(printf "1\nTemp Task\n\n\n\n5\n1\n%s\n" "$E" | timeout 5s "$BINARY" 2>&1); EC=$?
    [[ $EC -lt 124 ]] \
        && log_pass "TC31: Delete task option does not crash" \
        || log_fail "TC31: Delete task crashed"

    OUT=$(run_with_input "5\n9999\n$E"); EC=$?
    [[ $EC -lt 124 ]] \
        && log_pass "TC32: Invalid task ID for delete does not crash" \
        || log_fail "TC32: Invalid task ID caused crash"

    OUT=$(run_with_input "\-1\n$E"); EC=$?
    [[ $EC -lt 124 ]] \
        && log_pass "TC33: Negative menu choice does not crash" \
        || log_fail "TC33: Negative menu choice caused crash"

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

    OUT=$(run_with_input "1\nJuan Dela Cruz\n2021-0001\n$E"); EC=$?
    [[ $EC -lt 124 ]] && log_pass "TC23: Add student does not crash" || log_fail "TC23: Add student crashed/timed out"

    OUT=$(run_with_input "1\nJuan Dela Cruz\n2021-0001\n2\n$E")
    contains "$OUT" "Juan\|Dela Cruz\|2021-0001\|student\|record" \
        && log_pass "TC24: View all shows added student" \
        || log_fail "TC24: Added student not visible in view"

    OUT=$(printf "1\nJuan Dela Cruz\n2021-0001\n%s\nJuan\n%s\n" "$S" "$E" | timeout 5s "$BINARY" 2>&1)
    contains "$OUT" "Juan\|found\|result\|match\|record" \
        && log_pass "TC25: Search returns result for existing student (search option: $S)" \
        || log_fail "TC25: Search did not find existing student (search option used: $S)"

    OUT=$(printf "%s\nZZZFakeName999\n%s\n" "$S" "$E" | timeout 5s "$BINARY" 2>&1)
    contains "$OUT" "not found\|no result\|empty\|none\|does not\|no match\|0" \
        && log_pass "TC26: Search for missing student shows appropriate message (search option: $S)" \
        || log_fail "TC26: No message shown for missing student (search option used: $S)"

    OUT=$(run_with_input "2\n$E"); EC=$?
    [[ $EC -lt 124 ]] && log_pass "TC27: View empty student list does not crash" || log_fail "TC27: View empty list crashed"

    OUT=$(printf "1\nAnna Santos\n2021-0002\n\n\n1\nCarlos Reyes\n2021-0003\n\n\n2\n%s\n" "$E" | timeout 5s "$BINARY" 2>&1)
    contains "$OUT" "Anna\|Santos" && contains "$OUT" "Carlos\|Reyes" \
        && log_pass "TC28: Both students visible in view after adding two" \
        || log_fail "TC28: Not all students shown after adding two"

    OUT=$(run_with_input "1\nTest Student\n2021-0099\n4\n$E"); EC=$?
    [[ $EC -lt 124 ]] \
        && log_pass "TC29: Computation option does not crash" \
        || log_fail "TC29: Computation option crashed"

    OUT=$(run_with_input "1\nStudentA\n2021-001\n1\nStudentB\n2021-002\n4\n$E")
    contains "$OUT" "[0-9]\|average\|total\|gpa\|gwa\|mean\|count\|record\|compute" \
        && log_pass "TC30: Computation produces visible output" \
        || log_fail "TC30: Computation shows no recognizable result"

    OUT=$(run_with_input "1\nTemp Student\n2021-0099\n5\n2021-0099\n$E"); EC=$?
    [[ $EC -lt 124 ]] && log_pass "TC31: Delete student does not crash" || log_fail "TC31: Delete student crashed"

    OUT=$(run_with_input "5\n9999-9999\n$E"); EC=$?
    [[ $EC -lt 124 ]] && log_pass "TC32: Invalid student ID for delete does not crash" || log_fail "TC32: Invalid ID caused crash"

    OUT=$(run_with_input "\-5\n$E"); EC=$?
    [[ $EC -lt 124 ]] && log_pass "TC33: Negative menu choice does not crash" || log_fail "TC33: Negative menu choice crashed"

    LONGNAME="Maria Cristina dela Fuente-Villanueva"
    OUT=$(run_with_input "1\n$LONGNAME\n2021-LONG\n$E"); EC=$?
    [[ $EC -lt 124 ]] && log_pass "TC34: Long student name does not crash" || log_fail "TC34: Long student name caused crash"
}

# ── INVENTORY ─────────────────────────────────────────────────
test_inventory() {
    log_section "INVENTORY SYSTEM — FUNCTIONAL TESTS (TC23-TC34)"
    local E="$EXIT_OPT"
    local S="$SEARCH_OPT"

    OUT=$(printf "1\nApple\n50\n25.50\n\n\n%s\n" "$E" | timeout 5s "$BINARY" 2>&1); EC=$?
    [[ $EC -lt 124 ]] && log_pass "TC23: Add item does not crash" || log_fail "TC23: Add item crashed/timed out"

    OUT=$(printf "1\nApple\n50\n25.50\n\n\n2\n%s\n" "$E" | timeout 5s "$BINARY" 2>&1)
    contains "$OUT" "Apple\|item\|product\|inventory\|record\|stock" \
        && log_pass "TC24: View all shows added item" \
        || log_fail "TC24: Added item not visible in view"

    OUT=$(printf "1\nApple\n50\n25.50\n\n\n%s\nApple\n%s\n" "$S" "$E" | timeout 5s "$BINARY" 2>&1)
    contains "$OUT" "Apple\|found\|result\|match\|item" \
        && log_pass "TC25: Search returns result for existing item (search option: $S)" \
        || log_fail "TC25: Search did not find existing item (search option used: $S)"

    OUT=$(printf "%s\nZZZNoSuchItem999\n%s\n" "$S" "$E" | timeout 5s "$BINARY" 2>&1)
    contains "$OUT" "not found\|no result\|empty\|none\|does not\|no match\|0" \
        && log_pass "TC26: Search for missing item shows appropriate message (search option: $S)" \
        || log_fail "TC26: No message shown for missing item (search option used: $S)"

    OUT=$(run_with_input "2\n$E"); EC=$?
    [[ $EC -lt 124 ]] && log_pass "TC27: View empty inventory does not crash" || log_fail "TC27: View empty inventory crashed"

    OUT=$(printf "1\nApple\n50\n25.50\n\n\n1\nBanana\n30\n10.00\n\n\n2\n%s\n" "$E" | timeout 5s "$BINARY" 2>&1)
    contains "$OUT" "Apple" && contains "$OUT" "Banana" \
        && log_pass "TC28: Both items visible in view after adding two" \
        || log_fail "TC28: Not all items shown — field order mismatch may have consumed item names"

    OUT=$(printf "1\nApple\n50\n25.50\n\n\n4\n%s\n" "$E" | timeout 5s "$BINARY" 2>&1); EC=$?
    [[ $EC -lt 124 ]] && log_pass "TC29: Computation option does not crash" || log_fail "TC29: Computation option crashed"

    OUT=$(printf "1\nApple\n10\n100\n\n\n1\nBanana\n20\n50\n\n\n4\n%s\n" "$E" | timeout 5s "$BINARY" 2>&1)
    contains "$OUT" "[0-9]\|total\|value\|worth\|sum\|inventory\|compute\|average" \
        && log_pass "TC30: Computation produces visible output" \
        || log_fail "TC30: Computation shows no recognizable result"

    OUT=$(printf "1\nApple\n50\n25.50\n\n\n5\nApple\n30\n%s\n" "$E" | timeout 5s "$BINARY" 2>&1); EC=$?
    [[ $EC -lt 124 ]] && log_pass "TC31: Update item does not crash" || log_fail "TC31: Update item crashed"

    OUT=$(printf "1\nTempItem\n5\n10.00\n\n\n6\nTempItem\n%s\n" "$E" | timeout 5s "$BINARY" 2>&1); EC=$?
    [[ $EC -lt 124 ]] && log_pass "TC32: Delete item does not crash" || log_fail "TC32: Delete item crashed"

    OUT=$(run_with_input "\-1\n$E"); EC=$?
    [[ $EC -lt 124 ]] && log_pass "TC33: Negative menu choice does not crash" || log_fail "TC33: Negative menu choice crashed"

    OUT=$(printf "1\nZeroItem\n0\n10.00\n\n\n%s\n" "$E" | timeout 5s "$BINARY" 2>&1); EC=$?
    [[ $EC -lt 124 ]] && log_pass "TC34: Zero quantity input does not crash" || log_fail "TC34: Zero quantity input caused crash"
}

# ── GRADE CALCULATOR ──────────────────────────────────────────
test_grade() {
    log_section "GRADE CALCULATOR — FUNCTIONAL TESTS (TC23-TC34)"
    local E="$EXIT_OPT"
    local S="$SEARCH_OPT"

    OUT=$(printf "1\nMathematics\n90\n\n\n%s\n" "$E" | timeout 5s "$BINARY" 2>&1); EC=$?
    [[ $EC -lt 124 ]] && log_pass "TC23: Add subject/grade does not crash" || log_fail "TC23: Add subject crashed/timed out"

    OUT=$(printf "1\nMathematics\n90\n\n\n2\n%s\n" "$E" | timeout 5s "$BINARY" 2>&1)
    contains "$OUT" "Mathematics\|Math\|subject\|grade\|record\|list" \
        && log_pass "TC24: View all shows added subject" \
        || log_fail "TC24: Added subject not visible in view"

    OUT=$(printf "1\nMathematics\n90\n\n\n%s\nMath\n%s\n" "$S" "$E" | timeout 5s "$BINARY" 2>&1)
    contains "$OUT" "Math\|found\|result\|match\|subject\|grade" \
        && log_pass "TC25: Search returns result for existing subject (search option: $S)" \
        || log_fail "TC25: Search did not find existing subject (search option used: $S)"

    OUT=$(printf "%s\nZZZFakeSubject999\n%s\n" "$S" "$E" | timeout 5s "$BINARY" 2>&1)
    contains "$OUT" "not found\|no result\|empty\|none\|does not\|no match\|0" \
        && log_pass "TC26: Search for missing subject shows appropriate message (search option: $S)" \
        || log_fail "TC26: No message shown for missing subject (search option used: $S)"

    OUT=$(run_with_input "2\n$E"); EC=$?
    [[ $EC -lt 124 ]] && log_pass "TC27: View empty grade list does not crash" || log_fail "TC27: View empty list crashed"

    OUT=$(printf "1\nMath\n90\n\n\n1\nScience\n85\n\n\n2\n%s\n" "$E" | timeout 5s "$BINARY" 2>&1)
    contains "$OUT" "Math" && contains "$OUT" "Science" \
        && log_pass "TC28: Both subjects visible in view after adding two" \
        || log_fail "TC28: Not all subjects shown — extra field prompts may have consumed subject names"

    OUT=$(printf "1\nMath\n90\n\n\n1\nScience\n85\n\n\n4\n%s\n" "$E" | timeout 5s "$BINARY" 2>&1); EC=$?
    [[ $EC -lt 124 ]] && log_pass "TC29: Computation (average/GWA) does not crash" || log_fail "TC29: Computation crashed"

    OUT=$(printf "1\nMath\n90\n\n\n1\nScience\n80\n\n\n4\n%s\n" "$E" | timeout 5s "$BINARY" 2>&1)
    contains "$OUT" "[0-9][0-9]\|average\|gwa\|gpa\|mean\|total\|result\|compute" \
        && log_pass "TC30: Computation produces visible output" \
        || log_fail "TC30: Computation shows no recognizable output"

    OUT=$(printf "1\nTempSubject\n70\n\n\n5\n1\n%s\n" "$E" | timeout 5s "$BINARY" 2>&1); EC=$?
    [[ $EC -lt 124 ]] && log_pass "TC31: Delete subject does not crash" || log_fail "TC31: Delete subject crashed"

    OUT=$(run_with_input "5\n9999\n$E"); EC=$?
    [[ $EC -lt 124 ]] && log_pass "TC32: Invalid subject ID for delete does not crash" || log_fail "TC32: Invalid ID caused crash"

    OUT=$(printf "1\nMath\n110\n\n\n%s\n" "$E" | timeout 5s "$BINARY" 2>&1); EC=$?
    [[ $EC -lt 124 ]] && log_pass "TC33: Grade > 100 handled without crash" || log_fail "TC33: Grade > 100 caused crash"

    OUT=$(printf "1\nMath\n-5\n\n\n%s\n" "$E" | timeout 5s "$BINARY" 2>&1); EC=$?
    [[ $EC -lt 124 ]] && log_pass "TC34: Negative grade handled without crash" || log_fail "TC34: Negative grade caused crash"
}

# ── INPUT VALIDATION TESTS (TC51-TC60) ───────────────────────
# The rules say: "handle invalid input gracefully
# (invalid menu choice, missing record, incorrect values)"
# These tests check BOTH: program doesn't crash AND tells the user.
input_validation() {
    log_section "INPUT VALIDATION TESTS (TC51-TC60)"
    local E="$EXIT_OPT"
    local S="$SEARCH_OPT"
    local SYSTEM
    SYSTEM=$(detect_system)

    # TC51: Letters typed where a numeric data field is expected
    # (e.g. typing "abc" when asked for a grade, quantity, or price)
    # Only checks: does the program survive? Content checked in TC52.
    case "$SYSTEM" in
        grade)     BAD_NUM=$(printf "1\nMath\nabc\n\n\n%s\n" "$E") ;;
        inventory) BAD_NUM=$(printf "1\nApple\nabc\nabc\n\n\n%s\n" "$E") ;;
        student)   BAD_NUM=$(printf "1\nTestName\nabc\n\n\n%s\n" "$E") ;;
        *)         BAD_NUM=$(printf "1\nTestItem\nabc\n\n\n%s\n" "$E") ;;
    esac
    OUT=$(echo -e "$BAD_NUM" | timeout 5s "$BINARY" 2>&1); EC=$?
    [[ $EC -lt 124 ]] \
        && log_pass "TC51: Letters in a numeric field do not crash the program" \
        || log_fail "TC51: Letters in a numeric field caused crash or timeout"

    # TC52: Same bad input — does the program show a message?
    # Accepts any word that sounds like feedback or rejection
    contains "$OUT" "invalid\|error\|wrong\|try again\|not valid\|must be\|number\|incorrect\|please\|only digit" \
        && log_pass "TC52: Invalid numeric input shows a feedback message to the user" \
        || log_fail "TC52: No feedback shown for invalid numeric input (rules require graceful handling)"

    # TC53: Blank/empty name on add — does the program survive?
    # Sends just a newline as the name field
    OUT=$(printf "1\n\n\n\n\n%s\n" "$E" | timeout 5s "$BINARY" 2>&1); EC=$?
    [[ $EC -lt 124 ]] \
        && log_pass "TC53: Blank name on add does not crash the program" \
        || log_fail "TC53: Blank name on add caused crash or timeout"

    # TC54: Blank name — does the program reject it or warn the user?
    # Fair: accepts either a rejection message OR that the list stayed empty
    OUT_VIEW=$(printf "1\n\n\n\n\n2\n%s\n" "$E" | timeout 5s "$BINARY" 2>&1)
    if contains "$OUT_VIEW" "invalid\|error\|empty\|blank\|required\|cannot\|must\|please\|wrong"; then
        log_pass "TC54: Blank name rejected with a message"
    elif contains "$OUT_VIEW" "no record\|nothing\|no item\|no task\|no student\|no subject\|list is empty\|0 record"; then
        log_pass "TC54: Blank name not added — list remained empty (acceptable handling)"
    else
        log_fail "TC54: Blank name was accepted silently — program should reject or warn the user"
    fi

    # TC55: Delete a record ID that does not exist — does the program survive?
    OUT=$(run_with_input "5\n9999\n$E"); EC=$?
    [[ $EC -lt 124 ]] \
        && log_pass "TC55: Deleting a non-existent record ID does not crash" \
        || log_fail "TC55: Deleting a non-existent ID caused crash or timeout"

    # TC56: Same invalid delete — does the program tell the user?
    contains "$OUT" "not found\|no record\|invalid\|does not exist\|error\|wrong\|no match\|cannot\|failed" \
        && log_pass "TC56: Deleting non-existent record shows a feedback message" \
        || log_fail "TC56: No message shown when deleting a non-existent record (rules require graceful handling)"

    # TC57: Delete from a completely empty list — does the program survive?
    OUT=$(run_with_input "5\n$E"); EC=$?
    [[ $EC -lt 124 ]] \
        && log_pass "TC57: Attempting to delete from an empty list does not crash" \
        || log_fail "TC57: Delete on empty list caused crash or timeout"

    # TC58: Blank/empty search query — does the program survive?
    # Sends the search option, then just a newline as the search term
    OUT=$(printf "%s\n\n%s\n" "$S" "$E" | timeout 5s "$BINARY" 2>&1); EC=$?
    [[ $EC -lt 124 ]] \
        && log_pass "TC58: Blank search query does not crash the program" \
        || log_fail "TC58: Blank search query caused crash or timeout"

    # TC59: Program recovers and works normally after bad input
    # Sends an invalid menu choice, then immediately does a valid add + view
    # If the record appears in view, the loop recovered properly
    OUT=$(printf "9999\n1\nRecoveryTest\n\n\n\n2\n%s\n" "$E" | timeout 5s "$BINARY" 2>&1); EC=$?
    if [[ $EC -lt 124 ]] && contains "$OUT" "RecoveryTest\|record\|list\|item\|task\|student\|subject"; then
        log_pass "TC59: Program recovers and works normally after invalid menu input"
    else
        log_fail "TC59: Program did not recover after invalid input — menu loop may be broken"
    fi

    # TC60: A failed add does not corrupt or erase records already stored
    # Adds one valid record, then tries a bad add (blank name), then views
    # The first record must still be visible — bad input should not wipe data
    case "$SYSTEM" in
        grade)     GOOD=$(printf "1\nMathematics\n90\n\n\n") ; KEY="Mathematics\|Math" ;;
        inventory) GOOD=$(printf "1\nApple\n10\n5.00\n\n\n") ; KEY="Apple" ;;
        student)   GOOD=$(printf "1\nJose Rizal\n2021-001\n\n\n") ; KEY="Jose\|Rizal" ;;
        todolist)  GOOD=$(printf "1\nClean room\n\n\n\n") ; KEY="Clean" ;;
        *)         GOOD=$(printf "1\nGoodRecord\n\n\n\n") ; KEY="GoodRecord\|Good" ;;
    esac
    OUT=$(printf "%s1\n\n\n\n\n2\n%s\n" "$GOOD" "$E" | timeout 5s "$BINARY" 2>&1); EC=$?
    if [[ $EC -lt 124 ]] && contains "$OUT" "$KEY"; then
        log_pass "TC60: Valid record still visible after a failed add — data was not corrupted"
    else
        log_fail "TC60: Valid record missing after a failed add — bad input may have corrupted stored data"
    fi
}

# ── STRESS & CAPACITY TESTS (TC35-TC44) ──────────────────────
stress_tests() {
    log_section "STRESS & CAPACITY TESTS (TC35-TC44)"
    local E="$EXIT_OPT"
    local S="$SEARCH_OPT"

    INPUT=""
    for i in $(seq 1 10); do INPUT+="1\nRecord${i}\n\n\n\n"; done
    INPUT+="2\n${E}"
    OUT=$(echo -e "$INPUT" | timeout 15s "$BINARY" 2>&1); EC=$?
    [[ $EC -lt 124 ]] \
        && log_pass "TC35: 10 records added and viewed without crash" \
        || log_fail "TC35: Crashed or timed out adding 10 records"

    contains "$OUT" "Record\|record\|item\|student\|task\|subject\|data\|list" \
        && log_pass "TC36: View all with 10 records produces output" \
        || log_fail "TC36: View all with 10 records shows nothing"

    INPUT=""
    for i in $(seq 1 10); do INPUT+="1\nRecord${i}\n\n\n\n"; done
    INPUT+="${S}\nRecord5\n${E}"
    OUT=$(echo -e "$INPUT" | timeout 15s "$BINARY" 2>&1); EC=$?
    [[ $EC -lt 124 ]] \
        && log_pass "TC37: Search among 10 records does not crash (search option: $S)" \
        || log_fail "TC37: Search after 10 records crashed/timed out (search option used: $S)"

    OUT=$(printf "1\nO'Brien\n\n\n\n\n%s\n" "$E" | timeout 5s "$BINARY" 2>&1); EC=$?
    [[ $EC -lt 124 ]] \
        && log_pass "TC38: Apostrophe in input does not crash" \
        || log_fail "TC38: Apostrophe in input caused crash"

    LONG50="AAAAAAAAAABBBBBBBBBBCCCCCCCCCCDDDDDDDDDDEEEEEEEEE1"
    OUT=$(printf "1\n%s\n\n\n\n\n%s\n" "$LONG50" "$E" | timeout 5s "$BINARY" 2>&1); EC=$?
    [[ $EC -lt 124 ]] \
        && log_pass "TC39: 50-character name does not crash" \
        || log_fail "TC39: 50-character name caused crash"

    OUT=$(printf ' \n \n%s\n' "$E" | timeout 5s "$BINARY" 2>&1); EC=$?
    [[ $EC -lt 124 ]] \
        && log_pass "TC40: Whitespace-only menu input does not crash or hang" \
        || log_fail "TC40: Whitespace input caused crash or infinite loop"

    OUT=$(run_with_input "2\n2\n2\n$E"); EC=$?
    [[ $EC -lt 124 ]] \
        && log_pass "TC41: Repeated view selections do not crash" \
        || log_fail "TC41: Repeated view selections caused crash"

    OUT=$(printf "1\nBigNum\n99999\n9999.99\n\n\n%s\n" "$E" | timeout 5s "$BINARY" 2>&1); EC=$?
    [[ $EC -lt 124 ]] \
        && log_pass "TC42: Large number as data value does not crash" \
        || log_fail "TC42: Large data value caused crash"

    OUT=$(run_with_input "2.5\n$E"); EC=$?
    [[ $EC -lt 124 ]] \
        && log_pass "TC43: Decimal menu choice does not crash" \
        || log_fail "TC43: Decimal menu choice caused crash"

    OUT=$(printf "1\nSeqTest\n10\n\n\n2\n%s\nSeqTest\n4\n%s\n" "$S" "$E" | timeout 5s "$BINARY" 2>&1); EC=$?
    [[ $EC -lt 124 ]] \
        && log_pass "TC44: Add → View → Search → Compute in sequence does not crash" \
        || log_fail "TC44: Sequential operations caused crash/timeout"
}

# ── CODE STRUCTURE CHECKS (TC45-TC50) ────────────────────────
structure_checks() {
    log_section "CODE STRUCTURE CHECKS (TC45-TC50)"
    local S="$SEARCH_OPT"
    local E="$EXIT_OPT"
    local SYSTEM
    SYSTEM=$(detect_system)

    FUNC_COUNT=$(grep -cE "^(void|int|float|double|char|bool|long)\s+[a-zA-Z_][a-zA-Z0-9_]*\s*\(" "$SOURCE" 2>/dev/null || echo 0)
    [[ "$FUNC_COUNT" -ge 2 ]] \
        && log_pass "TC45: $FUNC_COUNT functions defined — code is modular" \
        || log_fail "TC45: Less than 2 functions found — logic should not all be in main()"

    OUT=$(run_with_input "$E")
    contains "$OUT" "system\|todo\|inventory\|student\|grade\|record\|management\|calculator\|welcome\|program" \
        && log_pass "TC46: Program displays a title or system name on startup" \
        || log_fail "TC46: No title or system name shown — add a welcome/header message"

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

    OUT=$(run_with_input "4\n$E"); EC=$?
    [[ $EC -lt 124 ]] \
        && log_pass "TC48: Computation on empty data does not crash" \
        || log_fail "TC48: Computation on empty data crashed"

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
    echo "║   IT DAYS CODING COMPETITION — CHECKER v4  ║"
    echo "╚════════════════════════════════════════════╝"
    echo -e "${RESET}"

    preflight          # TC01-TC05  : Compilation & library rules
    static_checks      # TC06-TC15  : Required features in source
    runtime_generic    # TC16-TC22  : Core menu behavior
    runtime_specific   # TC23-TC34  : System-specific functional tests
    structure_checks   # TC45-TC50  : Code structure & completeness
    input_validation   # TC51-TC60  : Input validation
    stress_tests       # TC35-TC44  : Capacity & edge cases

    print_warnings
    print_summary
}

main