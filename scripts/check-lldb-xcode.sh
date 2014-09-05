LLDB_DIR=`pwd`

# make sure the current directory contains an Xcode DerivedData subdirectory
if [ ! -d "DerivedData" ]; then
  echo; echo "Error: $LLDB_DIR/DerivedData not found."; echo
  echo "The working directory should be set to the"
  echo "lldb directory. Xcode's project prefs should"
  echo "be set so that Xcode's DerivedData is placed"
  echo "relative to the lldb parent directory."
  echo
  exit 1
fi

LLDB_EXE_DIR=$LLDB_DIR/DerivedData/lldb/Build/Products/Debug
LLDB_EXE=$LLDB_EXE_DIR/lldb

LLDB_FRAMEWORK="$LLDB_EXE_DIR/LLDB.framework"
export PYTHONPATH="$LLDB_FRAMEWORK/Versions/A/Resources/Python"

TEST_DIR=$LLDB_DIR/test
RESULTS_DIR=$LLDB_DIR/DerivedData/lldb-test-results

$TEST_DIR/dosep.py --options "--executable $LLDB_EXE --framework $LLDB_FRAMEWORK -A x86_64 -C clang -s $RESULTS_DIR $*"
