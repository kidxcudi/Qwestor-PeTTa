!(import! &self ../../utils/utils)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; MetaMo Routing Guards for PeTTa-Qwestor
;; Refactored for deterministic list processing using decons.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; ============================================================
;; 1. CONSTANTS
;; =================================;; ============================================================

(= (ACTION_BLOCKED_SCORE) -1000000000.0)
(= (ACTION_ACTIVE_FLOOR) -100000000.0)

;; ============================================================
;; 2. CORE UTILITIES (LIST PROCESSING)
;; ============================================================

;; Recursive score lookup using decons for standard lists
(= (get-action-score () $act) (ACTION_BLOCKED_SCORE))
(= (get-action-score $scores $act)
   (let* ((($head $rest) (decons $scores))
          (($a $v) $head))
     (if (== $a $act) $v (get-action-score $rest $act))))

;; Recursive score update returning a new list
(= (set-action-score () $act $new) (($act $new)))
(= (set-action-score $scores $act $new)
   (let* ((($head $rest) (decons $scores))
          (($a $v) $head))
     (if (== $a $act)
         (cons ($act $new) $rest)
         (cons $head (set-action-score $rest $act $new)))))

;; Delta adjustment helper
(= (adjust-action-score $scores $act $delta)
   (let $current (get-action-score $scores $act)
     (if (== $current (ACTION_BLOCKED_SCORE))
         $scores
         (set-action-score $scores $act (+ $current $delta)))))

;; Context Accessor: Standard list lookup (key value)
(= (ctx-val () $key) 0.0)
(= (ctx-val $ctx $key)
   (let* ((($head $rest) (decons $ctx))
          (($k $v) $head))
     (if (== $k $key) $v (ctx-val $rest $key))))

;; ============================================================
;; 3. THE GUARD FUNCTIONS
;; ============================================================

 
;; GUARD: DECOMPOSE
;; Decision: Block if complexity is too low or ambiguity too high.
(= (guard-decompose $scores $ctx $space)
   (let* (($cx (ctx-val $ctx complexity))
          ($_ (println! ("c: "$cx)))
          ($amb (ctx-val $ctx ambiguity))
          ($_ (println! ("a: "$amb)))
          ($urgent (ctx-val $ctx urgent_flag))
          ($_ (println! ("u: "$urgent)))
          ($min (getAlpha $space decompose_min_complexity))
          ($_ (println! ("min: "$min)))
          ($u_min (getAlpha $space decompose_urgent_min_complexity))
          ($_ (println! ("u_min: "$u_min)))
          ($max_amb (getAlpha $space decompose_max_ambiguity))
          ($_ (println! ("max_amb: "$max_amb)))
          ($thr (if (== $urgent true) $u_min $min))
          ($_ (println! ("thr: "$thr)))
          ($s1 (if (or (< $cx $thr) (>= $amb $max_amb))
                   (set-action-score $scores act_decompose (ACTION_BLOCKED_SCORE))
                   $scores))
          ($_ (println! ("s1: "$s1)))
          ($_ (println! ("scores": $scores)))
          ($final_s1 (car-atom $s1))
          ($_ (println! ("final: "$final_s1)))

          ($curr (get-action-score $s1 act_decompose)))
      (if (== $curr (ACTION_BLOCKED_SCORE)) $s1
         (let* (($task (ctx-val $ctx needs_task_plan))
                ($_ (println! ("task: "$task)))
                ($refl (ctx-val $ctx reflective_intent))
                ($_ (println! ("refl: "$refl)))
                ($ext (ctx-val $ctx needs_external_evidence))
                ($_ (println! ("evidence: "$ext)))
                )
                
           (if (and (< $task 0.45) (not (and (and (>= $cx 0.78) (<= $amb 0.35)) (>= $refl 0.75))))
               (set-action-score $s1 act_decompose (ACTION_BLOCKED_SCORE))
               (let* (($s2 (if (and (>= $ext 0.75) (<= $task 0.55))
                               (adjust-action-score $s1 act_decompose -0.30) $s1))
                      ($s3 (if (>= $task 0.60)
                               (adjust-action-score $s2 act_decompose 0.10) $s2)))
                 (if (and (<= $task 0.18) (< $cx 0.55))
                     (adjust-action-score $s3 act_decompose -0.30)
                     $s3)
               )
           )
          )
     )
    )
)

;
;; GUARD: SEARCH & SYNTHESIZE LOCAL
;; Decision: Boost search if external evidence is needed.
(= (guard-search-synth $scores $ctx)
   (let* (($ext (ctx-val $ctx needs_external_evidence))
          ($_ (println! ("ext: "$ext)))

          ($task (ctx-val $ctx needs_task_plan))
          ($_ (println! ("task: "$task)))

          ($multi (ctx-val $ctx needs_multi_source_integration))
          ($_ (println! ("multi: "$multi)))

          ($verify (ctx-val $ctx verify_request))
          ($_ (println! ("verify: "$verify)))

          ;; Search adjustments
          ($s1 (if (>= $ext 0.60)
                   (let* (($b1 (adjust-action-score $scores act_search 0.30))
                          ($bonus (if (<= $task 0.45) 0.12 0.0)))
                     (adjust-action-score $b1 act_search $bonus))
                   (if (and (<= $ext 0.22) (== $verify 0))
                       (adjust-action-score $scores act_search -0.18)
                       $scores)))
          ;; Synthesize adjustments
          ($s2 (if (>= $multi 0.65)
                   (adjust-action-score $s1 act_synthesize 0.20)
                   (if (and (< $multi 0.65) (== $verify 0))
                       (set-action-score $s1 act_synthesize (ACTION_BLOCKED_SCORE))
                       $s1)))
          ($s3 (if (and (>= $task 0.70) (>= $task $multi))
                   (adjust-action-score $s2 act_synthesize -0.22)
                   $s2)))
     (if (and (>= $ext 0.85) (<= $task 0.45))
         (adjust-action-score $s3 act_synthesize -0.15)
         $s3)))

;; GUARD: SEARCH/DECOMPOSE ARBITRATION
;; Decision: Prefer search if evidence need is significantly higher than plan need.
(= (guard-search-arb $scores $ctx)
   (let* (($ext (ctx-val $ctx needs_external_evidence))
          ($_ (println! ("ext: "$ext)))

          ($task (ctx-val $ctx needs_task_plan))
          ($_ (println! ("task: "$task)))

          ($multi (ctx-val $ctx needs_multi_source_integration))
          ($_ (println! ("multi: "$multi)))

          ($s_v (get-action-score $scores act_search))
          ($_ (println! ("act_search: "$s_v)))

          ($d_v (get-action-score $scores act_decompose))
          ($_ (println! ("act_decompose: "$d_v)))

          ($z_v (get-action-score $scores act_synthesize))
          ($_ (println! ("act_synthesize: "$z_v)))

          
          )
 
     (if (and (> $s_v (ACTION_BLOCKED_SCORE)) (> $d_v (ACTION_BLOCKED_SCORE)))
         (if (and (>= $ext 0.70) (and (>= $ext (+ $task 0.15)) (>= $ext (- $multi 0.02))))
             (let* (($b1 (adjust-action-score $scores act_search 0.26))
                    ($b2 (adjust-action-score $b1 act_decompose -0.26))
                    ($z_bonus (if (> $z_v (ACTION_BLOCKED_SCORE)) -0.12 0.0)))
               (adjust-action-score $b2 act_synthesize $z_bonus))
             (if (and (>= $task 0.72) (and (>= $task (+ $ext 0.18)) (>= $task (+ $multi 0.12))))
                 (let* (($b1 (adjust-action-score $scores act_decompose 0.18))
                        ($b2 (adjust-action-score $b1 act_search -0.12))
                        ($z_bonus (if (> $z_v (ACTION_BLOCKED_SCORE)) -0.10 0.0)))
                   (adjust-action-score $b2 act_synthesize $z_bonus))
                 (if (and (> $z_v (ACTION_ACTIVE_FLOOR)) (and (>= $multi 0.72) (>= $multi (+ $task 0.15))))
                     (let* (($b1 (adjust-action-score $scores act_synthesize 0.16)))
                       (adjust-action-score $b1 act_decompose -0.16))
                     $scores)))
         $scores)))
;; GUARD: VERIFY
;; Decision: Block verify if ambiguity is too high or request is absent.
(= (guard-verify $scores $ctx $space)
   (let* (($amb (ctx-val $ctx ambiguity))
          ($_ (println! ("amb: "$amb)))

          ($thr (ctx-val $ctx threshold))
          ($_ (println! ("thr: "$thr)))

          ($low   (- 1.0 $thr))
          ($_ (println! ("low: "$low)))

          ($fw (ctx-val $ctx failure_wariness))

          ($_ (println! ("fw: "$fw)))

          ($verify (ctx-val $ctx verify_request))
          ($_ (println! ("verify: "$verify)))

          ($cx (ctx-val $ctx complexity))
          ($_ (println! ("cx: "$cx)))

          ($intent (ctx-val $ctx intent_type))
          ($_ (println! ("intent: "$intent)))

          ;; Core block
          ($s1 (if (>= $amb 0.85)
                   (set-action-score $scores act_verify (ACTION_BLOCKED_SCORE))
                   (if (not (or (== $verify 1) (or (and (>= $thr 0.55) (>= $low 0.40)) (>= $fw 0.45))))
                       (set-action-score $scores act_verify (ACTION_BLOCKED_SCORE))
                       $scores)))
          ($curr (get-action-score $s1 act_verify)))
     (if (== $curr (ACTION_BLOCKED_SCORE)) $s1
         (let* (($s2 (if (== $verify 1)
                         (let* (($b1 (adjust-action-score $s1 act_verify 0.45)))
                           (adjust-action-score $b1 act_synthesize -0.35))
                         $s1)))
           (if (and (and (== $verify 0) (>= $cx 0.70)) (and (<= $amb 0.65) (or (== $intent mixed) (== $intent reflective))))
               (adjust-action-score $s2 act_verify -0.20)
               $s2)))))

;; GUARD: FAST LANE
;; Decision: Bypass planning for simple, high-familiarity inputs.
(= (guard-fast-lane $scores $ctx $space)
   (let* (($cx (ctx-val $ctx complexity))
          ($_ (println! ("cx: "$cx)))
          ($amb (ctx-val $ctx ambiguity))
          ($_ (println! ("amb: "$amb)))
          ($th_s (ctx-val $ctx threshold_signal))
          ($_ (println! ("th_s: "$th_s)))
          ($fail_s (ctx-val $ctx failure_signal))
          ($_ (println! ("fail_s: "$fail_s)))
          ($fam_s (ctx-val $ctx familiarity_signal))
          ($_ (println! ("fam_s: "$fam_s)))
          
          ($thr (ctx-val $ctx threshold))
          ($_ (println! ("thr: "$thr)))
          ($low   (- 1.0 $thr))
          ($_ (println! ("low: "$low)))
          ($verify (ctx-val $ctx verify_request))
          ($_ (println! ("verify: "$verify)))
          ;; Ultra fast trigger
          ($s1 (if (and (and (<= $cx 0.30) (and (<= $amb 0.30) (<= $th_s 0.25))) (and (and (<= $fail_s 0.25) (>= $fam_s 0.70)) (and (<= $low 0.35) (== $verify 0))))
                   (let* (($b1 (set-action-score $scores act_verify (ACTION_BLOCKED_SCORE)))
                          ($b2 (set-action-score $b1 act_search (ACTION_BLOCKED_SCORE)))
                          ($b3 (set-action-score $b2 act_clarify (ACTION_BLOCKED_SCORE)))
                          ($b4 (set-action-score $b3 act_think (ACTION_BLOCKED_SCORE))))
                     (adjust-action-score $b4 act_respond 0.60))
                   $scores))
          ($_ (println! ("s1: "$s1)))
          ($help (ctx-val $ctx help_short) ) 
          ($_ (println! ("help: "$help))))
     (if (and (and (<= $cx 0.45) (and (<= $amb 0.35) (<= $th_s 0.20))) (and (and (<= $low 0.30) (>= $fam_s 0.80)) (and (>= $help 0.55) (== $verify 0))))
         (let* (($b1 (set-action-score $s1 act_clarify (ACTION_BLOCKED_SCORE)))
                ($_ (println! ("b1: "$b1)))
                ($b2 (set-action-score $b1 act_search (ACTION_BLOCKED_SCORE)))
                ($_ (println! ("b1: "$b1))))
           (adjust-action-score $b2 act_respond 0.40))
         $s1)))

;; ============================================================
;; 4. SELECTION ENGINE (TIE-BREAKING)
;; ============================================================

;; Standard symbol-based preferred action logic
;; FACTUAL OVERRIDE
(= (get-preferred factual $low_conf $threshold)
   act_search)

;; REFLECTIVE OVERRIDE
(= (get-preferred reflective $low_conf $threshold)
   act_think)

;; GENERIC FALLBACK (ONLY FOR OTHER INTENTS)
(= (get-preferred $intent $low_conf $threshold)
   (if (and (not (== $intent factual))
            (not (== $intent reflective)))
       (if (or (>= $low_conf 0.40)
               (>= $threshold 0.45))
           act_search
           act_think)
    )
)  

 
(= (get-best-score (($action $value))) ($action $value))
(= (get-best-score $scores)
   (let* ((($head $rest) (decons $scores))
          (($a1 $v1) $head)
          (($a2 $v2) (get-best-score $rest)))
     (if (> $v1 $v2) ($a1 $v1) ($a2 $v2))))

;; Select action with intent-based tie-breaking
(= (select-action $scores $ctx $margin)
   (let* (($s_v (get-action-score $scores act_search))
          ($t_v (get-action-score $scores act_think))
          ($intent (ctx-val $ctx intent_type))
          ($low (ctx-val $ctx low_confidence))
          ($th (ctx-val $ctx threshold))
          ;; Detect tie within margin
          ($is_tie (and (> $s_v (ACTION_BLOCKED_SCORE)) (and (> $t_v (ACTION_BLOCKED_SCORE)) (<= (abs-math (- $s_v $t_v)) $margin))))
          )
     (if $is_tie
         (let* (($pref (get-preferred $intent $low $th))
                ($max_v (if (> $s_v $t_v) $s_v $t_v))
                ($new_v (+ $max_v (+ $margin 0.0001)))
                ($final_scores (set-action-score $scores $pref $new_v)))
           (Result (get-best-score $final_scores) $final_scores))
         (Result (get-best-score $scores) $scores))))



;; ============================================================
;; 5. MAIN PIPELINE
;; ============================================================

(= (apply-routing-guards $initial_scores $ctx $space)
   (guard-fast-lane
     (guard-verify
       (guard-search-arb
         (guard-search-synth
           (guard-decompose $initial_scores $ctx $space)
           $ctx)
         $ctx)
       $ctx $space)
     $ctx $space)
)