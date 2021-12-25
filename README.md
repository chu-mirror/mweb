# MWEB

This project is migarating to scheme.  To build the current version by:
```
$ mit-scheme --load boot
```
Some stages are available right now, use script _mweb.sh_ to use them.
```
# generate final executable script
$ make
# then put the result under $PATH

# you can parse a mweb source file using stage 1 by, for example:
$ mweb 1 stage-ex.mw defs stage-ex.scm
```

## References

+ Literate Programming [pdf](http://www.literateprogramming.com/knuthweb.pdf)
+ TeX: the Program [pdf](http://brokestream.com/tex.pdf)
+ Foundations for the Study of Software Architecture [pdf](http://users.ece.utexas.edu/~perry/work/papers/swa-sen.pdf)
