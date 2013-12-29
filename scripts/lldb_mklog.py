#!/usr/bin/python2.7

"""This script builds the lldb executable(s).

Run it from a 'build' directory outside of the llvm/../lldb tree to keep
generated files out of the source tree.

"""


import subprocess
import sys


# make $@ 2>&1 | tee make.log
def main():

  logfile = open("make.log", "w")

  proc = subprocess.Popen(["make"] + sys.argv[1:],
                          bufsize=1,
                          stdout=subprocess.PIPE,
                          stderr=subprocess.STDOUT)

  for line in iter(proc.stdout.readline, ""):
    sys.stdout.write(line)
    logfile.write(line)
  proc.wait()


if __name__ == "__main__":
  main()
