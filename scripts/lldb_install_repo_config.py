#!/usr/bin/env python

"""Install a version of the repo submodule git_config.py.

Find the .repo directory which controls the working directory,
and installs a version of git_config.py in that directory
which allows 'repo upload' to work on sso:// repositories
like lldb/tools.

"""


import filecmp
import os
import shutil
import sys

import lldb_utils


def main():
  # determine .repo directory
  repo_parent_dir = lldb_utils.FindParentInParentChain(".repo")
  if not repo_parent_dir:
    print "Error: no .repo in parent directory chain"
    exit(1)

  repo_dir = repo_parent_dir + "/.repo/repo"

  dest = repo_dir + "/git_config.py"
  src = os.path.dirname(sys.argv[0]) + "/support/git_config.py"

  if filecmp.cmp(src, dest):
    print "custom git_config.py already installed in " + dest
    return

  print "rm " + dest
  os.remove(dest)
  print "cp " + src + " " + dest
  shutil.copyfile(src, dest)


if __name__ == "__main__":
  main()
