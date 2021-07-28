

(define (protofile->codechunks file)
  (call-with-input-file file
    (lambda (port)
      (define parser (make-parser port))
      (define (parse)
	(let ((token (next-token port)))
	  (if (eof? token)
	      (parser 'result)
	      (begin
		((parser 'parse) token)
		(parse)))))
      (parse))))

(define (tangle title chunks)
  (define (expand section)
    (apply append
	   (map (lambda (ele)
		  (if (char? ele)
		      (list ele)
		      (tangle ele chunks)))
		section)))

  (expand (apply append
		 (map cdr (filter
			   (lambda (chunk)
			     (equal? (car chunk) title))
			   chunks)))))

#|
Tokens:
control-char: @<char>
normal-char: <char>
eof: eof
|#

(define (make-token type char)
  (cons type char))
(define (token-type token)
  (car token))
(define (token-char token)
  (cdr token))

(define (control-char? token)
  (eq? (token-type token) 'control-char))
(define (normal-char? token)
  (eq? (token-type token) 'normal-char))
(define (eof? token)
  (eq? (token-type token) 'eof))

(define (next-token port)
  (let ((char (read-char port)))
    (cond ((eof-object? char)
	   (make-token 'eof #f))
	  ((eq? char #\@)
	   (make-token 'control-char (read-char port)))
	  (else
	   (make-token 'normal-char char)))))
#|
<code chunk>:
<title>
<contents>

<title>:
<name>=

<name>:
@{ string @}

<contents>:
string <name> ...
@<blank>

<blank>:
newline or eof
|#

(define (chunk-begin? token)
  (title-begin? token))

(define (title-begin? token)
  (name-begin? token))

(define (title-end? token)
  (and (normal-char? token) (eq? (token-char token) #\=)))

(define (name-begin? token)
  (and (control-char? token) (eq? (token-char token) #\{)))

(define (name-end? token)
  (and (control-char? token) (eq? (token-char token) #\})))

(define (contents-end? token)
  (and (control-char? token) (blank? (token-char token))))

(define (blank? char)
  (or (eof-object? char) (eq? char #\newline)))

(define (make-parser port)
  (define chunks '(()))
  (define chunks-end chunks)

  (define (add-new-chunk! chunk)
    (set-cdr! chunks-end (list chunk))
    (set! chunks-end (cdr chunks-end)))

  (define (handle-token token)
    (if (chunk-begin? token)
	(add-new-chunk! (parse-chunk port))))

  (define (parse-chunk port)
    (let* ((title (parse-title port)) (contents (parse-contents port)))
      (cons title contents)))

  (define (parse-title port)
    (let ((name (parse-name port)))
      (if (title-end? (next-token port))
	  name
	  (error "miss =" name))))

  (define (parse-name port)
    (define (iter buf)
      (let ((token (next-token port)))
	(if (name-end? token)
	    (list->string (buffer-contents buf))
	    (iter (buffer-add-new! buf (token-char token))))))
    (iter (make-buffer)))

  (define (parse-contents port)
    (define (iter buf)
      (let ((token (next-token port)))
	(cond ((contents-end? token) (buffer-contents buf))
	      ((name-begin? token)
	       (let ((name (parse-name port)))
		 (iter (buffer-add-new! buf name))))
	      (else (iter (buffer-add-new! buf (token-char token)))))))
    (iter (make-buffer)))

  (define (dispatch message)
    (cond ((eq? message 'parse) handle-token)
	  ((eq? message 'result) (cdr chunks))))

  dispatch)

(define (make-buffer)
  (let* ((contents (list '())) (end contents))
    (cons contents end)))
(define (buffer-contents buf)
  (cdar buf))
(define (buffer-end buf)
  (cdr buf))

(define (buffer-add-new! buf ele)
  (set-cdr! (buffer-end buf) (list ele))
  (set-cdr! buf (cdr (buffer-end buf)))
  buf)

(define protofile "proto.mw")
(define root-section "literate programming tool mweb")
(define root-section "definitions")

(call-with-output-file "proto.scm"
  (lambda (port)
    (write-string (list->string (tangle root-section
					(protofile->codechunks protofile)))
		  port)))

