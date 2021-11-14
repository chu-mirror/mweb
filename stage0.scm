;;; core

;; The major interface of mweb,
;; every stage must have one.
(define (tangle file)
  (combine (extract-code-chunks (get-contents file))))

;; The code chunks are just strings now,
;; combine them by appending them one by one
;; to build the final program of stage 1.
(define (combine chunks)
  (fold-left string-append "" chunks))

;; Use regular expression to extract code chunks.
#|
    A code chunk is labeled as:

    @{code chunks in stage 1@}
    ...
    @
|#
(define (extract-code-chunks contents)
  (let ((search (regsexp-search-string-forward
		 (compile-regsexp
		  '(seq "@{code chunks in stage 1@}"
			(group code (*? (alt (any-char) #\newline)))
			"@\n" ))
		 contents)))
    (if search
	(let ((chunk (cdr (assoc 'code (cddr search))))
	      (next-start (cadr search)))
	  (cons chunk (extract-code-chunks
		       (string-tail contents next-start))))
	'())))

;;; I/O
;; The I/O operations are simply read in
;; or write out strings at this point,
;; procedure get-contents is shared among
;; stages.
(define file-size-max (expt 2 20)) ; 1MB
(define (get-contents file)
  (call-with-input-file file
    (lambda (port)
      (read-string file-size-max port))))

;;; Implementation of stages
;; The following procedures form the driver
;; of mweb's interpreting system.  Each stage
;; can be regarded as an implementation of
;; a subset of mweb's grammer.
;; Stage 0 is written in pure scheme, so it
;; can be interpreted by scheme interpreter directly.
;; Following stages require the previous stage's
;; interpretation.  The implementation in stage 0
;; is able to understand grammer in stage 1, so on.
;; This part of code does not belong to the specification
;; of mweb, written for the building of mweb.
(define (get-next-stage-src from to)
  (call-with-output-file (stage-exec-name to)
    (lambda (port)
      (write-string (eval `(tangle ,(stage-src-name to))
			  (stage-env from))
		    port))))
(define (build-next-environment from to)
  (get-next-stage-src from to)
  (let ((next-env (make-top-level-environment '(get-contents) `(,get-contents))))
    (load (stage-exec-name to) next-env)
    next-env))

(define (stage-exec-name stage-suf)
  (string-append "stage" stage-suf ".scm"))
(define (stage-src-name stage-suf)
  (string-append "stage" stage-suf ".mw"))
(define (stage-env suf)
  (cdr (assoc suf stage-list)))
(define stage-list `(("0" . ,(the-environment))))

(define (build-stages sufs)
  (let build-stage-from
      ((from (cdr (reverse sufs)))
       (to (car (reverse sufs))))
    (if (null? from)
	(write-line "build stage0 successfully.")
	(begin
	  (build-stage-from (cdr from) (car from))
	  (set! stage-list
		(cons (cons to (build-next-environment (car from) to))
		      stage-list))
	  (write-line (string-append "build stage" to " successfully."))))))
