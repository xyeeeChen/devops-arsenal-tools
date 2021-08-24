x=`grep -n "pattern" -m 1 file | cut -f1 -d:`
awk -v ln=$x 'NR>=ln' file
