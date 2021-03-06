#!/usr/bin/perl
use Test::More;
use t::common;
use POSIX qw/mkfifo geteuid getegid/;
use IO::Socket::UNIX;
require "t/vars.pl";

subtest "noop" => sub {
	pendulum_ok(qq(
	fn main
		noop noop noop noop noop noop noop noop noop
		noop noop noop noop noop noop noop noop noop
		noop noop noop noop noop noop noop noop noop
		noop noop noop noop noop noop noop noop noop
		noop noop noop noop noop noop noop noop noop
		noop noop noop noop noop noop noop noop noop
		noop noop noop noop noop noop noop noop noop
		print "ok"),

	"ok",
	"noop");
};

subtest "halt" => sub {
	pendulum_ok(qq(
	fn main
		print "ok"
		halt
		print "fail"),

	"ok",
	"halt stops execution immediately");
};

subtest "comparison operators" => sub {
	pendulum_ok(qq(
	fn main
		eq 0 0
		jz +1
		print "fail"
		print "ok"),

	"ok",
	"eq 0 0");

	pendulum_ok(qq(
	fn main
		eq 0 1
		jnz +1
		print "fail"
		print "ok"),

	"ok",
	"eq 0 1");

	pendulum_ok(qq(
	fn main
		eq 1 0
		jnz +1
		print "fail"
		print "ok"),

	"ok",
	"eq 1 0");

	pendulum_ok(qq(
	fn main
		set %a 42
		set %b 42
		eq %a %b
		jz +1
		print "fail"
		print "ok"),

	"ok",
	"eq %a %b");

	pendulum_ok(qq(
	fn main
		set %a 42
		eq %a 42
		jnz +2
			print "a == 42"
			ret
		print "a != 42"),

	"a == 42",
	"eq %a 42");

	pendulum_ok(qq(
	fn main
		set %a 42
		eq 42 %a
		jnz +2
			print "42 == a"
			ret
		print "42 != a"),

	"42 == a",
	"eq 42 %a");

	pendulum_ok(qq(
	fn main
		streq "foo" "foo"
		jnz +2
			print "foo == foo"
			ret
		print "foo != foo"),

	"foo == foo",
	'streq "foo" "foo"');

	pendulum_ok(qq(
	fn main
		set %a "foo"
		set %b "foo"
		streq %a %b
		jnz +2
			print "a == b"
			ret
		print "a != b"),

	"a == b",
	'streq %a %b');

	pendulum_ok(qq(
	fn main
		set %a "foo"
		streq %a "foo"
		jnz +2
			print "a == foo"
			ret
		print "a != foo"),

	"a == foo",
	'streq %a "foo"');

	pendulum_ok(qq(
	fn main
		set %b "foo"
		streq "foo" %b
		jnz +2
			print "foo == b"
			ret
		print "foo != b"),

	"foo == b",
	'streq "foo" %b');

	pendulum_ok(qq(
	fn main
		streq "foo" "FOO"
		jnz +2
			print "foo == FOO"
			ret
		print "foo != FOO"),

	"foo != FOO",
	'streq "foo" "FOO"');
};

subtest "jump operators" => sub {
	pendulum_ok(qq(
	fn main
		jmp +1
		print "fail"
		print "ok"),

	"ok",
	"unconditional jump with an offset");

	pendulum_ok(qq(
	fn main
		jmp over
		print "fail"
	over:
		print "ok"),

	"ok",
	"unconditional jump with a label");

	pendulum_ok(qq(
	fn main
		eq 0 0
		jz +1
		print "fail"
		print "ok"),

	"ok",
	"jz (jump-if-zero)");

	pendulum_ok(qq(
	fn main
		eq 0 1
		jnz +1
		print "fail"
		print "ok"),

	"ok",
	"jnz (jump-if-not-zero)");

	pendulum_ok(qq(
	fn main
		gt 42 0
		jz +1
		print "fail"
		print "ok"),

	"ok",
	"gt 42 0");

	pendulum_ok(qq(
	fn main
		gte 42 0
		jz +1
		print "fail"
		print "ok"),

	"ok",
	"gte 42 0");

	pendulum_ok(qq(
	fn main
		lt 0 42
		jz +1
		print "fail"
		print "ok"),

	"ok",
	"lt 0 42");

	pendulum_ok(qq(
	fn main
		lte 0 42
		jz +1
		print "fail"
		print "ok"),

	"ok",
	"lte 0 42");
};

subtest "print operators" => sub {
	pendulum_ok(qq(
	fn main
		print "hello, world"),

	"hello, world",
	"simple print statement, no format specifiers");

	pendulum_ok(qq(
	fn main
		set %a 42
		set %b "bugs"

		print "found %[a]d %[b]s"),

	"found 42 bugs",
	"print statement with basic format specifiers");

	pendulum_ok(qq(
	fn main
		print "110%%!"),

	"110%!",
	"literal '%' escape");

	pendulum_ok(qq(
	fn main
		set %c "str"
		print "[%[c]8s]"),

	"[     str]",
	"width-modifiers in print format specifier");

	pendulum_ok(qq(
	fn main
	  print "\\n\\r\\t\\""),

	"\n\r\t\"",
	"recognized all the escape characters");

	pendulum_ok(qq(
	fn main
		print <<EOF
this is a
multiline string
literal heredoc
EOF
), # ^-- that newline there is critical

	"this is a\n".
	"multiline string\n".
	"literal heredoc\n",
	"<<EOF heredoc markers work");

	pendulum_ok(qq(
	fn main
		print <<EOF
embedded EOF
is (EOF) ok
EOF at the beginning is fine too
EOF
), # ^-- that newline there is critical

	"embedded EOF\n".
	"is (EOF) ok\n".
	"EOF at the beginning is fine too\n",
	"heredoc markers can be embedded work");

	pendulum_ok(qq(
	fn main
		print <<IAMDONE
line 1
EOF
line 3
IAMDONE
), # ^-- that newline there is critical

	"line 1\n".
	"EOF\n".
	"line 3\n",
	"alternate heredoc markers are honored");
};

subtest "error operators" => sub {
	pendulum_ok(qq(
	fn main
		pragma test "on"
		error "danger!"),

	"danger!\n", # you get the newline for free!
	"error prints to stderr (with pragma test)");

	pendulum_ok(qq(
	fn main
		pragma test "on"
		fs.stat "/path/to/nowhere"
		perror "system error"),

	"system error: (2) No such file or directory\n",
	"perror invokes perror/strerror for us");
};

subtest "string operator" => sub {
	pendulum_ok(qq(
	fn main
		set %a 1
		set %b 2
		set %c 3
		string "easy as %[a]i-%[b]i-%[c]i" %d
		print "%[d]s"),

	"easy as 1-2-3",
	"string formatting");
};

subtest "register operators" => sub {
	pendulum_ok(qq(
	fn main
		set %a 2
		push %a
		set %a 3
		pop %a
		print "a == %[a]d"),

	"a == 2",
	"push / pop");

	pendulum_ok(qq(
	fn main
		pragma test "on"
		set %a 300

	again:
		push %b
		sub %a 1
		eq %a 0
		jnz again

		print "bye"),

	"stack overflow!\n",
	"stack should overflow at ~256");

	pendulum_ok(qq(
	fn main
		pragma test "on"
		set %a 300

	again:
		pop %b
		sub %a 1
		eq %a 0
		jnz again

		print "bye"),

	"stack underflow!\n",
	"stack should underflow very soon");

	pendulum_ok(qq(
	fn main
		set %a 1
		set %b 2
		swap %a %b
		print "a/b = %[a]d/%[b]d"),

	"a/b = 2/1",
	"swap");

	pendulum_ok(qq(
	fn main
		pragma test "on"
		swap %a %a),

	"pendulum bytecode error (0x0027): swap requires distinct registers\n",
	"`swap %a %a` is invalid");
};

subtest "math operators" => sub {
	pendulum_ok(qq(
	fn main
		set  %a 1
		add  %a 4
		sub  %a 3
		mult %a 12
		div  %a 4
		print "%[a]d"),

	"6",
	"arithmetic");

	pendulum_ok(qq(
	fn main
		set %a 17
		mod %a 10
		print "%[a]d"),

	"7",
	"modulo");
};

subtest "functions" => sub {
	pendulum_ok(qq(
	fn main
		call print.a

	fn print.a
		print "a"
		call print.b
		call print.b
		print "a"

	fn print.b
		print "b"),

	"abba",
	"nested function calls");

	pendulum_ok(qq(
	fn main
		call func

	fn func
		print "ok"
		ret
		print "fail"),

	"ok",
	"ret short-circuits function execution flow-control");

	pendulum_ok(qq(
	fn main
		call func
		jnz +1
		print "fail"
		print "ok"
	fn func
		retv 3),

	"ok",
	"user-defined functions can return values");

	pendulum_ok(qq(
	fn main
		call func
		acc %a
		print "func() == %[a]d"
	fn func
		retv 42),

	"func() == 42",
	"use acc opcode to get return value");

	pendulum_ok(qq(
	fn a:b-c.d_e?  print "ok"
	fn main        call a:b-c.d_e?),

	"ok",
	"function names can contain funky characters");
};

subtest "dump operator" => sub {
	my %opts = (
		postprocess => sub {
			my ($stdout) = @_;
			$stdout =~ s/\[[a-f0-9 ]+\] 0$/<program name> 0/m;
			return $stdout;
		},
	);

	pendulum_ok(qq(
	fn main
		dump),

	qq(
    ---------------------------------------------------------------------
    %a [ 00000000 ]   %b [ 00000000 ]   %c [ 00000000 ]   %d [ 00000000 ]
    %e [ 00000000 ]   %f [ 00000000 ]   %g [ 00000000 ]   %h [ 00000000 ]
    %i [ 00000000 ]   %j [ 00000000 ]   %k [ 00000000 ]   %l [ 00000000 ]
    %m [ 00000000 ]   %n [ 00000000 ]   %o [ 00000000 ]   %p [ 00000000 ]

    acc: 00000000
     pc: 00000015

    data: | 80000000 | 0
          | 00000001 | 1
          '----------'
    inst: <s_empty>
    heap:
          <program name> 0
    ---------------------------------------------------------------------

),
	"dump a fresh VM", %opts);

	pendulum_ok(qq(
	fn main
		pop %b
		pop %a
		dump),

	qq(
    ---------------------------------------------------------------------
    %a [ 80000000 ]   %b [ 00000001 ]   %c [ 00000000 ]   %d [ 00000000 ]
    %e [ 00000000 ]   %f [ 00000000 ]   %g [ 00000000 ]   %h [ 00000000 ]
    %i [ 00000000 ]   %j [ 00000000 ]   %k [ 00000000 ]   %l [ 00000000 ]
    %m [ 00000000 ]   %n [ 00000000 ]   %o [ 00000000 ]   %p [ 00000000 ]

    acc: 00000000
     pc: 00000021

    data: <s_empty>
    inst: <s_empty>
    heap:
          <program name> 0
    ---------------------------------------------------------------------

),
	"dump a clean VM", %opts);

	pendulum_ok(qq(
	fn main
		set %a 0x42
		set %p 0x24
		push 0x414141
		push 0x898989
		call func

	fn func
		set %a 0x36
		push 0x1111
		dump),

	qq(
    ---------------------------------------------------------------------
    %a [ 00000036 ]   %b [ 00000000 ]   %c [ 00000000 ]   %d [ 00000000 ]
    %e [ 00000000 ]   %f [ 00000000 ]   %g [ 00000000 ]   %h [ 00000000 ]
    %i [ 00000000 ]   %j [ 00000000 ]   %k [ 00000000 ]   %l [ 00000000 ]
    %m [ 00000000 ]   %n [ 00000000 ]   %o [ 00000000 ]   %p [ 00000024 ]

    acc: 00000000
     pc: 00000058

    data: | 80000000 | 0
          | 00000001 | 1
          | 00414141 | 2
          | 00898989 | 3
          | 00001111 | 4
          '----------'
    inst: | 00000039 | 0
          '----------'
    heap:
          <program name> 0
    ---------------------------------------------------------------------

),
	"dump a not-so-clean VM", %opts);

	pendulum_ok(qq(
	fn main
		call func1

	fn func1
		call func2

	fn func2
		dump),

	qq(
    ---------------------------------------------------------------------
    %a [ 00000000 ]   %b [ 00000000 ]   %c [ 00000000 ]   %d [ 00000000 ]
    %e [ 00000000 ]   %f [ 00000000 ]   %g [ 00000000 ]   %h [ 00000000 ]
    %i [ 00000000 ]   %j [ 00000000 ]   %k [ 00000000 ]   %l [ 00000000 ]
    %m [ 00000000 ]   %n [ 00000000 ]   %o [ 00000000 ]   %p [ 00000000 ]

    acc: 00000000
     pc: 0000003d

    data: | 80000000 | 0
          | 00000001 | 1
          '----------'
    inst: | 00000019 | 0
          | 0000002d | 1
          '----------'
    heap:
          <program name> 0
    ---------------------------------------------------------------------

),
	"dump a not-so-clean VM", %opts);
};

subtest "fs operators" => sub {
	mkdir "t/tmp";

	pendulum_ok(qq(
	fn main
		fs.stat "t/tmp/enoent"
		jnz +1
		print "fail"
		print "ok"),

	"ok",
	"fs.stat for non-existent file");

	rmdir "t/tmp/dir";
	pendulum_ok(qq(
	fn main
		fs.mkdir "t/tmp/dir"
		jz +1
		print "mkdir-failed;"

		fs.stat "t/tmp/dir"
		jz +1
		print "fail"
		print "ok"),

	"ok",
	"fs.mkdir can create directories");

	pendulum_ok(qq(
	fn main
		fs.rmdir "t/tmp/dir"
		jz +1
		print "FAIL"
		fs.stat "t/tmp/dir"
		jnz +1
		print "fail"
		print "ok"),

	"ok",
	"fs.rmdir can remove directories");

	unlink "t/tmp/newfile";
	pendulum_ok(qq(
	fn main
		fs.touch "t/tmp/newfile"
		jz +1
		print "touch-failed;"

		fs.stat "t/tmp/newfile"
		jz +1
		print "fail"
		print "ok"),

	"ok",
	"fs.touch can create new files");

	pendulum_ok(qq(
	fn main
		fs.unlink "t/tmp/newfile"
		jz +1
		print "FAIL"
		fs.stat "t/tmp/newfile"
		jnz +1
		print "fail"
		print "ok"),

	"ok",
	"fs.unlink can remove files");

	pendulum_ok(qq(
	fn main
		set %a "t/tmp/oldname"
		fs.touch %a
		fs.stat %a
		jz +2
			perror "touch oldname"
			ret

		set %b "t/tmp/newname"
		fs.unlink %b
		fs.stat %b
		jnz +2
			error "unlink failed"
			ret

		fs.rename %a %b

		fs.stat %a
		jnz +2
			error "rename didnt remove oldname"
			ret

		fs.stat %b
		jz +2
			error "rename didnt create newname"
			ret

		print "ok"),

	"ok",
	"fs.rename renames files");

	pendulum_ok(qq(
	fn main
		set %a "t/tmp/file"
		fs.unlink %a
		fs.touch %a
		fs.stat %a
		jz +2
		perror "stat failed"
		ret

		fs.inode %a %b
		gt %b 0
		jz +1
		print "fail"
		print "ok"),

	"ok",
	"retrieved inode from file");

	put_file "t/tmp/orig", "this is a file\n";
	pendulum_ok(qq(
	fn main
		fs.inode "t/tmp/orig" %a
		fs.link "t/tmp/orig" "t/tmp/link"
		fs.inode "t/tmp/link" %b

		eq %a %b
		jz +1
			print "fail"
		print "ok"),

	"ok",
	"fs.link creates hard links");

	SKIP: {
		skip "No /dev/null device found", 2
			unless -e "/dev/null";

		pendulum_ok(qq(
		fn main
			fs.chardev? "/dev/null"
			jz +1
			print "fail"
			print "ok"),

		"ok",
		"/dev/null is a character device");

		pendulum_ok(qq(
		fn main
			set %c "/dev/null"
			fs.major %c %a
			fs.minor %c %b
			print "%[a]d:%[b]d"),

		"1:3",
		"retrieved major/minor number for /dev/null");
	};

	SKIP: {
		skip "No /dev/loop0 device found", 2
			unless -e "/dev/loop0";

		pendulum_ok(qq(
		fn main
			fs.blockdev? "/dev/loop0"
			jz +1
			print "fail"
			print "ok"),

		"ok",
		"/dev/loop0 is a block device");
	};

	pendulum_ok(qq(
	fn main
		fs.dir? "t/tmp"
		jz +1
		print "fail"
		print "ok"),

	"ok",
	"t/tmp is a directory");

	pendulum_ok(qq(
	fn main
		fs.touch "t/tmp/file"
		fs.file? "t/tmp/file"
		jz +1
		print "fail"
		print "ok"),

	"ok",
	"t/tmp/file is a file");

	symlink "t/tmp/file", "t/tmp/syml";
	pendulum_ok(qq(
	fn main
		fs.symlink? "t/tmp/syml"
		jz +1
		print "fail"
		print "ok"),

	"ok",
	"t/tmp/syml is a symbolic link");

	mkfifo "t/tmp/fifo", 0644;
	pendulum_ok(qq(
	fn main
		fs.fifo? "t/tmp/fifo"
		jz +1
		print "fail"
		print "ok"),

	"ok",
	"t/tmp/fifo is a FIFO pipe");

	IO::Socket::UNIX->new(Type => SOCK_STREAM, Local => "t/tmp/socket");
	pendulum_ok(qq(
	fn main
		fs.socket? "t/tmp/socket"
		jz +1
		print "fail"
		print "ok"),

	"ok",
	"t/tmp/socket is a UNIX domain socket");

	SKIP: {
		skip "must be run as root for chown/chgrp tests", 2
			unless $< == 0;

		my ($uid, $gid) = ($> + 12, $) + 13);
		pendulum_ok(qq(
		fn main
			set %a "t/tmp/chown"
			fs.touch %a

			fs.chgrp %a $gid
			fs.chown %a $uid

			fs.uid %a %b
			fs.gid %a %c
			print "%[b]d:%[c]d"),

		"$uid:$gid",
		"file ownership change / retrieval");
	};

	pendulum_ok(qq(
	fn main
		set %a "t/tmp/chmod"
		fs.touch %a

		fs.chmod %a 0627
		fs.mode %a %b
		print "%[b]04o"),

	"0627",
	"chmod operation");

	SKIP: {
		skip "/etc/issue not found for stat tests", 1
			unless -e "/etc/issue";

		my @st = stat "/etc/issue";
		pendulum_ok(qq(
		fn main
			set %p "/etc/issue"
			fs.dev   %p %a
			fs.inode %p %b
			fs.nlink %p %c
			fs.size  %p %d
			fs.atime %p %e
			fs.ctime %p %f
			fs.mtime %p %g
			fs.uid   %p %h
			fs.gid   %p %i
			print "dev=%[a]d\\n"
			print "ino=%[b]d\\n"
			print "n=%[c]d\\n"
			print "size=%[d]d\\n"
			print "atime=%[e]d\\n"
			print "ctime=%[f]d\\n"
			print "mtime=%[g]d\\n"
			print "uid=%[h]d\\n"
			print "gid=%[i]d\\n"),

		"dev=$st[0]\nino=$st[1]\nn=$st[3]\nsize=$st[7]\n".
		"atime=$st[8]\nctime=$st[10]\nmtime=$st[9]\nuid=$st[4]\ngid=$st[5]\n",
		"stat-based accessor opcodes");
	}

	put_file "t/tmp/sha1", <<EOF;
This is a haiku.
You could write a better one.
Go ahead and try.
EOF
	pendulum_ok(qq(
	fn main
		fs.sha1 "t/tmp/sha1" %d
		jz +2
			print "fail"
			ret
		print "SHA1:%[d]s\\n"),

	"SHA1:9b032ba6005e483b9e33706a8e9e3f17e4c3d1fc\n",
	"fs.sha1");


	unlink "t/tmp/symread";
	symlink "/path/to/somewhere", "t/tmp/symread";
	pendulum_ok(qq(
	fn main
		fs.readlink "t/tmp/symread" %b
		jz +2
			print "fail"
			ret
		print "<%[b]s>"),

	"</path/to/somewhere>",
	"fs.readlink");

	put_file "t/tmp/fsget", <<EOF;
line 1
line the second
EOF
	pendulum_ok(qq(
	fn main
		fs.get "t/tmp/fsget" %a
		jnz +1
		print %a
		ret),

	"line 1\n".
	"line the second\n",
	"fs.get retrieves the full contents of a file");


	pendulum_ok(qq(
	fn main
		fs.put "t/tmp/fsget" "replacement data!"
		fs.get "t/tmp/fsget" %a
		jnz +1
		print %a
		ret),

	"replacement data!",
	"fs.put overwrites a file");

	mkdir "t/tmp/readdir";
	mkdir "t/tmp/readdir/$_" for qw/a b c d/;
	pendulum_ok(qq(
	fn main
		print "starting\\n"
		fs.opendir "t/tmp/readdir" %a
		jz +2
			print "opendir failed\\n"
			ret
	again:
		fs.readdir %a %b
		jnz done
		  print "found '%[b]s'\\n"
		  jmp again

	done:
		fs.closedir %a
		jz +2
			print "closedir failed\\n"
			ret
		print "ok\\n"),

	"starting\n".
	"found 'a'\n".
	"found 'b'\n".
	"found 'c'\n".
	"found 'd'\n".
	"ok\n",
	"fs directory traversal");
};

subtest "user management" => sub {
	mkdir "t/tmp/auth";
	put_file "t/tmp/auth/passwd", <<EOF;
root:x:0:0:root:/root:/bin/bash
daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin
bin:x:2:2:bin:/bin:/usr/sbin/nologin
sys:x:3:3:sys:/dev:/usr/sbin/nologin
user1:x:1000:1100:Some User:/home/user1:/bin/bash
user2:x:1001:1101:Some User:/home/user2:/bin/bash
EOF
	put_file "t/tmp/auth/shadow", <<EOF;
root:HASH:15390:0:99999:7:::
daemon:*:15259:0:99999:7:::
bin:*:15259:0:99999:7:::
sys:*:15259:0:99999:7:::
user1:PWHASH:15259:0:99999:7:::
user2:PWHASH:15259:0:99999:7:::
EOF

	put_file "t/tmp/auth/group", <<EOF;
root:x:0:
daemon:x:1:
bin:x:2:
sys:x:3:
user1:x:1100:
user2:x:1101:user1,sys
EOF

	put_file "t/tmp/auth/gshadow", <<EOF;
root:*::
daemon:*::
bin:*::
sys:*::
user1:*::user2
user2:*::sys
EOF

	pendulum_ok(qq(
	fn main
		pragma authdb.root "t/tmp/auth"
		authdb.open
		jz +2
			perror "failed to open auth databases"
			halt

		authdb.close
		jz +2
			perror "failed to close auth databases"
			halt

		print "ok"),

	"ok",
	"open/close auth databases");

	pendulum_ok(qq(
	fn main
		pragma authdb.root "t/tmp/auth"
		authdb.open

		authdb.nextuid 1000 %a
		authdb.nextgid 1100 %b

		print "uid=%[a]d\\n"
		print "gid=%[b]d\\n"

		authdb.close),

	"uid=1002\ngid=1102\n",
	"nextuid / nextgid");

	pendulum_ok(qq(
	fn main
		pragma authdb.root "t/tmp/auth"
		authdb.open

		authdb.nextuid 0 %a
		authdb.nextgid 0 %b

		print "uid=%[a]d\\n"
		print "gid=%[b]d\\n"

		authdb.close),

	"uid=4\ngid=4\n",
	"nextuid / nextgid (starting at 0)");

	pendulum_ok(qq(
	fn main
		pragma authdb.root "t/tmp/auth"
		authdb.open

		user.find "user1"
		jz +2
			print "user 'user1' not found"
			ret

		user.get "bogus" %c
		jnz +1
			print "bogus attribute didnt fail as expected\\n"

		user.get "uid"      %a    print "uid=%[a]d\\n"
		user.get "gid"      %a    print "gid=%[a]d\\n"
		user.get "username" %a    print "username=%[a]s\\n"
		user.get "comment"  %a    print "comment=%[a]s\\n"
		user.get "home"     %a    print "home=%[a]s\\n"
		user.get "shell"    %a    print "shell=%[a]s\\n"
		user.get "password" %a    print "password=%[a]s\\n"
		user.get "pwhash"   %a    print "pwhash=%[a]s\\n"
		user.get "changed"  %a    print "changed=%[a]d\\n"
		user.get "pwmin"    %a    print "pwmin=%[a]d\\n"
		user.get "pwmax"    %a    print "pwmax=%[a]d\\n"
		user.get "pwwarn"   %a    print "pwwarn=%[a]d\\n"
		user.get "inact"    %a    print "inact=%[a]d\\n"
		user.get "expiry"   %a    print "expiry=%[a]d\\n"

		authdb.close
		print "ok\\n"
		ret),

	"uid=1000\n".
	"gid=1100\n".
	"username=user1\n".
	"comment=Some User\n".
	"home=/home/user1\n".
	"shell=/bin/bash\n".
	"password=x\n".
	"pwhash=PWHASH\n".
	"changed=15259\n".
	"pwmin=0\n".
	"pwmax=99999\n".
	"pwwarn=7\n".
	"inact=-1\n".
	"expiry=-1\n".
	"ok\n",
	"user find / attribute retrieval");

	pendulum_ok(qq(
	fn main
		pragma authdb.root "t/tmp/auth"
		authdb.open

		user.find "user1"
		jz +2
			print "user 'user1' not found"
			ret

		user.set "bogus" 42
		jnz +1
			print "bogus attribute didnt fail as expected\\n"

		user.set "uid"        999
		user.set "gid"        999
		user.set "username"  "user99"
		user.set "comment"   "Comment"
		user.set "home"      "/path/to/home"
		user.set "shell"     "/bin/false"
		user.set "password"  "<secret>"
		user.set "pwhash"    "decafbad"
		user.set "changed"    89818
		user.set "pwmin"      1010
		user.set "pwmax"      1212
		user.set "pwwarn"     4242
		user.set "inact"      12345
		user.set "expiry"     54321

		authdb.save
		authdb.open

		user.find "user99"
		jz +2
			print "user 'user99' not found"
			ret

		user.get "uid"      %a    print "uid=%[a]d\\n"
		user.get "gid"      %a    print "gid=%[a]d\\n"
		user.get "username" %a    print "username=%[a]s\\n"
		user.get "comment"  %a    print "comment=%[a]s\\n"
		user.get "home"     %a    print "home=%[a]s\\n"
		user.get "shell"    %a    print "shell=%[a]s\\n"
		user.get "password" %a    print "password=%[a]s\\n"
		user.get "pwhash"   %a    print "pwhash=%[a]s\\n"
		user.get "changed"  %a    print "changed=%[a]d\\n"
		user.get "pwmin"    %a    print "pwmin=%[a]d\\n"
		user.get "pwmax"    %a    print "pwmax=%[a]d\\n"
		user.get "pwwarn"   %a    print "pwwarn=%[a]d\\n"
		user.get "inact"    %a    print "inact=%[a]d\\n"
		user.get "expiry"   %a    print "expiry=%[a]d\\n"

		authdb.close
		print "ok\\n"
		ret),

	"uid=999\n".
	"gid=999\n".
	"username=user99\n".
	"comment=Comment\n".
	"home=/path/to/home\n".
	"shell=/bin/false\n".
	"password=<secret>\n".
	"pwhash=decafbad\n".
	"changed=89818\n".
	"pwmin=1010\n".
	"pwmax=1212\n".
	"pwwarn=4242\n".
	"inact=12345\n".
	"expiry=54321\n".
	"ok\n",
	"user attribute update/retrieval");

	pendulum_ok(qq(
	fn main
		pragma authdb.root "t/tmp/auth"
		authdb.open

		group.find "sys"
		jz +2
			print "group 'sys' not found"
			ret

		group.get "bogus" %c
		jnz +1
			print "bogus attribute didnt fail as expected\\n"

		group.get "gid"      %a    print "gid=%[a]d\\n"
		group.get "name"     %a    print "name=%[a]s\\n"
		group.get "password" %a    print "password=%[a]s\\n"
		group.get "pwhash"   %a    print "pwhash=%[a]s\\n"

		print "ok\\n"),

	"gid=3\n".
	"name=sys\n".
	"password=x\n".
	"pwhash=*\n".
	"ok\n",
	"group find / attribute retreival");

	pendulum_ok(qq(
	fn main
		pragma authdb.root "t/tmp/auth"
		authdb.open

		group.find "sys"
		jz +2
			print "group 'sys' not found"
			ret

		group.set "bogus" 42
		jnz +1
			print "bogus attribute didnt fail as expected\\n"

		group.set "gid"       845
		group.set "name"     "systems"
		group.set "password" "SeCrEt!"
		group.set "pwhash"   "deadbeef"

		authdb.save
		authdb.open

		group.find "systems"
		jz +2
			print "group 'systems' not found"
			ret

		group.get "gid"      %a    print "gid=%[a]d\\n"
		group.get "name"     %a    print "name=%[a]s\\n"
		group.get "password" %a    print "password=%[a]s\\n"
		group.get "pwhash"   %a    print "pwhash=%[a]s\\n"

		print "ok\\n"),

	"gid=845\n".
	"name=systems\n".
	"password=SeCrEt!\n".
	"pwhash=deadbeef\n".
	"ok\n",
	"group find / attribute retreival");

	pendulum_ok(qq(
	fn main
		pragma authdb.root "t/tmp/auth"
		authdb.open

		user.find "bin"
		jz +2
			error "user 'bin' not found"
			ret

		user.delete
		authdb.save

		authdb.open
		user.find "bin"
		jnz +2
			error "user 'bin' not removed"
			ret

		print "ok"),

	"ok",
	"user.delete");

	pendulum_ok(qq(
	fn main
		pragma authdb.root "t/tmp/auth"
		authdb.open

		group.find "bin"
		jz +2
			error "group 'bin' not found"
			ret

		group.delete
		authdb.save

		authdb.open
		group.find "bin"
		jnz +2
			error "group 'bin' not removed"
			ret

		print "ok"),

	"ok",
	"group.delete");

	pendulum_ok(qq(
	fn main
		pragma authdb.root "t/tmp/auth"
		authdb.open

		authdb.nextuid 1000 %a
		user.new
		user.set "username" "joe"
		user.set "uid"      %a

		authdb.save
		authdb.close

		authdb.open
		user.find "joe"
		jz +1
		print "fail"
		print "ok"),

		"ok",
	"user.new");

	pendulum_ok(qq(
	fn main
		set %b "B"
		user.get "username" %b
		jnz +1
		print "fail"
		print "ok:%[b]s"),

	"ok:B",
	"user.get without a user.find returns non-zero to accumulator");

	pendulum_ok(qq(
	fn main
		user.set "username" "WHAT"
		jnz +1
		print "fail"
		print "ok"),

	"ok",
	"user.set without a user.find returns non-zero to accumulator");

	pendulum_ok(qq(
	fn main
		user.delete
		jnz +1
		print "fail"
		print "ok"),

	"ok",
	"user.delete without a user.find returns non-zero to accumulator");

	pendulum_ok(qq(
	fn main
		pragma authdb.root "t/tmp/auth"
		authdb.open

		authdb.nextgid 1000 %a
		group.new
		group.set "name" "ppl"
		group.set "uid"  %a

		authdb.save
		authdb.close

		authdb.open
		group.find "ppl"
		jz +1
		print "fail"
		print "ok"),

		"ok",
	"group.new");

	pendulum_ok(qq(
	fn main
		set %b "B"
		group.get "groupname" %b
		jnz +1
		print "fail"
		print "ok:%[b]s"),

	"ok:B",
	"group.get without a group.find returns non-zero to accumulator");

	pendulum_ok(qq(
	fn main
		group.set "groupname" "WHAT"
		jnz +1
		print "fail"
		print "ok"),

	"ok",
	"group.set without a group.find returns non-zero to accumulator");

	pendulum_ok(qq(
	fn main
		group.delete
		jnz +1
		print "fail"
		print "ok"),

	"ok",
	"group.delete without a group.find returns non-zero to accumulator");

};

subtest "group memberships" => sub {
	mkdir "t/tmp/auth";
	put_file "t/tmp/auth/passwd", <<EOF;
root:x:0:0:root:/root:/bin/bash
sys:x:3:3:sys:/dev:/usr/sbin/nologin
user1:x:1000:1100:Some User:/home/user1:/bin/bash
user2:x:1001:1101:Some User:/home/user2:/bin/bash
EOF
	put_file "t/tmp/auth/shadow", <<EOF;
root:HASH:15390:0:99999:7:::
sys:*:15259:0:99999:7:::
user1:PWHASH:15259:0:99999:7:::
user2:PWHASH:15259:0:99999:7:::
EOF

	put_file "t/tmp/auth/group", <<EOF;
root:x:0:
sys:x:3:
group1:x:1100:user1
group2:x:1101:user2,sys
EOF

	put_file "t/tmp/auth/gshadow", <<EOF;
root:*::
daemon:*::
bin:*::
sys:*::
group1:*::user1
group2:*:sys:user2,sys
EOF

	pendulum_ok(qq(
	fn main
		pragma authdb.root "t/tmp/auth"
		authdb.open

		group.find "group2" jz +2
			print "failed to find group2"
			bail 1

		user.find "user2" jz +2
			print "user2 not found in /etc/passwd"
			bail 1
		group.has? "member" "user2" jz +2
			print "user2 not found in group2"
			bail 1
		group.has? "admin" "user2" jnz +2
			print "user2 is an admin of group2"
			bail 1

		user.find "user1" jz +2
			print "user2 not found in /etc/passwd"
			bail 1
		group.has? "member" "user1" jnz +2
			print "user1 is a member of group2"
			bail 1

		user.find "sys" jz +2
			print "sys not found in /etc/passwd"
			bail 1
		group.has? "member" "sys" jz +2
			print "sys not found in group2"
			bail 1
		group.has? "admin" "sys" jz +2
			print "sys not an admin of group2"
			bail 1

		user.find "root" jz +2
			print "root not found in /etc/passwd"
			bail 1
		group.has? "member" "root" jnz +2
			print "root found in group2"
			bail 1
		print "ok"),

	"ok",
	"group.has? reports group membership properly");

	pendulum_ok(qq(
	fn main
		pragma authdb.root "t/tmp/auth"
		authdb.open

		; test without a found group
		group.has? "admin" "root" jnz +2
			print "fail"
			bail 1

		group.find "group2" jz +2
			print "failed to find group2"
			bail 1

		group.has? "member" "some-random-enoent" jnz +2
			print "found 'some-random-enoent' in group..."
			bail 1
		print "ok"),

	"ok",
	"group.has? handles non-existent things");

	pendulum_ok(qq(
	fn main
		pragma authdb.root "t/tmp/auth"
		authdb.open

		group.find "group2" jz +2
			print "failed to find group2"
			bail 1

		user.find "user2" jz +2
			print "user2 not found in /etc/passwd"
			bail 1
		group.has? "member" "user2" jz +2
			print "user2 not found in group2"
			bail 1
		group.has? "admin" "user2" jnz +2
			print "user2 is an admin of group2"
			bail 1

		group.kick "admin"  "user2"
		group.kick "member" "user2"

		group.has? "member" "user2" jnz +2
			print "user2 still in group2"
			bail 1
		group.has? "admin" "user2" jnz +2
			print "user2 is an admin of group2"
			bail 1

		print "ok"),

	"ok",
	"group.join and group.kick");
};

subtest "augeas operators" => sub {
	mkdir "t/tmp/root";
	mkdir "t/tmp/root/etc";
	put_file "t/tmp/root/etc/hosts", <<EOF;
127.0.0.1 localhost localhost.localdomain

# The following lines are desirable for IPv6 capable hosts
::1     ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters

10.10.0.1 host.remove-me
EOF
	mkdir "t/tmp/augeas";
	mkdir "t/tmp/augeas/lenses";
	put_file "t/tmp/augeas/lenses/hosts.aug", <<'EOF';
(* Parsing /etc/hosts *)
module Hosts =
  autoload xfm
  let sep_tab = Util.del_ws_tab
  let sep_spc = Util.del_ws_spc
  let eol = del /[ \t]*\n/ "\n"
  let indent = del /[ \t]*/ ""
  let comment = Util.comment
  let empty   = [ del /[ \t]*#?[ \t]*\n/ "\n" ]
  let word = /[^# \n\t]+/
  let record = [ seq "host" . indent .
                              [ label "ipaddr" . store  word ] . sep_tab .
                              [ label "canonical" . store word ] .
                              [ label "alias" . sep_spc . store word ]*
                 . (comment|eol) ]
  let lns = ( empty | comment | record ) *
  let xfm = transform lns (incl "/etc/hosts")
EOF
	put_file "t/tmp/augeas/lenses/util.aug", <<'EOF';
module Util =
  let del_str (s:string) = del s s
  let del_ws = del /[ \t]+/
  let del_ws_spc = del_ws " "
  let del_ws_tab = del_ws "\t"
  let del_opt_ws = del /[ \t]*/
  let eol = del /[ \t]*\n/ "\n"
  let indent = del /[ \t]*/ ""
  let comment =
    [ indent . label "#comment" . del /#[ \t]*/ "# "
        . store /([^ \t\n].*[^ \t\n]|[^ \t\n])/ . eol ]
  let empty   = [ del /[ \t]*#?[ \t]*\n/ "\n" ]
  let split (elt:lens) (sep:lens) =
    let sym = gensym "split" in
    counter sym . ( [ seq sym . sep . elt ] ) *
  let stdexcl = (excl "*~") .
    (excl "*.rpmnew") .
    (excl "*.rpmsave") .
    (excl "*.augsave") .
    (excl "*.augnew")
EOF

	pendulum_ok(qq(
	fn main
		pragma augeas.root "t/tmp/root"
		pragma augeas.libs "t/tmp/augeas/lenses"

		augeas.init
		jz +1
		print "fail"

		augeas.done
		jz +1
		print "fail"
		print "ok"),

	"ok",
	"augeas.init initializes");

	pendulum_ok(qq(
	fn main
		pragma augeas.root "t/tmp/root"
		pragma augeas.libs "t/tmp/augeas/lenses"

		augeas.init
		jz +2
			print "init failed"
			ret

		augeas.get "/files/etc/hosts/4/canonical" %a
		jz +2
			augeas.perror "failed to get host #3 entry"
			ret

		print "canonical=%[a]s\\n"

		augeas.get "/files/etc/hosts/3/ipaddr" %a
		jz +2
			augeas.perror "failed to get host #3 entry"
			ret

		print "ip=%[a]s\\n"

		augeas.find "/files/etc/hosts/*[ipaddr = \\"127.0.0.1\\" and canonical = \\"localhost\\"]" %a
		jz +2
			augeas.perror "failed to find localhost"
			ret

		print "localhost=%[a]s\\n"
		augeas.done
		jz +2
			print "augeas.done failed"
			ret

		print "ok"),

	"canonical=ip6-mcastprefix\n".
	"ip=fe00::0\n".
	"localhost=/files/etc/hosts/1\n".
	"ok",
	"augeas.get");

	pendulum_ok(qq(
	fn main
		pragma augeas.root "t/tmp/root"
		pragma augeas.libs "t/tmp/augeas/lenses"

		augeas.init
		jz +2
			print "init failed"
			ret

		augeas.set "/files/etc/hosts/9999/ipaddr" "10.8.7.9"
		jz +2
			print "augeas.set #1 failed"
			ret

		augeas.set "/files/etc/hosts/9999/canonical" "new.host.example"
		jz +2
			print "augeas.set #2 failed"
			ret

		augeas.remove "/files/etc/hosts/7"
		jz +2
			print "augeas.remove failed"
			ret

		augeas.write
		jz +2
			print "write failed"
			ret

		print "ok"),

	"ok",
	"destructive augeas operations (remove + set + write)");

	file_is "t/tmp/root/etc/hosts", <<'EOF', "etc/hosts changed";
127.0.0.1 localhost localhost.localdomain

# The following lines are desirable for IPv6 capable hosts
::1     ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters

10.8.7.9	new.host.example
EOF

	pendulum_ok(qq(
	fn main
		pragma augeas.root "t/tmp/root"
		pragma augeas.libs "t/tmp/augeas/lenses"
		augeas.init

		set %b "B"
		augeas.get "/etc/hosts/80/ipaddr" %b
		jnz +1
		print "fail"
		print "ok:%[b]s"),

	"ok:B",
	"augeas.get returns non-zero to accumulator on failure");

	pendulum_ok(qq(
	fn main
		pragma augeas.root "t/tmp/root"
		pragma augeas.libs "t/tmp/augeas/lenses"
		augeas.init

		set %b "B"
		augeas.find "/etc/hosts/80" %b
		jnz +1
		print "fail"
		print "ok:%[b]s"),

	"ok:B",
	"augeas.find returns non-zero to accumulator on failure");

	pendulum_ok(qq(
	fn main
		pragma test        "on"
		pragma augeas.root "t/tmp/root"
		pragma augeas.libs "t/tmp/augeas/nowhere"
		augeas.init
		augeas.perror "init"),

	"init: found 1 problem:\n".
	"  /augeas/load/Hosts/error: Can not find lens Hosts.lns\n",
	"augeas.perror explains the augeas-level problems");
};

subtest "env operators" => sub {
	$ENV{OPERATOR} = "smooth";
	pendulum_ok(qq(
	fn main
		env.get "OPERATOR" %o
		jz +1
		print "FAIL\\n"
		print "a %[o]s operator"),

	"a smooth operator",
	"env.get");

	delete $ENV{XYZZY};
	pendulum_ok(qq(
	fn main
		env.get "XYZZY" %o
		jnz +1
		print "fail"
		print "ok"),

	"ok",
	"env.get");

	pendulum_ok(qq(
	fn main
		env.set "XYZZY" "fool!"
		env.get "XYZZY" %f
		print "a hollow voice says: %[f]s"),

	"a hollow voice says: fool!",
	"env.set");

	$ENV{XYZZY} = "zork";
	pendulum_ok(qq(
	fn main
		env.unset "XYZZY"
		env.get "XYZZY" %o
		jnz +1
		print "fail"
		print "ok"),

	"ok",
	"env.unset");
};

subtest "try / bail" => sub {
	pendulum_ok(qq(
	fn main
		print "ok"
		bail 0
		print "fail"),

	"ok",
	"bail with no try == halt");

	pendulum_ok(qq(
	fn inner
		print "ok"
		bail 0
		print "fail"

	fn main
		call inner
		print "fail"),

	"ok",
	"nested bail with no try == halt");

	pendulum_ok(qq(
	fn inner
		print "O"
		bail 0
		print "fail"

	fn main
		try inner
		print "K"),

	"OK",
	"immediate bail with try == retv");

	pendulum_ok(qq(
	fn bailout
		print "bailing\\n"
		bail 1
		print "ERROR: fell-through (bailout)!\\n"

	fn middle
		print "in middle()\\n"
		call bailout
		print "ERROR: fell-through (middle)!\\n"

	fn main
		print "starting\\n"
		try middle
		print "ok\\n"),

	"starting\n".
	"in middle()\n".
	"bailing\n".
	"ok\n",
	"bail will unwind stack until it finds a try call");

	pendulum_ok(qq(
	fn bailout
		print "bailing\\n"
		bail 1
		print "ERROR: fell-through (middle)!\\n"

	fn middle
		print "in middle()\\n"
		try bailout
		print "exiting middle()\\n"

	fn main
		print "starting\\n"
		try middle
		print "ok\\n"),

	"starting\n".
	"in middle()\n".
	"bailing\n".
	"exiting middle()\n".
	"ok\n",
	"bail only unwinds to first (innermost) try call");

	pendulum_ok(qq(
	fn bailout
		print "bailing\\n"
		bail 1
		print "ERROR: fell-through (middle)!\\n"

	fn middle
		print "in middle()\\n"
		try bailout
		jz +1
			bail 1
		print "exiting middle()\\n"

	fn main
		print "starting\\n"
		try middle
		print "ok\\n"),

	"starting\n".
	"in middle()\n".
	"bailing\n".
	"ok\n",
	"bail sets acc, which can be used to re-bail after a try");
};

subtest "flags" => sub {
	pendulum_ok(qq(
	fn doflags
		flag "red"
		flag "green"

	fn main
		flagged? "red"
		jnz +1
			print "early"

		call doflags
		flagged? "red"
		jz +1
			print "fail"
		print "ok"),

	"ok",
	"flag / flagged?");

	pendulum_ok(qq(
	fn main
		flag "red"
		flagged? "red"
		jz +1
			print "early"

		unflag "red"
		unflag "blue"

		flagged? "red"
		jnz +1
			print "fail"
		print "ok"),

	"ok",
	"unflag / flagged?");
};

subtest "properies" => sub {
	pendulum_ok(qq(
	fn main
		property "runtime" %a
		property "version" %b
		print "v%[b]s runtime %[a]s"),

	"v$VERSION runtime $RUNTIME",
	"property retrieval");

	pendulum_ok(qq(
	fn main
		set %c "ok"
		property "nonexistent" %c
		jnz +1
		print "fail"
		print "%[c]s"),

	"ok",
	"property handles non-existent properties properly");

	pendulum_ok(qq(
	fn main
		set %c "fail"
		pragma xyzzy "ok"
		property "xyzzy" %c
		jz +2
			print "property failed"
			bail 1
		print "%[c]s"),

	"ok",
	"property will retrieve a pragma value if no property is found");
};

subtest "acl" => sub {
	pendulum_ok(qq(
	fn main
		acl allow %sys "show version" final
		acl allow * show
		show.acls),

	"allow %sys \"show version\" final\n".
	"allow * \"show\"\n",
	"acl / show.acls");

	pendulum_ok(qq(
	fn main
		acl allow %sys "show version" final
		acl allow * show
		show.acl "user:sys:users"),

	"allow %sys \"show version\" final\n",
	"acl / show.acls");
};

subtest "tracing" => sub {
	pendulum_ok(qq(
	fn main
		pragma test "on"
		pragma trace "on"
		set %a 42
		push %a
		ret),

	"+set [21] 00000000 0000002a\n".
	"+push [20] 00000000\n".
	"+ret [00]\n",
	"trace output");
};

subtest "exec" => sub {
	pendulum_ok(qq(
	fn main
		exec "/bin/echo this is a test" %a
		jz +1
		print "fail"
		print %a
		print "ok"),

	"this is a test". # exec removes the newline
	"ok",
	"exec + echo");

	pendulum_ok(qq(
	fn main
		exec "/usr/bin/test 0 == 1" %a
		jnz +1
		print "fail"
		print "ok"),

	"ok",
	"exec passes return code via accumulator");

	pendulum_ok(qq(
	fn main
		set %a "ok"
		exec "/no/such/binary" %a
		jnz +1
		print "fail"
		print %a),

	"ok",
	"exec with a bad binary");

	SKIP: {
		skip "must be run as root for run-as UID/GID tests", 2
			unless $< == 0;

		mkdir "t/tmp";
		put_file "t/tmp/exec.pl", <<'EOF';
use POSIX;
my $uid = geteuid();
my $gid = getegid();
print "$uid:$gid\n"
EOF

		my @st = stat($0);
		my ($uid, $gid) = @st[4,5];

		pendulum_ok(qq(
		fn main
			runas.uid $uid
			runas.gid $gid

			exec "/usr/bin/perl t/tmp/exec.pl" %b
			jz +1
			print "fail"
			print "%[b]s\\n"),

		"$uid:$gid\n",
		"exec honors runas.* values");

		($uid, $gid) = (geteuid(), getegid());
		pendulum_ok(qq(
		fn main
			runas.uid 165536
			runas.gid 265536

			exec "/usr/bin/perl t/tmp/exec.pl" %b
			jz +1
			print "fail"
			print "%[b]s\\n"),

		"$uid:$gid\n",
		"out-of-bounds runas.* values are ignored");
	};
};

subtest "localsys" => sub {
	pendulum_ok(qq(
	fn main
		;; cheat - don't test the actual localsys
		pragma localsys.cmd "/bin/echo"
		localsys "ok" %b
		jz +1
		print "fail"
		print %b),

	"ok",
	"localsys");

	pendulum_ok(qq(
	fn main
		;; cheat - don't test the actual localsys
		pragma localsys.cmd "/bin/echo"
		set %a "ok"
		localsys "{{%[a]s}}" %b
		jz +1
		print "fail"
		print %b),

	"{{ok}}",
	"localsys deals in format strings");
};

subtest "remote" => sub {
	pendulum_ok(qq(
	fn main
		remote.live?
		jnz +1
		print "fail"
		print "ok"),

	"ok",
	"remote.live?");
};

subtest "topics" => sub {
	pendulum_ok(qq(
	fn main
		topic "a"
		print "%T: topic A\\n"
		topic "b"
		print "%T: topic B\\n"),

	"a: topic A\n".
	"b: topic B\n",

	"topic opcode and the %T format code");
};

subtest "disassembly" => sub {
	disassemble_ok(qq(
	fn main
		print "foo"
		print "foo"
		ret),

	<<EOF, "pendulum compiler de-duplicates strings");
0x00000000: 70 6e
0x00000002: 18 30 [00 00 00 13]           jmp 0x00000013
                                 fn main
0x00000013: 1c 30 [00 00 00 23]         print 0x00000023 ; "foo"
0x00000019: 1c 30 [00 00 00 23]         print 0x00000023 ; "foo"
0x0000001f: 10 00                         ret
0x00000021: ff 00
---
0x00000023: [foo]
EOF

	disassemble_ok(qq(
	fn main
		print "foo"
		print "foo"),

	<<EOF, "pendulum compiler inserts ret opcodes at the end of functions");
0x00000000: 70 6e
0x00000002: 18 30 [00 00 00 13]           jmp 0x00000013
                                 fn main
0x00000013: 1c 30 [00 00 00 23]         print 0x00000023 ; "foo"
0x00000019: 1c 30 [00 00 00 23]         print 0x00000023 ; "foo"
0x0000001f: 10 00                         ret
0x00000021: ff 00
---
0x00000023: [foo]
EOF

	disassemble_ok(qq(
	fn main
		print "foo"
		print "foo"
		bail 2),

	<<EOF, "pendulum compiler treats a final bail as sufficient");
0x00000000: 70 6e
0x00000002: 18 30 [00 00 00 13]           jmp 0x00000013
                                 fn main
0x00000013: 1c 30 [00 00 00 27]         print 0x00000027 ; "foo"
0x00000019: 1c 30 [00 00 00 27]         print 0x00000027 ; "foo"
0x0000001f: 11 10 [00 00 00 02]          bail 2
0x00000025: ff 00
---
0x00000027: [foo]
EOF
};

subtest "includes" => sub {
	local $ENV{PENDULUM_INCLUDE} = "/usr/lib/clockwork/not/a/thing:t/tmp:/another/enoent/path";
	put_file "t/tmp/incl.pn", <<EOF;
fn from.incl
  print "Hello, Includes!\\n"
EOF
	put_file "t/tmp/incl2.pn", <<EOF;
#include incl
fn from.incl2
  set %a 1
EOF

	pendulum_ok(qq(
	#include incl
	fn main
		call from.incl
		print "fin\\n"),

	"Hello, Includes!\n".
	"fin\n",
	"preprocessor directive for including works");

	pendulum_ok(qq(
	#include incl
	#include incl
	#include incl
	#include incl
	fn main
		call from.incl
		print "fin\\n"),

	"Hello, Includes!\n".
	"fin\n",
	"files can only be included once");

	disassemble_ok(qq(
	#include incl2
	fn main),

	<<EOF, "pendulum compiler handles nested includes");
0x00000000: 70 6e
0x00000002: 18 30 [00 00 00 7c]           jmp 0x0000007c

=== [ module : incl ] ==========================================================

                                 fn from.incl
0x0000002c: 1c 30 [00 00 00 80]         print 0x00000080 ; "Hello, Includes!\\n"
0x00000032: 10 00                         ret

=== [ module : incl2 ] =========================================================

                                 fn from.incl2
0x0000005a: 03 21 [00 00 00 00]           set %a
                  [00 00 00 01]               1
0x00000064: 10 00                         ret

=== [ MAIN ] ===================================================================

                                 fn main
0x0000007c: 10 00                         ret
0x0000007e: ff 00
---
0x00000080: [Hello, Includes!\\n]
EOF
};

subtest "stack" => sub {
	pendulum_ok(qq(
	fn myfunc
		set %a "from myfunc"
		set %p "in myfunc"
		ret

	fn main
		set %a "from main"
		set %p "in main"
		call myfunc
		print "%[a]s, %[p]s"),

	"from main, in main",
	"ret opcode unwinds stack");

	pendulum_ok(qq(
	fn myfunc
		set %a "from myfunc"
		set %p "in myfunc"
		ret

	fn inner
		set %a "from inner"
		set %p "in inner"
		call myfunc
		set %a "after myfunc"
		set %p "still in inner"

	fn main
		set %a "from main"
		set %p "in main"
		call inner
		print "%[a]s, %[p]s"),

	"from main, in main",
	"ret opcode unwinds stack through multiple levels");

	pendulum_ok(qq(
	fn myfunc
		set %a "from myfunc"
		set %p "in myfunc"
		bail 0

	fn main
		set %a "from main"
		set %p "in main"
		try myfunc
		print "%[a]s, %[p]s"),

	"from main, in main",
	"bail opcode unwinds stack");

	pendulum_ok(qq(
	fn myfunc
		set %a "from myfunc"
		set %p "in myfunc"
		bail 0

	fn inner
		set %a "from inner"
		set %p "in inner"
		call myfunc
		set %a "after myfunc"
		set %p "still in inner"

	fn main
		set %a "from main"
		set %p "in main"
		try inner
		print "%[a]s, %[p]s"),

	"from main, in main",
	"bail opcode unwinds stack through multiple levels");

	pendulum_ok(qq(
	fn myfunc
		set %a "from myfunc"
		set %p "in myfunc"
		bail 0

	fn inner
		set %a "from inner"
		set %p "in inner"
		try myfunc
		set %a "after myfunc"
		set %p "still in inner"

	fn main
		set %a "from main"
		set %p "in main"
		call inner
		print "%[a]s, %[p]s"),

	"from main, in main",
	"bail opcode unwinds stack with an inner try");

	pendulum_ok(qq(
	fn myfunc
		push "from myfunc"
		ret
	fn main
		push "from main"
		call myfunc
		pop %b
		print "%[b]s"),

	"from myfunc",
	"push/pop operate on their own data stack");
};

subtest "runtime version detection" => sub {
	pendulum_ok(qq(
	fn main
		runtime %a
		lt %a 21840125 jz +2
			print "%[a]i >= 21840125...\\n"
			bail 1
		gt %a 20150119 jz +2 ; 20150131 was the first runtime
		                     ; to support `runtime %a`
			print "%[a]i <= 20150119...\\n"
			bail 1
		print "ok"),

	"ok",
	"runtime version detection works");
};

subtest "fs.mkparent parentage" => sub {
	qx(rm -rf t/tmp; mkdir -p t/tmp);
	pendulum_ok(qq(
	fn main
		fs.dir? "t/tmp/new" jnz +2
			print "t/tmp/new already exists!"
			bail 1
		fs.mkparent "t/tmp/new/file"
		jz +2
			perror "fs.mkparent call failed"
			bail 1
		fs.dir? "t/tmp/new" jz +2
			print "t/tmp/new not created!"
			bail 1
		fs.stat "t/tmp/new/file" jnz +2
			print "t/tmp/new/file was created!"
			bail 1
		print "ok"),

	"ok",
	"fs.mkparent creates single-level ancestry");

	qx(rm -rf t/tmp; mkdir -p t/tmp);
	pendulum_ok(qq(
	fn main
		fs.dir? "t/tmp/new" jnz +2
			print "t/tmp/new already exists!"
			bail 1
		fs.dir? "t/tmp/new/place/for" jnz +2
			print "t/tmp/new/place/for already exists!"
			bail 1
		fs.mkparent "t/tmp/new/place/for/file"
		jz +2
			perror "fs.mkparent call failed"
			bail 1
		fs.dir? "t/tmp/new" jz +2
			print "t/tmp/new not created!"
			bail 1
		fs.dir? "t/tmp/new/place/for" jz +2
			print "t/tmp/new/place/for not created!"
			bail 1
		fs.stat "t/tmp/new/place/for/file" jnz +2
			print "t/tmp/new/place/for/file was created!"
			bail 1
		print "ok"),

	"ok",
	"fs.mkparent creates multi-level ancestry");

	qx(rm -rf t/tmp; mkdir -p t/tmp/an/old/place/for);
	pendulum_ok(qq(
	fn main
		fs.dir? "t/tmp/an" jz +2
			print "t/tmp/an doesnt exist!"
			bail 1
		fs.dir? "t/tmp/an/old/place" jz +2
			print "t/tmp/an/old/place doesnt exist!"
			bail 1
		fs.mkparent "t/tmp/an/old/place/for/file"
		jz +2
			perror "fs.mkparent call failed"
			bail 1
		fs.dir? "t/tmp/an" jz +2
			print "t/tmp/an was removed!"
			bail 1
		fs.dir? "t/tmp/an/old/place/for" jz +2
			print "t/tmp/an/old/place/for was removed!"
			bail 1
		fs.stat "t/tmp/an/old/place/for/file" jnz +2
			print "t/tmp/an/old/place/for/file was created!"
			bail 1
		print "ok"),

	"ok",
	"fs.mkparent is idempotent");

	SKIP: {
		skip "must be run as root for chown/chgrp tests", 1
			unless $< == 0;
		qx(rm -rf t/tmp; mkdir -p t/tmp);
		pendulum_ok(qq(
		fn checkdir
			fs.dir? %a jz +2
				print "%[a]s not created!"
				bail 1

			fs.mode %a %e
			eq %e %b jz +2
				print "permissions of %[a]s set to %[e]04o (not %[b]04o)"
				bail 1

			fs.uid %a %e
			eq %e %c jz +2
				print "ownership of %[a]s set to %[e]i (not %[c]i)"
				bail 1

			fs.gid %a %e
			eq %e %d jz +2
				print "group ownership of %[a]s set to %[e]i (not %[d]i)"
				bail 1
			ret

		fn main
			fs.dir? "t/tmp" jz +2
				print "t/tmp doesnt exist!"
				bail 1
			fs.dir? "t/tmp/all/the/way" jnz +2
				print "t/tmp/all/the/way already exists!"
				bail 1

			fs.chmod "t/tmp" 0757 set %b 0757
			fs.chown "t/tmp" 1234 set %c 1234
			fs.chgrp "t/tmp" 9876 set %d 9876

			fs.mkparent "t/tmp/all/the/way/down"
			jz +2
				perror "fs.mkparent call failed"
				bail 1

			set %a "t/tmp/all"
			call checkdir

			set %a "t/tmp/all/the"
			call checkdir

			set %a "t/tmp/all/the/way"
			call checkdir
			print "ok"),

		"ok",
		"fs.mkparent honors parent ownership/permissions");
	};
};

subtest "sha1" => sub {
	pendulum_ok(qq(
		fn main
			sha1 "abc" %a
			jz +2
				perror "SHA1 failed"
				bail 1
			print "%[a]s"),

	"a9993e36"."4706816a"."ba3e2571"."7850c26c"."9cd0d89d",
	"FIPS Pub 180-1 test vector #1");

	pendulum_ok(qq(
		fn main
			sha1 "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq" %a
			jz +2
				perror "SHA1 failed"
				bail 1
			print "%[a]s"),

	"84983e44"."1c3bd26e"."baae4aa1"."f95129e5"."e54670f1",
	"FIPS Pub 180-1 test vector #2");
};

qx(rm -rf t/tmp);
done_testing;
