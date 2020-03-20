;;
;; Included from 181.sld
;;

(define-constant *buffer-size* 1024)

(define (make-seeker get-position set-position!)
  (^[offset whence]
    (if (and (= offset 0) (eq? whence 'SEEK_CUR))
      (and get-position (get-position))
      (and set-position!
           (ecase whence
             [(SEEK_SET) (set-position! offset)]
             [(SEEK_CUR) (and get-position
                              (set-position! (+ offset (get-position))))]
             [(SEEK_END) #f]            ; unsupportable
             )))))

(define (make-custom-binary-input-port id read!
                                       get-position set-position!
                                       close)
  (define (filler buf)
    (read! buf 0 (u8vector-length buf)))
  (make <buffered-input-port>
    :name id
    :fill filler
    :seek (make-seeker get-position set-position!)
    :close close))

(define (make-custom-textual-input-port id read!
                                        get-position set-position!
                                        close)
  ;; <buffered-input-port> uses u8vector for the buffer, so we have
  ;; to convert it.
  (define cbuf #f)                      ;vector, allocated on demand
  (define (filler buf)
    (unless cbuf
      (set! cbuf (make-vector (quotient (u8vector-length buf) 4))))
    (let1 n (read! cbuf 0 (vector-length cbuf))
      (if (zero? n)
        0
        (let* ([s (vector->string cbuf 0 n)]
               [size (string-size s)])
          (assume (<= size (u8vector-length buf)))
          (string->u8vector! buf 0 s)
          size))))
  (make <buffered-input-port>
    :name id
    :fill filler
    :seek (make-seeker get-position set-position!)
    :close close))

(define (make-custom-binary-output-port id write!
                                        get-position set-position!
                                        close :optional (flush #f))
  (define (flusher buf complete?)
    (if (not complete)
      (write! buf 0 (u8vector-length buf))
      ;; this is a buffer-flush operation
      (let1 len (u8vector-length buf)
        (let loop ([pos 0])
          (if (= pos len)
            (when flush (flush))
            len)
          (let1 n (write! buf pos (- len pos))
            (loop (+ pos n)))))))
  (make <buffered-output-port>
    :name id
    :flush flusher
    :seek (make-seeker get-position set-position!)
    :close close))

;; For textual output, <buffered-output-port> is inconvenient,
;; for the passed u8vector may end in the middle of multibyte character.
(define (make-custom-textual-output-port id write!
                                         get-position set-position!
                                         close :optional (flush #f))
  (define cbuf (make-vector 1))
  (make <virtual-output-port>
    :name id
    :putc (^c (vector-set! cbuf 0 c) (write! cbuf 0 1))
    :seek (make-seeker get-position set-position!)
    :flush (^[] (and flush (flush)))
    :close close))