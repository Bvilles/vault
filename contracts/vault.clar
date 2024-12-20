;; Vault: Bitcoin-Inspired DeFi Protocol
;; A decentralized finance protocol focused on savings, swaps, and liquidity pools

;; Define SIP-010 Fungible Token Interface
(define-trait ft-trait
    (
        ;; Transfer from the caller to a new principal
        (transfer (uint principal principal (optional (buff 34))) (response bool uint))

        ;; Get the token balance of the specified principal
        (get-balance (principal) (response uint uint))

        ;; Get the current total supply
        (get-total-supply () (response uint uint))

        ;; Get the token name
        (get-name () (response (string-ascii 32) uint))

        ;; Get the token symbol
        (get-symbol () (response (string-ascii 32) uint))

        ;; Get the number of decimals
        (get-decimals () (response uint uint))

        ;; Get the URI containing token metadata
        (get-token-uri () (response (optional (string-utf8 256)) uint))
    )
)

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u1001))
(define-constant ERR_INSUFFICIENT_BALANCE (err u1002))
(define-constant ERR_INVALID_AMOUNT (err u1003))
(define-constant ERR_INVALID_PAIR (err u1004))

;; Data Variables
(define-data-var total-supply uint u0)
(define-data-var protocol-fee-rate uint u5) ;; 0.5% fee rate (represented as 5/1000)

;; Data Maps
(define-map balances principal uint)
(define-map liquidity-pools 
    { token-x: principal, token-y: principal }
    { reserve-x: uint, reserve-y: uint, total-shares: uint })
(define-map user-pool-shares 
    { user: principal, pool-id: { token-x: principal, token-y: principal }}
    uint)

;; Read-Only Functions
(define-read-only (get-balance (user principal))
    (default-to u0 (map-get? balances user)))

(define-read-only (get-pool-info (token-x principal) (token-y principal))
    (map-get? liquidity-pools { token-x: token-x, token-y: token-y }))

(define-read-only (get-user-pool-shares (user principal) (token-x principal) (token-y principal))
    (default-to 
        u0 
        (map-get? user-pool-shares { user: user, pool-id: { token-x: token-x, token-y: token-y }})))

;; Public Functions
(define-public (deposit (amount uint))
    (let ((current-balance (get-balance tx-sender)))
        (begin
            (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
            (map-set balances 
                tx-sender 
                (+ current-balance amount))
            (var-set total-supply (+ (var-get total-supply) amount))
            (ok true))))

(define-public (withdraw (amount uint))
    (let ((current-balance (get-balance tx-sender)))
        (if (<= amount current-balance)
            (begin
                (try! (as-contract (stx-transfer? amount (as-contract tx-sender) tx-sender)))
                (map-set balances
                    tx-sender
                    (- current-balance amount))
                (var-set total-supply (- (var-get total-supply) amount))
                (ok true))
            ERR_INSUFFICIENT_BALANCE)))

(define-public (add-liquidity 
    (token-x <ft-trait>)
    (token-y <ft-trait>)
    (amount-x uint)
    (amount-y uint))
    (let (
        (pool (get-pool-info (contract-of token-x) (contract-of token-y)))
        (shares u0))
        (if (is-none pool)
            ;; Create new pool
            (begin
                (try! (contract-call? token-x transfer amount-x tx-sender (as-contract tx-sender) none))
                (try! (contract-call? token-y transfer amount-y tx-sender (as-contract tx-sender) none))
                (map-set liquidity-pools
                    { token-x: (contract-of token-x), token-y: (contract-of token-y) }
                    { reserve-x: amount-x, reserve-y: amount-y, total-shares: amount-x })
                (map-set user-pool-shares
                    { user: tx-sender, pool-id: { token-x: (contract-of token-x), token-y: (contract-of token-y) }}
                    amount-x)
                (ok amount-x))
            ;; Add to existing pool
            (let ((pool-data (unwrap! pool ERR_INVALID_AMOUNT)))
                (if (and
                        (>= (* amount-x (get reserve-y pool-data))
                            (* amount-y (get reserve-x pool-data)))
                        (<= (* amount-x (get reserve-y pool-data))
                            (* amount-y (get reserve-x pool-data))))
                    (begin
                        (try! (contract-call? token-x transfer amount-x tx-sender (as-contract tx-sender) none))
                        (try! (contract-call? token-y transfer amount-y tx-sender (as-contract tx-sender) none))
                        (let ((new-shares (/ (* amount-x (get total-shares pool-data))
                                           (get reserve-x pool-data))))
                            (map-set liquidity-pools
                                { token-x: (contract-of token-x), token-y: (contract-of token-y) }
                                { reserve-x: (+ (get reserve-x pool-data) amount-x),
                                  reserve-y: (+ (get reserve-y pool-data) amount-y),
                                  total-shares: (+ (get total-shares pool-data) new-shares) })
                            (map-set user-pool-shares
                                { user: tx-sender, pool-id: { token-x: (contract-of token-x), token-y: (contract-of token-y) }}
                                (+ (get-user-pool-shares tx-sender (contract-of token-x) (contract-of token-y)) new-shares))
                            (ok new-shares)))
                    ERR_INVALID_AMOUNT)))))

;; Private Functions
(define-private (calculate-swap-output (input-amount uint) (input-reserve uint) (output-reserve uint))
    (let ((input-amount-with-fee (* input-amount (- u1000 (var-get protocol-fee-rate)))))
        (/ (* input-amount-with-fee output-reserve)
           (* u1000 (+ input-reserve input-amount)))))

;; Admin Functions
(define-public (set-protocol-fee (new-fee-rate uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (asserts! (<= new-fee-rate u100) ERR_INVALID_AMOUNT)
        (var-set protocol-fee-rate new-fee-rate)
        (ok true)))