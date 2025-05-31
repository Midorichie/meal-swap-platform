;; reputation-system.clar
;; -----------------------------------------------------------------------------
;; A reputation and rating system for the meal swap platform
;;  - Users can rate completed swaps
;;  - Maintains reputation scores and history
;;  - Prevents spam and abuse through validation
;;  - Integrates with the main meal-swap contract
;; -----------------------------------------------------------------------------

;; Constants
(define-constant ERR-NOT-FOUND u200)
(define-constant ERR-UNAUTHORIZED u201)
(define-constant ERR-ALREADY-RATED u202)
(define-constant ERR-INVALID-RATING u203)
(define-constant ERR-CANNOT-RATE-SELF u204)
(define-constant ERR-SWAP-NOT-COMPLETED u205)

;; Rating bounds
(define-constant MIN-RATING u1)
(define-constant MAX-RATING u5)

;; Data Variables
(define-data-var next-rating-id uint u1)
(define-data-var meal-swap-contract principal tx-sender) ;; Will be set to actual contract

;; User reputation data
(define-map user-reputation
  { user: principal }
  { total-rating: uint,
    rating-count: uint,
    average-rating: uint,
    total-swaps: uint })

;; Individual rating records
(define-map ratings
  { rating-id: uint }
  { rater: principal,
    rated-user: principal,
    rating: uint,
    comment: (string-ascii 256),
    match-id: uint,
    created-at: uint })

;; Track which matches have been rated by whom
(define-map match-ratings
  { match-id: uint, rater: principal }
  { rating-id: uint,
    rated-user: principal })

;; -----------------------------------------------------------------------------
;; PRIVATE FUNCTIONS
;; -----------------------------------------------------------------------------

;; Calculate new average rating
(define-private (calculate-average (total uint) (count uint))
  (if (is-eq count u0)
      u0
      (/ total count)))

;; Update user reputation after new rating
(define-private (update-user-reputation (user principal) (new-rating uint))
  (let ((current-rep (default-to 
                      { total-rating: u0, rating-count: u0, average-rating: u0, total-swaps: u0 }
                      (map-get? user-reputation { user: user }))))
    (let ((new-total (+ (get total-rating current-rep) new-rating))
          (new-count (+ (get rating-count current-rep) u1)))
      (map-set user-reputation
        { user: user }
        { total-rating: new-total,
          rating-count: new-count,
          average-rating: (calculate-average new-total new-count),
          total-swaps: (get total-swaps current-rep) }))))

;; Validate rating value
(define-private (is-valid-rating (rating uint))
  (and (>= rating MIN-RATING) (<= rating MAX-RATING)))

;; Check if comment is valid (not empty, reasonable length)
(define-private (is-valid-comment (comment (string-ascii 256)))
  (and (> (len comment) u0) (<= (len comment) u256)))

;; Get min of two uints
(define-private (min (a uint) (b uint))
  (if (< a b) a b))

;; Check if rating is for specific user
(define-private (is-rating-for-user (rating-id uint) (user principal))
  (match (map-get? ratings { rating-id: rating-id })
    rating (is-eq (get rated-user rating) user)
    false))

;; -----------------------------------------------------------------------------
;; PUBLIC FUNCTIONS
;; -----------------------------------------------------------------------------

;; Set the meal-swap contract address (only callable once by deployer)
(define-public (set-meal-swap-contract (contract-address principal))
  (begin
    (asserts! (is-eq tx-sender (var-get meal-swap-contract)) (err ERR-UNAUTHORIZED))
    (var-set meal-swap-contract contract-address)
    (ok true)))

;; Submit a rating for a completed swap
(define-public (rate-user 
                (rated-user principal)
                (rating uint)
                (comment (string-ascii 256))
                (match-id uint))
  (let ((rating-id (var-get next-rating-id)))
    
    ;; Input validation
    (asserts! (is-valid-rating rating) (err ERR-INVALID-RATING))
    (asserts! (is-valid-comment comment) (err ERR-INVALID-RATING))
    (asserts! (not (is-eq tx-sender rated-user)) (err ERR-CANNOT-RATE-SELF))
    
    ;; Check if already rated this match
    (asserts! (is-none (map-get? match-ratings { match-id: match-id, rater: tx-sender }))
              (err ERR-ALREADY-RATED))
    
    ;; TODO: In a real implementation, we would call the meal-swap contract
    ;; to verify the match exists and is completed, and that tx-sender was a participant
    ;; For now, we'll assume the validation is done externally
    
    ;; Create rating record
    (map-set ratings
      { rating-id: rating-id }
      { rater: tx-sender,
        rated-user: rated-user,
        rating: rating,
        comment: comment,
        match-id: match-id,
        created-at: block-height })
    
    ;; Track that this match has been rated
    (map-set match-ratings
      { match-id: match-id, rater: tx-sender }
      { rating-id: rating-id,
        rated-user: rated-user })
    
    ;; Update user reputation
    (update-user-reputation rated-user rating)
    
    ;; Increment rating ID
    (var-set next-rating-id (+ rating-id u1))
    
    (ok rating-id)))

;; Increment swap count when a swap is completed (called by meal-swap contract)
(define-public (increment-user-swap-count (user principal))
  (let ((current-rep (default-to 
                      { total-rating: u0, rating-count: u0, average-rating: u0, total-swaps: u0 }
                      (map-get? user-reputation { user: user }))))
    ;; Only the meal-swap contract can call this
    (asserts! (is-eq tx-sender (var-get meal-swap-contract)) (err ERR-UNAUTHORIZED))
    
    (map-set user-reputation
      { user: user }
      (merge current-rep { total-swaps: (+ (get total-swaps current-rep) u1) }))
    
    (ok true)))

;; -----------------------------------------------------------------------------
;; READ-ONLY FUNCTIONS
;; -----------------------------------------------------------------------------

;; Get user reputation
(define-read-only (get-user-reputation (user principal))
  (default-to 
    { total-rating: u0, rating-count: u0, average-rating: u0, total-swaps: u0 }
    (map-get? user-reputation { user: user })))

;; Get specific rating
(define-read-only (get-rating (rating-id uint))
  (map-get? ratings { rating-id: rating-id }))

;; Get user ratings by checking specific IDs (simplified version)
(define-read-only (get-user-ratings (user principal) (start uint) (limit uint))
  (let ((max-id (var-get next-rating-id)))
    (if (>= start max-id)
        (list)
        ;; Check ratings one by one
        (let ((rating-1 (map-get? ratings { rating-id: start }))
              (rating-2 (map-get? ratings { rating-id: (+ start u1) }))
              (rating-3 (map-get? ratings { rating-id: (+ start u2) }))
              (rating-4 (map-get? ratings { rating-id: (+ start u3) }))
              (rating-5 (map-get? ratings { rating-id: (+ start u4) })))
          ;; Filter for user and build list using concat
          (concat
            (concat
              (concat
                (concat (if (and (is-some rating-1) 
                                 (is-eq (get rated-user (unwrap-panic rating-1)) user))
                            (list start) (list))
                        (if (and (is-some rating-2) 
                                 (is-eq (get rated-user (unwrap-panic rating-2)) user))
                            (list (+ start u1)) (list)))
                (if (and (is-some rating-3) 
                         (is-eq (get rated-user (unwrap-panic rating-3)) user))
                    (list (+ start u2)) (list)))
              (if (and (is-some rating-4) 
                       (is-eq (get rated-user (unwrap-panic rating-4)) user))
                  (list (+ start u3)) (list)))
            (if (and (is-some rating-5) 
                     (is-eq (get rated-user (unwrap-panic rating-5)) user))
                (list (+ start u4)) (list)))))))

;; Get ratings by ID list (up to 5 ratings)
(define-read-only (get-ratings-by-ids (rating-ids (list 5 uint)))
  (let ((id-1 (default-to u0 (element-at rating-ids u0)))
        (id-2 (default-to u0 (element-at rating-ids u1)))
        (id-3 (default-to u0 (element-at rating-ids u2)))
        (id-4 (default-to u0 (element-at rating-ids u3)))
        (id-5 (default-to u0 (element-at rating-ids u4))))
    (let ((rating-1 (map-get? ratings { rating-id: id-1 }))
          (rating-2 (map-get? ratings { rating-id: id-2 }))
          (rating-3 (map-get? ratings { rating-id: id-3 }))
          (rating-4 (map-get? ratings { rating-id: id-4 }))
          (rating-5 (map-get? ratings { rating-id: id-5 })))
      ;; Build list of non-none results using concat
      (concat
        (concat
          (concat
            (concat (if (is-some rating-1) (list (unwrap-panic rating-1)) (list))
                    (if (is-some rating-2) (list (unwrap-panic rating-2)) (list)))
            (if (is-some rating-3) (list (unwrap-panic rating-3)) (list)))
          (if (is-some rating-4) (list (unwrap-panic rating-4)) (list)))
        (if (is-some rating-5) (list (unwrap-panic rating-5)) (list))))))

;; Check if a match has been rated by a user
(define-read-only (has-rated-match (match-id uint) (rater principal))
  (is-some (map-get? match-ratings { match-id: match-id, rater: rater })))

;; Get user's trust score (combination of rating and swap count)
(define-read-only (get-user-trust-score (user principal))
  (let ((rep (get-user-reputation user)))
    (let ((rating-score (get average-rating rep))
          (swap-count (get total-swaps rep))
          (rating-count (get rating-count rep)))
      ;; Simple trust calculation: weighted average with swap completion bonus
      (if (is-eq rating-count u0)
          (if (> swap-count u0) u250 u0) ;; Base score for completing swaps without ratings
          (+ (* rating-score u50) ;; Rating component (1-5 * 50 = 50-250)
             (min (* swap-count u10) u100)))))) ;; Swap bonus (up to 100 points)

;; Get meal-swap contract address
(define-read-only (get-meal-swap-contract)
  (var-get meal-swap-contract))

;; Get next rating ID
(define-read-only (get-next-rating-id)
  (var-get next-rating-id))
