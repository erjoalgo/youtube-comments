(in-package #:yt-comments/util)

(stefil:defsuite* run-tests)

(defstruct my-unmarshal-test
  key-one
  key-two)

(stefil:deftest test-to-camel-case nil
  (stefil:is (equal "commentThreads" (to-camel-case
                                      (symbol-name :comment-threads))))
  (stefil:is (equal "nextPageToken" (to-api-param-key :next-page-token)))

  (stefil:is (equal (from-camel-case "commentThreads" :sep #\-)
                    "comment-threads"))

  (stefil:is (equal (json-key-to-lisp "comment_threads") "COMMENT-THREADS"))

  (stefil:is (equal (json-key-to-lisp "commentThreads") "COMMENT-THREADS"))


  (let* ((json "{ \"keyOne\" : 1,\"key_two\": 2 }")
         (json-alist (jonathan:parse json :as :alist))
        (obj (make-from-json-alist json-alist my-unmarshal-test)))
    (stefil:is (equal (my-unmarshal-test-key-one obj) 1))
    (stefil:is (equal (my-unmarshal-test-key-two obj) 2)))

  (stefil:is (equal (flat-to-alist "a" 1 "b" 2)
                    `(("a" . 1) ("b" . 2))))
  (stefil:is (equal (flat-to-alist-macro "a" 1 "b" 2)
                    `(("a" . 1) ("b" . 2)))))



(defstruct my-unmarshal-test-2
  access-token
  error
  error-description
  )

(let* ((json "{
  \"error\" : \"invalid_grant\",
  \"error_description\" : \"Code was already redeemed.\"
}")
       (json-alist (jonathan:parse json :as :alist))
       (obj (make-from-json-alist json-alist my-unmarshal-test-2)))
  (stefil:is (equal (my-unmarshal-test-2-error-description obj) "Code was already redeemed."))
  (stefil:is (equal (my-unmarshal-test-2-error obj) "invalid_grant")))


(let ((i 0))
  (stefil:is (eq 42 (retry-times 3 .1
                      (if (< (1- (incf i)) 2)
                          (error "err") 42)))))
(let ((i 0))
  (stefil:is (eq 43
                 (handler-case
                     (retry-times 3 .1
                       (if (< (1- (incf i)) 3)
                           (error "err") 42))
                   (error nil 43)))))

(run-tests)
