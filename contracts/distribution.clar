;; Distribution Contract
;; This contract manages investor payments based on tranche ownership

;; Define data variables
(define-data-var contract-owner principal tx-sender)
(define-map payment-periods
  { period-id: uint }
  {
    start-date: uint,
    end-date: uint,
    total-collected: uint,
    is-distributed: bool
  }
)

(define-map tranche-payments
  {
    period-id: uint,
    tranche-id: (string-utf8 36)
  }
  {
    amount-allocated: uint,
    payment-date: uint
  }
)

(define-map investor-payments
  {
    period-id: uint,
    tranche-id: (string-utf8 36),
    investor: principal
  }
  {
    amount: uint,
    claimed: bool
  }
)

;; Error codes
(define-constant ERR_UNAUTHORIZED u1)
(define-constant ERR_PERIOD_EXISTS u2)
(define-constant ERR_PERIOD_NOT_FOUND u3)
(define-constant ERR_ALREADY_DISTRIBUTED u4)
(define-constant ERR_INSUFFICIENT_BALANCE u5)
(define-constant ERR_ALREADY_CLAIMED u6)

;; Read-only functions
(define-read-only (get-payment-period (period-id uint))
  (map-get? payment-periods { period-id: period-id })
)

(define-read-only (get-tranche-payment (period-id uint) (tranche-id (string-utf8 36)))
  (map-get? tranche-payments { period-id: period-id, tranche-id: tranche-id })
)

(define-read-only (get-investor-payment (period-id uint) (tranche-id (string-utf8 36)) (investor principal))
  (map-get? investor-payments { period-id: period-id, tranche-id: tranche-id, investor: investor })
)

;; Public functions
(define-public (create-payment-period (period-id uint) (start-date uint) (end-date uint))
  (begin
    ;; Only contract owner can create payment periods
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))

    ;; Check if period already exists
    (asserts! (is-none (get-payment-period period-id)) (err ERR_PERIOD_EXISTS))

    ;; Create new payment period
    (ok (map-set payment-periods
      { period-id: period-id }
      {
        start-date: start-date,
        end-date: end-date,
        total-collected: u0,
        is-distributed: false
      }
    ))
  )
)

(define-public (collect-payments (period-id uint) (amount uint))
  (let (
    (period (unwrap! (get-payment-period period-id) (err ERR_PERIOD_NOT_FOUND)))
  )
    ;; Only contract owner can collect payments
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))

    ;; Update payment period with collected amount
    (ok (map-set payment-periods
      { period-id: period-id }
      (merge period {
        total-collected: (+ (get total-collected period) amount)
      })
    ))
  )
)

(define-public (allocate-to-tranche (period-id uint) (tranche-id (string-utf8 36)) (amount uint))
  (let (
    (period (unwrap! (get-payment-period period-id) (err ERR_PERIOD_NOT_FOUND)))
  )
    ;; Only contract owner can allocate payments
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))

    ;; Check if period has already been distributed
    (asserts! (not (get is-distributed period)) (err ERR_ALREADY_DISTRIBUTED))

    ;; Allocate payment to tranche
    (ok (map-set tranche-payments
      { period-id: period-id, tranche-id: tranche-id }
      {
        amount-allocated: amount,
        payment-date: block-height
      }
    ))
  )
)

(define-public (distribute-to-investors
    (period-id uint)
    (tranche-id (string-utf8 36))
    (investor principal)
    (amount uint)
  )
  (let (
    (period (unwrap! (get-payment-period period-id) (err ERR_PERIOD_NOT_FOUND)))
    (tranche-payment (unwrap! (get-tranche-payment period-id tranche-id) (err ERR_PERIOD_NOT_FOUND)))
  )
    ;; Only contract owner can distribute payments
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))

    ;; Check if investor payment already exists
    (asserts! (is-none (get-investor-payment period-id tranche-id investor)) (err ERR_ALREADY_DISTRIBUTED))

    ;; Record investor payment
    (ok (map-set investor-payments
      { period-id: period-id, tranche-id: tranche-id, investor: investor }
      {
        amount: amount,
        claimed: false
      }
    ))
  )
)

(define-public (claim-payment (period-id uint) (tranche-id (string-utf8 36)))
  (let (
    (payment (unwrap! (get-investor-payment period-id tranche-id tx-sender) (err ERR_PERIOD_NOT_FOUND)))
  )
    ;; Check if payment has already been claimed
    (asserts! (not (get claimed payment)) (err ERR_ALREADY_CLAIMED))

    ;; Mark payment as claimed
    (ok (map-set investor-payments
      { period-id: period-id, tranche-id: tranche-id, investor: tx-sender }
      (merge payment { claimed: true })
    ))
  )
)

(define-public (mark-period-distributed (period-id uint))
  (let (
    (period (unwrap! (get-payment-period period-id) (err ERR_PERIOD_NOT_FOUND)))
  )
    ;; Only contract owner can mark periods as distributed
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))

    ;; Mark period as distributed
    (ok (map-set payment-periods
      { period-id: period-id }
      (merge period { is-distributed: true })
    ))
  )
)
