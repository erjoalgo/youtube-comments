(asdf:defsystem :youtube-comments
                :serial t
                :description "tool to retrieve and delete youtube comments"
                :license "GPLv3"
                :author "Ernesto Alfonso <erjoalgo@gmail.com>"
                :depends-on (:drakma
                             :hunchentoot
                             :vom
                             :command-line-arguments
                             :cl-ppcre
                             :cl-json
                             :cl-markup
                             :fiasco
                             :erjoalgo-webutil
                             :sb-cltl2)
                :components ((:file "packages")
                             (:file "youtube-client")
                             (:file "server")
                             (:file "entity")
                             (:file "dom-util")
                             (:file "handler-util")
                             (:file "handlers")
                             (:file "handlers-noauth")
                             (:file "main")))
