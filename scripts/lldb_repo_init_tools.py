#!/usr/bin/env python


"""Do a repo init+sync on the Google-internal lldb 'tools' repo.

Typically you will do this in your ~/lldb directory.

"""


# Python built-in modules
import os
import subprocess


# Our modules
import lldb_utils
import workingdir


def main():
  lldb_utils.RequireProdaccess()

  # Make tools directory if necessary
  os.makedirs("tools")

  with workingdir.WorkingDir("tools"):
    command_tokens = ("repo", "init", "-u", "sso://team/lldb/tools-manifests")
    print " ".join(command_tokens)
    status = subprocess.call(command_tokens)
    if status != 0:
      print "repo command failed (see above)."
      return status

    command_tokens = ("repo", "sync")
    print " ".join(command_tokens)
    status = subprocess.call(command_tokens)
    if status != 0:
      print "repo command failed (see above)."
      return status

    return status


if __name__ == "__main__":
  exit(main())
