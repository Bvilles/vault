;; Vault: Bitcoin-Inspired DeFi Protocol
;; A decentralized finance protocol focused on savings, swaps, and liquidity pools

;; Define SIP-010 Fungible Token Interface
(define-trait ft-trait
    (
        (transfer (uint principal principal (optional (buff 34))) (response bool uint))
        (get-balance (principal) (response uint uint))
        (get-total-supply () (response uint uint))
        (get-name () (response (string-ascii 32) uint))
        (get-symbol () (response (string-ascii 32) uint))
        (get-decimals () (response uint uint))
        (get-token-uri () (response (optional (string-utf8 256)) uint))
    )
)

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u1001))
(define-constant ERR_INSUFFICIENT_BALANCE (err u1002))
(define-constant ERR_INVALID_AMOUNT (err u1003))
(define-constant ERR_INVALID_PAIR (err u1004))
(define-constant MAX_UINT u340282366920938463463374607431768211455)

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

;; Private Functions
(define-private (calculate-swap-output (input-amount uint) (input-reserve uint) (output-reserve uint))
    (let ((input-amount-with-fee (* input-amount (- u1000 (var-get protocol-fee-rate)))))
        (/ (* input-amount-with-fee output-reserve)
           (* u1000 (+ input-reserve input-amount)))))

(define-private (check-and-update-balance (user principal) (amount uint) (add bool))
    (let ((current-balance (get-balance user)))
        (if add
            (if (> (+ current-balance amount) MAX_UINT)
                ERR_INVALID_AMOUNT
                (ok (+ current-balance amount)))
            (if (> amount current-balance)
                ERR_INSUFFICIENT_BALANCE
                (ok (- current-balance amount))))))

;; Public Functions
(define-public (deposit (amount uint))
    (begin
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (let ((new-balance (try! (check-and-update-balance tx-sender amount true))))
            (map-set balances tx-sender new-balance)
            (var-set total-supply (+ (var-get total-supply) amount))
            (ok true))))

(define-public (withdraw (amount uint))
    (begin
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)
        (let ((new-balance (try! (check-and-update-balance tx-sender amount false))))
            (try! (as-contract (stx-transfer? amount (as-contract tx-sender) tx-sender)))
            (map-set balances tx-sender new-balance)
            (var-set total-supply (- (var-get total-supply) amount))
            (ok true))))

(define-public (add-liquidity 
    (token-x <ft-trait>)
    (token-y <ft-trait>)
    (amount-x uint)
    (amount-y uint))
    (begin
        (asserts! (and (> amount-x u0) (> amount-y u0)) ERR_INVALID_AMOUNT)
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
                (let ((pool-data (unwrap! pool ERR_INVALID_PAIR)))
                    (asserts! (and
                        (>= (* amount-x (get reserve-y pool-data))
                            (* amount-y (get reserve-x pool-data)))
                        (<= (* amount-x (get reserve-y pool-data))
                            (* amount-y (get reserve-x pool-data))))
                        ERR_INVALID_AMOUNT)
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
                        (ok new-shares)))))))

;; Admin Functions
(define-public (set-protocol-fee (new-fee-rate uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (asserts! (<= new-fee-rate u100) ERR_INVALID_AMOUNT)
        (var-set protocol-fee-rate new-fee-rate)
        (ok true)))

(define-public (swap
    (token-in <ft-trait>)
    (token-out <ft-trait>)
    (amount-in uint))
    (begin
        (asserts! (> amount-in u0) ERR_INVALID_AMOUNT)
        (let (
            (pool (unwrap! (get-pool-info (contract-of token-in) (contract-of token-out)) ERR_INVALID_PAIR))
            (input-reserve (get reserve-x pool))
            (output-reserve (get reserve-y pool))
            (output-amount (calculate-swap-output amount-in input-reserve output-reserve)))
            
            ;; Verify non-zero output and sufficient reserves
            (asserts! (and (> output-amount u0) 
                         (<= output-amount output-reserve)) ERR_INVALID_AMOUNT)
            
            ;; Execute transfers
            (try! (contract-call? token-in transfer 
                amount-in tx-sender (as-contract tx-sender) none))
            (try! (as-contract (contract-call? token-out transfer 
                output-amount (as-contract tx-sender) tx-sender none)))
            
            ;; Update pool reserves
            (map-set liquidity-pools
                { token-x: (contract-of token-in), token-y: (contract-of token-out) }
                { reserve-x: (+ input-reserve amount-in),
                  reserve-y: (- output-reserve output-amount),
                  total-shares: (get total-shares pool) })
                
            (ok output-amount))))

;; Read-Only Function to get current exchange rate
(define-read-only (get-exchange-rate
    (token-x principal)
    (token-y principal)
    (amount uint))
    (let ((pool (get-pool-info token-x token-y)))
        (match pool
            pool-data (let (
                (reserve-x (get reserve-x pool-data))
                (reserve-y (get reserve-y pool-data)))
                (ok (/ (* amount reserve-y) (* reserve-x u1000))))
            ERR_INVALID_PAIR)))

;; Public function to remove liquidity from a pool
(define-public (remove-liquidity
    (token-x <ft-trait>)
    (token-y <ft-trait>)
    (shares-to-burn uint))
    (begin
        (asserts! (> shares-to-burn u0) ERR_INVALID_AMOUNT)
        (let (
            (pool (unwrap! (get-pool-info (contract-of token-x) (contract-of token-y)) ERR_INVALID_PAIR))
            (user-shares (get-user-pool-shares tx-sender (contract-of token-x) (contract-of token-y))))
            
            ;; Verify user has sufficient shares
            (asserts! (>= user-shares shares-to-burn) ERR_INSUFFICIENT_BALANCE)
            
            (let (
                (total-shares (get total-shares pool))
                (reserve-x (get reserve-x pool))
                (reserve-y (get reserve-y pool))
                (amount-x (/ (* shares-to-burn reserve-x) total-shares))
                (amount-y (/ (* shares-to-burn reserve-y) total-shares)))
                
                ;; Update user shares
                (map-set user-pool-shares
                    { user: tx-sender, pool-id: { token-x: (contract-of token-x), token-y: (contract-of token-y) }}
                    (- user-shares shares-to-burn))
                
                ;; Update pool data
                (map-set liquidity-pools
                    { token-x: (contract-of token-x), token-y: (contract-of token-y) }
                    { reserve-x: (- reserve-x amount-x),
                      reserve-y: (- reserve-y amount-y),
                      total-shares: (- total-shares shares-to-burn) })
                
                ;; Transfer tokens back to user
                (try! (as-contract (contract-call? token-x transfer 
                    amount-x (as-contract tx-sender) tx-sender none)))
                (try! (as-contract (contract-call? token-y transfer 
                    amount-y (as-contract tx-sender) tx-sender none)))
                
                (ok { amount-x: amount-x, amount-y: amount-y })))))