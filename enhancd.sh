# Version:    v2.1.4
# Repository: https://github.com/b4b4r07/enhancd
# Author:     b4b4r07 (BABAROT)
# License:    MIT
# Note:
#   this enhancd.sh supports bash and zsh only
#

# __die puts a string to stderr
__die() {
    echo "$1" 1>&2
}

# __unique uniques a stdin contents
__unique() {
    if __empty "$1"; then
        cat <&0
    else
        cat "$1"
    fi | awk '!a[$0]++' 2>/dev/null
}

# __reverse reverses a stdin contents
__reverse() {
    if __empty "$1"; then
        cat <&0
    else
        cat "$1"
    fi | awk -f "$ENHANCD_ROOT/share/reverse.awk"
}

# __available narrows list down to one
__available() {
    local x candidates

    # candidates should be list like "a:b:c" concatenated by a colon
    candidates="$1:"

    while [ -n "$candidates" ]; do
        # the first remaining entry
        x=${candidates%%:*}
        # reset candidates
        candidates=${candidates#*:}

        # check if x is __available
        if __has "${x%% *}"; then
            echo "$x"
            return 0
        else
            continue
        fi
    done

    return 1
}

# __empty returns true if $1 is __empty value
__empty() {
    [ -z "$1" ]
}

# __has returns true if $1 exists in the PATH environment variable
__has() {
    if __empty "$1"; then
        return 1
    fi

    type "$1" >/dev/null 2>&1
    return $?
}

# __nl reads lines from the named file or the standard input if the file argument is ommitted,
# applies a configurable line numbering filter operation and writes the result to the standard output
__nl() {
    # d in awk's argument is a delimiter
    awk -v d="${1:-": "}" -f "$ENHANCD_ROOT/share/nl.awk"
}

# enhancd::get_dirstep returns a list of stepwise path
enhancd::get_dirstep() {
    # enhancd::get_dirstep requires $1 that should be a path
    if __empty "$1"; then
        __die "too few arguments"
        return 1
    fi

    local slash c cwd
    slash="$(echo "$1" | sed -e 's@[^/]@@g')"
    # c is a length of all slash(s) in $1
    c="${#slash}"

    # Print a stepwise path
    while [ "$c" -ge 0 ]
    do
        echo "${cwd:=$1}"
        # refresh cwd
        cwd="$(dirname "$cwd")"
        # count down slash
        c="$(expr "$c" - 1)"
    done
}

# enhancd::cat_log outputs the content of the log file or __empty line to stdin
enhancd::cat_log()
{
    if [ -s "$ENHANCD_DIR"/enhancd.log ]; then
        cat "$ENHANCD_DIR"/enhancd.log
    else
        echo
    fi
}

# enhancd::split_path decomposes the path with a slash as a delimiter
enhancd::split_path()
{
    local arg

    awk -v arg="${1:-$PWD}" -f "$ENHANCD_ROOT/share/split_path.awk"
}

# enhancd::get_dirname returns the divided directory name with a slash
enhancd::get_dirname()
{
    local is_uniq dir

    # dir is a target directory that defaults to the PWD
    dir="${1:-$PWD}"

    # uniq is the variable that checks whether there is
    # the duplicate directory in the PWD environment variable
    is_uniq="$(enhancd::split_path "$dir" | sort | uniq -c | sort -nr | head -n 1 | awk '{print $1}')"

    # Tests whether is_uniq is true or false
    if [ "$is_uniq" -eq 1 ]; then
        # is_uniq is true
        enhancd::split_path "$dir"
    else
        # is_uniq is false
        enhancd::split_path "$dir" | awk '{ printf("%d: %s\n", NR, $1); }'
    fi
}

# enhancd::get_abspath regains the path from the divided directory name with a slash
enhancd::get_abspath()
{
    # enhancd::get_abspath requires two arguments
    if [ $# -lt 2 ]; then
        __die "too few arguments"
        return 1
    fi

    # $1 is cwd, $2 is dir
    local cwd dir
    cwd="$(dirname "$1")"

    local num c

    # It searches the directory name from the rear of the PWD,
    # and returns the path to where it was found
    if echo "$2" | command grep -q "[0-9]:"; then
        # When decomposing the PWD with a slash,
        # put the number to it if there is the same directory name.

        # num is a number for identification
        num="$(echo "$2" | cut -d: -f1)"

        local i
        if [ -n "$num" ]; then
            # c is a line number
            c=2

            # It is listed path stepwise
            enhancd::get_dirstep "$1" | __reverse | __nl ":" | command grep "^$num" | cut -d: -f2
        fi
    else
        # If there are no duplicate directory name
        awk -v cwd="$cwd" -v dir="$2" -f "$ENHANCD_ROOT/share/get_abspath.awk"
    fi
}

# enhancd::list returns a directory list for changing directory of enhancd
enhancd::list()
{
    # if no argument is given, read stdin
    if [ -p /dev/stdin ]; then
        cat <&0
    else
        enhancd::cat_log
    fi | __reverse | __unique
    #    ^- needs to be inverted before __unique
}

# enhancd::fuzzy returns a list of hits in the fuzzy search
enhancd::fuzzy()
{
    if __empty "$1"; then
        __die "too few arguments"
        return 1
    fi

    awk -v search_string="$1" -f "$ENHANCD_ROOT/share/fuzzy.awk"
}

# enhancd::narrow returns result narrowed down by $1
enhancd::narrow()
{
    local stdin m

    # Save stdin
    stdin="$(cat <&0)"
    m="$(echo "$stdin" | awk 'tolower($0) ~ /\/.?'"$1"'[^\/]*$/{print $0}' 2>/dev/null)"

    # If m is __empty, do fuzzy-search; otherwise puts m
    if __empty "$m"; then
        echo "$stdin" | enhancd::fuzzy "$1"
    else
        echo "$m"
    fi
}

# enhancd::enumrate returns a list that was decomposed with a slash 
# to the directory path that visited just before
# e.g., /home/lisa/src/github.com
# -> /home
# -> /home/lisa
# -> /home/lisa/src
# -> /home/lisa/src/github.com
enhancd::enumrate()
{
    local dir
    dir="${1:-$PWD}"

    enhancd::get_dirstep "$dir" | __reverse
    if [ -d "$dir" ]; then
        find "$dir" -maxdepth 1 -type d | command grep -v "\/\."
    fi
}

# enhancd::makelog carefully open/close the log
enhancd::makelog()
{
    if [ ! -d "$ENHANCD_DIR" ]; then
        mkdir -p "$ENHANCD_DIR"
    fi

    # an temporary variable
    local esc

    # Create ~/.enhancd/enhancd.log
    touch "$ENHANCD_DIR"/enhancd.log

    # Prepare a temporary file for overwriting
    esc="$ENHANCD_DIR"/enhancd."$(date +%d%m%y%H%M%S)"$$$RANDOM

    # $1 should be a function name
    # Run $1 process, and puts to the temporary file
    if __empty "$1"; then
        enhancd::list | __reverse >"$esc"
    else
        $1 >"$esc"
    fi

    # Create a backup in preparation for the failure of the overwriting
    cp -f "$ENHANCD_DIR"/enhancd.log "$ENHANCD_DIR"/enhancd.backup
    rm -f "$ENHANCD_DIR"/enhancd.log

    # Run the overwrite process
    mv "$esc" "$ENHANCD_DIR"/enhancd.log 2>/dev/null

    # Restore from the backup if overwriting fails
    if [ $? -eq 0 ]; then
        rm -f "$ENHANCD_DIR"/enhancd.backup
    else
        cp -f "$ENHANCD_DIR"/enhancd.backup "$ENHANCD_DIR"/enhancd.log
    fi
}

# enhancd::refresh returns the result of removing a directory that does not exist from the log
enhancd::refresh()
{
    local line

    # Remove all to a directory that does not exist
    while read line
    do
        [ -d "$line" ] && echo "$line"
    done <"$ENHANCD_DIR"/enhancd.log
}

# enhancd::assemble returns the assembled log
enhancd::assemble()
{
    enhancd::enumrate
    enhancd::cat_log
    pwd
}

# enhancd::add adds a current working directory path to the log
enhancd::add()
{
    # No overlaps and no underlaps in the log
    if [ ! -f "$ENHANCD_DIR"/enhancd.log -o "$(tail -n 1 "$ENHANCD_DIR"/enhancd.log)" = "$PWD" ]; then
        return 0
    fi

    pwd >>"$ENHANCD_DIR"/enhancd.log
}

# enhancd::interface searches the directory that in the given list, 
# and extracts with the filter if the list __has several paths, 
# otherwise, call enhancd::builtin function
enhancd::interface()
{
    # Sets default values to ENHANCD_FILTER if it is __empty
    if __empty "$ENHANCD_FILTER"; then
        ENHANCD_FILTER="fzf:peco:percol:gof:pick:icepick:sentaku:selecta"
        export ENHANCD_FILTER
    fi

    # Narrows the ENHANCD_FILTER environment variables down to one
    # and sets it to the variables filter
    local filter
    filter="$(__available "$ENHANCD_FILTER")"
    if __empty "$ENHANCD_FILTER"; then
        __die '$ENHANCD_FILTER not set'
        return 1
    elif __empty "$filter"; then
        __die "$ENHANCD_FILTER is invalid \$ENHANCD_FILTER"
        return 1
    fi

    # Check if options are specified
    # If you pass a double-dot (..) as an argument to enhancd::interface
    if [ "$1" = ".." ]; then
        shift
        local flag_dot
        flag_dot="enable"
    fi

    # The list should be a directory list separated by a newline (\n).
    # e.g.,
    #   /home/lisa/src
    #   /home/lisa/work/temp
    local list
    list="$1"

    # If no argument is given to enhancd::interface
    if __empty "$list"; then
        __die "enhancd::interface requires an argument at least"
        return 1
    fi

    # Count lines in the list
    local wc
    wc="$(echo "$list" | command grep -c "")"

    # main conditional branch
    case "$wc" in
        0 )
            # Unbelievable branch
            __die "$LINENO: something is wrong"
            return 1
            ;;
        1 )
            # If you pass a double-dot (..) as an argument to enhancd::interface
            if [ "$flag_dot" = "enable" ]; then
                builtin cd "$(enhancd::get_abspath "$PWD" "$list")"
                return $?
            fi

            # A regular behavior
            if [ -d "$list" ]; then
                builtin cd "$list"
            else
                __die "$list: no such file or directory"
                return 1
            fi
            ;;
        * )
            local t
            t="$(echo "$list" | eval "$filter")"
            if ! __empty "$t"; then
                # If you pass a double-dot (..) as an argument to enhancd::interface
                if [ "$flag_dot" = "enable" ]; then
                    builtin cd "$(enhancd::get_abspath "$PWD" "$t")"
                    return $?
                fi

                # A regular behavior
                if [ -d "$t" ]; then
                    builtin cd "$t"
                else
                    __die "$t: no such file or directory"
                    return 1
                fi
            fi
            ;;
    esac
}

# cd is redefined shell builtin cd function and is overrided
#
# SYNOPSIS
#     cd [-] [DIR]
#
# DESCRIPTION
#     Change the current directory to DIR. The default DIR is all directories that
#     you visited in the past in the value of the ENHANCD_LOG(ENHANCD_DIR/enhancd.log)
#     shell variable
#
#     The variable ENHANCD_FILTER defines a visual filter command you want to use
#     The visual filter such as peco and fzf in ENHANCD_FILTER are separated by a colon (:)
#
#     Options:
#         -     latest 10 histories that do not include the current directory
#         ..    like zsh-bd
#
#     Exit Status:
#     Returns 0 if the directory is changed; non-zero otherwise
#
enhancd::cd()
{
    # In zsh it will cause field splitting to be performed
    # on unquoted parameter expansions.
    if __has "setopt" && ! __empty "$ZSH_VERSION"; then
        # Note in particular the fact that words of unquoted parameters are not
        # automatically split on whitespace unless the option SH_WORD_SPLIT is set;
        # see references to this option below for more details.
        # This is an important difference from other shells.
        # (Zsh Manual 14.3 Parameter Expansion)
        setopt localoptions SH_WORD_SPLIT
    fi

    # Read from standard input
    if [ -p /dev/stdin ]; then
        local stdin
        stdin="$(cat <&0)"
        if [ -d "$stdin" ]; then
            builtin cd "$stdin"
            return $?
        else
            __die "$stdin: no such file or directory"
            return 1
        fi
    fi

    # t is an argument of the list for enhancd::interface
    local t

    # First of all, this enhancd::makelog and enhancd::refresh function creates it
    # if the enhancd history file does not exist
    enhancd::makelog
    # Then, remove non existing directories from the history and refresh it
    enhancd::makelog "enhancd::refresh"

    # If a hyphen is passed as the argument,
    # searchs from the last 10 directory items in the log
    if [ "$1" = "-" ]; then
        if [ "$ENHANCD_DISABLE_HYPHEN" -ne 0 ]; then
            builtin cd -
            return $?
        else
            t="$(enhancd::list | command grep -v "^$PWD$" | head | enhancd::narrow "$2")"
            enhancd::interface "${t:-$2}"
            return $?
        fi
    fi

    # If a double-dot is passed as the argument,
    # it behaves like a zsh-bd plugin
    # In short, you can jump back to a specific directory,
    # without doing `cd ../../..`
    if [ "$1" = ".." ] && [ "$ENHANCD_DISABLE_DOT" -eq 0 ]; then
        t="$(enhancd::get_dirname "$PWD" | __reverse | command grep "$2")"
        enhancd::interface ".." "${t:-$2}"
        return $?
    fi

    # Process a regular argument
    # If a given argument is a directory that exists already,
    # call builtin cd function; enhancd::interface otherwise
    if [ -d "$1" ]; then
        builtin cd "$1"
    else
        # If no argument is given, imitate builtin cd command and rearrange
        # the history so that the HOME environment variable could be latest
        if __empty "$1"; then
            t="$({ enhancd::cat_log; echo "$HOME"; } | enhancd::list)"
        else
            t="$(enhancd::list | enhancd::narrow "$1")"
        fi

        # trim PWD
        t="$(echo "$t" | command grep -v "^$PWD$")"

        # If the t is __empty, pass $1 to enhancd::interface instead of the t
        enhancd::interface "${t:-$1}"
    fi

    # Finally, assemble the cd history
    enhancd::makelog "enhancd::assemble"

    # Add $PWD to the enhancd log
    enhancd::add
}
