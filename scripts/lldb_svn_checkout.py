#!/usr/bin/env python

"""Do an svn checkout on llvm, clang, and lldb."""


# Python built-in modules
import os


# Our modules
import lldb_utils


def main():
  llvm_username = os.environ["USER"]  # FIXME(spucci): This isn't right, but it works for me and tfiala.
                                      #    Fix will be to ask and cache in ~/.llvm_username

  lldb_utils.RunInDirectory(".",
                            ("svn", "checkout", "https://" + llvm_username + "@llvm.org/svn/llvm-project/llvm/trunk", "llvm"))
  lldb_utils.RunInDirectory(os.path.join("llvm", "tools"),
                            ("svn", "checkout", "https://" + llvm_username + "@llvm.org/svn/llvm-project/cfe/trunk", "clang"))
  lldb_utils.RunInDirectory(os.path.join("llvm", "tools"),
                            ("svn", "checkout", "https://" + llvm_username + "@llvm.org/svn/llvm-project/lldb/trunk", "lldb"))


if __name__ == "__main__":
  main()
