#!/usr/bin/env python


"""Do a repo init+sync on the Google-internal repos required for lldb.

Specifically:
 * lldb/llvm  => llvm
 * lldb/clang => llvm/tools/clang
 * lldb/lldb  => llvm/tools/lldb

using the repo manifest in sso://team/lldb/llvm-manifests

"""


# Python built-in modules
import subprocess


# Our modules
import lldb_utils


def main():
  lldb_utils.RequireProdaccess()

  command_tokens = ("repo", "init", "-u", "sso://team/lldb/llvm-manifests")
  print " ".join(command_tokens)
  status = subprocess.call(command_tokens)
  if status != 0:
    print "git command failed (see above)."

  command_tokens = ("repo", "sync")
  print " ".join(command_tokens)
  status = subprocess.call(command_tokens)
  if status != 0:
    print "repo command failed (see above)."
    return status

  return status


if __name__ == "__main__":
  exit(main())
