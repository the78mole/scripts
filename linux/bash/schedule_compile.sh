#!/bin/bash

if [ "$1" == "-h" -o "$1" == "--help" ]; then
cat <<HERE

  Usage: $0: [<EXE> [SUFFIX] [<MEMLIMIT>]]]

    EXE      : The executable to be scheduled (default: cc1plus)
    SUFFIX   : Suffix of compilation uint files (e.g. cc)
    MEMLIMIT : Memlimit in bytes, when procs (with less runtime) 
               shall be suspended

HERE
exit 0
fi

declare -a arrprgs
declare -a procarr
tmpfile=$(mktemp)

EXENAME=${1:-cc1plus}
SUFFIX=${2:-cc}
# 4K-PAGES
MEMAMOUNT=${3:-900000000}
PAGESIZE=$(getconf PAGESIZE)
PAGELIMIT=$(expr $MEMAMOUNT / $PAGESIZE)
PRGS=$(pgrep cc1plus)
let PMEMSTOP=$PAGELIMIT*$PAGESIZE/1024/1024

echo "Executable name is    : $EXENAME"
echo "Mem stop limit is     : $MEMAMOUNT"
echo "System's pagesize is  : $PAGESIZE"
echo "Resulting pagelimit is: ${PMEMSTOP}M ($PAGELIMIT)"
echo -e "Tempfile              : $tmpfile\n"

for aproc in $PRGS; do
	procut=$(cat /proc/$aproc/stat | cut -d ' ' -f 14)
	arrprgs+="$procut $aproc"
	echo "$procut $aproc" >> $tmpfile
done

printf "      PID S    UTIME    VIRT   RES %7s  %-30s  ST\n" "MSUM" "Compile Unit"
PAGESUM=0
CNT=1
while read aline; do
	runtime=$(echo $aline | cut -d ' ' -f 1)
	aproc=$(echo $aline | cut -d ' ' -f 2)
	if [ -d /proc/$aproc ]; then
		MEMSTAT=$(cat /proc/$aproc/statm)
		CUNIT=$(cat /proc/$aproc/cmdline | tr '\0' ' ' | sed -e "s/^.*\?\/\(\w\+\.${SUFFIX}\).*\?\$/\1/")
		SSTAT=$(cat /proc/$aproc/stat | cut -d ' ' -f 3)
		MEMV=$(echo $MEMSTAT | cut -d ' ' -f 1)
		let PMEMV=$MEMV*$PAGESIZE/1024/1024
		MEMR=$(echo $MEMSTAT | cut -d ' ' -f 2)
		let PMEMR=$MEMR*$PAGESIZE/1024/1024
		let PPSUM=$PAGESUM*$PAGESIZE/1024/1024
		printf "%-2d [%5d:%s] [%6d] (%4dM,%4dM - %4dM) %-30s: " $CNT $aproc $SSTAT $runtime $PMEMV $PMEMR $PPSUM ${CUNIT:0:29}
		if [ $PAGESUM -gt $PAGELIMIT ]; then
			if [ $SSTAT == "T" ]; then
				echo "T"
			else
				echo "$SSTAT>T"
				kill -TSTP $aproc
			fi
		else
			if [ $SSTAT == "T" ]; then
				echo "T>R"
				kill -CONT $aproc
			else
				echo "R"
			fi
		fi
		let PAGESUM=$PAGESUM+$MEMV
		let CNT++
	fi
done < <(cat $tmpfile | sort -nr)

rm $tmpfile
