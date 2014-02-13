#!/usr/bin/env python

"""This script greatly shortens the PROMPT_COMMAND introduced by lunch.

The default command looks like

  echo -ne "\033]0;[arm-aosp_arm-eng] spucci@spucci-linux.mtv.corp.google.com: /usr/local/google/home/spucci/android/master\007"

most of which is unneeded if your prompt already includes host+cwd,
and the special characters of which are useless inside emacs.

The script looks at the environment variable and returns only the part inside
brackets, if any.  The best way to invoke the script is via an alias, e.g.,

  alias fix_lunch="PROMPT_COMMAND=\`strip_android_prompt.py\`"

then after running lunch, you'd say

  fix_lunch

"""


from __future__ import print_function
import re
import os
import sys


def main():
  current_env = os.environ.get("PROMPT_COMMAND")
  if not current_env:
    print("No lunch to fix (PROMPT_COMMAND not set)", file=sys.stderr)
    print("")
    exit(0)
  match = re.search("\\[[-_a-z0-9A-Z]+\\]", current_env)
  if not match:
    print("No lunch to fix (PROMPT_COMMAND has unrecognized format)", file=sys.stderr)
    print(current_env)
    exit(0)
  print("echo -ne '%s '" % match.group(0))
  exit(0)


if __name__ == "__main__":
  main()
