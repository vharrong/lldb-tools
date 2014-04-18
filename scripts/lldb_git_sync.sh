#!/bin/sh
echo "executing from $(pwd)"
pushd llvm

git pull origin master

pushd tools/clang
git pull origin master
popd

pushd tools/lldb
GIT_BRANCH=$(git branch | awk '/^* / { print $2; }')
if [ "$GIT_BRANCH" = "master" ]; then
    echo "on master branch: pulling origin master"
    git pull origin master
    if [ "$?" - eq 0 ]; then
        echo "git pull origin master succeeded"
    else
        echo "git pull origin master failed"
        exit 1
    fi
else
    echo "on branch $GIT_BRANCH: fetching origin master"
    git fetch origin master
    if [ "$?" -eq 0 ]; then
        echo "rebasing origin/master"
        git rebase origin/master
        if [ "$?" -eq 0 ]; then
            echo "success rebasing lldb"
            exit 0
        else
            echo "failed to rebase lldb"
            exit 1
        fi
    else
        echo "git fetch origin master failed"
        exit 1
    fi
fi
