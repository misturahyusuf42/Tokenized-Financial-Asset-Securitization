;; Asset Verification Contract
;; This contract validates underlying assets before they can be securitized

;; Define data variables
(define-data-var contract-owner principal tx-sender)
(define-map verified-assets
  { asset-id: (string-utf8 36) }
  {
    owner: principal,
    value: uint,
    asset-type: (string-utf8 24),
    verification-date: uint,
    is-verified: bool
  }
)

;; Error codes
(define-constant ERR_UNAUTHORIZED u1)
(define-constant ERR_ALREADY_VERIFIED u2)
(define-constant ERR_INVALID_VALUE u3)

;; Read-only functions
(define-read-only (get-asset-details (asset-id (string-utf8 36)))
  (map-get? verified-assets { asset-id: asset-id })
)

(define-read-only (is-asset-verified (asset-id (string-utf8 36)))
  (default-to false (get is-verified (get-asset-details asset-id)))
)

;; Public functions
(define-public (register-asset
    (asset-id (string-utf8 36))
    (asset-type (string-utf8 24))
    (value uint)
  )
  (begin
    ;; Check if value is greater than zero
    (asserts! (> value u0) (err ERR_INVALID_VALUE))

    ;; Check if asset already exists
    (asserts! (is-none (get-asset-details asset-id)) (err ERR_ALREADY_VERIFIED))

    ;; Add asset to map
    (ok (map-set verified-assets
      { asset-id: asset-id }
      {
        owner: tx-sender,
        value: value,
        asset-type: asset-type,
        verification-date: block-height,
        is-verified: false
      }
    ))
  )
)

(define-public (verify-asset (asset-id (string-utf8 36)))
  (let (
    (asset (unwrap! (get-asset-details asset-id) (err ERR_UNAUTHORIZED)))
  )
    ;; Only contract owner can verify assets
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))

    ;; Update asset verification status
    (ok (map-set verified-assets
      { asset-id: asset-id }
      (merge asset { is-verified: true })
    ))
  )
)

;; Administrative functions
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (ok (var-set contract-owner new-owner))
  )
)
