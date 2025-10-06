;; royalty-payment-processor
;; Automated royalty payments to artists on secondary sales

;; constants
(define-constant ERR_NOT_AUTHORIZED (err u200))
(define-constant ERR_NOT_FOUND (err u201))
(define-constant ERR_INVALID_AMOUNT (err u202))
(define-constant ERR_INVALID_PERCENTAGE (err u203))
(define-constant ERR_TRANSFER_FAILED (err u204))
(define-constant ERR_INSUFFICIENT_FUNDS (err u205))

(define-constant MAX_ROYALTY_PERCENTAGE u1000) ;; 10% in basis points (10000 = 100%)

;; data maps and vars
(define-map nft-royalties
    { token-id: uint }
    {
        artist: principal,
        royalty-percentage: uint, ;; in basis points (100 = 1%)
        total-earned: uint,
        last-sale-price: uint,
        last-sale-at: uint
    }
)

(define-map royalty-splits
    { token-id: uint, recipient: principal }
    {
        percentage: uint, ;; percentage of the royalty (not sale price)
        total-earned: uint
    }
)

(define-map payment-history
    { payment-id: uint }
    {
        token-id: uint,
        sale-price: uint,
        royalty-amount: uint,
        buyer: principal,
        seller: principal,
        processed-at: uint,
        transaction-hash: (buff 32)
    }
)

(define-data-var next-payment-id uint u1)
(define-data-var contract-owner principal tx-sender)
(define-data-var platform-fee-percentage uint u250) ;; 2.5% platform fee
(define-data-var platform-fee-recipient principal tx-sender)

;; private functions
(define-private (is-contract-owner)
    (is-eq tx-sender (var-get contract-owner))
)

(define-private (calculate-royalty-amount (sale-price uint) (royalty-percentage uint))
    (/ (* sale-price royalty-percentage) u10000)
)

(define-private (calculate-platform-fee (sale-price uint))
    (/ (* sale-price (var-get platform-fee-percentage)) u10000)
)

;; public functions
(define-public (set-nft-royalty
    (token-id uint)
    (artist principal)
    (royalty-percentage uint)
)
    (begin
        ;; Validate royalty percentage
        (asserts! (<= royalty-percentage MAX_ROYALTY_PERCENTAGE) ERR_INVALID_PERCENTAGE)
        
        ;; Only contract owner can set royalty for now
        (asserts! (is-contract-owner) ERR_NOT_AUTHORIZED)
        
        (map-set nft-royalties
            { token-id: token-id }
            {
                artist: artist,
                royalty-percentage: royalty-percentage,
                total-earned: u0,
                last-sale-price: u0,
                last-sale-at: u0
            }
        )
        
        (ok true)
    )
)

(define-public (add-royalty-split
    (token-id uint)
    (recipient principal)
    (percentage uint)
)
    (let (
        (royalty-data (unwrap! (map-get? nft-royalties { token-id: token-id }) ERR_NOT_FOUND))
    )
        ;; Only artist can add splits
        (asserts! (is-eq tx-sender (get artist royalty-data)) ERR_NOT_AUTHORIZED)
        
        ;; Validate percentage
        (asserts! (<= percentage u10000) ERR_INVALID_PERCENTAGE)
        
        (map-set royalty-splits
            { token-id: token-id, recipient: recipient }
            {
                percentage: percentage,
                total-earned: u0
            }
        )
        
        (ok true)
    )
)

(define-public (process-sale
    (token-id uint)
    (sale-price uint)
    (buyer principal)
    (seller principal)
    (transaction-hash (buff 32))
)
    (let (
        (royalty-data (map-get? nft-royalties { token-id: token-id }))
        (payment-id (var-get next-payment-id))
    )
        ;; Validate sale price
        (asserts! (> sale-price u0) ERR_INVALID_AMOUNT)
        
        ;; Process royalty payment if royalty exists
        (match royalty-data
            royalty-info
            (let (
                (royalty-amount (calculate-royalty-amount sale-price (get royalty-percentage royalty-info)))
                (platform-fee (calculate-platform-fee sale-price))
            )
                ;; Record payment history
                (map-set payment-history
                    { payment-id: payment-id }
                    {
                        token-id: token-id,
                        sale-price: sale-price,
                        royalty-amount: royalty-amount,
                        buyer: buyer,
                        seller: seller,
                        processed-at: stacks-block-height,
                        transaction-hash: transaction-hash
                    }
                )
                
                ;; Update royalty data
                (map-set nft-royalties
                    { token-id: token-id }
                    (merge royalty-info {
                        total-earned: (+ (get total-earned royalty-info) royalty-amount),
                        last-sale-price: sale-price,
                        last-sale-at: stacks-block-height
                    })
                )
                
                ;; Process royalty splits if any exist
                (distribute-royalty-splits token-id royalty-amount)
                
                ;; Pay platform fee
                (try! (stx-transfer? platform-fee tx-sender (var-get platform-fee-recipient)))
                
                ;; Pay remaining amount to seller
                (let ((seller-amount (- (- sale-price royalty-amount) platform-fee)))
                    (try! (stx-transfer? seller-amount tx-sender seller))
                )
            )
            ;; No royalty set, just pay platform fee and seller
            (let (
                (platform-fee (calculate-platform-fee sale-price))
                (seller-amount (- sale-price platform-fee))
            )
                (map-set payment-history
                    { payment-id: payment-id }
                    {
                        token-id: token-id,
                        sale-price: sale-price,
                        royalty-amount: u0,
                        buyer: buyer,
                        seller: seller,
                        processed-at: stacks-block-height,
                        transaction-hash: transaction-hash
                    }
                )
                
                (try! (stx-transfer? platform-fee tx-sender (var-get platform-fee-recipient)))
                (try! (stx-transfer? seller-amount tx-sender seller))
            )
        )
        
        ;; Increment payment ID
        (var-set next-payment-id (+ payment-id u1))
        
        (ok payment-id)
    )
)

(define-public (claim-royalties (token-id uint))
    (let (
        (royalty-data (unwrap! (map-get? nft-royalties { token-id: token-id }) ERR_NOT_FOUND))
        (claimable-amount (get-claimable-royalties token-id tx-sender))
    )
        ;; Only artist can claim royalties
        (asserts! (is-eq tx-sender (get artist royalty-data)) ERR_NOT_AUTHORIZED)
        (asserts! (> claimable-amount u0) ERR_INVALID_AMOUNT)
        
        ;; Transfer royalties (implementation would depend on how royalties are held)
        ;; For now, this is a placeholder
        (ok claimable-amount)
    )
)

(define-public (update-platform-fee (new-percentage uint) (new-recipient principal))
    (begin
        (asserts! (is-contract-owner) ERR_NOT_AUTHORIZED)
        (asserts! (<= new-percentage u1000) ERR_INVALID_PERCENTAGE) ;; Max 10%
        
        (var-set platform-fee-percentage new-percentage)
        (var-set platform-fee-recipient new-recipient)
        
        (ok true)
    )
)

;; Read-only functions
(define-read-only (get-nft-royalty (token-id uint))
    (map-get? nft-royalties { token-id: token-id })
)

(define-read-only (get-royalty-split (token-id uint) (recipient principal))
    (map-get? royalty-splits { token-id: token-id, recipient: recipient })
)

(define-read-only (get-payment-history (payment-id uint))
    (map-get? payment-history { payment-id: payment-id })
)

(define-read-only (calculate-royalty (token-id uint) (sale-price uint))
    (match (map-get? nft-royalties { token-id: token-id })
        royalty-data (ok (calculate-royalty-amount sale-price (get royalty-percentage royalty-data)))
        (ok u0)
    )
)

(define-read-only (get-claimable-royalties (token-id uint) (claimant principal))
    ;; Simplified implementation - in practice, this would track pending payments
    u0
)

(define-read-only (get-platform-fee-info)
    {
        percentage: (var-get platform-fee-percentage),
        recipient: (var-get platform-fee-recipient)
    }
)

;; Private helper functions
(define-private (distribute-royalty-splits (token-id uint) (total-royalty uint))
    ;; This would iterate through all splits and distribute payments
    ;; Simplified implementation for now
    true
)
