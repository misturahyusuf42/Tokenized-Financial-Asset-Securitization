;; Pooling Contract
;; This contract groups similar assets together into pools

;; Define data variables
(define-data-var contract-owner principal tx-sender)
(define-map asset-pools
  { pool-id: (string-utf8 36) }
  {
    pool-name: (string-utf8 64),
    asset-type: (string-utf8 24),
    total-value: uint,
    asset-count: uint,
    creation-date: uint,
    is-active: bool
  }
)

(define-map pool-assets
  {
    pool-id: (string-utf8 36),
    asset-id: (string-utf8 36)
  }
  {
    value: uint,
    added-at: uint
  }
)

;; Error codes
(define-constant ERR_UNAUTHORIZED u1)
(define-constant ERR_POOL_NOT_FOUND u2)
(define-constant ERR_ASSET_ALREADY_POOLED u3)
(define-constant ERR_POOL_INACTIVE u4)

;; Read-only functions
(define-read-only (get-pool-details (pool-id (string-utf8 36)))
  (map-get? asset-pools { pool-id: pool-id })
)

(define-read-only (get-asset-in-pool (pool-id (string-utf8 36)) (asset-id (string-utf8 36)))
  (map-get? pool-assets { pool-id: pool-id, asset-id: asset-id })
)

;; Public functions
(define-public (create-pool
    (pool-id (string-utf8 36))
    (pool-name (string-utf8 64))
    (asset-type (string-utf8 24))
  )
  (begin
    ;; Only contract owner can create pools
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))

    ;; Check if pool already exists
    (asserts! (is-none (get-pool-details pool-id)) (err ERR_UNAUTHORIZED))

    ;; Create new pool
    (ok (map-set asset-pools
      { pool-id: pool-id }
      {
        pool-name: pool-name,
        asset-type: asset-type,
        total-value: u0,
        asset-count: u0,
        creation-date: block-height,
        is-active: true
      }
    ))
  )
)

(define-public (add-asset-to-pool
    (pool-id (string-utf8 36))
    (asset-id (string-utf8 36))
    (asset-value uint)
  )
  (let (
    (pool (unwrap! (get-pool-details pool-id) (err ERR_POOL_NOT_FOUND)))
  )
    ;; Check if pool is active
    (asserts! (get is-active pool) (err ERR_POOL_INACTIVE))

    ;; Check if asset is already in a pool
    (asserts! (is-none (get-asset-in-pool pool-id asset-id)) (err ERR_ASSET_ALREADY_POOLED))

    ;; Add asset to pool
    (map-set pool-assets
      { pool-id: pool-id, asset-id: asset-id }
      { value: asset-value, added-at: block-height }
    )

    ;; Update pool details
    (ok (map-set asset-pools
      { pool-id: pool-id }
      (merge pool {
        total-value: (+ (get total-value pool) asset-value),
        asset-count: (+ (get asset-count pool) u1)
      })
    ))
  )
)

(define-public (deactivate-pool (pool-id (string-utf8 36)))
  (let (
    (pool (unwrap! (get-pool-details pool-id) (err ERR_POOL_NOT_FOUND)))
  )
    ;; Only contract owner can deactivate pools
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))

    ;; Update pool status
    (ok (map-set asset-pools
      { pool-id: pool-id }
      (merge pool { is-active: false })
    ))
  )
)
