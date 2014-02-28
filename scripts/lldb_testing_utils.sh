# source this

function lldb_skipped_linux_tests () {
    # Expects to be running from the lldb source dir (llvm/tools/lldb).
    find test -type f -name '*.py' | xargs grep @skipIfLinux 2>/dev/null | grep -v @skipIfLinuxClang 2>/dev/null | awk 'match($1, /^(.+):/, m) {print m[1]}' | sort | uniq
}

function lldb_run_test () {
    # Expects to  be running from the root of the build dir.
    local TEST_SOURCE_DIR=`pwd`/../llvm/tools/lldb/test
    # assume cmake dir for now
    local LLDB_EXE=`pwd`/bin/lldb
    pushd $TEST_SOURCE_DIR
    python dotest.py --executable=$LLDB_EXE --compiler=gcc -p $@
    popd
}

function lldb_collate_test_results () {
    local PASS_COUNT="$(grep '^PASS: LLDB' $1 | wc -l)"
    local XFAIL_COUNT="$(grep '^XFAIL: LLDB' $1 | wc -l)"
    local FAIL_COUNT="$(grep '^FAIL: LLDB' $1 | wc -l)"

    local TOTAL_RUN_COUNT=$(expr $PASS_COUNT + $XFAIL_COUNT + $FAIL_COUNT)
    local PASS_PERCENT=$(echo "( $PASS_COUNT * 100.0 ) / $TOTAL_RUN_COUNT" | bc -l)
    local XFAIL_PERCENT=$(echo "( $XFAIL_COUNT * 100.0 ) / $TOTAL_RUN_COUNT" | bc -l)
    local FAIL_PERCENT=$(echo "( $FAIL_COUNT * 100.0 ) / $TOTAL_RUN_COUNT" | bc -l)

    local UNSUPPORTED_COUNT="$(grep '^UNSUPPORTED: LLDB' $1 | wc -l)"
    local UNSUPPORTED_DARWIN_COUNT="$(grep '^UNSUPPORTED: LLDB' $1 | grep "requires Darwin" | wc -l)"
    local UNSUPPORTED_SKIP_LINUX_COUNT="$(grep '^UNSUPPORTED: LLDB' $1 | grep "skip on linux" | wc -l)"
    local UNSUPPORTED_OTHER_COUNT="$(grep '^UNSUPPORTED: LLDB' $1 | grep -v "requires Darwin" | grep -v "skip on linux" | wc -l)"

    local UNSUPPORTED_DARWIN_PERCENT=$(echo "( $UNSUPPORTED_DARWIN_COUNT * 100.0 ) / $UNSUPPORTED_COUNT" | bc -l)
    local UNSUPPORTED_SKIP_LINUX_PERCENT=$(echo "( $UNSUPPORTED_SKIP_LINUX_COUNT * 100.0 ) / $UNSUPPORTED_COUNT" | bc -l)
    local UNSUPPORTED_OTHER_PERCENT=$(echo "( $UNSUPPORTED_OTHER_COUNT * 100.0 ) / $UNSUPPORTED_COUNT" | bc -l)


    echo "======"
    echo "TOTALS"
    echo "======"
    printf "pass:  %4d (%5.2f%% of tests run)\n" $PASS_COUNT $PASS_PERCENT
    printf "xfail: %4d (%5.2f%% of tests run)\n" $XFAIL_COUNT $XFAIL_PERCENT
    printf "fail:  %4d (%5.2f%% of tests run)\n" $FAIL_COUNT $FAIL_PERCENT
    echo ""
    echo "==========="
    echo "UNSUPPORTED"
    echo "==========="
    printf "unsupported (total):       %4d\n" $UNSUPPORTED_COUNT
    printf "unsupported (Darwin-only): %4d (%5.2f%% of unsupported tests)\n" $UNSUPPORTED_DARWIN_COUNT $UNSUPPORTED_DARWIN_PERCENT
    printf "unsupported (skip linux):  %4d (%5.2f%% of unsupported tests)\n" $UNSUPPORTED_SKIP_LINUX_COUNT $UNSUPPORTED_SKIP_LINUX_PERCENT
    printf "unsupported (other):       %4d (%5.2f%% of unsupported tests)\n" $UNSUPPORTED_OTHER_COUNT $UNSUPPORTED_OTHER_PERCENT
}
