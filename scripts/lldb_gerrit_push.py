#!/usr/bin/python

"""Pushes with git to the appropriate branch for the current directory.

Example:

    lldb_gerrit_push.py <reviewer>  [<branch>]

(where <branch> defaults to "master") will generate and execute the following
command:

    git push origin HEAD:refs/for/<branch>%r=<reviewer>@google.com

"""

import os
import sys


def UsageAndDie():
  print "Usage:  lldb_gerrit_push.py  <reviewer>  [<branch>]"
  exit(1)


def main():
  # TODO(spucci): Check that current sandbox is properly a branch with a
  #               single unpushed commit

  # TODO(spucci): Store/restore reviewer for this branch/repository?

  if len(sys.argv) < 2:
    print "Need reviewer!"
    UsageAndDie()

  reviewer = sys.argv[1]
  if not reviewer.endswith("@google.com"):
    if reviewer.find("@") >= 0:
      print "Reviewer should be @google.com address, not", reviewer
      UsageAndDie()
    reviewer += "@google.com"
    # print "Reviewer: ", reviewer

    # TODO(spucci): Add check that reviewer is valid google ldap
    # TODO(spucci): (optionally) add cc=lldb@google.com

  if len(sys.argv) < 3:
    # TODO(spucci): Determine appropriate branch name from current sandbox
    # No branch, assume master
    branch = "master"
  else:
    branch = sys.argv[2]

  # print "Branch: ", branch

  command = "git push origin HEAD:refs/for/" + branch + "%r=" + reviewer

  print command
  os.system(command)


if __name__ == "__main__":
  main()
