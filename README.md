# MWEB

Still under developing.  See _examples_ and source code for more information.


```
# get an executable file
$ make

# generate a document(PDF)
$ make doc
```

This project is migarating to scheme.  To build the current version by:
```
(load "stage0.scm")
(build-stages '("0" "1"))
```