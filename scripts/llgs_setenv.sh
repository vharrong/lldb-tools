# This script sets variables that are given to the lldb-gdbserver commandline
# when lldb executes llgs for local debugging.  It also provides a mode to
# unset the variables.
#
# Usage:
#  source llgs_setenv.sh
#        Sets the variables.
#  source llgs_setenv.sh -u
#        Unsets the variables.


if [ "$1" == "-u" ]; then
    unset LLDB_DEBUGSERVER_EXTRA_ARG_1
    unset LLDB_DEBUGSERVER_EXTRA_ARG_2
    unset LLDB_DEBUGSERVER_EXTRA_ARG_3
    unset LLDB_DEBUGSERVER_EXTRA_ARG_4
else
    # Set up LLGS environment variables for logging.
    export LLDB_DEBUGSERVER_EXTRA_ARG_1="-c"
    export LLDB_DEBUGSERVER_EXTRA_ARG_2="log enable -f /tmp/llgs_packets.log gdb-remote packets process"
    export LLDB_DEBUGSERVER_EXTRA_ARG_3="-c"
    export LLDB_DEBUGSERVER_EXTRA_ARG_4="log enable -f /tmp/llgs_process.log lldb process thread"
fi
