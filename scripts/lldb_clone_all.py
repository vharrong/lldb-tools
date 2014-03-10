#!/usr/bin/env python

"""Do a git clone on the Google-internal repos required for lldb.

Specifically:
 * lldb/llvm  => llvm
 * lldb/clang => llvm/tools/clang
 * lldb/lldb  => llvm/tools/lldb

"""


import os


import lldb_utils


def main():
  if lldb_utils.RunInDirectory(".",
                               ("git", "clone", "sso://team/lldb/llvm")) != 0:
    print "Error: failed to clone llvm (see errors above)"
    exit(1)

  if lldb_utils.RunInDirectory(os.path.join("llvm", "tools"),
                               ("git", "clone", "sso://team/lldb/clang")) != 0:
    print "Error: failed to clone clang (see errors above)"
    exit(1)

  if lldb_utils.RunInDirectory(os.path.join("llvm", "tools"),
                               ("git", "clone", "sso://team/lldb/lldb")) != 0:
    print "Error: failed to clone lldb (see errors above)"
    exit(1)


if __name__ == "__main__":
  main()
