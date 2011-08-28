#!/bin/bash

sha1_define()
{
	local FILE=$TEST_UNIT_DATA/sha1/$1

	local CKSUM=$(sha1sum $FILE | sed -e 's/ .*//')
	local DEFINE=$(echo "TEST_SHA1_$1" | dd conv=ucase 2>/dev/null)

	echo "#define $DEFINE \"$CKSUM\""
}

task "Setting up files for SHA1 tests"
mkdir -p $TEST_UNIT_DATA/sha1
cat > $TEST_UNIT_DATA/sha1/file1 <<EOF
This file is used by the res_file unit tests as a remote path
for source and SHA1 testing.

DO NOT EDIT THIS FILE, since SHA1 checksums in the test code
are dependent on the contents of this file being intact.

(This is file1, which should be different from file2)
EOF
sha1_define file1 >> $TEST_DEFS_H

cat > $TEST_UNIT_DATA/sha1/file2 <<EOF
This file is used by the res_file unit tests as a remote path
for source and SHA1 testing.

DO NOT EDIT THIS FILE, since SHA1 checksums in the test code
are dependent on the contents of this file being intact.

(This is file2, which should be different from file1)
EOF
sha1_define file2 >> $TEST_DEFS_H
