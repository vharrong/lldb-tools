#!/usr/bin/python

# Pushes to the appropriate branch, as with
#
#    git push origin HEAD:refs/for/<branch>%r=<reviewer>@google.com
#
# by typing
#
#    lldb-gerrit-push.py <reviewer>  [<branch>]
#
# where <branch> defaults to "master"

import sys
import os

def usage_and_die():
    print "Usage:  lldb-gerrit-push.py  <reviewer>  [<branch>]"
    exit(1)

# TODO: Check that current sandbox is properly a branch with a single unpushed commit

# TODO: Store/restore reviewer for this branch/repository?

if len(sys.argv) < 2:
    print "Need reviewer!"
    usage_and_die()

reviewer = sys.argv[1]
if not reviewer.endswith("@google.com"):
    if (reviewer.find("@") >= 0):
        print "Reviewer should be @google.com address, not", reviewer
        usage_and_die()
    reviewer += "@google.com"
#print "Reviewer: ", reviewer

# TODO: Add check that reviewer is valid google ldap
# TODO: (optionally) add cc=lldb@google.com

if len(sys.argv) < 3:
    # TODO: Determine appropriate branch name from current sandbox
    # No branch, assume master
    branch = "master"
else:
    branch = sys.argv[2]

#print "Branch: ", branch

command = "git push origin HEAD:refs/for/" + branch + "%r=" + reviewer

print command
os.system(command)
