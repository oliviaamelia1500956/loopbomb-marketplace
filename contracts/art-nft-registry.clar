;; art-nft-registry
;; Registry system for cataloging and verifying art NFTs

;; constants
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_PARAMS (err u103))

;; data maps and vars
(define-map nft-registry
    { token-id: uint }
    {
        creator: principal,
        title: (string-ascii 256),
        description: (string-ascii 1024),
        image-uri: (string-ascii 512),
        metadata-uri: (string-ascii 512),
        created-at: uint,
        verified: bool,
        collection-id: (optional uint)
    }
)

(define-map collections
    { collection-id: uint }
    {
        name: (string-ascii 256),
        creator: principal,
        description: (string-ascii 1024),
        created-at: uint,
        total-nfts: uint
    }
)

(define-map verification-requests
    { token-id: uint }
    {
        requester: principal,
        requested-at: uint,
        status: (string-ascii 32) ;; "pending", "approved", "rejected"
    }
)

(define-data-var next-token-id uint u1)
(define-data-var next-collection-id uint u1)
(define-data-var contract-owner principal tx-sender)

;; private functions
(define-private (is-contract-owner)
    (is-eq tx-sender (var-get contract-owner))
)

(define-private (is-nft-creator (token-id uint))
    (match (map-get? nft-registry { token-id: token-id })
        nft-data (is-eq tx-sender (get creator nft-data))
        false
    )
)

;; public functions
(define-public (register-nft 
    (title (string-ascii 256))
    (description (string-ascii 1024))
    (image-uri (string-ascii 512))
    (metadata-uri (string-ascii 512))
    (collection-id (optional uint))
)
    (let (
        (token-id (var-get next-token-id))
        (current-height stacks-block-height)
    )
        ;; Validate collection exists if provided
        (asserts! (or (is-none collection-id)
                     (is-some (map-get? collections { collection-id: (unwrap! collection-id ERR_NOT_FOUND) })))
                 ERR_NOT_FOUND)
        
        ;; Register the NFT
        (map-set nft-registry
            { token-id: token-id }
            {
                creator: tx-sender,
                title: title,
                description: description,
                image-uri: image-uri,
                metadata-uri: metadata-uri,
                created-at: current-height,
                verified: false,
                collection-id: collection-id
            }
        )
        
        ;; Update collection NFT count if applicable
        (match collection-id
            coll-id (update-collection-nft-count coll-id)
            true
        )
        
        ;; Increment token ID
        (var-set next-token-id (+ token-id u1))
        
        (ok token-id)
    )
)

(define-public (create-collection
    (name (string-ascii 256))
    (description (string-ascii 1024))
)
    (let (
        (collection-id (var-get next-collection-id))
        (current-height stacks-block-height)
    )
        (map-set collections
            { collection-id: collection-id }
            {
                name: name,
                creator: tx-sender,
                description: description,
                created-at: current-height,
                total-nfts: u0
            }
        )
        
        (var-set next-collection-id (+ collection-id u1))
        (ok collection-id)
    )
)

(define-public (request-verification (token-id uint))
    (let (
        (nft-data (unwrap! (map-get? nft-registry { token-id: token-id }) ERR_NOT_FOUND))
    )
        ;; Only NFT creator can request verification
        (asserts! (is-eq tx-sender (get creator nft-data)) ERR_NOT_AUTHORIZED)
        
        ;; Check if verification request already exists
        (asserts! (is-none (map-get? verification-requests { token-id: token-id })) ERR_ALREADY_EXISTS)
        
        (map-set verification-requests
            { token-id: token-id }
            {
                requester: tx-sender,
                requested-at: stacks-block-height,
                status: "pending"
            }
        )
        
        (ok true)
    )
)

(define-public (verify-nft (token-id uint) (approve bool))
    (let (
        (nft-data (unwrap! (map-get? nft-registry { token-id: token-id }) ERR_NOT_FOUND))
        (verification-data (unwrap! (map-get? verification-requests { token-id: token-id }) ERR_NOT_FOUND))
    )
        ;; Only contract owner can verify NFTs
        (asserts! (is-contract-owner) ERR_NOT_AUTHORIZED)
        
        ;; Update verification status
        (if approve
            (begin
                (map-set nft-registry
                    { token-id: token-id }
                    (merge nft-data { verified: true })
                )
                (map-set verification-requests
                    { token-id: token-id }
                    (merge verification-data { status: "approved" })
                )
            )
            (map-set verification-requests
                { token-id: token-id }
                (merge verification-data { status: "rejected" })
            )
        )
        
        (ok approve)
    )
)

(define-public (update-nft-metadata
    (token-id uint)
    (title (string-ascii 256))
    (description (string-ascii 1024))
    (image-uri (string-ascii 512))
    (metadata-uri (string-ascii 512))
)
    (let (
        (nft-data (unwrap! (map-get? nft-registry { token-id: token-id }) ERR_NOT_FOUND))
    )
        ;; Only creator can update metadata
        (asserts! (is-eq tx-sender (get creator nft-data)) ERR_NOT_AUTHORIZED)
        
        (map-set nft-registry
            { token-id: token-id }
            (merge nft-data {
                title: title,
                description: description,
                image-uri: image-uri,
                metadata-uri: metadata-uri
            })
        )
        
        (ok true)
    )
)

;; Read-only functions
(define-read-only (get-nft-data (token-id uint))
    (map-get? nft-registry { token-id: token-id })
)

(define-read-only (get-collection-data (collection-id uint))
    (map-get? collections { collection-id: collection-id })
)

(define-read-only (get-verification-status (token-id uint))
    (map-get? verification-requests { token-id: token-id })
)

(define-read-only (get-next-token-id)
    (var-get next-token-id)
)

(define-read-only (get-next-collection-id)
    (var-get next-collection-id)
)

;; Helper functions
(define-private (update-collection-nft-count (collection-id uint))
    (match (map-get? collections { collection-id: collection-id })
        collection-data (map-set collections
                           { collection-id: collection-id }
                           (merge collection-data { total-nfts: (+ (get total-nfts collection-data) u1) }))
        false
    )
)
