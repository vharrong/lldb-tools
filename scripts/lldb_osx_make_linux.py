#!/usr/bin/env python

import getpass
import os
import os.path
import re
import subprocess

_USER = getpass.getuser()

_COMMON_SYNC_OPTS = "-avzhe ssh"
_COMMON_EXCLUDE_OPTS = "--exclude=DerivedData --exclude=.svn --exclude=.git --exclude=llvm-build/Release+Asserts"

_LINUX_SYNC_ROOT_PATH = "lldb/macosx.sync"
_LOCAL_SYNC_LLDB_PATH = os.getcwd()

_REMOTE_HOSTNAME = "tfiala2.mtv.corp.google.com"


def sync_llvm():
    commandline = ['rsync']
    commandline.extend(_COMMON_SYNC_OPTS.split())
    commandline.extend(_COMMON_EXCLUDE_OPTS.split())
    commandline.extend([
        "%s/llvm" % os.path.expanduser(_LOCAL_SYNC_LLDB_PATH),
        "%s@%s:%s" % (_USER, _REMOTE_HOSTNAME, _LINUX_SYNC_ROOT_PATH)])
    return subprocess.call(commandline)


def sync_lldb():
    commandline = ['rsync']
    commandline.extend(_COMMON_SYNC_OPTS.split())
    commandline.extend(_COMMON_EXCLUDE_OPTS.split())
    commandline.extend([
        "--exclude=/lldb/llvm",
        os.path.expanduser(_LOCAL_SYNC_LLDB_PATH),
        "%s@%s:%s/llvm/tools" % (_USER, _REMOTE_HOSTNAME, _LINUX_SYNC_ROOT_PATH)])
    return subprocess.call(commandline)


def maybe_configure():
    commandline = [
        "ssh",
        "%s@%s" % (_USER, _REMOTE_HOSTNAME),
        "cd",
        _LINUX_SYNC_ROOT_PATH,
        "&&",
        "touch",
        "llvm/.git",
        "&&",
        "lldb_configure.py",
        "-c"]
    return subprocess.call(commandline)


def build():
    commandline = [
        "ssh",
        "%s@%s" % (_USER, _REMOTE_HOSTNAME),
        "cd",
        "%s/build" % _LINUX_SYNC_ROOT_PATH,
        "&&",
        "time",
        "ninja"]
    return subprocess.call(commandline)


if __name__ == "__main__":
    sync_llvm()
    sync_lldb()
    maybe_configure()
    build()
