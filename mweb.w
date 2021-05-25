% control sequence list
\def\ctrli{\hbox{\tt @@i}}

@** Introduction.
This is \.{MWEB} program by Zhizhong Ma, based on \.{CWEB} and \.{NOWEB},
aimed at providing a literate programming tool useful in creating programs
with multiple languages.  It's similar to its two predecessors in weaving,
\.{CWEB}'s formating and \.{NOWEB}'s cross-referencing particularly, 
other parts are written from scratch.  The \.{M} in name is from {\it multiple},
my family name(accidentally), and \.{MAKE}.

I believe that a well documented program dose not only depend on well printing
and ordering, but also expressive code.  Starting from this belief,
I often write a program with several languages simultaneously,
some of them are even created by myself.
\.{CWEB} is supposed to be a criterion for all literate programming tools,
it's pure and beautiful, but can not do these dirty works for me.
Then I turn to \.{NOWEB}, another powerful tool,
having a happy time with it, but usually these hacking stuffs rely heavily
on \.{MAKE} or other related tools.  \.{NOWEB}'s model of multiple source files to
multiple object files is also a problem when dealing with large programs.

The essence of these problems or limitations is that these tools are supposed
to cooperate with current building process of a program. For example,
they regard producing \CEE/ source files as the final object,
and let \.{MAKE} or others do the remaining part of building.
The result is that what they document is source files in fact,
rather than programs that they ought to document.
When I try to read a literate program, the first file I read is
usually not the well printed PDF document, but the \.{Makefile}.

Let's consider the constructing of a program in a broad view.
If we want the program running on \.{linux} of \.{X64} platform,
what we need exactly is \.{X64} assembly code with specification of linux's system calls,
but we do not write assembly code ourselves.  Relying on marvelous
compilers and interpreters, we write \CEE/, \.{Python}, \.{Shell} to achieve
what we want to do.  These compilers and interpreters perform translation
between the code we write and the code machine want, or more generally,
any code we are happy to write and any code be able to perform actions.
Now the important, the two kinds of code are equivalent.

The major purpose of \.{MWEB} is to integrate the translation to
literate programming.  Thus, I can use any code I like to describe
the computing, the program, or the process.
It means a part of functionalities of \.{MAKE} will be transfered to \.{MWEB},
as you will see later, I rewrite this part in a more efficient way,
which is adopted by \.{GIT}.

@c
@<includes@>@;
@<macros@>@;
@<typedefs@>@;
@<global variables@>@;
@<prototypes@>@;
@#
int
main(int argc, char **argv)
{
	int t_flag = 1, w_flag = 1;
	ifile *src; /* the source file */

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

@* Usage. \.{MWEB} is invoked from command line, accept a file name as the only argument.
Unlike \.{CWEB} and \.{NOWEB}, I do not divide it into two parts.
Each invoking will do both tangling and weaving.
This behaviour can be changed by renaming the final executable file,
you can create links to achieve same effect.

@<parse command line@>=
{
	char *cmd;
	int i;

	if (argc != 2) {
		err_quit("usage: %s file", argv[0]);
	}

	src = ifile_open(argv[1]);

	cmd = strrchr(argv[0], '/');
	if (cmd) {
		cmd++;
	} else {
		cmd = argv[0];
	}

	if (strcmp(cmd, "mtangle") == 0) {
		w_flag = 0;
	} else if (strcmp(cmd, "mweave") == 0) {
		t_flag = 0;
	}
}

@* Read input. To improve efficiency and make use of modern PC's big memory,
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

@ This process can be influenced by control sequence \ctrli,
when \ctrli\ is found, we must temporily stop reading the current file
and start reading from a file that named by following contents of the same line.
\ctrli\ should be placed at beginning of a line, followed by a filename(with double
quotes if contains blanks), the remainder is ignored.

A recursive invoking may be a good choice.
@<read input@>=
read_input(src);
ifile_close(src);

@
@<prototypes@>=
void read_input(ifile *);

@
@c
void
read_input(ifile *ifp)
{
	while (readline(ifp)) {
		int skip = 0; /* whether to skip this line */
		@<handle control sequence when in inputting@>@;
		if (skip) continue;
		strcpy(buffer_end, line_buffer);
		buffer_end += strlen(line_buffer);
	}
}

@
@<handle control sequence when in inputting@>=
if (line_buffer[0] == '@@') {
	switch(line_buffer[1]) { /* use a switch for further extending */
	case 'i':
		@<parse filename and include it@>@;
		skip = 1; /* discard \ctrli\ line */
		break;
	default:
		break;
	}
}

@
@<parse filename and include it@>=
{
	char *f;
	ifile *nifp; /* new ifp */

	f = &line_buffer[2];
	f = skip_blank(f);
	{	/* find ending of a file name */
		char *e = f;
		do {
			e++;
		} while (*e != '"' && *e != '\n');
		*e = '\0';
	}

	nifp = ifile_open(f);
	read_input(nifp);
	ifile_close(nifp);
}

@** Tangling.

@
@<do tangling@>=

@** Weaving.
@<do weaving@>=
printf("%s", buffer);

@** I/O control.
There are two kinds of I/O, line-oriented and byte-oriented.
Line-oritented is used for inputting source files and informing user running state
of \.{MWEB}.  Byte-oriented is used for saving code chunks.

@* Line-oriented.

@<prototypes@>=
void inform(char *); /* inform user */
ifile *ifile_open(char *); /* open an file for inputting */
void ifile_close(ifile *);
char *readline(ifile *); /* read a line */

@ The longest string of characters seperated by newline is limited to size of 1024.
@<macros@>=
#define MAXLINE (2<<10)

@ Use a common buffer.
@<global variables@>=
char line_buffer[MAXLINE];

@ A wrapper of |fputs|, inform user what happened, always use |stderr| as target.
@c
void
inform(char *msg)
{
	fputs(msg, stderr);
	fflush(stderr);
}

@ Reading of source files is controlled by |struct ifile|,
which consists of a pathname and a pointer to stream connecting to the file.
Assume that the pathname is shorter than the longest specified by \.{POSIX}.
@f ifile int
@<typedefs@>=
typedef struct ifile {
	char path[_POSIX_PATH_MAX];
	FILE *fp;
} ifile;

@ Together with a initialization funciton. The function searches
the file through a list of paths that is specified by environment variable {\tt MWEBINPUTS}.
{\tt MWEBINPUTS} is similar to {\tt PATH}, pathnames are seperated by {\tt :}.
@c
ifile *
ifile_open(char *f)
{
	ifile *ifp;
	FILE *fp;
	char *pl, *p; /* path list and path */
	static char plr[MAXLINE * 4]; /* path list reserved */

	ifp = (ifile *) malloc(sizeof(ifile));
	pl = getenv("MWEBINPUTS");

	if (strlen(pl) >= MAXLINE) { /* assume length(MWEBINPUTS) < 4096 */
		err_quit("the environment variable MWEBINPUTS is too long");
	}
	strcpy(plr, pl);
	pl = plr;

	strcpy(ifp->path, f); /* search current directory first */
	do {
		fp = fopen(ifp->path, "r");
		if (fp || !pl) break;

		p = pl;  /* the head of current path list */
		pl = strchr(pl, ':');
		if (pl) *(pl++) = '\0'; /* remove the head */

		strcpy(ifp->path, p);
		strcat(ifp->path, "/");
		strcat(ifp->path, f);
	} while(1);

	if (fp == NULL) {
		err_quit("failed to find %s", f);
	}
	ifp->fp = fp;
	return ifp;
}

@ Like file descriptor and stream, you should close a |ifile| if you do not need
it anymore.
@c
void
ifile_close(ifile *ifp)
{
	if (fclose(ifp->fp) == EOF) {
		err_sys("failed to close %s", ifp->path);
	}
	free(ifp);
}

@ Read a source file line by line.
@c
char *
readline(ifile *ifp)
{
	char *l;
	l = fgets(line_buffer, MAXLINE, ifp->fp);
	if (l && strlen(l) == MAXLINE - 1) {
		err_quit("met a line too long when read %s", ifp->path);
	}
	return l;
}

@** Miscellaneous.
This chapter is about the part of this program not worthy of mentioning
but indipensable for actually running.

@* Interface to \CEE/ programming environment. A lot of header files are
used to get access to \CEE/ standard library and system calls.

@<includes@>=
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>

#include <limits.h>
#include <errno.h>
#include <fcntl.h>

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <stdarg.h>

@* String operation.  \CEE/ standard library does not provide
some useful operations.

@<prototypes@>=
char *skip_blank(char *); /* skip continues blanks */

@ The blanks can be tabs and spaces.
@c
char *
skip_blank(char *cur)
{
	while (*cur == ' ' || *cur == '\t') {
		cur++;
	}
	return cur;
}

@* Error handling.  Functions used to locate different conditions
when an error occur.  Mainly two conditions under consideration:

1. Related to a system call.

2. Unrelated to a system call.

@<prototypes@>=
void err_sys(const char *, ...); /* condition 1, print a message and terminate */
void err_dump(const char *, ...); /* condition 1, print a message, dump core, and terminate */
void err_quit(const char *, ...); /* condition 2, print a message and terminate */

@ Use a helper function |err_doit| to print message.
Caller specifies |errnoflag| to decide whether to append |errno| imformation.
@c
void 
err_doit(int errnoflag, const char* fmt, va_list ap)
{
	vsnprintf(line_buffer, MAXLINE-1, fmt, ap);
	if (errnoflag)
		snprintf(line_buffer + strlen(line_buffer),
			MAXLINE - strlen(line_buffer) - 1, 
			": %s", strerror(errno));
	strcat(line_buffer, "\n");
	inform(line_buffer);
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
