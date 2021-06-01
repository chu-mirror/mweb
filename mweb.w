% control sequence
\def\ctrllist#1#2{\hbox{\hskip 0.5in\ctrl#1 #2}}
\def\ctrl#1{\hbox{\tt @@{#1}}}

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

	@<initialize global variables@>@;
	@<parse command line@>@;
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
	char f[MAXLINE], *cp;
	ifile *nifp; /* new ifp */

	cp = &line_buffer[2];
	cp = skip_blank(cp);
	{ /* lable the end with |'\0'| */
		char *e = cp;
		if (*cp == '"') {
			cp++;
			@<find the end with double quotes@>@;
		} else {
			do {
				e++;
			} while(isblank(*e));
		}
		*e = '\0';
	}

	strcpy(f, cp);

	nifp = ifile_open(f);
	read_input(nifp);
	ifile_close(nifp);
}

@
@<find the end with double quotes@>=
do {
	e++;
} while (*e != '"' && *e != '\n');
if (*e != '"') {
	err_quit("syntax error: missing a '\"'");
}
*e = '\0';

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
@f chunk int
@<typedefs@>=
typedef struct chunk {
	char *start;
	char *end;
	struct chunk *next;
} chunk;

@ A section contains a section name, a list of code chunks, and the filter it use.
The size of space used by names' saving can be safely set to |MAXLINE|, for
all names are given within one line.
@f section int
@<typedefs@>=
typedef struct section {
	char name[MAXLINE]; 
	char filter[MAXLINE];
	struct chunk *code;
} section;

@ A filter is itself a program, so it can also be expressed as text plus a filter
as same as sections.  The difference between a section and a filter is the way in
treating the text, a section's text is used as a component of the program,
a filter's text is used to drive the interpreter, the drived interpreter's actions
form a program named filter.  To \.{MWEB}, a filter is just a section plus a
interpreter, \.{MWEB} use Bourne Shell as the interpreter.

@<global variables@>=
char interpreter[] = "/bin/sh";

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
\ctrllist{>}{end of a section name or end of a filter name, start of a code chunk}
\ctrllist{:}{end of a section name, followed by the filter name used in this section}
\ctrllist{\it newline}{end of a code chunk}
\vskip 3pt
You might have noticed that there are some rules of places they appear.  For example, you can not
place start of another section name in a section name.  From this observation,
\.{MWEB} use global variable to indicate current type of text.
@<global variables@>=
contexts_1 context_1; /* current context, |context_0| may be used in reading input */
char *loc; /* current location */

@ There are four types of text for now, code, section's name, filter's name, others.
@f contexts_1 int
@<typedefs@>=
typedef enum contexts_1{ NAME_SECTION, NAME_FILTER, CODE, OTHERS } contexts_1; 

@ |context| should be initialized to |OTHERS| at the beginning of parsing,
together with a lot of other initializations.

@<prepare global variables before parsing for tangling@>=
loc = &buffer[0];
context_1 = OTHERS;

@ The parsing is designed to handle one character at once, so an immediate passing
should be done if current character is needed.
@<global variables@>=
char *dest;

@
@c
int
pass_to_dest(char c)
{
	if (dest) *(dest++) = c;
	return dest != NULL;
}

@
@<prototypes@>=
int pass_to_dest(char);

@
@<prepare global variables before parsing for tangling@>=
dest = NULL;

@ So the entire parse process can be written.
@<parse input for tangling@>=
@<prepare global variables before parsing for tangling@>@;
while (loc != buffer_end) {
	if (*loc == '@@') {
		loc++; /* take |'@@'| */
		@<handle control sequence in parsing for tangling@>@;
	} else {
		pass_to_dest(*(loc++));
	}
}

@ The next is studying the functions, find out how they can be implemented.
From the list above, we can get the basic operations:
@<prototypes@>=
void start_section_name_1(void); /* number |1| is from |context_1| */
void end_section_name_1(void);
void start_filter_name_1(void);
void end_filter_name_1(void);
void start_code_chunk_1(void);
void end_code_chunk_1(void);

@ The basic operations take effect on following global variables.
@<global variables@>=
section *cur_section; /* current section */
chunk *cur_chunk; /* current code chunk */
hash_table sections;

@
@c
void
start_section_name_1()
{
	section *scp;

	NEW(scp);
	cur_section = scp;
	dest = scp->name;

	loc = skip_blank(loc);
}

@
@c
void
end_section_name_1()
{

	*dest = '\0';

	strip_blank(cur_section->name);
	hash_insert(&sections, cur_section->name, cur_section);

	dest = NULL;
}

@
@c
void start_code_chunk_1()
{
	chunk *ckp;

	NEW(ckp);
	cur_chunk = ckp;
	ckp->start = loc;
}

@
@c
void
end_code_chunk_1()
{
	cur_chunk->end = loc-2;

	@<add new code chunk to current section@>@;

	cur_chunk = NULL;
	cur_section = NULL;
}

@
@<add new code chunk to current section@>=
{
	if (!cur_section->code) {
		cur_section->code = cur_chunk;
	} else {
		chunk *ckp_t;
		for (ckp_t = cur_section->code; ckp_t->next; ckp_t = ckp_t->next)
			;
		ckp_t->next = cur_chunk;
	}
}

@
@c
void
start_filter_name_1()
{
	dest = cur_section->filter;
	loc = skip_blank(loc);
}

@
@c
void
end_filter_name_1()
{
	*dest = '\0';
	strip_blank(cur_section->filter);

	dest = NULL;
}
@ Combine them to build functions defined by contexts and control sequences.
@<prototypes@>=
void others_left_angle_bracket_1(void);
void name1_right_angle_bracket_1(void); /* |name1|'s |1| means section name */
void name2_right_angle_bracket_1(void); /* |2| means filter name */
void name1_colon_1(void);
void code_newline_1(void);

@ Functions of left angle bracket.
@c
void
others_left_angle_bracket_1()
{
	context_1 = NAME_SECTION;
	start_section_name_1();
}

@ Right angle bracket. Use a {\tt =} to indicate start of code chunk.
@c
#define START_CODE_CHUNK { \
	context_1 = CODE; \
	if (*loc != '=') err_quit("syntax error: missing a '='"); \
	loc++; \
	start_code_chunk_1(); \
}

void
name1_right_angle_bracket_1()
{
	end_section_name_1();
	START_CODE_CHUNK;
}

void
name2_right_angle_bracket_1()
{
	end_filter_name_1();
	START_CODE_CHUNK;
}
#undef START_CODE_CHUNK

@ Colon.
@c
void
name1_colon_1()
{
	context_1 = NAME_FILTER;
	end_section_name_1();
	start_filter_name_1();
}

@ Newline.
@c
void
code_newline_1()
{
	context_1 = OTHERS;
	end_code_chunk_1();
}

@ \.{MWEB} assigns these funtions to control sequences by checking tables,
the number of contexts can be represented by |OTEHRS+1|, and \.{MWEB}
only handle \.{ASCII} characters now.
@<global variables@>=
void (*func_map_1[OTHERS+1][UCHAR_MAX])(void) = {
	[OTHERS]['<']		= others_left_angle_bracket_1,
	[NAME_SECTION]['>']	= name1_right_angle_bracket_1,
	[NAME_SECTION][':']	= name1_colon_1,
	[NAME_FILTER]['>']	= name1_right_angle_bracket_1,
	[CODE]['\n']		= code_newline_1
};

@ We can complete the parsing now.
@<handle control sequence in parsing for tangling@>=
{
	void (*fnp)(void);

	fnp = func_map_1[context_1][*loc]; 
	loc++;
	if (fnp) {
		(*fnp)();
	} else {
		pass_to_dest('@@');
		pass_to_dest(*(loc-1));
	}
}

@ The parsing is completed, you can see that the naming of these functions
follows an explicit rule.  In fact, we do not care about these names, as far as
they are unique.  We place the functions to correct grids in |func_map_1|,
then the names become useless, a waste of namespace, bring in unwanted complexity.
This problem can not be solved in one single \CEE/ program, but we can use
another program to automatically generate this part of \CEE/ code.
The information distilled from this part of code is expressed in another
language, translated by filter to produce corresponding \CEE/ code.
\.{MWEB} has potential to do a lot of works, but this is the most important.

@* Tangle up.  This is the core part of \.{MWEB}.

@<do tangling@>=
@<prepare global variables for tangling up@>@;
@<tangle up code chunks@>@;

@ For convenience, \.{MWEB} assume the existing of a section named {\it root},
as its name suggests, it's the root node in the tree of sections.
@<tangle up code chunks@>=
tangle_up("root");

@
@c
void
tangle_up(char *sec)
{
	char *cp; /* do not use |loc|, this process can be invoked recursively */
	section *scp;
	chunk *ckp;
	int fd;

	context_2 = PLAIN_CODE;
	dest = &swap_area[0];
	scp = (section *)hash_get(&sections, sec);
	sha_1_str(sec);
	fd = file_open(sha_1_h);

	for (ckp = scp->code; ckp != NULL; ckp = ckp->next) {
		@<tangle each code chunk@>@;
	}

	if (dest != &swap_area[0]) {
		swap_end = dest;
		clear_swap(fd);
	}

	file_close(fd);
}

@
@<tangle each code chunk@>=
#define CLEAR_SWAP { \
	if (context_2 == PLAIN_CODE && dest-swap_area == SWAP_LENGTH) { \
		swap_end = dest; \
		clear_swap(fd); \
		dest = &swap_area[0]; \
	} \
}
for (cp = ckp->start; cp != ckp->end; cp++) {
	if (*cp == '@@') {
		cp++;
		@<handle control sequence for tangling up@>@;
	} else {
		pass_to_dest(*cp);
		CLEAR_SWAP;
	}
}
#undef CLEAR_SWAP

@ Use the same strategy from previous chapter.
@<handle control sequence for tangling up@>=
{
	void (*fnp)(int);

	fnp = func_map_2[context_2][*cp];

	if (fnp) {
		(*fnp)(fd);
	} else {
		pass_to_dest('@@');
		CLEAR_SWAP;
		pass_to_dest(*(cp-1));
		CLEAR_SWAP;
	}
}

@
@<prototypes@>=
void tangle_up(char *);

@ Control sequences.
\vskip 3pt
\ctrllist{<}{start of a section name being included}
\ctrllist{>}{end of a section name being included}
\ctrllist{(}{start of a section name being referenced}
\ctrllist{)}{end of a section name being referenced}
\vskip 3pt
@f contexts_2 int
@<typedefs@>=
typedef enum contexts_2 {NAME_INC, NAME_REF, PLAIN_CODE} contexts_2;

@ Like parsing, I use a new context for tangling up.
@<global variables@>=
contexts_2 context_2;
char cur_section_name[MAXLINE];

@
@<prepare global variables for tangling up@>=
context_2 = PLAIN_CODE;
dest = NULL;

@
@<prototypes@>=
void start_section_name_include_2(int);
void end_section_name_include_2(int);
void start_section_name_reference_2(int);
void end_section_name_reference_2(int);

@
@c
void
start_section_name_include_2(int fd)
{
	swap_end = dest;
	clear_swap(fd);
	dest = cur_section_name;
}

void
end_section_name_include_2(int fd)
{
	*dest = '\0';
	include_sec(fd, cur_section_name);
	dest = &swap_area[0];
}

@
@c
void
start_section_name_reference_2(int fd)
{
	swap_end = dest;
	clear_swap(fd);
	dest = cur_section_name;
}

void
end_section_name_reference_2(int fd)
{
	*dest = '\0';
	ref_sec(fd, cur_section_name);
	dest = &swap_area[0];
}

@ \.{MWEB} uses two special functions to handle including and referencing.
@<prototypes@>=
void include_sec(int, char *);
void ref_sec(int, char *);

@
@c
void
include_sec(int fd, char *sec)
{
	tangle_up(sec); /* ensure the section being included has been tangled */
	sha_1_str(sec);
	transfer(fd, sha_1_h);
}

void
ref_sec(int fd, char *sec)
{
	strcpy(swap_area, sec);
	swap_end = swap_area + strlen(sec);
	clear_swap(fd);
}

@
@<prototypes@>=
void code_left_angle_bracket_2(int);
void code_left_circle_bracket_2(int);
void name1_right_angle_bracket_2(int);
void name2_right_circle_bracket_2(int);

@
@c
void
code_left_angle_bracket_2(int fd)
{
	context_2 = NAME_INC;
	start_section_name_include_2(fd);
}

@
@c
void
code_left_circle_bracket_2(int fd)
{
	context_2 = NAME_REF;
	start_section_name_reference_2(fd);
}

@
@c
void
name1_right_angle_bracket_2(int fd)
{
	context_2 = PLAIN_CODE;
	end_section_name_include_2(fd);
}

@
@c
void
name2_right_circle_bracket_2(int fd)
{
	context_2 = PLAIN_CODE;
	end_section_name_reference_2(fd);
}

@
@<global variables@>=
void (*func_map_2[PLAIN_CODE+1][UCHAR_MAX])(int) = {
	[PLAIN_CODE]['<'] = code_left_angle_bracket_2,
	[PLAIN_CODE]['('] = code_left_circle_bracket_2,
	[NAME_INC]['>'] = name1_right_angle_bracket_2,
	[NAME_REF][')'] = name2_right_circle_bracket_2
};

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
		err_quit("failed to find %s", f);
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

@* Byte-oriented.  \.{MWEB} use unbuffered I/O to do saving of mid products,
outside world communicate with this module through a swap area. The swap area
is same with buffer, but controled under \.{MWEB}, rather than standard library.

@<prototypes@>=
void transfer(int, char *);
void clear_swap(int);
int file_open(char *);
void file_close(int);

@
@<global variables@>=
char swap_area[SWAP_LENGTH];
char *swap_end;

@ The size is set to 32KB, according to {\sl Advanced Programming in the UNIX
Environment}, it may be an ideal size to transfer data's blocks.
@<macros@>=
#define SWAP_LENGTH (2<<15)

@ The mid products are placed in the folder {\tt .srcfile},
{\tt srcfile} is the name of input file.
@<global variables@>=
int mid_dir;

@
@<initialize global variables@>=
swap_end = &swap_area[0];
{
	char dir[MAXLINE], *dir_end;
	char *cp, *slp; /* slash's position */
	int n;

	strcpy(dir, argv[1]);
	dir_end = dir + strlen(dir);

	slp = strrchr(dir, '/');
	cp = slp ? slp + 1 : dir;
	{ 
		char c1 = '.', c2;
		for (; cp != dir_end; cp++) {
			c2 = c1;
			c1 = *cp;
			*cp = c2;
		}
		*cp = c1;
		*(cp+1) = '\0';
	}
	strip_suffix(dir);

	n = mkdirat(AT_FDCWD, dir, 0700);
	if (n == -1 && errno != EEXIST) {
		err_sys("failed to create directory %s", dir);
	}
	mid_dir = openat(AT_FDCWD, dir, O_DIRECTORY);
	if (mid_dir == -1) {
		err_sys("failed to open directory %s", dir);
	}
}

@
@c
int
file_open(char *f)
{
	int fd;
	fd = openat(mid_dir, f, O_RDWR | O_CREAT, 0600);
	if (fd == -1) {
		err_sys("failed to open %s", f);
	}

	return fd;
}

@
@c
void
file_close(int fd)
{
	if (close(fd) == -1) {
		err_sys("failed to close file");
	}
}

@ Write the swap area to |fd|.
@c
void
clear_swap(int fd)
{
	ssize_t n;
	n = write(fd, swap_area, swap_end - swap_area);
	if (n == -1 || n != swap_end - swap_area) {
		err_sys("failed to save mid product");
	}
	swap_end = &swap_area[0];
}

@ Copy the the contents of file |f| to the |fd|.
@c
void
transfer(int fd, char *f)
{
	int fd_t;
	ssize_t n1, n2;
	fd_t = file_open(f);

	if (swap_end != &swap_area[0]) {
		clear_swap(fd);
	}

	do {
		n1 = read(fd_t, swap_area, SWAP_LENGTH);
		if (n1 == -1) {
			err_sys("failed to read mid product");
		}
		if (n1) {
			n2 = write(fd, swap_area, n1);
			if (n2 == -1 || n1 != n2) {
				err_sys("failed to transfer mid product");
			}
		}
	} while (n1);

	file_close(fd_t);
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
#include <dirent.h>

#include <limits.h>
#include <errno.h>
#include <fcntl.h>

#include <ctype.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <stdarg.h>
#include <stdint.h>

@* String operation.  \CEE/ standard library does not provide
some useful operations.

@<prototypes@>=
char *skip_blank(char *); /* skip continues blanks */
void strip_blank(char *);
void strip_suffix(char *);
char char_n_to_hex(int);

@ The blanks can be tabs and spaces.
@c
char *
skip_blank(char *cur)
{
	while (isblank(*cur)) {
		cur++;
	}
	return cur;
}

@ Strip the unneeded ending.
@c
void
strip_blank(char *s)
{
	char *e;
	e = s + strlen(s);
	while (isblank(*(--e)))
		;
	*(e+1) = '\0';
}

void
strip_suffix(char *s)
{
	char *dotp, *slp; /* dot's position, slash's position */
	dotp = strrchr(s, '.');
	slp = strrchr(s, '/');

	if (dotp && slp < dotp) {
		*dotp = '\0';
	}
}

@
@c
char
char_n_to_hex(int n)
{
	if (n > 9) {
		return 'A' + n - 10;
	} else {
		return '0' + n;
	}
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
@f hash_entry int
@f hash_table int
@<typedefs@>=
typedef struct hash_entry {
	struct hash_entry *next;
	char lable[MAXLINE];
	void *p;
} hash_entry;

typedef struct hash_table {
	hash_entry *entries[hash_size];
} hash_table;

@ Insert an element to |hash_table|.
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

@* SHA-1.  An implementation of \.{SHA-1}.
@f word int
@f uint32_t int
@f block int
@f block_stream int
@<typedefs@>=
typedef uint32_t word;
typedef struct block_run {
	word arr[16];
	struct block_run *next;
} block_run;

@ A buffer for result.
@<global variables@>=
char sha_1_h[64];

@
@<prototypes@>=
void sha_1_digest(block_run *);

@ The four functions and circular left shift.
@<prototypes@>=
word sha_1_f0(word, word, word);
word sha_1_f1(word, word, word);
word sha_1_f2(word, word, word);
word sha_1_f3(word, word, word);
word cir_sll(word, int);

@
@c
word
sha_1_f0(word B, word C, word D)
{
	return (B & C) | (~B & D);
}

word
sha_1_f1(word B, word C, word D)
{
	return B ^ C ^ D;
}

word
sha_1_f2(word B, word C, word D)
{
	return (B & C) | (B & D) | (C & D);
}

word
sha_1_f3(word B, word C, word D)
{
	return B ^ C ^ D;
}

word
cir_sll(word X, int n)
{
	return (X << n) | (X >> (32-n));
}

@
@<global variables@>=
word (*sha_1_fs[4])(word, word, word) = {
	sha_1_f0, sha_1_f1, sha_1_f2, sha_1_f3
};

@
@<macros@>=
#define sha_1_f(t) (*sha_1_fs[(int)(t)/20])

@ The four constants.
@<global variables@>=
word sha_1_ks[4] = {
	0x5A827999, 0x6ED9EBA1,
	0x8F1BBCDC, 0xCA62C1D6
};

@
@<macros@>=
#define sha_1_k(t) (sha_1_ks[(int)(t)/20])

@
@c
void
sha_1_digest(block_run *blks)
{
	word buf1[5], temp, buf2[85] = {
		0x67452301, 0xEFCDAB89,
		0x98BADCFE, 0x10325476,
		0xC3D2E1F0
	};
	int i;
	block_run *blp, *blp_t = NULL;

	for (blp = blks; blp; blp = blp->next) {
		if (blp_t) FREE(blp_t);
		@<digest block pointed by |blp|@>@;
		blp_t = blp;
	}
	for (i = 0; i < 40; i++) {
		unsigned char hex;
		hex = buf2[i/8] >> (7*4);
		buf2[i/8] <<= 4;
		sha_1_h[i] = char_n_to_hex(hex);
	}
	sha_1_h[40] = '\0';
}

@
@<digest block pointed by |blp|@>=
{
	int t;

	for (t = 0; t < 16; t++) {
		buf2[t+5] = blp->arr[t];
	}
	for (t = 16 + 5; t < 80 + 5; t++) {
		buf2[t] = cir_sll(buf2[t-3], 1) ^ buf2[t-8] ^ buf2[t-14] ^ buf2[t-16];
	}
	for (t = 0; t < 5; t++) {
		buf1[t] = buf2[t];
	}
	for (t = 0; t < 80; t++) {
		temp = cir_sll(buf1[0], 5) + sha_1_f(t)(buf1[1], buf1[2], buf1[3])
			+ buf1[4] + buf2[t+5] + sha_1_k(t);
		buf1[4] = buf1[3];
		buf1[3] = buf1[2];
		buf1[2] = cir_sll(buf1[1], 30);
		buf1[1] = buf1[0];
		buf1[0] = temp;
	}
	for (t = 0; t < 5; t++) {
		buf2[t] += buf1[t];
	}
}

@ Build blocks from a buffer.
@c
block_run *
build_blocks(char *v)
{
	int len, pad_len, i;
	block_run *blks = NULL, *blp1, *blp2;

	len = strlen(v);

	i = 0;
	while (i + 64 <= len) {
		NEW0(blp1);
		strncpy((char *)blp1->arr, v+i, 64);
		if (blks == NULL) {
			blks = blp1;
			continue;
		}
		blp2->next = blp1;
		blp2 = blp1;

		i += 64;
	}
	@<build the padding block@>@;

	return blks;
}

@
@<build the padding block@>=
pad_len = (64 - (len%64)) %64;
if (pad_len == 0) return blks;

NEW0(blp1);
strcpy((char *)blp1->arr, v+i);
strcat((char *)blp1->arr, "\x80");

if (blks == NULL) {
	blks = blp1;
} else {
	blp2->next = blp1;
}
blp2 = blp1;

if (pad_len < 3) {
	NEW0(blp1);
	blp2->next = blp1;
	blp2 = blp1;
}

blp2->arr[15] = len * 8; /* the length of message is assumed less than $2^32-1$ */

@
@<prototypes@>=
block_run *build_blocks(char *);

@ Get |sha_1_h| from various sources.
@c
void
sha_1_str(char *v)
{
	block_run *blks;
	blks = build_blocks(v);
	sha_1_digest(blks);
}

@
@<prototypes@>=
void sha_1_str(char *);

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

