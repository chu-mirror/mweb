;;; core

;; The functionality of stage0: extract code chunks from stage1 and combine them
(define (tangle file)
  (combine (extract-code-chunks (get-content file))))

;; The code chunks are just strings now, combine them by concating them one by one
;; to build the final program of stage 1.
(define (combine chunks)
  (fold-left string-append "" chunks))

;; Use regular expression to extract code chunks.
#|
    A code chunk is labeled as:

    @[stage 1@]
    ...
    @
|#
(define (extract-code-chunks content)
  (let ((search (regsexp-search-string-forward
		 (compile-regsexp
		  '(seq "@[stage 1@]"
			(group code (*? (alt (any-char) #\newline)))
			"@\n" ))
		 content)))
    (if search
	(let ((chunk (cdr (assoc 'code (cddr search))))
	      (next-start (cadr search)))
	  (cons chunk (extract-code-chunks
		       (string-tail content next-start))))
	'())))

;;; I/O

;; The I/O operations are simply read in or write out strings in buiding.
;; Procedure get-content is shared among stages.
(define file-max-size (expt 2 20)) ; 1MB
(define (get-content file)
  (call-with-input-file file
    (lambda (port)
      (read-string file-max-size port))))

;;; Build stage1

(call-with-output-file "stage-1.scm"
  (lambda (port)
    (write-string (tangle "stage-1.mw") port)))
(load "stage-1.scm")

