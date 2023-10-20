#!/bin/zsh
#
# Test cases from:
# https://github.com/freebsd/freebsd-src/tree/main/contrib/netbsd-tests/usr.bin/grep (3e2d96a)
# https://github.com/freebsd/freebsd-src/tree/main/usr.bin/grep/tests (d0b2dbf)
#
# Hard to port atf to Linux, so just re-implement it in zsh.

set -u

dir=$PWD
grep=(timeout  -v 0.4s $dir/grep)
fgrep=(timeout -v 0.4s $dir/fgrep)
egrep=(timeout -v 0.4s $dir/egrep)
rgrep=(timeout -v 0.4s $dir/rgrep)
zgrep=(timeout -v 0.4s $dir/zgrep.sh)
testdata=$dir/testdata
verbose=0
run=()
for f in $argv; do
	case $f in
		-v|-verbose|--verbose) verbose=1 ;;
		*)                     run+=$f   ;;
	esac
done

export GREP_COLOR=  # reset
export GREP_OPTIONS=
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

nonzero() {
	if (( $1 == 0 )); then
		print "want status >1 but have 0"
		return 1
	fi
	return 0
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
	have=$(seq -f '%.2f' -1 0.1 1 | $grep -f $testdata/d_file_exp.in 2>&1)
	diff -u <(print $have) $testdata/d_file_exp.out || return 1
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
	echo 'foo bar' > test
	diff -u <($zgrep -we foo test) <(print 'foo bar') || return 1

	# atf_expect_fail "known but unsolved zgrep wrapper script regression"
	#diff -u <($zgrep -wefoo test </dev/null) <(print 'foo bar') || return 1
}

# Checks for zgrep wrapper problems with -e PATTERN (PR 247126)
test-zgrep_eflag_body() {
	echo 'foo bar' > test
	diff -u <($zgrep -e 'foo bar' test </dev/null 2>&1)       <(print 'foo bar') || return 1
	diff -u <($zgrep --regexp='foo bar' test </dev/null 2>&1) <(print 'foo bar') || return 1
}

# Checks for zgrep wrapper problems with -f FILE (PR 247126)
test-zgrep_fflag_body() {
	echo foo > pattern
	echo foobar > test

	# Avoid hang on reading from stdin in the failure case
	diff -u <($zgrep -f pattern test </dev/null 2>&1)     <(print 'foobar') || return 1
	diff -u <($zgrep --file=pattern test </dev/null 2>&1) <(print 'foobar') || return 1
}

# Checks for zgrep wrapper problems with --ignore-case reading from stdin (PR 247126)
test-zgrep_long_eflag_body() {
	echo foobar > test

	have=$($zgrep -e foo --ignore-case < test 2>&1)
	diff -u <(print $have) <(print 'foobar') || return 1
}

# Checks for zgrep wrapper problems with multiple -e flags (PR 247126)
test-zgrep_multiple_eflags_body() {
	# atf_expect_fail "known but unsolved zgrep wrapper script regression"
	# echo foobar > test
	# diff -u <($zgrep -e foo -e xxx test) <(print 'foobar')
}

# Checks for zgrep wrapper problems with empty -e flags pattern (PR 247126)
test-zgrep_empty_eflag_body() {
	echo foobar > test

	have=$($zgrep -e '' < test 2>&1)
	diff -u <(print $have) <(print 'foobar') || return 1
}

# Checks that -s flag suppresses error messages about nonexistent files
test-nonexistent_body() {
	have=$($grep -s foobar nonexistent 2>&1)
	nonzero $status || return 1
	diff -u <(print $have) <(print '') || return 1
}

# Checks displaying context with -z flag
test-context2_body() {
	printf "haddock\000cod\000plaice\000" > test1
	printf "mackeral\000cod\000crab\000" > test2

	diff -u <($grep -z -A1 cod test1 test2 2>&1) "$testdata/d_context2_a.out" || return 1
	diff -u <($grep -z -B1 cod test1 test2 2>&1) "$testdata/d_context2_b.out" || return 1
	diff -u <($grep -z -C1 cod test1 test2 2>&1) "$testdata/d_context2_c.out" || return 1
}

# Check behavior of zero-length matches with -o flag (PR 195763)
test-oflag_zerolen_body() {
	diff -u <($grep -Eo '(^|:)0*' "$testdata/d_oflag_zerolen_a.in" 2>&1)      "$testdata/d_oflag_zerolen_a.out" || return 1
	diff -u <($grep -Eo '(^|:)0*' "$testdata/d_oflag_zerolen_b.in" 2>&1)      "$testdata/d_oflag_zerolen_b.out" || return 1
	diff -u <($grep -Eo '[[:alnum:]]*' "$testdata/d_oflag_zerolen_c.in" 2>&1) "$testdata/d_oflag_zerolen_c.out" || return 1
	diff -u <($grep -Eo '' "$testdata/d_oflag_zerolen_d.in" 2>&1)             <(print -n '')                    || return 1
	diff -u <($grep -o -e 'ab' -e 'bc' "$testdata/d_oflag_zerolen_e.in" 2>&1) "$testdata/d_oflag_zerolen_e.out" || return 1
	diff -u <($grep -o -e 'bc' -e 'ab' "$testdata/d_oflag_zerolen_e.in" 2>&1) "$testdata/d_oflag_zerolen_e.out" || return 1
}

# Check that we actually get a match with -x flag (PR 180990)
test-xflag_body() {
	echo 128 > match_file
	seq 1 128 > pattern_file

	diff -u <($grep -xf pattern_file match_file) <(print 128)
}

# Check --color support
test-color_body() {
	echo 'abcd*' > grepfile
	echo 'abc$' >> grepfile
	echo '^abc' >> grepfile

	diff -u <($grep --color=auto -e '.*' -e 'a' "$testdata/d_color_a.in" 2>&1) $testdata/d_color_a.out || return 1
	diff -u <($grep --color=auto -f grepfile "$testdata/d_color_b.in" 2>&1)    $testdata/d_color_b.out || return 1
	diff -u <($grep --color=always -f grepfile "$testdata/d_color_b.in" 2>&1)  $testdata/d_color_c.out || return 1
}

# Check for handling of a null byte in empty file, specified by -f (PR 202022)
test-f_file_empty_body() {
	printf "\0\n" > nulpat

	have=$($grep -f nulpat "$testdata/d_f_file_empty.in" 2>&1)
	nonzero $status || return 1
	diff -u <(print $have) <(print '') || return 1
}

# Check proper handling of escaped vs. unescaped dot expressions (PR 175314)
test-escmap_body() {
	have=$($grep -o 'f.o\.' "$testdata/d_escmap.in" 2>&1)
	nonzero $status || return 1
	diff -u <(print $have) <(print '') || return 1

	diff -u <($grep -o 'f.o.' "$testdata/d_escmap.in" 2>&1) <(print 'f.oo') || return 1
}

# Check for handling of an invalid empty pattern (PR 194823)
test-egrep_empty_invalid_body() {
	have=$($egrep '{' /dev/null 2>&1)
	nonzero $status || return 1
}

# Check for successful zero-length matches with ^$
test-zerolen_body() {
	printf "Eggs\n\nCheese" > test1
	diff -u <($grep -e "^$" test1 2>&1)    <(print '')             || return 1
	diff -u <($grep -v -e "^$" test1 2>&1) <(print "Eggs\nCheese") || return 1
}

# Check for proper handling of -w with an empty pattern (PR 105221)
test-wflag_emptypat_body() {
	printf "" > test1
	printf "\n" > test2
	printf "qaz" > test3
	printf " qaz\n" > test4

	have=$($grep -w -e "" test1 2>&1)
	nonzero $status || return 1
	diff -u <(print $have) <(print '') || return 1

	have=$($grep -w -e "" test3 2>&1)
	nonzero $status || return 1
	diff -u <(print $have) <(print '') || return 1

	diff -u <($grep -vw -e "" test2 2>&1) test2
	diff -u <($grep -vw -e "" test4 2>&1) test4
}

test-xflag_emptypat_body() {
	printf "" > test1
	printf "\n" > test2
	printf "qaz" > test3
	printf " qaz\n" > test4

	have=$($grep -x -e "" test1 2>&1)
	nonzero $status || return 1
	diff -u <(print $have) <(print '') || return 1

	diff -u <($grep -x -e "" test2) test2 || return 1

	have=$($grep -x -e "" test3 2>&1)
	nonzero $status || return 1
	diff -u <(print $have) <(print '') || return 1

	have=$($grep -x -e "" test4 2>&1)
	nonzero $status || return 1
	diff -u <(print $have) <(print '') || return 1

	# Simple checks that grep -x with an empty pattern isn't matching every
	# line.  The exact counts aren't important, as long as they don't
	# match the total line count and as long as they don't match each other.
	total=$(wc -l $testdata/COPYRIGHT | sed 's/[^0-9]//g')
	pos=$($grep -Fxc '' $testdata/COPYRIGHT 2>&1)
	neg=$($grep -Fvxc '' $testdata/COPYRIGHT 2>&1)

	if (( $pos == $total )); then
		print '-Fxc = total'
		return 1
	fi
	if (( $neg == $total )); then
		print '-Fvxc = total'
		return 1
	fi
	if (( $pos == $neg )); then
		print '-Fxc = -Fvxc'
		return 1
	fi
}

test-xflag_emptypat_plus_body() {
	printf "foo\n\nbar\n\nbaz\n" > target
	printf "foo\n \nbar\n \nbaz\n" > target_spacelines
	printf "foo\nbar\nbaz\n" > matches
	printf " \n \n" > spacelines

	printf "foo\n\nbar\n\nbaz\n" > patlist1
	printf "foo\n\nba\n\nbaz\n" > patlist2

	sed -e '/bar/d' target > matches_not2

	# Normal handling first
	diff -u <($grep -Fxf patlist1 target 2>&1)            target       || return 1
	diff -u <($grep -Fxf patlist1 target_spacelines 2>&1) matches      || return 1
	diff -u <($grep -Fxf patlist2 target 2>&1)            matches_not2 || return 1

	# -v handling
	have=$($grep -Fvxf patlist1 target 2>&1)
	nonzero $status || return 1
	diff -u <(print $have) <(print '') || return 1

	diff -u <($grep -Fxvf patlist1 target_spacelines 2>&1) spacelines || return 1
}

# Check for proper handling of empty pattern files (PR 253209)
test-emptyfile_body() {
	:> epatfile
	echo "blubb" > subj

	# From PR 253209, bsdgrep was short-circuiting completely on an empty
	# file, but we should have still been processing lines.
	have=$($fgrep -f epatfile subj 2>&1)
	nonzero $status || return 1
	diff -u <(print $have) <(print '') || return 1

	diff -u <($fgrep -vf epatfile subj) subj || return 1
}

# Check for proper handling of lines with excessive matches (PR 218811)
test-excessive_matches_body() {
	repeat 4096; printf "x" >> test.in

	have=($($grep -o x test.in 2>&1))
	if (( $status != 0 )); then
		print "status $status"
		return 1
	fi
	if (( $#have != 4096 )); then
		print "len $#have"
		return 1
	fi

	have=($($grep -on x test.in |& grep -v 1:x))
	nonzero $status || return 1
	if (( $#have != 0 )); then
		print "len $#have"
		return 1
	fi
}

# Check for fgrep sanity, literal expressions only
test-fgrep_sanity_body() {
	printf "Foo" > test1

	diff -u <($fgrep -e "Foo" test1 2>&1) <(print 'Foo') || return 1

	have=$($fgrep -e "Fo." test1 2>&1)
	nonzero $status || return 1
	diff -u <(print $have) <(print '') || return 1
}

# Check for egrep sanity, EREs only
test-egrep_sanity_body() {
	printf "Foobar(ed)" > test1
	printf "M{1}" > test2

	diff -u <($egrep -o -e "F.." test1 2>&1)     <(print "Foo")    || return 1
	diff -u <($egrep -o -e "F[a-z]*" test1 2>&1) <(print "Foobar") || return 1
	diff -u <($egrep -o -e "F(o|p)" test1 2>&1)  <(print "Fo")     || return 1
	diff -u <($egrep -o -e "\(ed\)" test1 2>&1)  <(print "(ed)")   || return 1
	diff -u <($egrep -o -e "M{1}" test2 2>&1)    <(print "M")      || return 1
	diff -u <($egrep -o -e "M\{1\}" test2 2>&1)  <(print "M{1}")   || return 1
}

# Check for basic grep sanity, BREs only
test-grep_sanity_body() {
	printf "Foobar(ed)" > test1
	printf "M{1}" > test2

	diff -u <($grep -o -e "F.." test1 2>&1)     <(print "Foo")    || return 1
	diff -u <($grep -o -e "F[a-z]*" test1 2>&1) <(print "Foobar") || return 1
	diff -u <($grep -o -e "F\(o\)" test1 2>&1)  <(print "Fo")     || return 1
	diff -u <($grep -o -e "(ed)" test1 2>&1)    <(print "(ed)")   || return 1
	diff -u <($grep -o -e "M{1}" test2 2>&1)    <(print "M{1}")   || return 1
	diff -u <($grep -o -e "M\{1\}" test2 2>&1)  <(print "M")      || return 1
}

# Check for incorrectly matching lines with both -w and -v flags (PR 218467)
test-wv_combo_break_body() {
	printf "x xx\n" > test1
	printf "xx x\n" > test2

	diff -u <($grep -w "x" test1 2>&1) test1 || return 1
	diff -u <($grep -w "x" test2 2>&1) test2 || return 1

	$grep -v -w "x" test1; nonzero $status || return 1
	$grep -v -w "x" test2; nonzero $status || return 1
}

# Check for -n/-b producing per-line metadata output
test-ocolor_metadata_body() {
	printf "xxx\nyyyy\nzzz\nfoobarbaz\n" > test1
	check_expr="^[^:]*[0-9][^:]*:[^:]+$"

	diff -u <($grep -bon "xx$" test1 2>&1) <(print "1:1:xx")   || return 1
	diff -u <($grep -bn "yy" test1 2>&1)   <(print "2:4:yyyy") || return 1
	diff -u <($grep -bon "yy$" test1 2>&1) <(print "2:6:yy")   || return 1

	# These checks ensure that grep isn't producing bogus line numbering
	# in the middle of a line.
	$grep -Eon 'x|y|z|f' test1 | $grep -Ev $check_expr;                nonzero $status || return 1
	$grep -En 'x|y|z|f' --color=always test1 | $grep -Ev $check_expr;  nonzero $status || return 1
	$grep -Eon 'x|y|z|f' --color=always test1 | $grep -Ev $check_expr; nonzero $status || return 1
}

# Check for no match (-c, -l, -L, -q) flags not producing line matches or context (PR 219077)
test-grep_nomatch_flags_body() {
	printf "A\nB\nC\n" > test1

	diff -u <($grep -c -C 1 -e "B" test1 2>&1) <(print "1")     || return 1
	diff -u <($grep -c -B 1 -e "B" test1 2>&1) <(print "1")     || return 1
	diff -u <($grep -c -A 1 -e "B" test1 2>&1) <(print "1")     || return 1
	diff -u <($grep -c -C 1 -e "B" test1 2>&1) <(print "1")     || return 1

	diff -u <($grep -l -e "B" test1 2>&1)      <(print "test1") || return 1
	diff -u <($grep -l -B 1 -e "B" test1 2>&1) <(print "test1") || return 1
	diff -u <($grep -l -A 1 -e "B" test1 2>&1) <(print "test1") || return 1
	diff -u <($grep -l -C 1 -e "B" test1 2>&1) <(print "test1") || return 1

	diff -u <($grep -L -e "D" test1 2>&1)      <(print "test1") || return 1

	diff -u <($grep -q -e "B" test1 2>&1)      <(print -n '') || return 1
	diff -u <($grep -q -B 1 -e "B" test1 2>&1) <(print -n '') || return 1
	diff -u <($grep -q -A 1 -e "B" test1 2>&1) <(print -n '') || return 1
	diff -u <($grep -q -C 1 -e "B" test1 2>&1) <(print -n '') || return 1
}

# Check for handling of invalid context arguments
test-badcontext_body() {
	printf "A\nB\nC\n" > test1

	$grep -A "-1" "B" test1 2>/dev/null; nonzero $status || return 1
	$grep -B "-1" "B" test1 2>/dev/null; nonzero $status || return 1
	$grep -C "-1" "B" test1 2>/dev/null; nonzero $status || return 1
	$grep -A "B" "B" test1  2>/dev/null;  nonzero $status || return 1
	$grep -B "B" "B" test1  2>/dev/null;  nonzero $status || return 1
	$grep -C "B" "B" test1  2>/dev/null;  nonzero $status || return 1
}

# Check output for binary flags (-a, -I, -U, --binary-files)
test-binary_flags_body() {
	printf "A\000B\000C" > test1
	printf "A\n\000B\n\000C" > test2
	binmatchtext="Binary file test1 matches"

	# Binaries not treated as text (default, -U)
	diff -u <($grep 'B' test1 2>&1)         <(print "${binmatchtext}") || return 1
	diff -u <($grep 'B' -C 1 test1 2>&1)    <(print "${binmatchtext}") || return 1
	diff -u <($grep -U 'B' test1 2>&1)      <(print "${binmatchtext}") || return 1
	diff -u <($grep -U 'B' -C 1 test1 2>&1) <(print "${binmatchtext}") || return 1

	# Binary, -a, no newlines
	diff -u <($grep -a 'B' test1 2>&1)      <(print "A\000B\000C") || return 1
	diff -u <($grep -a 'B' -C 1 test1 2>&1) <(print "A\000B\000C") || return 1

	# Binary, -a, newlines
	diff -u <($grep -a 'B' test2 2>&1)      <(print "\000B") || return 1
	diff -u <($grep -a 'B' -C 1 test2 2>&1) <(print "A\n\000B\n\000C") || return 1

	# Binary files ignored
	$grep -I 'B' test2; nonzero $status || return 1

	# --binary-files equivalence
	diff -u <($grep --binary-files=binary 'B' test1 2>&1) <(print "${binmatchtext}") || return 1
	diff -u <($grep --binary-files=text 'B' test1 2>&1)   <(print "A\000B\000C") || return 1
	$grep --binary-files=without-match 'B' test2; nonzero $status || return 1
}

# Check basic matching with --mmap flag
test-mmap_body() {
	printf "A\nB\nC\n" > test1

	diff -u <($grep --mmap -oe "B" test1 2>&1) <(print 'B')

	$grep --mmap -e "Z" test1
	nonzero $status || return 1
}

# Check proper behavior of matching all with an empty string
test-matchall_body() {
	printf "" > test1
	printf "A" > test2
	printf "A\nB" > test3

	diff -u <($grep "" test1 test2 test3 2>&1) <(print "test2:A\ntest3:A\ntest3:B") || return 1
	diff -u <($grep "" test3 test1 test2 2>&1) <(print "test3:A\ntest3:B\ntest2:A") || return 1
	diff -u <($grep "" test2 test3 test1 2>&1) <(print "test2:A\ntest3:A\ntest3:B") || return 1

	have=$($grep "" test1 2>&1)
	nonzero $status || return 1
}

# Check proper behavior with multiple patterns supplied to fgrep
test-fgrep_multipattern_body() {
	printf "Foo\nBar\nBaz" > test1

	diff -u <($grep -F -e "Foo" -e "Baz" test1 2>&1) <(print "Foo\nBaz") || return 1
	diff -u <($grep -F -e "Baz" -e "Foo" test1 2>&1) <(print "Foo\nBaz") || return 1
	diff -u <($grep -F -e "Bar" -e "Baz" test1 2>&1) <(print "Bar\nBaz") || return 1
}

# Check proper handling of -i supplied to fgrep
test-fgrep_icase_body() {
	printf "Foo\nBar\nBaz" > test1

	diff -u <($grep -Fi -e "foo" -e "baz" test1 2>&1) <(print "Foo\nBaz") || return 1
	diff -u <($grep -Fi -e "baz" -e "foo" test1 2>&1) <(print "Foo\nBaz") || return 1
	diff -u <($grep -Fi -e "bar" -e "baz" test1 2>&1) <(print "Bar\nBaz") || return 1
	diff -u <($grep -Fi -e "BAR" -e "bAz" test1 2>&1) <(print "Bar\nBaz") || return 1
}

# Check proper handling of -o supplied to fgrep
test-fgrep_oflag_body() {
	printf "abcdefghi\n" > test1

	diff -u <($grep -Fo "a" test1 2>&1)               <(print "a")        || return 1
	diff -u <($grep -Fo "i" test1 2>&1)               <(print "i")        || return 1
	diff -u <($grep -Fo "abc" test1 2>&1)             <(print "abc")      || return 1
	diff -u <($grep -Fo "fgh" test1 2>&1)             <(print "fgh")      || return 1
	diff -u <($grep -Fo "cde" test1 2>&1)             <(print "cde")      || return 1
	diff -u <($grep -Fo -e "bcd" -e "cde" test1 2>&1) <(print "bcd")      || return 1
	diff -u <($grep -Fo -e "bcd" -e "efg" test1 2>&1) <(print "bcd\nefg") || return 1

	$grep -Fo "xabc" test1;                      nonzero $status || return 1
	$grep -Fo "abcx" test1;                      nonzero $status || return 1
	$grep -Fo "xghi" test1;                      nonzero $status || return 1
	$grep -Fo "ghix" test1;                      nonzero $status || return 1
	$grep -Fo "abcdefghiklmnopqrstuvwxyz" test1; nonzero $status || return 1
}

# Check proper handling of -c
test-cflag_body() {
	printf "a\nb\nc\n" > test1

	diff -u <($grep -Ec "a" test1 2>&1)     <(print "1")       || return 1
	diff -u <($grep -Ec "a|b" test1 2>&1)   <(print "2")       || return 1
	diff -u <($grep -Ec "a|b|c" test1 2>&1) <(print "3")       || return 1
	diff -u <($grep -EHc "a|b" test1 2>&1)  <(print "test1:2") || return 1
}

# Check proper handling of -m
test-mflag_body() {
	printf "a\nb\nc\nd\ne\nf\n" > test1

	diff -u <($grep -m 1 -Ec "a" test1 2>&1)        <(print "1")       || return 1
	diff -u <($grep -m 2 -Ec "a|b" test1 2>&1)      <(print "2")       || return 1
	diff -u <($grep -m 3 -Ec "a|b|c|f" test1 2>&1)  <(print "3")       || return 1
	diff -u <($grep -m 2 -EHc "a|b|e|f" test1 2>&1) <(print "test1:2") || return 1
}

# Check proper handling of -m with trailing context (PR 253350)
test-mflag_trail_ctx_body() {
	printf "foo\nfoo\nbar\nfoo\nbar\nfoo\nbar\n" > test1

	# Should pick up the next line after matching the first.
	diff -u <($grep -A1 -m1 foo test1 2>&1) <(print "foo\nfoo") || return 1

	# Make sure the trailer is picked up as a non-match!
	diff -u <($grep -A1 -nm1 foo test1 2>&1) <(print "1:foo\n2-foo") || return 1
}

# Ensures that zgrep functions properly with multiple files
test-zgrep_multiple_files_body() {
	echo foo > test1
	echo foo > test2
	diff -u <($zgrep foo test1 test2 2>&1) <(print "test1:foo\ntest2:foo") || return 1

	echo bar > test1
	diff -u <($zgrep foo test1 test2 2>&1) <(print "test2:foo") || return 1

	echo bar > test2
	$zgrep foo test1 test2
	nonzero $status || return 1
}

test-grep_r_implied_body() {
	diff -u \
		<(cd $testdata && $grep -r --exclude="*.out" -e "test" . 2>&1) \
		<(cd $testdata && $grep -r --exclude="*.out" -e "test"   2>&1) || return 1
}

test-rgrep_body() {
	diff -u \
		<($grep -r --exclude="*.out" -e "test" $testdata) \
		<($rgrep   --exclude="*.out" -e "test" $testdata) || return 1
}

test-gnuext_body() {
	diff -u \
		<($grep -o '[[:alnum:]]' $testdata/COPYRIGHT 2>&1) \
		<($grep -o '\w' $testdata/COPYRIGHT 2>&1) || return 1

	diff -u \
		<($grep -o '[^[:alnum:]]' $testdata/COPYRIGHT 2>&1) \
		<($grep -o '\W' $testdata/COPYRIGHT 2>&1) || return 1
	diff -u \
		<($grep -o '[[:space:]]' $testdata/COPYRIGHT 2>&1) \
		<($grep -o '\s' $testdata/COPYRIGHT 2>&1) || return 1
	diff -u \
		<($grep -o '[^[:space:]]' $testdata/COPYRIGHT 2>&1) \
		<($grep -o '\S' $testdata/COPYRIGHT 2>&1) || return 1
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
