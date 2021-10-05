(define (tangle contents)
  (let ((chunks (extract-code-chunks contents)))
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

(define (get-contents file)
  (call-with-input-file file
    (lambda (port)
      (read-string 5000 port))))
