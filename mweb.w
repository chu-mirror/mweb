@** Introduction.
This is \.{MWEB} program by Ma Zhizhong, based on \.{CWEB} and \.{NOWEB},
aimed at providing a literate programming tool useful in creating programs
with multiple languages.  It's similar to its two predecessors in weaving,
\.{CWEB}'s formating and \.{NOWEB}'s cross-referencing particularly, 
other parts are written from scratch.  The \.{M} in name is from {\it multiple},
my family name(accidentally), and {\it make}.

I believe that a well documented program dose not only depend on well printing
and ordering, but also expressive code.  Starting from this belief,
I often write a program with several languages simultaneously,
some of them are even created by myself.
\.{CWEB} is supposed to be a criterion for all literate programming tools,
it's pure and beautiful, but can not do these dirty works for me.
Then I turn to \.{NOWEB}, another powerful tool,
having a happy time with it, but usually these hacking stuffs rely heavily
on \.{make} or other related tools.
\.{NOWEB}'s model of multiple to multiple is also a problem when dealing with
large programs.

The essence of these problems or limitations is that these tools are supposed
to cooperate with current building process of a program. For example,
they regard producing \CEE/ source files as the final object,
and let \.{make} or others do the remaining part of building.
The result is that what they documented is source files in fact,
rather than programs themselves.
When I try to read a literate program, the first file I read is
usually not the well printed PDF document, but the \.{Makefile}.

Let's consider the constructing of a program in a broad view.
If we want the program running on \.{linux} of \.{X64} platform,
what we need exactly is \.{X64} assembly code with specification of linux's system calls,
but we do not write assembly code ourselve.  Relying on marvelous
compilers and interpreters, we write \CEE/, \.{Python}, \.{Shell} to achieve
what we want to do.  These compilers and interpreters perform translation
between the code we write and the code machine want, or more generally,
any code we are happy to write and any code be able to perform actions.
Now the important, the two kinds of code are equivalent.

The major purpose of \.{MWEB} is integrating the translation to
literate programming.  Thus, I can use any code I like to describe
the computing, the program, the process.
It means a part of functionalities of \.{make} will be transfered to \.{MWEB},
as you will see later, I rewrite this part in a more efficient way,
which used by \.{GIT}.

@c
@<includes@>@/
@<macros@>@/
@<typedefs@>@/
@<global variables@>@/
@<prototypes@>
@#
int
main(int argc, char **argv)
{
	int fd_in;
	int t_flag = 1, w_flag = 1;

	@<parse command line@>@;
	@<initialize global variables@>@;
	@<read input@>@;

	if (t_flag) {
		@<do tangling@>@;
	}
	if (w_flag) {
		@<do weaving@>@;
	}
}

@* Usage. \.{MWEB} is invoked from command line, accept a file name as the argument.
Unlike \.{CWEB} and \.{NOWEB}, I do not divide it into two parts.
Each invoking will do both tangling and weaving.
This behaviour can be changed by rename the final executable file,
you can create links to achieve same effect.

@<parse command line@>=
{
	char *name;
	int i;

	if (argc != 2) {
		err_quit("usage: %s file", argv[0]);
	}

	fd_in = openat(AT_FDCWD, argv[1], O_RDONLY);
	if (fd_in == -1) {
		err_sys("failed to open file %s", argv[1]);
	}

	for (name = argv[0], i = 0; argv[0][i]; i++) {
		if (argv[0][i] == '/') {
			name = &argv[0][i+1];
		}
	}
	if (strcmp(name, "mtangle") == 0) {
		w_flag = 0;
	} else if (strcmp(name, "mweave") == 0) {
		t_flag = 0;
	}
}

@* Read file. To improve efficiency and make use of modern PC's big memory,
I use a relatively large buffer(16MB) to save the whole file.
@<macros@>=
#define BUFFER_LENGTH (1<<24)

@
@<global variables@>=
char buffer[BUFFER_LENGTH];
char *buffer_end;

@ 
@<initialize global variables@>=
buffer_end = &buffer[0];

@
@<read input@>=
{
	ssize_t rd, fr;
	fr = BUFFER_LENGTH; /* remaining free space */
	do {
		rd = read(fd_in, buffer_end, fr);
		if (rd == -1) {
			err_sys("failed to read file %s", argv[1]);
		} else {
			buffer_end += rd;
			fr -= rd;
		}
		if (fr == 0) {
			err_quit("file %s is too big", argv[1]);
		}
	} while (rd);
	*buffer_end = '\0';
}

@** Tangling.
@<typedefs@>=
typedef struct chunk{
	struct chunk *li;
} chunk;

@
@<do tangling@>=

@** Weaving.
@<do weaving@>=
printf("%s", buffer);

@** Miscellaneous.
This chapter is about the part of this program not worthy of mentioning
but indipensable for actually running.

@* Interface to \CEE/ programming environment. A lot of header files are
used to get access to \CEE/ standard library and system calls.

@<includes@>=
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>

#include <errno.h>
#include <fcntl.h>

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <stdarg.h>

@* I/O control.

@ The longest string of characters seperated by newline is limited to size of 1024.
@<macros@>=
#define MAXLINE (2<<10)

@* Error handling.
Defined functions used to locate different conditions
when an error occur.  
Mainly two conditions under consideration:

1. Related to a system call.

2. Unrelated to a system call.

@<prototypes@>=
void err_sys(const char *fmt, ...); /* condition 1, print a message and terminate */
void err_dump(const char *fmt, ...); /* condition 1, print a message, dump core, and terminate */
void err_quit(const char *fmt, ...); /* condition 2, print a message and terminate */

@ Use a helper function |err_doit| to print message.
Caller specifies |errnoflag| to decide whether to append |errno| imformation.
@c
void 
err_doit(int errnoflag, const char* fmt, va_list ap)
{
	char buf[MAXLINE];

	vsnprintf(buf, MAXLINE-1, fmt, ap);
	if (errnoflag)
		snprintf(buf + strlen(buf), MAXLINE - strlen(buf) - 1, 
		  ": %s", strerror(errno));
	strcat(buf, "\n");
	fflush(stdout);
	fputs(buf, stderr);
	fflush(NULL);
}


@ Fatal error related to a system call, 
print a message and terminate.
@c
#define ERR_PRINT(flag) { \
	va_list ap; \
	va_start(ap,fmt) ; \
	err_doit(flag,fmt,ap) ; \
	va_end(ap) ; \
}
void 
err_sys(const char *fmt, ...)
{
	ERR_PRINT(1);
	exit(1);
}

@ Fatal error related to a system call,
print a message, dump core, and terminate.
@c
void 
err_dump(const char *fmt, ...)
{

	ERR_PRINT(1);
	abort();
	exit(1);
}

@ Fatal error unrelated to a system call,
print a message and terminate.
@c
void
err_quit(const char *fmt, ...)
{
	ERR_PRINT(0);
	exit(1);
}

#undef ERR_PRINT
