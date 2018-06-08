#!/bin/bash
#
# the only reason why /bin/sh isn't being used 
# is because "echo -n" is broken on the Mac.

print_usage() {
  echo
  echo "Folds the text file, only if needed, at the specified"
  echo "column, according to BCP XX."
  echo
  echo "Usage: $0 [-c <col>] [-r] -i <infile> -o <outfile>"
  echo
  echo "  -c: column to fold on (default: 69)"
  echo "  -r: reverses the operation"
  echo "  -i: the input filename"
  echo "  -o: the output filename"
  echo "  -d: show debug messages"
  echo "  -h: show this message"
  echo
  echo "Exit status code: zero on success, non-zero otherwise."
  echo
}


# global vars, do not edit
debug=0
reversed=0
infile=""
outfile=""
maxcol=69  # default, may be overridden by param
hdr_txt=" NOTE: '\' line wrapping per BCP XX (RFC XXXX) "
equal_chars="==========================================="

fold_it() {
  # since upcomming tests are >= (not >)
  testcol=`expr "$maxcol" + 1`

  # check if file needs folding
  grep ".\{$testcol\}" $infile >> /dev/null 2>&1
  if [ $? -ne 0 ]; then
    if [[ $debug -eq 1 ]]; then
      echo "nothing to do"
    fi
    cp $infile $outfile
    return 0
  fi

  foldcol=`expr "$maxcol" - 1` # for the inserted '\' char

  # ensure file doesn't have any '\' char on $maxcol already
  #  - as this would lead to false positives...
  grep "^.\{$foldcol\}\\\\$" $infile >> /dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo
    echo "Error: infile has a '\\\' on colomn $maxcol already."
    echo
    exit 1
  fi

  # calculate '=' filled header
  length=${#hdr_txt}
  left_sp=`expr \( "$maxcol" - "$length" \) / 2`
  right_sp=`expr "$maxcol" - "$length" - "$left_sp"`
  header=`printf "%.*s%s%.*s" "$left_sp" "$equal_chars" "$hdr_txt" "$right_sp"  "$equal_chars"`

  # generate outfile and return
  echo -ne "$header\n\n" > $outfile
  gsed "/.\{$testcol\}/s/\(.\{$foldcol\}\)/\1\\\\\n/g" < $infile >> $outfile
  return 0
}


unfold_it() {
  # check if it looks like a BCP XX header
  line=`head -n 1 $infile | fgrep "$hdr_txt"`
  if [ $? -ne 0 ]; then
    if [[ $debug -eq 1 ]]; then
      echo "nothing to do"
    fi
    cp $infile $outfile
    return 0
  fi

  # determine what maxcol value was used
  maxcol=${#line}

  # output all but the first two lines (the header) to wip (work in progress) file
  awk "NR>2" $infile > /tmp/wip

  # unfold wip file
  foldcol=`expr "$maxcol" - 1` # for the inserted '\' char
  gsed ":x; /[^\t]\\{$foldcol\\}\\\\\$/N; s/\\\\\n/\t/; tx; s/\t//g" /tmp/wip > $outfile

  # clean up and return
  rm /tmp/wip
  return 0
}


process_input() {
  while [ "$1" != "" ]; do
    if [ "$1" == "-h" -o "$1" == "--help" ]; then
      print_usage
      exit 1
    fi
    if [ "$1" == "-d" ]; then
      debug=1
    fi
    if [ "$1" == "-c" ]; then
      maxcol="$2"
      shift
    fi
    if [ "$1" == "-r" ]; then
      reversed=1
    fi
    if [ "$1" == "-i" ]; then
      infile="$2"
      shift
    fi
    if [ "$1" == "-o" ]; then
      outfile="$2"
      shift
    fi
    shift 
  done

  if [ -z "$infile" ]; then
    echo
    echo "Error: infile parameter missing (use -h for help)"
    echo
    exit 1
  fi

  if [ -z "$outfile" ]; then
    echo
    echo "Error: outfile parameter missing (use -h for help)"
    echo
    exit 1
  fi

  if [ ! -f "$infile" ]; then
    echo
    echo "Error: specified file \"$infile\" is does not exist."
    echo
    exit 1
  fi

  mincol=`expr ${#hdr_txt} + 6`
  if [ $maxcol -lt $mincol ]; then
    echo
    echo "Error: the folding column cannot be less than $mincol"
    echo
    exit 1
  fi
}


main() {
  if [ "$#" == "0" ]; then
     print_usage
     exit 1
  fi

  process_input $@

  if [[ $reversed -eq 0 ]]; then
    fold_it
    code=$?
  else
    unfold_it
    code=$?
  fi
  exit $code
}

main "$@"
