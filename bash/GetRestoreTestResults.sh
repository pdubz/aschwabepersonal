#!/bin/bash
#set -x
#
# GetRestoreTestResults.sh
#
# Pulls restore test results from the s3 bucket, builds a local json database, and reports
# from it.
#
#  26 apr 16	aschwabe	initial version
#  19 jul 16	rsharp		retry loop for s3 call, debug option, add DateOfTest, comments
#

# ------------------------------------------------------------
# SETUP
# ------------------------------------------------------------
#
# requires 
#     jq, iconv must be installed and available in your PATH
#     sts client must be installed, configured, and running
#         s3 bucket names have account names embedded
#         sts config must match these names: devops-dev ade auto sb int prd-ncr prd
#
# ------------------------------------------------------------
# CONFIGURATION
# set the following two variables and the rest will work
# the default profile should be an entry in your sts client setup
# ------------------------------------------------------------
defaultprofile="--profile sb"
defaultregion="--region ap-southeast-2"
#
# ------------------------------------------------------------
# END USER SETUP AND CONFIGURATION
# ------------------------------------------------------------


#
# global variables
#
prgname=$0
prgname=${prgname##*/}
tmpfile=/tmp/$prgname.$$
LocalDocumentsDir="/tmp/restoretesting"
BigJSON="/tmp/restoretesting/RestoreTestResults.json"
debug=""
compact=""
full=""

# ------------------------------------------------------------
function cleanup {
# ------------------------------------------------------------
	rm $tmpfile > /dev/null 2>&1
	rm $tmpfile.* > /dev/null 2>&1
}
trap cleanup EXIT

# ------------------------------------------------------------
function display_usage {
# ------------------------------------------------------------
	echo " "
	echo "$prgname"
	echo " "
	echo "Product report of database restore tests from output stored in s3."
	echo " "
	echo "usage: $prgname [-h] [-d] [-v]"
	echo " "
	echo "where:"
	echo "  -h this help"
	echo "  -d debug mode"
	echo "  -c compact output"
	echo "  -f full (all fields) output"
}

# ------------------------------------------------------------
function read_cmd_line {
# ------------------------------------------------------------
	while getopts ":hdcf" opt
	do
		case $opt in
		h )	display_usage
			exit 0
			;;
		d )	debug="true"
			;;
		c ) compact="-c"
			;;
		f )	full="true"
			;;
		: )     display_usage
			echo "ERROR: -$OPTARG requires an argument!"
			echo " "
			exit 1
			;;
		* )     echo "ERROR: -$OPTARG not recognized!"
			echo " "
			display_usage
			exit 1
			;;
		esac
	done
	shift $(($OPTIND - 1))
}


# ------------------------------------------------------------
# main
# ------------------------------------------------------------

cleanup
read_cmd_line $*

#
# test ability to log in to amazon 
# exit otherwise to avoid erasing database
# 
if [ -n "$debug" ]; then echo "Testing AWS CLI access..."; fi
aws ec2 $defaultprofile $defaultregion describe-regions > /dev/null 2>&1
if [[ $? -ne 0 ]]; then
	echo ""
	echo "    ERROR: cannot access default account in aws"
	echo "    Perhaps you need to log in with your sts client?"
	echo ""
	exit 1
fi

# create temp directory for local output, clean up from last time
if [ -d "${LocalDocumentsDir}" ]; then
	rm -rf "${LocalDocumentsDir}"
fi
mkdir ${LocalDocumentsDir}

# warning: s3 bucket names have account name embedded
declare -a Accounts
Accounts=(devops-dev auto sb int prd-ncr prd)
#Accounts=(sb)

# loop thru all available regions pulling restore test files from s3
if [[ -n "$debug" ]]; then echo "Pulling files from s3:"; fi
for Account in "${Accounts[@]}"; do
	for Region in `aws ec2 $defaultprofile $defaultregion describe-regions | jq -r '.Regions[].RegionName' | sort`; do
		Bucket=infor-"${Account}"-dbasecure-"${Region}"
		if [[ -n "$debug" ]]; then echo "    $Account $Bucket"; fi

		while ( true ); do
			aws s3 cp s3://"${Bucket}"/restoretesting/ "${LocalDocumentsDir}" --include "*.json" --recursive --profile "${Account}" --region "${Region}" > "/dev/null" 2>$tmpfile
			
			if [[ $? -eq 0 ]]; then
				break
			fi
			grep -q "specified bucket does not exist" $tmpfile
			if [[ $? -eq 0 ]]; then
				break
			fi
			if [[ -n "$debug" ]]; then echo "        ERROR, retrying..."; fi
		done
	done
done

# loop thru files, possibly converting, amassing to one database file
if [[ -n "$debug" ]]; then echo "Processing local json files:"; fi
for File in $(find "${LocalDocumentsDir}" -type f -name '*.json' ); do
	#
	# determine a few things about our file and its contents
	#
	
	# get the datetime of the actual test from the filename
	DateOfTest=${File##*/}
	DateOfTest=${DateOfTest%%\-*}

	# determine file encoding
	FileType=$(file --brief "${File}")
	CurrentEncoding=$(echo ${FileType} | cut -d ' ' -f 1)
	if [[ "$CurrentEncoding" = "Little-endian" ]]; then
		CurrentEncoding=$(echo ${FileType} | cut -d ' ' -f 2)
	fi
	
	# is there a Byte Order Mark present in the file?
	BOMPresent=$(echo ${FileType} | grep -c BOM)

	if [[ -n "$debug" ]]; then echo "    $BOMPresent $DateOfTest $File $CurrentEncoding"; fi

	#
	# build up our command, possibly stripping out a BOM, possibly converting the encoding	
	#
	Command="cat ${File}"
	
	# switch encoding if needed
	if [[ ! (${CurrentEncoding} = "ASCII" || ${CurrentEncoding} = "UTF-8") ]]; then
		Command="${Command} | iconv -f ${CurrentEncoding} -t UTF-8"
	fi

	# strip BOM if needed
	if [[ $BOMPresent -eq 1 ]]; then
		Command="${Command} | tail -c +4"
	fi
	
	# add DateOfTest to json structre
	Command="${Command} | jq -c '. + {\"DateOfTest\":\"${DateOfTest}\"}'"

	# run the command we just made and add the result to the json db file
	if [[ -n "$debug" ]]; then echo "        $Command"; fi
	eval ${Command} >> "${BigJSON}"
done

if [[ -n "$debug" ]]; then echo "Calling jq"; fi

if [[ -n "$full" ]]; then
	jq '{Account,Service,Product,Region,ServerName,DBA,Database,DateOfTest,TestType,TestDate,TestStatus,TestComment}' -c "${BigJSON}" | sort | jq ${compact} '.' 
else
	jq '{Account,Service,Product,ServerName,DateOfTest,TestType,TestDate,TestStatus}' -c "${BigJSON}" | sort | jq ${compact} '.'
fi
