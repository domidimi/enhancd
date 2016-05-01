#!/bin/bash

# definition
fzf() { :; }

true=0
false=1

. ./init.sh || exit 1

test_text="$(cat <<EOF
aaa
bbb
aaa
ccc
EOF
)"

describe "enhancd"
  describe "normal function"

    it "__unique"
      expect="aaa\nbbb\nccc"
      actual="$(echo "$test_text" | __unique)"
      assert equal "$expect" "$actual"
    end

    it "__reverse"
      expect="ccc\naaa\nbbb\naaa"
      actual="$(echo "$test_text" | __reverse)"
      assert equal "$expect" "$actual"
    end

    it "__available"
      assert equal "$(__available "notfunc:fzf:peco")" "fzf"
    end

    it "__available (space)"
      assert equal "$(__available "notfunc:fzf --select-1:peco")" "fzf --select-1"
    end

    it "__empty"
      __empty ""
      assert equal $? $true
    end

    it "__has"
      __has "ls"
      assert equal $? $true
    end

    it "__nl 1"
      expect="1: aaa\n2: bbb\n3: aaa\n4: ccc"
      actual="$(echo "$test_text" | __nl)"
      assert equal "$expect" "$actual"
    end

    it "__nl 2"
      expect="1-aaa\n2-bbb\n3-aaa\n4-ccc"
      actual="$(echo "$test_text" | __nl "-")"
      assert equal "$expect" "$actual"
    end
  end

  describe "cd function"
    it "enhancd::get_dirstep"
      expect="$(cat <<EOF
/home/lisa/work/dir/someA
/home/lisa/work/dir
/home/lisa/work
/home/lisa
/home
/
EOF
)"
      actual="$(enhancd::get_dirstep /home/lisa/work/dir/someA)"
      assert equal "$expect" "$actual"
    end

    it "enhancd::split_path"
      expect="$(cat <<EOF
/
home
lisa
work
dir
EOF
)"
      actual="$(enhancd::split_path /home/lisa/work/dir/someA)"
      assert equal "$expect" "$actual"
    end

    it "enhancd::get_dirname"
      expect="$(cat <<EOF
/
home
lisa
work
dir
EOF
)"
      actual="$(enhancd::get_dirname /home/lisa/work/dir/someA)"
      assert equal "$expect" "$actual"
    end

    it "enhancd::get_abspath"
    end

    it "enhancd::list"
      expect="$(cat <<EOF
ccc
aaa
bbb
EOF
)"
      actual="$(echo "$test_text" | enhancd::list)"
      assert equal "$expect" "$actual"
    end

    it "enhancd::fuzzy"
      text="$(cat <<EOF
/home/lisa/work/dir/test
/home/lisa/work/dir/abcd
/home/lisa/work/dir/efgh
EOF
)"
      expect="/home/lisa/work/dir/test"
      actual="$(echo "$text" | enhancd::fuzzy post)"
      assert equal "$expect" "$actual"
    end

    it "enhancd::narrow"
      text="$(cat <<EOF
/home/lisa/work/dir/test
/home/lisa/work/dir/abcd
/home/lisa/work/dir/efgh
EOF
)"
      expect="/home/lisa/work/dir/abcd"
      actual="$(echo "$text" | enhancd::narrow a)"
      assert equal "$expect" "$actual"
    end

    it "enhancd::narrow (ignore case)"
      text="$(cat <<EOF
/home/lisa/work/dir/test
/home/lisa/work/dir/Abcd
/home/lisa/work/dir/Efgh
EOF
)"
      expect="/home/lisa/work/dir/Abcd"
      actual="$(echo "$text" | enhancd::narrow a)"
      assert equal "$expect" "$actual"
    end

    it "enhancd::enumrate"
      expect="$(cat <<EOF
/
/home
/home/lisa
/home/lisa/src
/home/lisa/src/github.com
EOF
)"
      actual="$(enhancd::enumrate /home/lisa/src/github.com)"
      assert equal "$expect" "$actual"
    end

    it "enhancd::interface"
      # before
      list="$(cat <<EOF
$HOME/enhancd_testA
$HOME/enhancd_testB
EOF
)"
      mkdir -p ~/enhancd_test{A,B}
      fzf() { head -n 1; }
      export ENHANCD_FILTER=fzf

      # test
      expect="$HOME/enhancd_testA"
      actual="$(enhancd::interface "$list" && pwd)"
      assert equal "$expect" "$actual"

      # after
      rmdir ~/enhancd_test{A,B}
    end

    it "enhancd::interface .."
      # before
      list="$(cat <<EOF
a
b
c
EOF
)"
      mkdir -p ~/enhancd_test/a/b/c/d/e/f
      builtin cd ~/enhancd_test/a/b/c/d/e/f
      fzf() { head -n 2 | tail -n 1; }
      export ENHANCD_FILTER=fzf

      # test
      expect="$HOME/enhancd_test/a/b"
      actual="$(enhancd::interface ".." "$list" && pwd)"
      assert equal "$expect" "$actual"

      # after
      rm -r ~/enhancd_test
    end


    it "enhancd::interface .. w/ dup"
      # before
      list="$(cat <<EOF
a
b
c
EOF
)"
      mkdir -p ~/enhancd_test/a/b/c/d.c/e/f
      builtin cd ~/enhancd_test/a/b/c/d.c/e/f
      fzf() { tail -n 1; }
      export ENHANCD_FILTER=fzf

      # test
      expect="$HOME/enhancd_test/a/b/c"
      actual="$(enhancd::interface ".." "$list" && pwd)"
      assert equal "$expect" "$actual"

      # after
      rm -r ~/enhancd_test
    end

  end
end
