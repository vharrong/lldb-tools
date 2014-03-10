#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""This script builds the lldb executable(s).

Usage:  lldb_mklog.py  [--filter]  { <make-args> ... }

It runs make with the given arguments, and sending the output both to
stdout of this script and to "make.log" in the current directory.

If --filter is specified (it must be the first argument), the output
is filtered to remove gcc warnings emitted about %p not matching void*,
and an additional file "make-unfiltered.log" is also created in the
current directory

Run this script from a 'build' directory outside of the llvm/../lldb
tree to keep generated files out of the source tree.

"""


import re
import subprocess
import sys


# make $@ 2>&1 | tee make.log
def main():

  do_filter = 0
  real_arg_start = 1
  unfiltered_logfile = None
  filtered_logfile = None
  if sys.argv[1] == "--filter":
    do_filter = 1
    real_arg_start = 2
    unfiltered_logfile = open("make-unfiltered.log", "w")
    filtered_logfile = open("make.log", "w")
  else:
    unfiltered_logfile = open("make.log", "w")

  proc = subprocess.Popen(["make"] + sys.argv[real_arg_start:],
                          bufsize=1,
                          stdout=subprocess.PIPE,
                          stderr=subprocess.STDOUT)

  # Just go ahead and make these variables, assuming we're filtering
  prev_line = None
  prev_error_line = None
  skip_lines = 0  # The number of lines to skip *checking*
  pattern = r"^(.*): warning: format ‘%p’ expects argument of type ‘void"
  pattern_prog = re.compile(pattern)

  for line in iter(proc.stdout.readline, ""):
    unfiltered_logfile.write(line)
    if do_filter:
      skip_prev_line = not prev_line
      if skip_lines:
        prev_line = None  # We skip writing it on the *next* iteration
        skip_lines -= 1
      elif pattern_prog.match(line):
        m = pattern_prog.match(line)
        error_line = m.group(1)
        if prev_line and prev_line.endswith(":"):
          skip_prev_line = 1
        prev_line = None  # We skip writing it on the *next* iteration
        if error_line != prev_error_line:  # If they're the same, we don't skip
          prev_error_line = error_line
          skip_lines = 2
      else:
        if prev_line and not skip_prev_line:
          sys.stdout.write(prev_line)
          filtered_logfile.write(prev_line)
        prev_line = line
    else:
      sys.stdout.write(line)
  if do_filter and prev_line:  # Write the last held line
    sys.stdout.write(prev_line)
    filtered_logfile.write(prev_line)
  proc.wait()


if __name__ == "__main__":
  main()
