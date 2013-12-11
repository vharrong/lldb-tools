# commands to be sourced into shell startup for lldb dev commands

# reload lldb scripts
function reload_lldb_commands () {
    echo -n "re-sourcing $BASH_SOURCE..."
    source $BASH_SOURCE
    echo "done."
}

# Args:
#   $1 - the variable name in which to return the found directory
#   path.
#
#   $2 - the directory path fragment to find somewhere between `pwd`
#   and somewhere up the parent directory chain.
#
# e.g.
# $ pwd
# /home/tfiala/llvm/work/llvm/tools
# $ find_dir_parent_chain result 'llvm/.git'
# $ echo $?
# 0
# $ echo $result
# /home/tfiala/llvm/work

function find_dir_parent_chain () {
    if [ -z "$1" -o -z "$2" ]; then
        echo "find_dir_parent_chain () requires two arguments"
        return 1
    fi

    local __retvarname=$1
    local dir_suffix=$2

    # find the dir suffix directory.
    # start in current directory, then walk up parent chain.
    local PARENT_DIR=`pwd`
    while test -n "$PARENT_DIR" && test ! -d "$PARENT_DIR/$dir_suffix"; do
        # echo "$dir_suffix dir not found in $PARENT_DIR, checking parent"
        PARENT_DIR=`dirname $PARENT_DIR`
    done

    if [ -d "$PARENT_DIR/$dir_suffix" ]; then
        # echo "found $dir_suffix here: $PARENT_DIR"
        eval $__retvarname="'$PARENT_DIR'"
        return 0
    else
        # echo "failed to find llvm dir starting at $(pwd)"
        return 1
    fi
}

# args:
#   $1: directory in which to run the 'git pull'
#   $2: (optional) the remote to pull from (defaults to: "origin")
#   $3: (optional) the branch mapping to specify (defaults to:
#   "master:master")
#
# Will leave the cwd untouched on exit

function git_pull () {
    local retval

    # validate directory name
    if [ -z "$1" ]; then
        echo "git_pull requires a first argument"
        return 1
    fi
    local command_dir=$1

    # determine remote repo
    local remote_repo
    if [ -n "$2" ]; then
        remote_repo=$2
    else
        remote_repo='origin'
    fi

    # determine branch mapping
    local branch_mapping
    if [ -n "$3" ]; then
        branch_mapping=$3
    else
        branch_mapping=''
    fi

    # do the git pull
    pushd . >/dev/null
    cd $command_dir
    retval=$?
    if [ $retval -ne 0 ]; then
        echo "git_pull: cannot change directory to $command_dir"
        return $retval
    fi

    echo "Executing 'git pull $remote_repo $branch_mapping' in $command_dir"
    git pull $remote_repo $branch_mapping
    retval=$?
    popd >/dev/null

    # indicate result
    return $retval
}

# args:
#   $1: directory in which to run the 'git clone'
#   $2: the git remote path to clone
#
# Will leave the cwd untouched on exit

function git_clone () {
    local retval

    if [ -z "$1" -o -z "$2" ]; then
        echo "usage: git_clone {cwd-for-clone-op} {repo-to-clone}"
        return 1
    fi

    local command_dir=$1
    local remote_repo=$2

    # do the git clone
    pushd . >/dev/null
    cd $command_dir
    retval=$?
    if [ $retval -ne 0 ]; then
        echo "git_clone: cannot change directory to $command_dir"
        return $retval
    fi

    echo "Executing 'git clone $remote_repo' with cwd $command_dir"
    git clone $remote_repo
    retval=$?
    popd >/dev/null

    # indicate result
    return $retval
}

# Do a git clone on the Google-internal lldb/llvm, lldb/clang and
# lldb/lldb directories.  Place them in LLVM standard order:
#
# lldb/llvm  => ./llvm
# lldb/clang => ./llvm/tools/clang
# lldb/lldb  => ./llvm/tools/lldb

function clone_lldb_all () {
    if ! git_clone '.' 'sso://team/lldb/llvm' ; then
        echo "failed to clone llvm"
        return 1
    fi

    if ! git_clone 'llvm/tools' 'sso://team/lldb/clang' ; then
        echo "failed to clone clang"
        return 1
    fi

    if ! git_clone 'llvm/tools' 'sso://team/lldb/lldb' ; then
        echo "failed to clone lldb"
        return 1
    fi
}

# Do a 'git pull origin' from the llvm root directory. Assumes llvm's
# root git directory lies somewhere within the parent directory chain.

function pull_llvm () {
    local llvm_parent_dir
    find_dir_parent_chain "llvm_parent_dir" "llvm/.git"
    local retval=$?
    if [ "$retval" -ne 0 ]; then
        echo "llvm/.git not found within $(pwd)"
        return $retval
    fi
    # echo "llvm/.git found in $llvm_parent_dir"

    # do the git pull
    git_pull "$llvm_parent_dir/llvm"
    retval=$?

    # indicate result
    return $retval
}

# Do a 'git pull origin' from the clang root directory. Assumes the
# current working directory is somewhere under the llvm (although not
# necessarily clang) parent directory chain.

function pull_clang () {
    local llvm_parent_dir
    find_dir_parent_chain "llvm_parent_dir" "llvm/tools/clang/.git"
    local retval=$?
    if [ $retval -ne 0 ]; then
        echo "llvm/tools/clang/.git not found within $(pwd)"
        return $retval
    fi
    # echo "llvm/tools/clang/.git found in $llvm_parent_dir"

    # do the git pull
    git_pull "$llvm_parent_dir/llvm/tools/clang"
    retval=$?

    # indicate result
    return $retval
}

# This command will:
# - stash if any changes exist on the branch
# - change to the master branch
# - pull the remote origin onto master
# - change back to the previous branch
# - rebase the master onto the working branch
# - apply the latest stash
#
# Assumes the user is somewhere underneath the llvm (although
# not necessarily lldb) directory tree.

function pull_lldb_rebase () {
    local retval
    local overall_retval=0
    local pull_remote='origin'
    local pull_local_branch='master'
    local pull_branch_spec=''

    # find lldb directory
    local llvm_parent_dir
    find_dir_parent_chain "llvm_parent_dir" "llvm/tools/lldb/.git"
    local retval=$?
    if [ $retval -ne 0 ]; then
        echo "llvm/tools/lldb/.git not found within $(pwd)"
        return $retval
    fi
    # echo "llvm/tools/lldb/.git found in $llvm_parent_dir"

    local lldb_dir="$llvm_parent_dir/llvm/tools/lldb"

    # change into lldb_dir
    pushd . >/dev/null
    cd $lldb_dir
    retval=$?
    if [ $retval -ne 0 ]; then
        echo "failed to change working directory to $lldb_dir: $retval"
        return retval
    fi

    # stash if any changes exist on the branch
    local stash_result=$(git status -s)
    if [ -n "$stash_result" ]; then
        # Stash the changes.
        #
        # Add anything that is unknown.  We do this in case we're
        # adding something that was also added upstream. This will
        # help understand the merge conflict more readily.
        local unknown_wd_files=$(echo "$stash_result" | grep '^??' | \
            awk ' { print $2 } ')
        if [ -n "$unknown_wd_files" ]; then
            echo "$unknown_wd_files" | xargs git add
            retval=$?
            if [ $retval -ne 0 ]; then
                echo "failed to add local changes to the git repo: $retval"
                popd >/dev/null
                return $retval
            fi
        fi

        echo "stashing branch state"
        git stash save
        retval=$?
        if [ $retval -ne 0 ]; then
            echo "failed to save current working directory state: $?"
            popd >/dev/null
            return $retval
        fi
    else
        echo "no local changes need to be stashed"
    fi

    # get the current branch so we can restore it later
    local old_branch=$(git branch | grep '^*' | awk ' { print $2 } ')
    echo "old branch: $old_branch"

    # checkout the master branch
    git checkout "$pull_local_branch"
    retval=$?
    if [ $retval -ne 0 ]; then
        echo "switching to branch $pull_local_branch failed"
        # mark the call as failing, but allow orderly cleanup
        overall_retval=1
    else
        # do the pull
        git pull $pull_remote $pull_branch_spec
        if [ $retval -ne 0 ]; then
            echo "git pull "$pull_remote" "$pull_branch_spec" failed: $retval"
            overall_retval=1
        fi
    fi

    # change back to the old branch
    git checkout "$old_branch"
    retval=$?
    if [ $retval -ne 0 ]; then
        echo "switching back to branch $old_branch failed: $retval"
        overall_retval=1
    else
        # rebase from the local pull branch
        git rebase "$pull_local_branch"
        retval=$?
        if [ $retval -ne 0 ]; then
            echo "failed to rebase $pull_local_branch onto $old_branch: $retval"
            overall_retval=1
        else
            # reapply the stash
            if [ -n "$stash_result" ]; then
                git stash pop
                retval=$?
                if [ $retval -ne 0 ]; then
                    echo "git stash pop failed: $retval"
                    echo "It is likely you will need to resolve conflicts."
                    overall_retval=1
                fi
            fi
        fi
    fi

    # restore dir
    popd >/dev/null

    return $overall_retval
}

# make_lldb_tags [tags-path, default: LLVM-PARENT:TAGS]
function make_lldb_tags () {
    # find llvm root dir
    local llvm_parent_dir
    find_dir_parent_chain "llvm_parent_dir" "llvm/.git"
    local retval=$?
    if [ "$retval" -ne 0 ]; then
        echo "llvm/.git not found within $(pwd)"
        return $retval
    fi
    echo "Found llvm parent dir: $llvm_parent_dir"

    # figure out tags path name
    local tags_path
    if [ -n "$1" ]; then
	tags_path=$1
    else
	tags_path="$llvm_parent_dir/TAGS"
    fi
    echo "Writing tags file to: $tags_path"

    # run ctags on .h/.cpp files in llvm tree and
    # .h files in /usr/include
    { find /usr/include -name '*.h' -exec echo '"{}"' \; ; \
	find "$llvm_parent_dir/llvm" -name '*.h' -o -name '*cpp' -exec echo '"{}"' \; ; \
    } | xargs ctags -e --c++-kinds=+p --fields=+iaS --extra=+q \
	--language-force=C++ -f $tags_path
    local retval=$?
    if [ $retval -ne 0 ]; then
	echo "failed to generate tags file"
    fi
    return $retval
}

# usage: configure_lldb [INSTALL_DIR]
#   INSTALL_DIR defaults to 'install'.
#
# Runs ../llvm/configure with --prefix=`pwd`/../INSTALL_DIR.
# i.e. assumes it is being run at the top level of a build
# directory, which is assumed to be a sibling of the
# llvm code directory.
#
# This script now checks to make sure that the system does
# not have a clang defined in the path.  Currently this will
# break our build on Goobuntu 12.04, where we assume we
# build with gcc 4.8+.

function configure_lldb () {
    # determine build directory
    local BUILD_DIR
    if [ -n "$1" ]; then
        BUILD_DIR=$1
    else
        BUILD_DIR=build
    fi
    echo Using build dir: $BUILD_DIR

    # setup the configure prefix dir
    local INSTALL_DIR
    if [ -n "$2" ]; then
        INSTALL_DIR=$2
    else
        INSTALL_DIR=install
    fi
    echo Using install dir $INSTALL_DIR

    # fail if there is a clang in the path
    if [ -n "$(which clang)" ]; then
        echo "clang found in path: $(which clang)"
        echo "Our lldb build setup does not support building with clang."
        echo "Please remove clang from your path."
        return 1
    fi

    # find the parent of the llvm directory
    local llvm_parent_dir
    find_dir_parent_chain "llvm_parent_dir" "llvm/.git"
    local retval=$?
    if [ "$retval" -ne 0 ]; then
        echo "llvm/.git not found within $(pwd)"
        return $retval
    fi
    echo "Found llvm parent dir: $llvm_parent_dir"

    # fail if the build directory already exists
    if [ -e "$llvm_parent_dir/$BUILD_DIR" ]; then
        echo "build dir already exists - please delete before running"
        return 1
    fi

    # fail if the install directory already exists
    if [ -e "$llvm_parent_dir/$INSTALL_DIR" ]; then
        echo "install dir already exists - please delete before running"
        return 1
    fi

    # make the build dir
    if ! mkdir $llvm_parent_dir/$BUILD_DIR ; then
        echo "failed to make build dir: $llvm_parent_dir/$BUILD_DIR"
        return 1
    fi

    # remember current dir
    pushd . >/dev/null

    local retval=0

    if cd $llvm_parent_dir/$BUILD_DIR ; then
        # run the configure command
        ../llvm/configure --enable-cxx11 --prefix=`pwd`/../$INSTALL_DIR
        if [ $? -ne 0 ]; then
            echo "configure failed"
            retval=1
        fi
    else
        echo "failed to cd into $llvm_parent_dir/$BUILD_DIR"
        retval=1
    fi

    # restore directory
    popd >/dev/null

    return $retval
}

function mklog () {
    make $@ 2>&1 | tee make.log
}

function mkilog () {
    make $@ install 2>&1 | tee make_install.log
}
