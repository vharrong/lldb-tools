# Source this file to get local python settings ready for building
# lldb.
#
# Note: this script assumes you have built a local python and
# installed it into /usr/local/python/python-release.

LLDB_PYTHON_BASE_DIR=/usr/local/python/python-release
LLDB_PYTHON_VERSION=2.7
if [ -d "$LLDB_PYTHON_BASE_DIR" ]; then

    export LLDB_PYTHON_BASE_DIR
    export PATH=$LLDB_PYTHON_BASE_DIR/bin:$PATH
    export LD_LIBRARY_PATH=$LLDB_PYTHON_BASE_DIR/lib:$LD_LIBRARY_PATH
    export PYTHONPATH=$LLDB_PYTHON_BASE_DIR/lib/python$PYTHON_VERSION

else
    echo "error: you don't seem to have a python at $LLDB_PYTHON_BASE_DIR"
fi
