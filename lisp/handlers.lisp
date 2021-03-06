(in-package #:youtube-comments)

(defroutes *youtube-dispatchers*

    (((:get) "^/youtube/subscriptions(.html)?/?$" is-html)

     (if is-html
         render-table-html
         (channels-handler
          (loop for sub in (-> (subscriptions-get (params
                                                :mine "true"
                                                :part "snippet"))
                               (check-http-ok)
                               (-json-get-nested "items"))

             collect (with-json-paths sub
                         ((chan-id "snippet.resourceId.channelId")
                          (title "snippet.title")
                          (description "snippet.description"))
                       (make-channel
                        :id chan-id
                        :title title
                        :description description))))))

  (((:get) "^/youtube/playlists(.html)?/?$" is-html)

   (if is-html
       render-table-html
       (progn
         (setf (hunchentoot:content-type*) "application/json")
         (->
          `(
            ("headers" . ("title"  "published" "videos"))
            ("items" .
                     ,(or (loop with playlists =
                                               (-> (playlists-get (params
                                                                   :mine "true"
                                                                   :part "snippet"))
                                                   (check-http-ok)
                                                   (-json-get-nested "items"))
                             for playlist in playlists
                             collect
                               (with-json-paths playlist
                                   ((id "id")
                                    (title "snippet.title")
                                    (published "snippet.publishedAt"))
                                 (params
                                  "title" (dom-link (playlist-url id) title)
                                  "published" published
                                  "videos" (dom-link (format nil "/youtube/playlists/~A/videos.html"
                                                             id)
                                                     "videos"))))
                          *json-empty-list*)))
          cl-json:encode-json-alist-to-string))))

  (((:get) "^/youtube/playlists/([^/]+)/videos(.html)?/?$" playlist-id is-html)
   (if is-html
       render-table-html
       (videos-handler
        (loop for video-alist in (->
                                  (playlist-items-get (params
                                                       :playlist-id playlist-id
                                                       :mine "true"
                                                       :part "snippet"))
                                  (check-http-ok)
                                  (-json-get-nested "items"))
           as video = (make-video-from-alist video-alist)
           do (setf (video-id video)
                    (-json-get-nested video-alist "snippet.resourceId.videoId"))
           collect video))))

  (((:get) "^/youtube/videos/([^/]*)/comments-count$" video-id)

   "list number of matching comments for the current user on the given video"
   (assert (session-channel-title))
   (results-count-handler
    (comment-threads-get
     `(("part" . "id")
       ("searchTerms" . ,(session-channel-title))
       ("videoId" . ,video-id)
       ("maxResults" . "50"))
     :depaginator nil)))

  (((:get) "^/youtube/channels/([^/]*)/comments-count$" channel-id)

   "list number of matching comments for the current user on the given video"
   (assert (session-channel-title))
   (results-count-handler
    (comment-threads-get
     `(("part" . "id")
       ("searchTerms" . ,(session-channel-title))
       ("allThreadsRelatedToChannelId" . ,channel-id)
       ("maxResults" . "50"))
     :depaginator nil)))

  (((:get) "^/youtube/channels/([^/]*)/comments(.html)?/?$" sub-channel-id is-html)
   (if is-html
       (html
        (:script :type "text/javascript"
                 :src (raw js-table-render-script-path)
                 "hello"))
       ;; (assert (session-channel-title))
       (list-comment-threads-handler (channel-comment-threads sub-channel-id))))

  (((:get) "^/youtube/videos/([^/]+)/comments(.html)?/?$" video-id is-html)
   (if is-html
       render-table-html
       (progn
         (assert (session-channel-title))
         (list-comment-threads-handler
          (comment-threads-get (params
                                :part "snippet"
                                :search-terms (session-channel-title)
                                :video-id video-id))))))

  (((:delete) "^/youtube/comment/([^/]+)/delete$" comment-id)

   "delete a given comment"
   (vom:debug "deleting comment ~A~%" comment-id)
   (multiple-value-bind (resp-alist http-code)
       (comment-delete comment-id)
     (unless (= 204 http-code)
       (format nil "non-204 delete resp: ~A~%" resp-alist))
     (markup (:font :color (if (= 204 http-code) "green" "red")
                    (:b (write-to-string http-code))))))

  (((:post) "^/youtube/feed-history/video-ids$")
   "parse video ids from the inner html of https://www.youtube.com/feed/history/comment_history"
   (let* ((json (json-req))
          (video-ids (assoq json :video-ids))
          (aggregation (assoq json :aggregation))
          (unique-id (gen-unique-id)))
     (unless (null (session-value 'feed-req-ids))
       (setf (session-value 'feed-req-ids) nil))
     (push (cons unique-id
                 (cons aggregation video-ids))
           (session-value 'feed-req-ids))
     (json-resp
      `(("location" .
                    ,(format nil "/youtube/feed-history/results/~A" unique-id))))))

  (((:get) "^/youtube/feed-history/results/([0-9]+)$" (#'parse-integer unique-id))

   "parse video ids from the https://www.youtube.com/feed/history/comment_history inner html"
   (let ((req (assoq (session-value 'feed-req-ids) unique-id)))
     (if (not req)
         (progn (vom:warn "req ~A~%" req)
                (format nil "request id ~A not found" unique-id))
         (destructuring-bind (aggregation . video-ids) req
           (feed-aggregation-handler aggregation video-ids)))))

  (((:get) "^/rated-videos/?$")

   "list user's liked videos"
   (videos-handler
    (loop for rating in '("like" "dislike") append
         (loop for video-alist in (videos-get
                                   (params
                                    :my-rating rating
                                    :part "snippet"))
            as video = (make-video-from-alist video-alist)
            do (setf (video-rating video) rating)
            collect video)))))
