#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""Filter out bogus warnings from lldb compilation output.

In particular, remove "format '%p' expects argument of type 'void*',
the following code snippet, and the blank line.

"""


# Python built-in modules
import re
import sys


# Our modules
import lldb_utils
import workingdir


# We need lookahead, because the context line *can* (but doesn't always)
# appear before the warning.  So we keep prev_line in reserve until we
# know it's ok to print it.
def main():
  prev_line = None
  prev_error_line = None
  skip_lines = 0;  # The number of lines to skip *checking*
  pattern = r"^(.*): warning: format ‘%p’ expects argument of type ‘void"
  pattern_prog = re.compile(pattern)
  for line in sys.stdin:
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
      prev_line = line;
  if prev_line:  # Write the last held line
    sys.stdout.write(prev_line)


if __name__ == "__main__":
  main()
