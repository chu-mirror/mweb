% control sequence
\def\ctrllist#1#2{\hbox{\hskip 0.5in\ctrl#1: #2}}
\def\ctrl#1{\hbox{\tt @@#1}}

@** Introduction.
This is \.{MWEB} program by Zhizhong Ma, based on \.{CWEB} and \.{NOWEB},
aiming at providing a literate programming tool useful in creating programs
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
rather than programs that they ought to describe.
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
Now the important, the two kinds of code are equivalent in means of taking actions.

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
@<prototypes@>@;
@<global variables@>@;
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
I use a relatively large buffer(16MB) to save the whole input.
@<macros@>=
#define BUFFER_LENGTH (1<<24)

@
@<global variables@>=
char buffer[BUFFER_LENGTH];
char *buffer_end;

@ 
@<initialize global variables@>=
buffer_end = &buffer[0];

@ This process can be influenced by control sequence \ctrl{i},
when \ctrl{i}\ is found, we must temporily stop reading the current file
and start reading from a file that named by following contents of the same line.
\ctrl{i}\ should be placed at beginning of a line, followed by a filename(with double
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
		skip = 1; /* discard \ctrl{i}\ line */
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
Like other literate programming tools, code is represented as code chunks.
Each code chunk describe a part of the whole program, they can be combined in
mainly two ways, including and concatenating.  Concatenating is simply combining them
one by one, \.{MWEB} does on special things in combining.  The combined
chunks act as a new unit, called {\t section}, and each section has a name.
By now, \.{MWEB} is not different with other tools, but it will diverge from tradition
soon when including is under consideration. 

Including works the same as \ctrl{i}, I have said that it's a way to combining chunks, but
what can be included is sections in fact.  \.{MWEB} introduced translating to
including, an including does not copy text verbatim from the section included,
the text is transfered to a filter. The name {\it filter} comes from \.{UNIX} system,
and it means basically the same thing in \.{MWEB}.  So, an including recepts the
output from filters, and insert it into the section that performs the including.
A filter can be \CEE/ compiler, \.{m4} interpreter, a perl script...etc, it can
be defined in \.{MWEB}'s source file as a piece of shell script, like any other code chunk.

The outline of tangling is all introduced, details will be talked in following
implementation.  Make sure the data structures first.

@ A code chunk can be represented by two pointers to |buffer|, |start| and |end|,
for convenience, a pointer to next chunk is also saved.
@<typedefs@>=
typedef struct chunk {
	char *start;
	char *end;
	struct chunk *next;
} chunk;

@ A section contains a section name, a list of code chunks, and the filter it use.
The size of space used by names' saving can be safely set to |MAXLINE|, for
all names are specified within one line.
@<typedefs@>=
typedef struct section {
	char name[MAXLINE]; 
	char filter[MAXLINE];
	struct chunk *code;
} section;

@ A filter is itself a program, so it can also be expressed as text plus filter
as same as sections.  The difference between a section and a filter is the way in
treating the text, a section's text is used as input to a filter for getting output,
a filter's text is used to drive the interpreter, the drived interpreter's actions
form a program named filter.  To \.{MWEB}, a filter is just a section plus a
interpreter, \.{MWEB} use Bourne Shell as the interpreter.

@* Parse input.  The main purpose of this phrase is extracting useful informations
for tangling, and build index for sections and filters by hash tables.
@<do tangling@>=
@<parse input for tangling@>

@ Before going forward, a little work should be done for further development.
We have introduced control sequence \ctrl{i}\ to \.{MWEB}, no surprise there are a lot
others.  We only care about \ctrl{i}\ in reading input, so sequence's function
and sequence can be easily paired.  Things change when the number
of sequences increased, each one has its own function, but these functions
can relate to each other.  The complexity will soon be out of control, if we do not
give a plan in mapping sequences to their functions.

In parsing for tangling, we want control sequences to be able to label the start and the end of some
contents.  The contents is a block of text, can be code or name. So we define:
\vskip 3pt
\ctrllist{<}{start of a section name}
\ctrllist{>}{end of a section name, start of a code chunk}
\ctrllist{:}{followed by the filter name used in this section}
\ctrllist{\it newline}{end of a code chunk}
\vskip 3pt
You might have noticed that there are some rules of places they appear.  For example, you can not
place start of another section name in a section name.  From this observation,
\.{MWEB} use a global variable |context| to indicate current type of text.
@<global variables@>=
context_1 context; /* current context, |context_0| is used in reading input */
char *loc; /* current location */

@ There are three types of text for now, code, name, others.
@<typedefs@>=
typedef enum context_1{ NAME, CODE, OTHERS }; 

@ |context| should be initialized to |OTHERS| at the beginning of parsing,
together with a lot of other initializations.

@<prepare global variables before parsing for tangling@>=
loc = 0;
context = OTHERS;

@ The parsing is designed to handle one character at once, so an immediate pasing
should be done if current character is needed.
@<global variables@>=
char *dest;

@
@<prepare global variables before parsing for tangling@>=
dest = NULL;

@ So the entire parse process can be written.
@<parse input for tangling@>=
@<prepare global variables before parsing for tangling@>@;
while (loc != buffer_end) {
	if (*loc == '@@') {
		@<handle control sequence in parsing for tangling@>@;
	} else {
		if (dest) *(dest++) = *(loc++);
	}
}

@
@<handle control sequence in parsing for tangling@>=


@ The next is studying the functions, find out how they can be implemented.
From the list above, we can get:
@<prototypes@>=
void start_section_name(void);
void end_section_name(void);
void start_code_chunk(void);
void end_code_chunk(void);
void attach_filter(void);

@
@c
void
start_section_name()
{
	
}

@ Combine them to build functions defined by contexts and control sequences.
@<prototypes@>=
void others_left_angle_bracket(void);
void name_others_right_angle_bracket(void);
void code_colon(void);
void code_newline(void);

@ Functions of left angle bracket.
@c
void
others_left_angle_bracket()
{
	start_section_name();
}

@ Right angle bracket. Use a {\tt =} to indicate start of code chunk.
@c
void
name_right_angle_bracket()
{
	end_section_name();
	if (*loc != '=') {
		err_quit("syntax error: missing a '='");
	}
	loc++;
	start_code_chunk();
}

@ Colon.
@c
void
code_newline()
{
	attach_filter();
}



@** Weaving.
@<do weaving@>=


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
@<global variables@>=
char *inputs_path; /* position of environment variable MWEBINPUTS */

@
@<initialize global variables@>=
inputs_path = getenv("MWEBINPUTS");
if (!inputs_path) {
	inputs_path = "."; /* give it a default value */
}
if (strlen(inputs_path) >= MAXLINE * 4) { /* assume length(MWEBINPUTS) < 4096 */
	err_quit("the environment variable MWEBINPUTS is too long");
}

@
@c
ifile *
ifile_open(char *f)
{
	ifile *ifp;
	FILE *fp;
	char *pl, *p; /* path list and path */
	static char plt[MAXLINE * 4]; /* tempory storing for path list */

	NEW(ifp);

	strcpy(plt, inputs_path); /* avoid operating on |env| */
	pl = plt;

	@<search for |f| in |pl|@>@;

	if (fp == NULL) {
		char ff[MAXLINE];
		strcpy(ff, f);
		err_quit("failed to find %s", ff);
		/* |err_quit("...", f)| do wrong, and I don't known why */
	}
	ifp->fp = fp;
	return ifp;
}

@
@<search for |f| in |pl|@>=
strcpy(ifp->path, f); /* search current directory first */
do {
	fp = fopen(ifp->path, "r");
	if (fp || !pl) break;

	p = pl;  /* the head of current path list */

	pl = strchr(pl, ':'); /* remove the head */
	if (pl) *(pl++) = '\0';

	strcpy(ifp->path, p); /* build new path */
	strcat(ifp->path, "/");
	strcat(ifp->path, f);
} while(1);

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

@* Hash table.  \.{MWEB} use a simple hash code that is also used by \.{CWEB}.
$$
(2^{n-1}c_1+2^{n-2}c_2+\cdots+c_n)\bmod |hash_size|
$$
@<prototypes@>=
int hash_code(char *);
void hash_insert(hash_table *, char *, void *);
void *hash_get(hash_table *, char *);

@
@c
int
hash_code(char *v)
{
	char *cp;
	int h;

	for (h = 0, cp = v; *cp; cp++) {
		h = (h + h + *cp) % hash_size;
	}

	return h;
}

@ |hash_size| is set to |8501|.
@<macros@>=
#define hash_size 8501

@ Because there are different kinds of names,
I do not allocate memory for these tables here.
@<typedefs@>=

typedef struct hash_entry {
	struct hash_entry *next;
	char lable[MAXLINE];
	void *p;
} hash_entry;

typedef struct hash_table {
	hash_entry *entries[hash_size];
} hash_table;

@ Insert a element to |hash_table|.
@c
void
hash_insert(hash_table *tbl, char *v, void *e)
{
	int h;
	hash_entry *et;

	h = hash_code(v);
	NEW(et);

	strcpy(et->lable, v); /* initialize new |hash_entry| */
	et->p = e;
	et->next = tbl->entries[h];

	tbl->entries[h] = et; /* insert it to head of list */
}

@
@c
void *
hash_get(hash_table *tbl, char *v)
{
	int h;
	hash_entry *li;

	h = hash_code(v);
	li = tbl->entries[h];

	while(li) {
		if (!strcmp(li->lable, v)) {
			return li->p;
		}
		li = li->next;
	}

	return NULL;
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

@* Memory management.
All nontrivial \.{C} programs allocate memory at runtime.
And I'm going to write nontrivial \.{C} programs,
so careful reflection should be paid on memory management.

This chapter repackages the standard \.{C} library's three
memory-management routines: |malloc|, |calloc|, and |free|,
aiming to provide a interface that are less prone to error
and provide a few additional capabilities.

@ @<prototypes@>=
void *mem_alloc(long, int);
void *mem_calloc(long, long, int);
void mem_free(void *, int);

@ The two basic functions to allocate memory, 
use additional argument |line| to report bugs.
The standard library use type |size_t| for arguments,
but arguments are declared |long| here to avoid errors
when negative numbers are passed to unsigned arguments.
@f line x
@c
void *
mem_alloc(long nbytes, int line)
{
	void *p;

	if (nbytes <= 0) {
		err_quit("allocating %d bytes memory in line %d", nbytes, line);
	}
	p = malloc(nbytes);
	if (p == NULL) {
		err_sys("failed to allocate memory in line %d", line);
	}
	return p;
}

void *
mem_calloc(long count, long nbytes, int line)
{
	void *p;

	if (nbytes <= 0 || count <= 0) {
		err_quit("allocating %d times %d bytes memory in line %d", 
			count, nbytes, line);
	}
	p = calloc(count, nbytes);
	if (p == NULL) {
		err_sys("failed to allocate memory in line %d", line);
	}
	return p;
}


@ Use macro |__LINE__| to get current line's number.
@<macros@>=
#define ALLOC(nbytes) mem_alloc((nbytes), __LINE__)
#define CALLOC(count, nbytes) mem_calloc((count), (nbytes), __LINE__)

@ It's common to use idiom |p = malloc(sizeof *p)|,
encapsulate the allocation and assignment with macros. 
|NEW0| allocate a initialized block of zeros. 
@<macros@>=
#define NEW(p) ((p) = ALLOC((long)sizeof *(p)))
#define NEW0(p) ((p) = CALLOC(1, (long)sizeof *(p)))

@ Memory is deallocated by |mem_free|, 
like the previous two functions,
use |line| to report bugs.
Deallocating of a null pointer is regarded as a bug.
|FREE| does two things, invokes |mem_free| and sets |ptr| to the null pointer.
Note that |FREE| evaluates ptr more than once.
@<macros@>=
#define FREE(ptr) ((void)(mem_free((ptr), __LINE__), (ptr) = 0))

@
@c
void
mem_free(void *ptr, int line)
{
	if (ptr == NULL) {
		err_quit("deallocating a NULL pointer in line %d", line);
	}
	free(ptr);
}

