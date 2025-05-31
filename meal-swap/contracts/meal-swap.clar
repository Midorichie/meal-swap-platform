;; ============================================================================
;; Meal Swap Platform (Clarity Smart Contract)
;; Allows users to list meals and swap them peer-to-peer.
;; ============================================================================

(define-trait meal-details
  (
    ;; Returns the meal name for a given meal-id (if needed)
    (get-name (tuple (meal-id uint))) (response (string-ascii 64) uint)
  )
)

;; --------------------------------------------------------------------------
;; Data Structures / Maps
;; --------------------------------------------------------------------------

;; Auto-incrementing counter for meal IDs
(define-data-var next-meal-id uint u1)

;; Maps meal-id → { owner: principal, description: string-ASCII, available: bool }
(define-map meals
  { meal-id: uint }
  { owner: principal,
    description: (string-ascii 128),
    available: bool }
)

;; Auto-incrementing counter for swap request IDs
(define-data-var next-swap-id uint u1)

;; Maps swap-id → { proposer: principal, proposee: principal, meal-offered: uint, meal-requested: uint, accepted: bool }
(define-map swap-requests
  { swap-id: uint }
  { proposer: principal,
    proposee: principal,
    meal-offered: uint,
    meal-requested: uint,
    accepted: bool }
)

;; --------------------------------------------------------------------------
;; Private Helper Functions
;; --------------------------------------------------------------------------

(define-private (get-next-id)
  (let ((current (var-get next-meal-id)))
    (var-set next-meal-id (+ current u1))
    current))

(define-private (get-next-swap-id)
  (let ((current (var-get next-swap-id)))
    (var-set next-swap-id (+ current u1))
    current))

(define-read-only (is-owner (meal-id uint) (caller principal))
  (match (map-get? meals { meal-id: meal-id })
    entry (is-eq caller (get owner entry))
    false))

;; --------------------------------------------------------------------------
;; Public Functions: Meal Management
;; --------------------------------------------------------------------------

(define-public (list-meal (description (string-ascii 128)))
  (let (
    (id (get-next-id))
    (sender (contract-caller))
  )
    (map-set meals
      { meal-id: id }
      { owner: sender,
        description: description,
        available: true })
    (ok id)))

(define-public (set-availability (meal-id uint) (status bool))
  (if (is-owner meal-id (contract-caller))
    (let ((entry (unwrap! (map-get? meals { meal-id: meal-id }) (err u100))))
      (map-set meals
        { meal-id: meal-id }
        { owner: (get owner entry),
          description: (get description entry),
          available: status })
      (ok status))
    (err u101)))

(define-public (update-description (meal-id uint) (new-desc (string-ascii 128)))
  (let ((entry (map-get? meals { meal-id: meal-id })))
    (asserts! (is-some entry) (err u102))
    (let ((full (unwrap! entry (err u102))))
      (asserts! (is-eq (contract-caller) (get owner full)) (err u103))
      (map-set meals
        { meal-id: meal-id }
        { owner: (get owner full),
          description: new-desc,
          available: (get available full) })
      (ok meal-id))))

;; --------------------------------------------------------------------------
;; Public Functions: Swap Management
;; --------------------------------------------------------------------------

(define-public (propose-swap (meal-offered uint) (meal-requested uint) (target principal))
  (let ((id (get-next-swap-id)) (sender (contract-caller)))
    (match (map-get? meals { meal-id: meal-offered })
      offering
        (if (and (is-eq sender (get owner (unwrap! offering (err u104)))) (get available (unwrap! offering (err u104))))
          (match (map-get? meals { meal-id: meal-requested })
            requesting
              (if (get available (unwrap! requesting (err u105)))
                (begin
                  (map-set swap-requests
                    { swap-id: id }
                    { proposer: sender,
                       proposee: target,
                       meal-offered: meal-offered,
                       meal-requested: meal-requested,
                       accepted: false })
                  (ok id))
                (err u106))
            (err u107))
          (err u108))
      (err u104))))

(define-public (accept-swap (swap-id uint))
  (match (map-get? swap-requests { swap-id: swap-id })
    proposal
      (let ((caller (contract-caller)))
        (if (and (is-eq caller (get proposee (unwrap! proposal (err u109)))) (not (get accepted (unwrap! proposal (err u109)))))
          (let ((offered (get meal-offered (unwrap! proposal (err u109)))) (requested (get meal-requested (unwrap! proposal (err u109)))))
            ;; Mark both meals unavailable
            (let ((off-entry (unwrap! (map-get? meals { meal-id: offered }) (err u110))))
              (map-set meals
                { meal-id: offered }
                { owner: (get proposer (unwrap! proposal (err u109))),
                  description: (get description off-entry),
                  available: false }))
            (let ((rq-entry (unwrap! (map-get? meals { meal-id: requested }) (err u111))))
              (map-set meals
                { meal-id: requested }
                { owner: (get proposee (unwrap! proposal (err u109))),
                  description: (get description rq-entry),
                  available: false }))
            ;; Mark swap accepted
            (map-set swap-requests
              { swap-id: swap-id }
              { proposer: (get proposer (unwrap! proposal (err u109))),
                proposee: (get proposee (unwrap! proposal (err u109))),
                meal-offered: offered,
                meal-requested: requested,
                accepted: true })
            (ok true))
          (err u112)))
    (err u113)))

(define-public (cancel-swap (swap-id uint))
  (match (map-get? swap-requests { swap-id: swap-id })
    proposal
      (let ((caller (contract-caller)))
        (if (and (is-eq caller (get proposer (unwrap! proposal (err u114)))) (not (get accepted (unwrap! proposal (err u114)))))
          (begin
            (map-delete swap-requests { swap-id: swap-id })
            (ok true))
          (err u115)))
    (err u116)))

;; --------------------------------------------------------------------------
;; Read-Only Functions: Queries
;; --------------------------------------------------------------------------

(define-read-only (get-meal (meal-id uint))
  (map-get? meals { meal-id: meal-id }))

(define-read-only (get-swap (swap-id uint))
  (map-get? swap-requests { swap-id: swap-id }))
