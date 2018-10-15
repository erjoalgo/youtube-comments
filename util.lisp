(in-package #:yt-comments/util)

(defun json-key-to-lisp (key)
  ;; TODO first apply CAMEL-CASE-TO-LISP in case keys are camel case
  (string-upcase (cl-ppcre:regex-replace-all
                  "--"
                  (cl-json:camel-case-to-lisp key)
                  "-")))

;; (defalias json-key-to-lisp cl-json:lisp-to-camel-case)
;; (setf (fdefinition 'lisp-to-json-key) #'cl-json:lisp-to-camel-case)
(defun lisp-to-json-key (lisp-identifier)
  (cl-json:lisp-to-camel-case (symbol-name lisp-identifier)))

(setf cl-json:*json-identifier-name-to-lisp*
      'json-key-to-lisp)

(defmacro -> (&rest forms)
  (if (cadr forms)
      (destructuring-bind (first second . rest) forms
	(destructuring-bind (a . a-rest) (if (atom second)
					     (cons second nil)
                                             second)
	  `(-> ,(apply 'list a first a-rest) ,@rest)))
      (car forms)))

(defmacro with-unique-names ((&rest bindings) &body body)
  `(let ,(mapcar #'(lambda (binding)
                     (destructuring-bind (var prefix)
                         (if (consp binding) binding (list binding binding))
                       `(,var (gensym ,(string prefix)))))
                 bindings)
     ,@body))


(defmacro ->> (&rest forms)
  (if (cadr forms)
      (destructuring-bind (a b . rest) forms
          `(->> ,(append
                  (if (atom b) (cons b nil) b)
                  (list a))
                ,@rest))
      (car forms)))

'(defmacro with-alist-values (alist syms key-transform-fun &body body)
  `(let
       ,(loop for sym in syms
           as sym-name = (symbol-name sym)
           collect
             `(,sym
               (cdr (or ,@(loop for k in sym-name)
                        collect `(assoc (intern (,key-transform-fun ,k))
                                        ,alist :test 'equal)))))
     ,@body))

(defmacro make-from-json-alist (json-alist type)
  (let ((slots (loop for slot in (sb-mop:class-direct-slots (find-class type))
                  collect (slot-value slot 'SB-PCL::NAME)))
        (instance (gensym "instance"))
        (k (gensym "k"))
        (v (gensym "v"))
        (slot-sym (gensym "slot-sym"))
        (class-package (symbol-package type))
        )
    `(progn
       (loop
          with ,instance = (make-instance ',type)
          for (,k . ,v) in ,json-alist
          as ,slot-sym = (intern (symbol-name ,k) ,class-package)
          when (member ,slot-sym ',slots)
          do (setf (slot-value ,instance ,slot-sym) ,v)
          finally (return ,instance)))))

;; `(with-alist-values ,json-alist ,slots from-camel-case
;;            (let ((,instance (make-instance ',type)))
;;              (setf ,@(loop for slot in slots append
;;                           `((slot-value ,instance ',slot) ,slot)))
;;              ,instance))

(defun get-nested (alist path)
  (when (stringp path)
    (setf path (cl-ppcre:split "[.]" path)))
  (reduce (lambda (alist attr) (cdr (assoc attr alist :test #'equal)))
          path :initial-value alist))

(defmacro get-nested-macro (alist path)
  `(get-nested ,alist ',(cl-ppcre:split "[.]" path)))

(defmacro with-json-paths (obj var-paths &body body)
  `(let ,(loop for (var path) in var-paths collect
              `(,var (get-nested ,obj ,path)))
     ,@body))

(defun drakma-json-content-type-hack (&optional remove)
  (let ((json (cons "application" "json")))
    (setf drakma:*text-content-types*
          (delete json drakma:*text-content-types* :test 'equal))
    (unless remove (push json drakma:*text-content-types*))
    drakma:*text-content-types*))

'(drakma-json-content-type-hack t)

(defun lisp-alist-to-json-map (params)
  (loop for (k . v) in params
     ;; by #'cddr
     as k-string = (to-api-param-key k)
     do (format t "~A ~A~%" k-string v)
     unless (assoc k-string params :test #' equal)
     collect (cons k-string v) into params
     finally (return params)))

(defun flat-to-alist (&rest flat)
  (loop for (k v) on flat by #'cddr collect (cons k v)))

(defmacro flat-to-alist-macro (&rest flat)
  `(flat-to-alist ,@flat))

(defun read-file (filename)
  (with-output-to-string (out)
    (with-open-file (in filename)
      (format out "~{~A~^~%~}"
              (loop as line = (read-line in nil)
                 while line
                 collect line)))))

;; https://stackoverflow.com/questions/9743056/common-lisp-exporting-symbols-from-packages
'(let ((pack (find-package 'yt-comments/util)))
  (do-all-symbols (sym pack)
    (when (eql (symbol-package sym) pack) (export sym))))

(defmacro retry-times (n timeout-secs &body body)
  (let ((i-sym (gensym "i"))
        (ex-sym (gensym "ex"))
        (loop-ex-sym (gensym "loop-ex"))
        (loop-tag-sym (gensym "loop-tag"))
        (timeout-secs (or timeout-secs 1)))
    `(loop
        named ,loop-tag-sym
        with ,loop-ex-sym = nil
        for ,i-sym below ,n
        do (format t "~A ~A~%" ,i-sym ,loop-ex-sym)
        do
          (handler-case
              (progn
                (setf ,loop-ex-sym nil)
                (return-from ,loop-tag-sym
                  (progn ,@body)))
            (error (,ex-sym)
              (setf ,loop-ex-sym ,ex-sym)
              (format nil "failed with ~A retrying ~D/~D... ~%"
                      ,ex-sym (1+ ,i-sym) ,n)
              (sleep ,timeout-secs)))
        while ,loop-ex-sym
        finally (error ,loop-ex-sym))))

(defmacro assoq (alist item)
  `(cdr (assoc ,item ,alist :test 'equal)))
