;; core
(define (tangle file)
  (let* ((contents (get-contents file))
	 (chunks (extract-code-chunks contents)))
    (combine chunks)))

(define (combine chunks)
  (fold-left string-append "" chunks))

(define (extract-code-chunks contents)
  (let ((search (regsexp-search-string-forward
		 (compile-regsexp
		  '(seq "@{" (* (any-char)) "@}"
			(group code (*? (alt (any-char) #\newline)))
			#\@ (char-in " \n\t")))
		 contents)))
    (if search
	(let ((chunk (cdr (assoc 'code (cddr search))))
	      (next-start (cadr search)))
	  (cons chunk (extract-code-chunks
		       (string-tail contents next-start))))
	'())))

;; I/O
(define file-size-max 8192) ; 2^13 bytes
(define (get-contents file)
  (call-with-input-file file
    (lambda (port)
      (read-string file-size-max port))))

;; stages
(define (get-next-stage-src from to)
  (call-with-output-file (stage-exec-name to)
    (lambda (port)
      (write-string (eval `(tangle ,(stage-src-name to))
			  (stage-env from))
		    port))))
(define (build-next-environment from to)
  (get-next-stage-src from to)
  (let ((next-env (make-top-level-environment)))
    (eval `(begin (load ,(stage-exec-name to))
		  (the-environment))
	  next-env)))

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
