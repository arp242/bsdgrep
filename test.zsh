#!/bin/zsh
#
# Test cases from:
# https://github.com/freebsd/freebsd-src/tree/main/contrib/netbsd-tests/usr.bin/grep (3e2d96a)
# https://github.com/freebsd/freebsd-src/tree/main/usr.bin/grep/tests (d0b2dbf)
#
# Hard to port atf to Linux, so just re-implement it in zsh.

dir=$PWD
grep=$dir/grep
fgrep=$dir/grep
egrep=$dir/egrep
rgrep=$dir/rgrep
zgrep=$dir/zgrep.sh
testdata=$dir/testdata
verbose=0
run=()
for f in $argv; do
	case $f in
		-v|-verbose|--verbose) verbose=1 ;;
		*)                     run+=$f   ;;
	esac
done

ln -sf grep egrep
ln -sf grep fgrep
ln -sf grep rgrep

main() {
	integer passed=0
	integer failed=0
	for f in $(typeset -f + | grep '^test-'); do
		if (( $#run > 0 )); then
			found=0
			for r in $run; do
				if [[ $f =~ ".*$r.*" ]]; then
					found=1
					break
				fi
			done
			(( $found )) || continue
		fi

		tmp=$(mktemp -d)
		out=$(cd $tmp && $f 2>&1)
		s=$status

		if (( $s )); then
			failed+=1
			p='FAIL'
		else
			passed+=1
			p='PASS'
		fi
		if (( $verbose || $s )); then
			print -f '=== %-32s %s\n' $f $p
			if [[ -n $out ]]; then
				out=${out//$'\n'/$'\n\t'}
				print -r -- $'\t'$out
			fi
		fi
		rm -rf $tmp
	done

	if (( $verbose || $failed )); then
		p='PASS'
		(( $failed )) && p='FAIL'
		print "\n$p  $passed passed; $failed failed"
	fi
}

# Checks basic functionality
test-basic_body() {
	have=$((for (( i=0; i<10000; i++ )); print $i) | $grep 123 2>&1)  # Fix Vim syntax hl: ))
	diff -u <(print $have) $testdata/d_basic.out || return 1
}

# Checks handling of binary files
test-binary_body() {
	dd if=/dev/zero count=1 of=test.file status=none
	echo -n "foobar" >> test.file

	have=$($grep foobar test.file 2>&1)
	diff -u <(print $have) $testdata/d_binary.out || return 1
}

# Checks recursive searching
test-recurse_body() {
	mkdir -p recurse/a/f recurse/d
	echo -e "cod\ndover sole\nhaddock\nhalibut\npilchard" > recurse/d/fish
	echo -e "cod\nhaddock\nplaice" > recurse/a/f/favourite-fish

	have=$($grep -r haddock recurse |& sort)
	diff -u <(print $have) $testdata/d_recurse.out || return 1
}

#  Checks symbolic link recursion
test-recurse_symlink_body() {
	mkdir -p test/c/d
	(cd test/c/d && ln -s ../d .)
	echo "Test string" > test/c/match

	have=$($grep -r string test 2>&1)
	diff -u <(print $have) $testdata/d_recurse_symlink.out || return 1
}

# Checks word-regexps
test-word_regexps_body() {
	have=$($grep -w separated $testdata/d_input 2>&1)
	diff -u <(print $have) $testdata/d_word_regexps.out || return 1

	printf "xmatch pmatch\n" > test1
	have=$($grep -Eow "(match )?pmatch" test1)

	diff -u <(print $have) <(print 'pmatch') || return 1
}

# Checks handling of line beginnings and ends
test-begin_end_body() {
	have=$($grep ^Front "$testdata/d_input" 2>&1)
	diff -u <(print $have) $testdata/d_begin_end_a.out || return 1

	have=$($grep ending$ "$testdata/d_input" 2>&1)
	diff -u <(print $have) $testdata/d_begin_end_b.out || return 1
}

# Checks ignore-case option
test-ignore_case_body() {
	have=$($grep -i Upper "$testdata/d_input" 2>&1)
	diff -u <(print $have) $testdata/d_ignore_case.out || return 1
}

# Checks selecting non-matching lines with -v option
test-invert_body() {
	have=$($grep -v fish "$testdata/d_invert.in" 2>&1)
	diff -u <(print $have) $testdata/d_invert.out || return 1
}

# Checks whole-line matching with -x flag
test-whole_line_body() {
	have=$($grep -x matchme "$testdata/d_input" 2>&1)
	diff -u <(print $have) $testdata/d_whole_line.out || return 1
}

# Checks handling of files with no matches
test-negative_body() {
	have=$($grep "not a hope in hell" "$testdata/d_input" 2>&1)
	diff -u <(print $have) <(print '') || return 1
}

# Checks displaying context with -A, -B and -C flags
test-context_body() {
	cp $testdata/d_context_*.* .

	diff -u <($grep -C2 bamboo d_context_a.in 2>&1)                      $testdata/d_context_a.out || return 1
	diff -u <($grep -A3 tilt d_context_a.in 2>&1)                        $testdata/d_context_b.out || return 1
	diff -u <($grep -B4 Whig d_context_a.in 2>&1)                        $testdata/d_context_c.out || return 1
	diff -u <($grep -C1 pig d_context_a.in d_context_b.in 2>&1)          $testdata/d_context_d.out || return 1
	diff -u <($grep -E -C1 '(banana|monkey)' d_context_e.in 2>&1)        $testdata/d_context_e.out || return 1
	diff -u <($grep -Ev -B2 '(banana|monkey|fruit)' d_context_e.in 2>&1) $testdata/d_context_f.out || return 1
	diff -u <($grep -Ev -A1 '(banana|monkey|fruit)' d_context_e.in 2>&1) $testdata/d_context_g.out || return 1
}

# Checks reading expressions from file
test-file_exp_body() {
return # TODO
	atf_check -o file:"$testdata/d_file_exp.out" -x \
	    'jot 21 -1 1.00 | $grep -f '"$testdata"'/d_file_exp.in'
}

# Checks matching special characters with egrep
test-egrep_body() {
	have=$($egrep '\?|\*$$' "$testdata/d_input" 2>&1)
	diff -u <(print $have) $testdata/d_egrep.out || return 1
}

# Checks handling of gzipped files with zgrep
test-zgrep_body() {
	cp "$testdata/d_input" .
	gzip d_input || return 1

	have=$($zgrep -h line d_input.gz 2>&1)
	diff -u <(print $have) $testdata/d_zgrep.out || return 1
}

# Checks for zgrep wrapper problems with combined flags (PR 247126)
test-zgrep_combined_flags_body() {
return # TODO
	atf_expect_fail "known but unsolved zgrep wrapper script regression"

	echo 'foo bar' > test

	atf_check -o inline:"foo bar\n" $zgrep -we foo test
	# Avoid hang on reading from stdin in the failure case
	atf_check -o inline:"foo bar\n" $zgrep -wefoo test < /dev/null
}

# Checks for zgrep wrapper problems with -e PATTERN (PR 247126)
test-zgrep_eflag_body() {
return # TODO
	echo 'foo bar' > test

	# Avoid hang on reading from stdin in the failure case
	atf_check -o inline:"foo bar\n" $zgrep -e 'foo bar' test < /dev/null
	atf_check -o inline:"foo bar\n" $zgrep --regexp='foo bar' test < /dev/null
}

# Checks for zgrep wrapper problems with -f FILE (PR 247126)
test-zgrep_fflag_body() {
return # TODO
	echo foo > pattern
	echo foobar > test

	# Avoid hang on reading from stdin in the failure case
	atf_check -o inline:"foobar\n" $zgrep -f pattern test </dev/null
	atf_check -o inline:"foobar\n" $zgrep --file=pattern test </dev/null
}

# Checks for zgrep wrapper problems with --ignore-case reading from stdin (PR 247126)
test-zgrep_long_eflag_body() {
return # TODO
	echo foobar > test

	atf_check -o inline:"foobar\n" $zgrep -e foo --ignore-case < test
}

# Checks for zgrep wrapper problems with multiple -e flags (PR 247126)
test-zgrep_multiple_eflags_body() {
return # TODO
	atf_expect_fail "known but unsolved zgrep wrapper script regression"

	echo foobar > test

	atf_check -o inline:"foobar\n" $zgrep -e foo -e xxx test
}

# Checks for zgrep wrapper problems with empty -e flags pattern (PR 247126)
test-zgrep_empty_eflag_body() {
return # TODO
	echo foobar > test

	atf_check -o inline:"foobar\n" $zgrep -e '' test
}

# Checks that -s flag suppresses error messages about nonexistent files
test-nonexistent_body() {
return # TODO
	atf_check -s ne:0 $grep -s foobar nonexistent
}

# Checks displaying context with -z flag
test-context2_body() {
return # TODO
	printf "haddock\000cod\000plaice\000" > test1
	printf "mackeral\000cod\000crab\000" > test2

	atf_check -o file:"$testdata/d_context2_a.out" $grep -z -A1 cod test1 test2
	atf_check -o file:"$testdata/d_context2_b.out" $grep -z -B1 cod test1 test2
	atf_check -o file:"$testdata/d_context2_c.out" $grep -z -C1 cod test1 test2
}

# Check behavior of zero-length matches with -o flag (PR 195763)
test-oflag_zerolen_body() {
return # TODO
	atf_check -o file:"$testdata/d_oflag_zerolen_a.out" $grep -Eo '(^|:)0*' "$testdata/d_oflag_zerolen_a.in"
	atf_check -o file:"$testdata/d_oflag_zerolen_b.out" $grep -Eo '(^|:)0*' "$testdata/d_oflag_zerolen_b.in"
	atf_check -o file:"$testdata/d_oflag_zerolen_c.out" $grep -Eo '[[:alnum:]]*' "$testdata/d_oflag_zerolen_c.in"
	atf_check -o empty $grep -Eo '' "$testdata/d_oflag_zerolen_d.in"
	atf_check -o file:"$testdata/d_oflag_zerolen_e.out" $grep -o -e 'ab' -e 'bc' "$testdata/d_oflag_zerolen_e.in"
	atf_check -o file:"$testdata/d_oflag_zerolen_e.out" $grep -o -e 'bc' -e 'ab' "$testdata/d_oflag_zerolen_e.in"
}

# Check that we actually get a match with -x flag (PR 180990)
test-xflag_body() {
return # TODO
	echo 128 > match_file
	seq 1 128 > pattern_file
	$grep -xf pattern_file match_file
}

# Check --color support
test-color_body() {
return # TODO
	echo 'abcd*' > grepfile
	echo 'abc$' >> grepfile
	echo '^abc' >> grepfile

	atf_check -o file:"$testdata/d_color_a.out" $grep --color=auto -e '.*' -e 'a' "$testdata/d_color_a.in"
	atf_check -o file:"$testdata/d_color_b.out" $grep --color=auto -f grepfile "$testdata/d_color_b.in"
	atf_check -o file:"$testdata/d_color_c.out" $grep --color=always -f grepfile "$testdata/d_color_b.in"
}

# Check for handling of a null byte in empty file, specified by -f (PR 202022)
test-f_file_empty_body() {
return # TODO
	printf "\0\n" > nulpat

	atf_check -s exit:1 $grep -f nulpat "$testdata/d_f_file_empty.in"
}

# Check proper handling of escaped vs. unescaped dot expressions (PR 175314)
test-escmap_body() {
return # TODO
	atf_check -s exit:1 $grep -o 'f.o\.' "$testdata/d_escmap.in"
	atf_check -o not-empty $grep -o 'f.o.' "$testdata/d_escmap.in"
}

# Check for handling of an invalid empty pattern (PR 194823)
test-egrep_empty_invalid_body() {
return # TODO
	atf_check -e ignore -s not-exit:0 $egrep '{' /dev/null
}

# Check for successful zero-length matches with ^$
test-zerolen_body() {
return # TODO
	printf "Eggs\n\nCheese" > test1
	atf_check -o inline:"\n" $grep -e "^$" test1
	atf_check -o inline:"Eggs\nCheese\n" $grep -v -e "^$" test1
}

# Check for proper handling of -w with an empty pattern (PR 105221)
test-wflag_emptypat_body() {
return # TODO
	printf "" > test1
	printf "\n" > test2
	printf "qaz" > test3
	printf " qaz\n" > test4

	atf_check -s exit:1 -o empty $grep -w -e "" test1
	atf_check -o file:test2 $grep -vw -e "" test2
	atf_check -s exit:1 -o empty $grep -w -e "" test3
	atf_check -o file:test4 $grep -vw -e "" test4
}

test-xflag_emptypat_body() {
return # TODO
	printf "" > test1
	printf "\n" > test2
	printf "qaz" > test3
	printf " qaz\n" > test4

	atf_check -s exit:1 -o empty $grep -x -e "" test1
	atf_check -o file:test2 $grep -x -e "" test2
	atf_check -s exit:1 -o empty $grep -x -e "" test3
	atf_check -s exit:1 -o empty $grep -x -e "" test4
	total=$(wc -l /COPYRIGHT | sed 's/[^0-9]//g')

	# Simple checks that grep -x with an empty pattern isn't matching every
	# line.  The exact counts aren't important, as long as they don't
	# match the total line count and as long as they don't match each other.
	atf_check -o save:xpositive.count $grep -Fxc '' /COPYRIGHT
	atf_check -o save:xnegative.count $grep -Fvxc '' /COPYRIGHT

	atf_check -o not-inline:"${total}" cat xpositive.count
	atf_check -o not-inline:"${total}" cat xnegative.count

	atf_check -o not-file:xnegative.count cat xpositive.count
}

test-xflag_emptypat_plus_body() {
return # TODO
	printf "foo\n\nbar\n\nbaz\n" > target
	printf "foo\n \nbar\n \nbaz\n" > target_spacelines
	printf "foo\nbar\nbaz\n" > matches
	printf " \n \n" > spacelines

	printf "foo\n\nbar\n\nbaz\n" > patlist1
	printf "foo\n\nba\n\nbaz\n" > patlist2

	sed -e '/bar/d' target > matches_not2

	# Normal handling first
	atf_check -o file:target $grep -Fxf patlist1 target
	atf_check -o file:matches $grep -Fxf patlist1 target_spacelines
	atf_check -o file:matches_not2 $grep -Fxf patlist2 target

	# -v handling
	atf_check -s exit:1 -o empty $grep -Fvxf patlist1 target
	atf_check -o file:spacelines $grep -Fxvf patlist1 target_spacelines
}

# Check for proper handling of empty pattern files (PR 253209)
test-emptyfile_body() {
return # TODO
	:> epatfile
	echo "blubb" > subj

	# From PR 253209, bsdgrep was short-circuiting completely on an empty
	# file, but we should have still been processing lines.
	atf_check -s exit:1 -o empty $fgrep -f epatfile subj
	atf_check -o file:subj $fgrep -vf epatfile subj
}

# Check for proper handling of lines with excessive matches (PR 218811)
test-excessive_matches_body() {
return # TODO
	for i in $(jot 4096); do
		printf "x" >> test.in
	done

	atf_check -s exit:0 -x '[ $($grep -o x test.in | wc -l) -eq 4096 ]'
	atf_check -s exit:1 -x '$grep -on x test.in | $grep -v "1:x"'
}

# Check for fgrep sanity, literal expressions only
test-fgrep_sanity_body() {
return # TODO
	printf "Foo" > test1

	atf_check -o inline:"Foo\n" $fgrep -e "Foo" test1

	atf_check -s exit:1 -o empty $fgrep -e "Fo." test1
}

# Check for egrep sanity, EREs only
test-egrep_sanity_body() {
return # TODO
	printf "Foobar(ed)" > test1
	printf "M{1}" > test2

	atf_check -o inline:"Foo\n" $egrep -o -e "F.." test1
	atf_check -o inline:"Foobar\n" $egrep -o -e "F[a-z]*" test1
	atf_check -o inline:"Fo\n" $egrep -o -e "F(o|p)" test1
	atf_check -o inline:"(ed)\n" $egrep -o -e "\(ed\)" test1
	atf_check -o inline:"M\n" $egrep -o -e "M{1}" test2
	atf_check -o inline:"M{1}\n" $egrep -o -e "M\{1\}" test2
}

# Check for basic grep sanity, BREs only
test-grep_sanity_body() {
return # TODO
	printf "Foobar(ed)" > test1
	printf "M{1}" > test2

	atf_check -o inline:"Foo\n" $grep -o -e "F.." test1
	atf_check -o inline:"Foobar\n" $grep -o -e "F[a-z]*" test1
	atf_check -o inline:"Fo\n" $grep -o -e "F\(o\)" test1
	atf_check -o inline:"(ed)\n" $grep -o -e "(ed)" test1
	atf_check -o inline:"M{1}\n" $grep -o -e "M{1}" test2
	atf_check -o inline:"M\n" $grep -o -e "M\{1\}" test2
}

# Check for incorrectly matching lines with both -w and -v flags (PR 218467)
test-wv_combo_break_body() {
return # TODO
	printf "x xx\n" > test1
	printf "xx x\n" > test2

	atf_check -o file:test1 $grep -w "x" test1
	atf_check -o file:test2 $grep -w "x" test2

	atf_check -s exit:1 $grep -v -w "x" test1
	atf_check -s exit:1 $grep -v -w "x" test2
}

# Check for -n/-b producing per-line metadata output
test-ocolor_metadata_body() {
return # TODO
	printf "xxx\nyyyy\nzzz\nfoobarbaz\n" > test1
	check_expr="^[^:]*[0-9][^:]*:[^:]+$"

	atf_check -o inline:"1:1:xx\n" $grep -bon "xx$" test1
	atf_check -o inline:"2:4:yyyy\n" $grep -bn "yy" test1
	atf_check -o inline:"2:6:yy\n" $grep -bon "yy$" test1

	# These checks ensure that grep isn't producing bogus line numbering
	# in the middle of a line.
	atf_check -s exit:1 -x "$grep -Eon 'x|y|z|f' test1 | $grep -Ev '${check_expr}'"
	atf_check -s exit:1 -x "$grep -En 'x|y|z|f' --color=always test1 | $grep -Ev '${check_expr}'"
	atf_check -s exit:1 -x "$grep -Eon 'x|y|z|f' --color=always test1 | $grep -Ev '${check_expr}'"
}

# Check for no match (-c, -l, -L, -q) flags not producing line matches or context (PR 219077)
test-grep_nomatch_flags_body() {
return # TODO
	printf "A\nB\nC\n" > test1

	atf_check -o inline:"1\n" $grep -c -C 1 -e "B" test1
	atf_check -o inline:"1\n" $grep -c -B 1 -e "B" test1
	atf_check -o inline:"1\n" $grep -c -A 1 -e "B" test1
	atf_check -o inline:"1\n" $grep -c -C 1 -e "B" test1

	atf_check -o inline:"test1\n" $grep -l -e "B" test1
	atf_check -o inline:"test1\n" $grep -l -B 1 -e "B" test1
	atf_check -o inline:"test1\n" $grep -l -A 1 -e "B" test1
	atf_check -o inline:"test1\n" $grep -l -C 1 -e "B" test1

	atf_check -o inline:"test1\n" $grep -L -e "D" test1

	atf_check -o empty $grep -q -e "B" test1
	atf_check -o empty $grep -q -B 1 -e "B" test1
	atf_check -o empty $grep -q -A 1 -e "B" test1
	atf_check -o empty $grep -q -C 1 -e "B" test1
}

# Check for handling of invalid context arguments
test-badcontext_body() {
return # TODO
	printf "A\nB\nC\n" > test1

	atf_check -s not-exit:0 -e ignore $grep -A "-1" "B" test1
	atf_check -s not-exit:0 -e ignore $grep -B "-1" "B" test1
	atf_check -s not-exit:0 -e ignore $grep -C "-1" "B" test1
	atf_check -s not-exit:0 -e ignore $grep -A "B" "B" test1
	atf_check -s not-exit:0 -e ignore $grep -B "B" "B" test1
	atf_check -s not-exit:0 -e ignore $grep -C "B" "B" test1
}

# Check output for binary flags (-a, -I, -U, --binary-files)
test-binary_flags_body() {
return # TODO
	printf "A\000B\000C" > test1
	printf "A\n\000B\n\000C" > test2
	binmatchtext="Binary file test1 matches\n"

	# Binaries not treated as text (default, -U)
	atf_check -o inline:"${binmatchtext}" $grep 'B' test1
	atf_check -o inline:"${binmatchtext}" $grep 'B' -C 1 test1

	atf_check -o inline:"${binmatchtext}" $grep -U 'B' test1
	atf_check -o inline:"${binmatchtext}" $grep -U 'B' -C 1 test1

	# Binary, -a, no newlines
	atf_check -o inline:"A\000B\000C\n" $grep -a 'B' test1
	atf_check -o inline:"A\000B\000C\n" $grep -a 'B' -C 1 test1

	# Binary, -a, newlines
	atf_check -o inline:"\000B\n" $grep -a 'B' test2
	atf_check -o inline:"A\n\000B\n\000C\n" $grep -a 'B' -C 1 test2

	# Binary files ignored
	atf_check -s exit:1 $grep -I 'B' test2

	# --binary-files equivalence
	atf_check -o inline:"${binmatchtext}" $grep --binary-files=binary 'B' test1
	atf_check -o inline:"A\000B\000C\n" $grep --binary-files=text 'B' test1
	atf_check -s exit:1 $grep --binary-files=without-match 'B' test2
}

# Check basic matching with --mmap flag
test-mmap_body() {
return # TODO
	printf "A\nB\nC\n" > test1

	atf_check -s exit:0 -o inline:"B\n" $grep --mmap -oe "B" test1
	atf_check -s exit:1 $grep --mmap -e "Z" test1
}

# Check proper behavior of matching all with an empty string
test-matchall_body() {
return # TODO
	printf "" > test1
	printf "A" > test2
	printf "A\nB" > test3

	atf_check -o inline:"test2:A\ntest3:A\ntest3:B\n" $grep "" test1 test2 test3
	atf_check -o inline:"test3:A\ntest3:B\ntest2:A\n" $grep "" test3 test1 test2
	atf_check -o inline:"test2:A\ntest3:A\ntest3:B\n" $grep "" test2 test3 test1

	atf_check -s exit:1 $grep "" test1
}

# Check proper behavior with multiple patterns supplied to fgrep
test-fgrep_multipattern_body() {
return # TODO
	printf "Foo\nBar\nBaz" > test1

	atf_check -o inline:"Foo\nBaz\n" $grep -F -e "Foo" -e "Baz" test1
	atf_check -o inline:"Foo\nBaz\n" $grep -F -e "Baz" -e "Foo" test1
	atf_check -o inline:"Bar\nBaz\n" $grep -F -e "Bar" -e "Baz" test1
}

# Check proper handling of -i supplied to fgrep
test-fgrep_icase_body() {
return # TODO
	printf "Foo\nBar\nBaz" > test1

	atf_check -o inline:"Foo\nBaz\n" $grep -Fi -e "foo" -e "baz" test1
	atf_check -o inline:"Foo\nBaz\n" $grep -Fi -e "baz" -e "foo" test1
	atf_check -o inline:"Bar\nBaz\n" $grep -Fi -e "bar" -e "baz" test1
	atf_check -o inline:"Bar\nBaz\n" $grep -Fi -e "BAR" -e "bAz" test1
}

# Check proper handling of -o supplied to fgrep
test-fgrep_oflag_body() {
return # TODO
	printf "abcdefghi\n" > test1

	atf_check -o inline:"a\n" $grep -Fo "a" test1
	atf_check -o inline:"i\n" $grep -Fo "i" test1
	atf_check -o inline:"abc\n" $grep -Fo "abc" test1
	atf_check -o inline:"fgh\n" $grep -Fo "fgh" test1
	atf_check -o inline:"cde\n" $grep -Fo "cde" test1
	atf_check -o inline:"bcd\n" $grep -Fo -e "bcd" -e "cde" test1
	atf_check -o inline:"bcd\nefg\n" $grep -Fo -e "bcd" -e "efg" test1

	atf_check -s exit:1 $grep -Fo "xabc" test1
	atf_check -s exit:1 $grep -Fo "abcx" test1
	atf_check -s exit:1 $grep -Fo "xghi" test1
	atf_check -s exit:1 $grep -Fo "ghix" test1
	atf_check -s exit:1 $grep -Fo "abcdefghiklmnopqrstuvwxyz" test1
}

# Check proper handling of -c
test-cflag_body() {
return # TODO
	printf "a\nb\nc\n" > test1

	atf_check -o inline:"1\n" $grep -Ec "a" test1
	atf_check -o inline:"2\n" $grep -Ec "a|b" test1
	atf_check -o inline:"3\n" $grep -Ec "a|b|c" test1

	atf_check -o inline:"test1:2\n" $grep -EHc "a|b" test1
}

# Check proper handling of -m
test-mflag_body() {
return # TODO
	printf "a\nb\nc\nd\ne\nf\n" > test1

	atf_check -o inline:"1\n" $grep -m 1 -Ec "a" test1
	atf_check -o inline:"2\n" $grep -m 2 -Ec "a|b" test1
	atf_check -o inline:"3\n" $grep -m 3 -Ec "a|b|c|f" test1

	atf_check -o inline:"test1:2\n" $grep -m 2 -EHc "a|b|e|f" test1
}

# Check proper handling of -m with trailing context (PR 253350)
test-mflag_trail_ctx_body() {
return # TODO
	printf "foo\nfoo\nbar\nfoo\nbar\nfoo\nbar\n" > test1

	# Should pick up the next line after matching the first.
	atf_check -o inline:"foo\nfoo\n" $grep -A1 -m1 foo test1

	# Make sure the trailer is picked up as a non-match!
	atf_check -o inline:"1:foo\n2-foo\n" $grep -A1 -nm1 foo test1
}

# Ensures that zgrep functions properly with multiple files
test-zgrep_multiple_files_body() {
return # TODO
	echo foo > test1
	echo foo > test2
	atf_check -o inline:"test1:foo\ntest2:foo\n" $zgrep foo test1 test2

	echo bar > test1
	atf_check -o inline:"test2:foo\n" $zgrep foo test1 test2

	echo bar > test2
	atf_check -s exit:1 $zgrep foo test1 test2
}

test-grep_r_implied_body() {
return # TODO
	(cd "$testdata" && $grep -r --exclude="*.out" -e "test" .) > d_grep_r_implied.out

	atf_check -s exit:0 -x \
	    "(cd $testdata && $grep -r --exclude=\"*.out\" -e \"test\") | diff d_grep_r_implied.out -"
}

test-rgrep_body() {
return # TODO
	atf_check -o save:d_grep_r_implied.out $grep -r --exclude="*.out" -e "test" "$testdata"
	atf_check -o file:d_grep_r_implied.out $rgrep --exclude="*.out" -e "test" "$testdata"
}


test-gnuext_body() {
return # TODO

	atf_check -o save:grep_alnum.out $grep -o '[[:alnum:]]' /COPYRIGHT
	atf_check -o file:grep_alnum.out $grep -o '\w' /COPYRIGHT

	atf_check -o save:grep_nalnum.out $grep -o '[^[:alnum:]]' /COPYRIGHT
	atf_check -o file:grep_nalnum.out $grep -o '\W' /COPYRIGHT

	atf_check -o save:grep_space.out $grep -o '[[:space:]]' /COPYRIGHT
	atf_check -o file:grep_space.out $grep -o '\s' /COPYRIGHT

	atf_check -o save:grep_nspace.out $grep -o '[^[:space:]]' /COPYRIGHT
	atf_check -o file:grep_nspace.out $grep -o '\S' /COPYRIGHT

}

test-zflag_body() {
	# The -z flag should pick up 'foo' and 'bar' as on the same line with
	# 'some kind of junk' in between; a bug was present that instead made
	# it process this incorrectly.
	printf "foo\nbar\0" > in

	have=$($grep -z "foo.*bar" in)
	diff -au <(print $have) <(print $'foo\nbar\0') || return 1
}

main
