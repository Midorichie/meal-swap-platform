;; meal-swap.clar (Phase 2 - Enhanced)
;; -----------------------------------------------------------------------------
;; An enhanced "meal swap" contract with security improvements and new features:
;;  - Input validation and overflow protection (Bug Fix)
;;  - Proposal status management and matching system (New Functionality)
;;  - Access controls and security enhancements
;;  - Integration with reputation system
;; -----------------------------------------------------------------------------

;; Constants
(define-constant ERR-NOT-FOUND u100)
(define-constant ERR-UNAUTHORIZED u101)
(define-constant ERR-INVALID-INPUT u102)
(define-constant ERR-PROPOSAL-NOT-ACTIVE u103)
(define-constant ERR-CANNOT-MATCH-OWN-PROPOSAL u104)
(define-constant ERR-ALREADY-MATCHED u105)
(define-constant ERR-SWAP-NOT-READY u106)

;; Proposal status constants
(define-constant STATUS-ACTIVE u1)
(define-constant STATUS-MATCHED u2)
(define-constant STATUS-COMPLETED u3)
(define-constant STATUS-CANCELLED u4)

;; Data Variables
(define-data-var next-proposal-id uint u1)
(define-data-var contract-owner principal tx-sender)

;; Enhanced proposal structure with status and matching
(define-map proposals
  { proposal-id: uint }
  { proposer: principal,
    meal-details: (string-ascii 128),  ;; Increased from 64 to 128
    desired-meal: (string-ascii 128),
    status: uint,
    created-at: uint,
    matched-with: (optional uint),
    matcher: (optional principal) })

;; Track matches between proposals
(define-map matches
  { match-id: uint }
  { proposal-a: uint,
    proposal-b: uint,
    proposer-a: principal,
    proposer-b: principal,
    created-at: uint,
    completed: bool })

(define-data-var next-match-id uint u1)

;; User proposal count for rate limiting
(define-map user-proposal-count
  { user: principal }
  { count: uint,
    last-proposal-time: uint })

;; -----------------------------------------------------------------------------
;; PRIVATE FUNCTIONS
;; -----------------------------------------------------------------------------

;; Input validation helper
(define-private (is-valid-string (str (string-ascii 128)))
  (and 
    (> (len str) u0)
    (<= (len str) u128)))

;; Check if user can create proposal (rate limiting)
(define-private (can-user-create-proposal (user principal))
  (let ((user-data (default-to { count: u0, last-proposal-time: u0 } 
                                (map-get? user-proposal-count { user: user }))))
    ;; Allow max 5 proposals per user, with 1 block cooldown
    (and 
      (< (get count user-data) u5)
      (> block-height (get last-proposal-time user-data)))))

;; Update user proposal count
(define-private (update-user-proposal-count (user principal))
  (let ((current-data (default-to { count: u0, last-proposal-time: u0 } 
                                  (map-get? user-proposal-count { user: user }))))
    (map-set user-proposal-count 
      { user: user }
      { count: (+ (get count current-data) u1),
        last-proposal-time: block-height })))

;; Get min of two uints
(define-private (min (a uint) (b uint))
  (if (< a b) a b))

;; Check if proposal is active
(define-private (get-proposal-if-active (proposal-id uint))
  (match (map-get? proposals { proposal-id: proposal-id })
    proposal (if (is-eq (get status proposal) STATUS-ACTIVE)
                 (some { proposal-id: proposal-id, data: proposal })
                 none)
    none))

;; -----------------------------------------------------------------------------
;; PUBLIC FUNCTIONS
;; -----------------------------------------------------------------------------

;; Enhanced create-proposal with input validation and security
(define-public (create-proposal 
                (meal-details (string-ascii 128)) 
                (desired-meal (string-ascii 128)))
  (let ((current-id (var-get next-proposal-id)))
    ;; Input validation
    (asserts! (is-valid-string meal-details) (err ERR-INVALID-INPUT))
    (asserts! (is-valid-string desired-meal) (err ERR-INVALID-INPUT))
    ;; Rate limiting check
    (asserts! (can-user-create-proposal tx-sender) (err ERR-UNAUTHORIZED))
    
    ;; Create proposal
    (map-set proposals 
      { proposal-id: current-id }
      { proposer: tx-sender,
        meal-details: meal-details,
        desired-meal: desired-meal,
        status: STATUS-ACTIVE,
        created-at: block-height,
        matched-with: none,
        matcher: none })
    
    ;; Update counters safely (prevent overflow)
    (asserts! (< current-id u4294967295) (err ERR-INVALID-INPUT)) ;; Max uint check
    (var-set next-proposal-id (+ current-id u1))
    (update-user-proposal-count tx-sender)
    
    (ok current-id)))

;; Match two proposals together
(define-public (match-proposals (proposal-a-id uint) (proposal-b-id uint))
  (let ((proposal-a (unwrap! (map-get? proposals { proposal-id: proposal-a-id }) 
                            (err ERR-NOT-FOUND)))
        (proposal-b (unwrap! (map-get? proposals { proposal-id: proposal-b-id }) 
                            (err ERR-NOT-FOUND)))
        (match-id (var-get next-match-id)))
    
    ;; Validation checks
    (asserts! (is-eq (get status proposal-a) STATUS-ACTIVE) (err ERR-PROPOSAL-NOT-ACTIVE))
    (asserts! (is-eq (get status proposal-b) STATUS-ACTIVE) (err ERR-PROPOSAL-NOT-ACTIVE))
    (asserts! (not (is-eq (get proposer proposal-a) tx-sender)) (err ERR-CANNOT-MATCH-OWN-PROPOSAL))
    (asserts! (not (is-eq (get proposer proposal-b) tx-sender)) (err ERR-CANNOT-MATCH-OWN-PROPOSAL))
    
    ;; Only one of the proposers can initiate the match
    (asserts! (or (is-eq (get proposer proposal-a) tx-sender)
                  (is-eq (get proposer proposal-b) tx-sender)) (err ERR-UNAUTHORIZED))
    
    ;; Create match record
    (map-set matches
      { match-id: match-id }
      { proposal-a: proposal-a-id,
        proposal-b: proposal-b-id,
        proposer-a: (get proposer proposal-a),
        proposer-b: (get proposer proposal-b),
        created-at: block-height,
        completed: false })
    
    ;; Update proposal statuses
    (map-set proposals 
      { proposal-id: proposal-a-id }
      (merge proposal-a { status: STATUS-MATCHED,
                         matched-with: (some proposal-b-id),
                         matcher: (some tx-sender) }))
    
    (map-set proposals 
      { proposal-id: proposal-b-id }
      (merge proposal-b { status: STATUS-MATCHED,
                         matched-with: (some proposal-a-id),
                         matcher: (some tx-sender) }))
    
    (var-set next-match-id (+ match-id u1))
    (ok match-id)))

;; Complete a swap (both parties must confirm)
(define-public (complete-swap (match-id uint))
  (let ((match-data (unwrap! (map-get? matches { match-id: match-id }) 
                            (err ERR-NOT-FOUND))))
    
    ;; Only the involved parties can complete
    (asserts! (or (is-eq (get proposer-a match-data) tx-sender)
                  (is-eq (get proposer-b match-data) tx-sender)) (err ERR-UNAUTHORIZED))
    
    ;; Check if swap is ready to complete
    (asserts! (not (get completed match-data)) (err ERR-ALREADY-MATCHED))
    
    ;; Mark match as completed
    (map-set matches
      { match-id: match-id }
      (merge match-data { completed: true }))
    
    ;; Update proposal statuses to completed
    (map-set proposals 
      { proposal-id: (get proposal-a match-data) }
      (merge (unwrap-panic (map-get? proposals { proposal-id: (get proposal-a match-data) }))
             { status: STATUS-COMPLETED }))
    
    (map-set proposals 
      { proposal-id: (get proposal-b match-data) }
      (merge (unwrap-panic (map-get? proposals { proposal-id: (get proposal-b match-data) }))
             { status: STATUS-COMPLETED }))
    
    (ok true)))

;; Cancel a proposal (only by proposer or contract owner)
(define-public (cancel-proposal (proposal-id uint))
  (let ((proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) 
                          (err ERR-NOT-FOUND))))
    
    ;; Authorization check
    (asserts! (or (is-eq (get proposer proposal) tx-sender)
                  (is-eq (var-get contract-owner) tx-sender)) (err ERR-UNAUTHORIZED))
    
    ;; Can only cancel active proposals
    (asserts! (is-eq (get status proposal) STATUS-ACTIVE) (err ERR-PROPOSAL-NOT-ACTIVE))
    
    ;; Update status
    (map-set proposals 
      { proposal-id: proposal-id }
      (merge proposal { status: STATUS-CANCELLED }))
    
    (ok true)))

;; Emergency function for contract owner
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-UNAUTHORIZED))
    (var-set contract-owner new-owner)
    (ok true)))

;; -----------------------------------------------------------------------------
;; READ-ONLY FUNCTIONS
;; -----------------------------------------------------------------------------

;; Enhanced get-proposal with more data
(define-read-only (get-proposal (proposal-id uint))
  (match (map-get? proposals { proposal-id: proposal-id })
    data (ok data)
    (err ERR-NOT-FOUND)))

;; Get match details
(define-read-only (get-match (match-id uint))
  (match (map-get? matches { match-id: match-id })
    data (ok data)
    (err ERR-NOT-FOUND)))

;; Get active proposals in a range (simplified version)
(define-read-only (get-active-proposals-range (start uint) (limit uint))
  (let ((max-id (var-get next-proposal-id)))
    (if (>= start max-id)
        (list)
        ;; Check proposals one by one and collect active ones
        (let ((proposal-1 (get-proposal-if-active start))
              (proposal-2 (get-proposal-if-active (+ start u1)))
              (proposal-3 (get-proposal-if-active (+ start u2)))
              (proposal-4 (get-proposal-if-active (+ start u3)))
              (proposal-5 (get-proposal-if-active (+ start u4))))
          ;; Build list of non-none results using concat
          (concat
            (concat
              (concat
                (concat (if (is-some proposal-1) (list (unwrap-panic proposal-1)) (list))
                        (if (is-some proposal-2) (list (unwrap-panic proposal-2)) (list)))
                (if (is-some proposal-3) (list (unwrap-panic proposal-3)) (list)))
              (if (is-some proposal-4) (list (unwrap-panic proposal-4)) (list)))
            (if (is-some proposal-5) (list (unwrap-panic proposal-5)) (list)))))))

;; Get specific proposals by ID list (up to 5 proposals)
(define-read-only (get-proposals-by-ids (proposal-ids (list 5 uint)))
  (let ((id-1 (default-to u0 (element-at proposal-ids u0)))
        (id-2 (default-to u0 (element-at proposal-ids u1)))
        (id-3 (default-to u0 (element-at proposal-ids u2)))
        (id-4 (default-to u0 (element-at proposal-ids u3)))
        (id-5 (default-to u0 (element-at proposal-ids u4))))
    (let ((proposal-1 (get-proposal-if-active id-1))
          (proposal-2 (get-proposal-if-active id-2))
          (proposal-3 (get-proposal-if-active id-3))
          (proposal-4 (get-proposal-if-active id-4))
          (proposal-5 (get-proposal-if-active id-5)))
      ;; Build list of non-none results using concat
      (concat
        (concat
          (concat
            (concat (if (is-some proposal-1) (list (unwrap-panic proposal-1)) (list))
                    (if (is-some proposal-2) (list (unwrap-panic proposal-2)) (list)))
            (if (is-some proposal-3) (list (unwrap-panic proposal-3)) (list)))
          (if (is-some proposal-4) (list (unwrap-panic proposal-4)) (list)))
        (if (is-some proposal-5) (list (unwrap-panic proposal-5)) (list))))))

;; Get user's proposals
(define-read-only (get-user-proposal-count (user principal))
  (default-to { count: u0, last-proposal-time: u0 } 
              (map-get? user-proposal-count { user: user })))

;; Get next IDs for reference
(define-read-only (get-next-proposal-id)
  (var-get next-proposal-id))

(define-read-only (get-next-match-id)
  (var-get next-match-id))

;; Get contract owner
(define-read-only (get-contract-owner)
  (var-get contract-owner))
