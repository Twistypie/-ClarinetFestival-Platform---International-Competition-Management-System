;; ClarinetFestival - International Competition Platform
;; A blockchain-based platform for clarinet festival management, competition tracking,
;; and artistic community celebration

;; Contract constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-unauthorized (err u103))
(define-constant err-invalid-input (err u104))

;; Token constants
(define-constant token-name "ClarinetFestival Allegro Token")
(define-constant token-symbol "CAT")
(define-constant token-decimals u6)
(define-constant token-max-supply u72000000000) ;; 72k tokens with 6 decimals

;; Reward amounts (in micro-tokens)
(define-constant reward-workshop u3500000) ;; 3.5 CAT
(define-constant reward-competition u8900000) ;; 8.9 CAT
(define-constant reward-championship u25000000) ;; 25.0 CAT

;; Data variables
(define-data-var total-supply uint u0)
(define-data-var next-competition-id uint u1)
(define-data-var next-workshop-id uint u1)

;; Token balances
(define-map token-balances principal uint)

;; Artist profiles
(define-map artist-profiles
  principal
  {
    festival-name: (string-ascii 19),
    competition-tier: (string-ascii 13), ;; "junior", "collegiate", "professional", "international"
    workshops-joined: uint,
    competitions-won: uint,
    total-festival: uint,
    artistic-merit: uint, ;; 1-5
    debut-date: uint
  }
)

;; Festival competitions
(define-map festival-competitions
  uint
  {
    competition-name: (string-ascii 13),
    musical-period: (string-ascii 10), ;; "renaissance", "baroque", "classical", "romantic", "modern"
    skill-category: (string-ascii 8), ;; "novice", "junior", "senior", "master"
    duration: uint, ;; minutes
    judging-tempo: uint, ;; BPM
    max-competitors: uint,
    organizer: principal,
    workshop-count: uint,
    festival-rating: uint ;; average festival
  }
)

;; Competition workshops
(define-map competition-workshops
  uint
  {
    competition-id: uint,
    competitor: principal,
    piece-performed: (string-ascii 10),
    workshop-time: uint, ;; minutes
    performance-tempo: uint, ;; BPM
    tone-production: uint, ;; 1-5
    stage-presence: uint, ;; 1-5
    artistic-expression: uint, ;; 1-5
    workshop-memo: (string-ascii 15),
    workshop-date: uint,
    competitive: bool
  }
)

;; Competition judgments
(define-map competition-judgments
  { competition-id: uint, judge: principal }
  {
    score: uint, ;; 1-10
    judgment-text: (string-ascii 15),
    performance-standard: (string-ascii 8), ;; "poor", "below", "average", "above", "excellent"
    judgment-date: uint,
    approval-votes: uint
  }
)

;; Festival championships
(define-map festival-championships
  { competitor: principal, championship: (string-ascii 15) }
  {
    victory-date: uint,
    workshop-total: uint
  }
)

;; Helper function to get or create profile
(define-private (get-or-create-profile (competitor principal))
  (match (map-get? artist-profiles competitor)
    profile profile
    {
      festival-name: "",
      competition-tier: "junior",
      workshops-joined: u0,
      competitions-won: u0,
      total-festival: u0,
      artistic-merit: u1,
      debut-date: stacks-block-height
    }
  )
)

;; Token functions
(define-read-only (get-name)
  (ok token-name)
)

(define-read-only (get-symbol)
  (ok token-symbol)
)

(define-read-only (get-decimals)
  (ok token-decimals)
)

(define-read-only (get-balance (user principal))
  (ok (default-to u0 (map-get? token-balances user)))
)

(define-private (mint-tokens (recipient principal) (amount uint))
  (let (
    (current-balance (default-to u0 (map-get? token-balances recipient)))
    (new-balance (+ current-balance amount))
    (new-total-supply (+ (var-get total-supply) amount))
  )
    (asserts! (<= new-total-supply token-max-supply) err-invalid-input)
    (map-set token-balances recipient new-balance)
    (var-set total-supply new-total-supply)
    (ok amount)
  )
)

;; Create festival competition
(define-public (create-competition (competition-name (string-ascii 13)) (musical-period (string-ascii 10)) (skill-category (string-ascii 8)) (duration uint) (judging-tempo uint) (max-competitors uint))
  (let (
    (competition-id (var-get next-competition-id))
    (profile (get-or-create-profile tx-sender))
  )
    (asserts! (> (len competition-name) u0) err-invalid-input)
    (asserts! (> duration u0) err-invalid-input)
    (asserts! (and (>= judging-tempo u55) (<= judging-tempo u175)) err-invalid-input)
    (asserts! (> max-competitors u0) err-invalid-input)
    
    (map-set festival-competitions competition-id {
      competition-name: competition-name,
      musical-period: musical-period,
      skill-category: skill-category,
      duration: duration,
      judging-tempo: judging-tempo,
      max-competitors: max-competitors,
      organizer: tx-sender,
      workshop-count: u0,
      festival-rating: u0
    })
    
    ;; Update profile
    (map-set artist-profiles tx-sender
      (merge profile {competitions-won: (+ (get competitions-won profile) u1)})
    )
    
    ;; Award competition creation tokens
    (try! (mint-tokens tx-sender reward-competition))
    
    (var-set next-competition-id (+ competition-id u1))
    (print {action: "competition-created", competition-id: competition-id, organizer: tx-sender})
    (ok competition-id)
  )
)

;; Log competition workshop
(define-public (log-workshop (competition-id uint) (piece-performed (string-ascii 10)) (workshop-time uint) (performance-tempo uint) (tone-production uint) (stage-presence uint) (artistic-expression uint) (workshop-memo (string-ascii 15)) (competitive bool))
  (let (
    (workshop-id (var-get next-workshop-id))
    (competition (unwrap! (map-get? festival-competitions competition-id) err-not-found))
    (profile (get-or-create-profile tx-sender))
  )
    (asserts! (> workshop-time u0) err-invalid-input)
    (asserts! (and (>= performance-tempo u40) (<= performance-tempo u195)) err-invalid-input)
    (asserts! (and (>= tone-production u1) (<= tone-production u5)) err-invalid-input)
    (asserts! (and (>= stage-presence u1) (<= stage-presence u5)) err-invalid-input)
    (asserts! (and (>= artistic-expression u1) (<= artistic-expression u5)) err-invalid-input)
    
    (map-set competition-workshops workshop-id {
      competition-id: competition-id,
      competitor: tx-sender,
      piece-performed: piece-performed,
      workshop-time: workshop-time,
      performance-tempo: performance-tempo,
      tone-production: tone-production,
      stage-presence: stage-presence,
      artistic-expression: artistic-expression,
      workshop-memo: workshop-memo,
      workshop-date: stacks-block-height,
      competitive: competitive
    })
    
    ;; Update competition stats if competitive
    (if competitive
      (let (
        (new-workshop-count (+ (get workshop-count competition) u1))
        (current-festival (* (get festival-rating competition) (get workshop-count competition)))
        (festival-value (/ (+ tone-production stage-presence artistic-expression) u3))
        (new-festival-rating (/ (+ current-festival festival-value) new-workshop-count))
      )
        (map-set festival-competitions competition-id
          (merge competition {
            workshop-count: new-workshop-count,
            festival-rating: new-festival-rating
          })
        )
        true
      )
      true
    )
    
    ;; Update profile
    (if competitive
      (begin
        (map-set artist-profiles tx-sender
          (merge profile {
            workshops-joined: (+ (get workshops-joined profile) u1),
            total-festival: (+ (get total-festival profile) (/ workshop-time u60)),
            artistic-merit: (+ (get artistic-merit profile) (/ tone-production u22))
          })
        )
        (try! (mint-tokens tx-sender reward-workshop))
        true
      )
      (begin
        (try! (mint-tokens tx-sender (/ reward-workshop u8)))
        true
      )
    )
    
    (var-set next-workshop-id (+ workshop-id u1))
    (print {action: "workshop-logged", workshop-id: workshop-id, competition-id: competition-id})
    (ok workshop-id)
  )
)

;; Write competition judgment
(define-public (write-judgment (competition-id uint) (score uint) (judgment-text (string-ascii 15)) (performance-standard (string-ascii 8)))
  (let (
    (competition (unwrap! (map-get? festival-competitions competition-id) err-not-found))
    (profile (get-or-create-profile tx-sender))
  )
    (asserts! (and (>= score u1) (<= score u10)) err-invalid-input)
    (asserts! (> (len judgment-text) u0) err-invalid-input)
    (asserts! (is-none (map-get? competition-judgments {competition-id: competition-id, judge: tx-sender})) err-already-exists)
    
    (map-set competition-judgments {competition-id: competition-id, judge: tx-sender} {
      score: score,
      judgment-text: judgment-text,
      performance-standard: performance-standard,
      judgment-date: stacks-block-height,
      approval-votes: u0
    })
    
    (print {action: "judgment-written", competition-id: competition-id, judge: tx-sender})
    (ok true)
  )
)

;; Vote approval for judgment
(define-public (vote-approval (competition-id uint) (judge principal))
  (let (
    (judgment (unwrap! (map-get? competition-judgments {competition-id: competition-id, judge: judge}) err-not-found))
  )
    (asserts! (not (is-eq tx-sender judge)) err-unauthorized)
    
    (map-set competition-judgments {competition-id: competition-id, judge: judge}
      (merge judgment {approval-votes: (+ (get approval-votes judgment) u1)})
    )
    
    (print {action: "judgment-approved", competition-id: competition-id, judge: judge})
    (ok true)
  )
)

;; Update competition tier
(define-public (update-competition-tier (new-competition-tier (string-ascii 13)))
  (let (
    (profile (get-or-create-profile tx-sender))
  )
    (asserts! (> (len new-competition-tier) u0) err-invalid-input)
    
    (map-set artist-profiles tx-sender (merge profile {competition-tier: new-competition-tier}))
    
    (print {action: "competition-tier-updated", competitor: tx-sender, tier: new-competition-tier})
    (ok true)
  )
)

;; Claim championship
(define-public (claim-championship (championship (string-ascii 15)))
  (let (
    (profile (get-or-create-profile tx-sender))
  )
    (asserts! (is-none (map-get? festival-championships {competitor: tx-sender, championship: championship})) err-already-exists)
    
    ;; Check championship requirements
    (let (
      (championship-won
        (if (is-eq championship "grand-champion") (>= (get workshops-joined profile) u70)
        (if (is-eq championship "festival-winner") (>= (get competitions-won profile) u6)
        false)))
    )
      (asserts! championship-won err-unauthorized)
      
      ;; Record championship
      (map-set festival-championships {competitor: tx-sender, championship: championship} {
        victory-date: stacks-block-height,
        workshop-total: (get workshops-joined profile)
      })
      
      ;; Award championship tokens
      (try! (mint-tokens tx-sender reward-championship))
      
      (print {action: "championship-claimed", competitor: tx-sender, championship: championship})
      (ok true)
    )
  )
)

;; Update festival name
(define-public (update-festival-name (new-festival-name (string-ascii 19)))
  (let (
    (profile (get-or-create-profile tx-sender))
  )
    (asserts! (> (len new-festival-name) u0) err-invalid-input)
    (map-set artist-profiles tx-sender (merge profile {festival-name: new-festival-name}))
    (print {action: "festival-name-updated", competitor: tx-sender})
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-artist-profile (competitor principal))
  (map-get? artist-profiles competitor)
)

(define-read-only (get-festival-competition (competition-id uint))
  (map-get? festival-competitions competition-id)
)

(define-read-only (get-competition-workshop (workshop-id uint))
  (map-get? competition-workshops workshop-id)
)

(define-read-only (get-competition-judgment (competition-id uint) (judge principal))
  (map-get? competition-judgments {competition-id: competition-id, judge: judge})
)

(define-read-only (get-championship (competitor principal) (championship (string-ascii 15)))
  (map-get? festival-championships {competitor: competitor, championship: championship})
)