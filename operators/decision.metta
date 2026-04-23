; ─────────────────────────────────────────────
;
; Goal vector accessors and weight computation.
;
; ─────────────────────────────────────────────


; ─────────────────────────────────────────────
; get-goal – read a single goal value by name.
;   match the canonical default-goals ordering.
; ─────────────────────────────────────────────
(= (get-goal $space $goal-name)
(let*
   (
    ($goal-vec  (match $space (state $turn $g $m $anti $alpha) $g))
    ($goal-list (cdr-atom $goal-vec))
    ($pair
    (case $goal-name
        (
        (efficiency           (index-atom $goal-list 0))
        (accuracy             (index-atom $goal-list 1))
        (success_moderate     (index-atom $goal-list 2))
        (knowledge            (index-atom $goal-list 3))
        (novelty              (index-atom $goal-list 4))
        (success_breakthrough (index-atom $goal-list 5))
        (coherence            (index-atom $goal-list 6))
        (originality          (index-atom $goal-list 7))
        (social               (index-atom $goal-list 8))
        (help_short           (index-atom $goal-list 9))
        (help_long            (index-atom $goal-list 10))
        (over_beneficial      (index-atom $goal-list 11))
        (over_safety          (index-atom $goal-list 12))
        (over_honesty         (index-atom $goal-list 13))
        )
   ))
   )
   (index-atom $pair 1)
))


; ─────────────────────────────────────────────
; getGoal – convenience alias matching the name
;           used inside goalWeight formulas.
; ─────────────────────────────────────────────
(= (getGoal $space $goal-name)
   (get-goal $space $goal-name)
)
(= (getGoals $space)
   (match $space (state $turn $g $m $anti $alpha) (cdr-atom $g))
)

; ─────────────────────────────────────────────
; updateGoal – replace one goal's value.
; ─────────────────────────────────────────────
(= (updateGoal $space $name $value)
    (let*
     (
        ($current-turn (match $space (state $turn $x $y $anti $alpha) $turn))
        ($current-modulator-vec (match $space (state $turn $x $y $anti $alpha) $y))
        ($current-goal (cdr-atom (match $space (state $turn $x $y $anti $alpha) $x)))
        ($current-anti-goal (match $space (state $turn $x $y $anti $alpha) $anti))
        ($current-alpha (match $space (state $turn $x $y $anti $alpha) $alpha))
        
        ($updated-goal  (case $name
        (
            (efficiency           (eval (replaceByIndex $current-goal 0  ($name $value))))
            (accuracy             (eval (replaceByIndex $current-goal 1  ($name $value))))
            (success_moderate     (eval (replaceByIndex $current-goal 2  ($name $value))))
            (knowledge            (eval (replaceByIndex $current-goal 3  ($name $value))))
            (novelty              (eval (replaceByIndex $current-goal 4  ($name $value))))
            (success_breakthrough (eval (replaceByIndex $current-goal 5  ($name $value))))
            (coherence            (eval (replaceByIndex $current-goal 6  ($name $value))))
            (originality          (eval (replaceByIndex $current-goal 7  ($name $value))))
            (social               (eval (replaceByIndex $current-goal 8  ($name $value))))
            (help_short           (eval (replaceByIndex $current-goal 9  ($name $value))))
            (help_long            (eval (replaceByIndex $current-goal 10 ($name $value))))
            (over_beneficial      (eval (replaceByIndex $current-goal 11 ($name $value))))
            (over_safety          (eval (replaceByIndex $current-goal 12 ($name $value))))
            (over_honesty         (eval (replaceByIndex $current-goal 13 ($name $value))))
        )))
        ($updated-state (state $current-turn (cons goal-vector $updateoal) $current-modulator-vec $current-anti-goal $current-alpha))
        ($_ (remove-state $space))
     )
     (add-atom $space $updated-state)
      )
)


; ─────────────────────────────────────────────
; updateGoals – replace the entire goal list.
; ─────────────────────────────────────────────
(= (updateGoals $space $goals)
      (let* (
         ($mods     (getMods $space))
         ($alpha  (match $space (state $turn $x $y $anti $alpha) $alpha))
         ($anti  (match $space (state $turn $x $y $anti $alpha) $anti))
         ($t   (match $space (state $turn $x $y $anti $alpha) $turn))
         ($_ (remove-state $space))
         ($updated  (state $t (cons goal-vector $goals) $mods $anti $alpha))
         ($_ (add-atom $space $updated))    ; ← $space was missing before
         )
         (println! (goals update success 🎉))
   )
)

; ─────────────────────────────────────────────
; goalWeight – compute weighted goal values
;             from current context and modulators.
; ─────────────────────────────────────────────
(= (goalWeight $space)
    (let*
      (
        ; ── context signals ──────────────────────────────
        ($complexity       (eval (getContext $space complexity)))
        ($failure_signal   (eval (getContext $space failure_signal)))
        ($_ (println! ("failure_signal ctx" $failure_signal)))
        ($urg_ctx          (eval (getContext $space urgent)))

        ; ── modulator values ─────────────────────────────
        ($urgency          (eval (getMod $space m_urgency)))
        ($_ (println! ("urgency ctx" $urgency)))
        ($resolution       (eval (getMod $space m_resolution)))
        ($threshold        (eval (getMod $space m_threshold)))
        ($securing         (eval (getMod $space m_securing)))
        ($valence          (eval (getMod $space m_valence)))

        ; ── derived signal ───────────────────────────────
        ($low_confidence   (- 1.0 $threshold))
        ; ── current goal values ──────────────────────────
        ($efficiency_goal        (getGoal $space efficiency))
        ($_ (println! ("efficiency goal" $efficiency_goal)))
        ($accuracy_goal          (getGoal $space accuracy))
        ($success_moderate_goal  (getGoal $space success_moderate))
        ($knowledge_goal         (getGoal $space knowledge))
        ($novelty_goal           (getGoal $space novelty))
        ($breakthrough_goal      (getGoal $space success_breakthrough))
        ($coherence_goal         (getGoal $space coherence))
        ($originality_goal       (getGoal $space originality))
        ($social_goal            (getGoal $space social))
        ($help_short_goal        (getGoal $space help_short))
        ($help_long_goal         (getGoal $space help_long))
        ($over_beneficial_goal   (getGoal $space over_beneficial)) 
        ($over_safety_goal       (getGoal $space over_safety))
        ($over_honesty_goal      (getGoal $space over_honesty))
        ; ── valence helper  (map [-1,1] → [0,1]) ─────────
        ($valence_norm     (eval (_clamp01 (* (+ $valence 1.0) 0.5))))

        ; ── weighted goal calculations ─────────────────────
        ($efficiency_base  (* $efficiency_goal (- 1.0 (* 0.30 $complexity))))
        ($efficiency       (* $efficiency_base (+ 0.70 (* 0.60 $urgency))))

        ($accuracy_base    (* $accuracy_goal (+ 1.0 (* 0.30 $complexity))))
        ($accuracy         (* $accuracy_base (+
                               (- 0.70 (* 0.40 $urgency))
                               (* 0.50 $resolution))))

        ($short_help       (* $help_short_goal (+
                               0.65
                               (+ (* 0.55 $urgency)
                                  (* 0.25 (- 1.0 $complexity))))))

        ($success_moderate (-
                               (+ 0.65
                                  (+ (* 0.35 $threshold)
                                     (+ (* 0.35 $securing)
                                        (+ (* 0.30 $low_confidence)
                                           (* 0.20 $complexity)))))
                               (* 0.20 $urgency)))

        ($knowledge_w      (* $knowledge_goal (-
                               (+ 0.55
                                  (+ (* 0.55 $complexity)
                                     (* 0.30 $resolution)))
                               (* 0.20 $urgency))))

        ($breakthrough_w   (* $breakthrough_goal (-
                               (+ 0.45
                                  (+ (* 0.45 $complexity)
                                     (+ (* 0.35 $low_confidence)
                                        (* 0.20 $threshold))))
                               (* 0.15 $urgency))))

        ($novelty_w        (* $novelty_goal (-
                               (+ 0.45
                                  (+ (* 0.45 $complexity)
                                     (+ (* 0.35 $resolution)
                                        (* 0.25 $low_confidence))))
                               (+ (* 0.20 $threshold)
                                  (* 0.15 $urgency)))))

        ($coherence_w      (* $coherence_goal (+
                               0.60
                               (+ (* 0.30 $resolution)
                                  (+ (* 0.25 (- 1.0 $low_confidence))
                                     (+ (* 0.20 $threshold)
                                        (+ (* 0.10 (- 1.0 $urgency))
                                           (* 0.08 $valence_norm))))))))

        ($originality_w    (* $originality_goal (-
                               (+ 0.45
                                  (+ (* 0.40 $complexity)
                                     (+ (* 0.30 $resolution)
                                        (* 0.20 $valence_norm))))
                               (+ (* 0.15 $urgency)
                                  (* 0.10 $threshold)))))

        ($social_w         (* $social_goal (+
                               0.55
                               (+ (* 0.35 (- 1.0 $low_confidence))
                                  (+ (* 0.20 $urgency)
                                     (* 0.10 $valence_norm))))))

        ($beneficial_w     (* $over_beneficial_goal (+
                               0.60
                               (+ (* 0.45 $threshold)
                                  (+ (* 0.40 $securing)
                                     (* 0.30 $low_confidence))))))

        ($help_long_w      (* $help_long_goal (+
                               0.55
                               (+ (* 0.65 $resolution)
                                  (* 0.30 $complexity)))))

        ($safety_w         (* $over_safety_goal (+
                               0.60
                               (+ (* 0.45 $complexity)
                                  (+ (* 0.55 $threshold)
                                     (* 0.50 $securing))))))
      
        ($honesty_w        (* $over_honesty_goal (+
                               0.60
                               (+ (* 0.60 $low_confidence)
                                  (* 0.30 $threshold)))))
        ; ── assemble ordered goal list ─────────────────────
        ($goalList (
            (efficiency          $efficiency)
            (accuracy            $accuracy)
            (success_moderate    $success_moderate)
            (knowledge           $knowledge_w)
            (novelty             $novelty_w)
            (success_breakthrough $breakthrough_w)
            (coherence           $coherence_w)
            (originality         $originality_w)
            (social              $social_w)
            (help_short          $short_help)
            (help_long           $help_long_w)
            (over_beneficial     $beneficial_w)
            (over_safety         $safety_w)
            (over_honesty        $honesty_w)
        ))
         ($_ (println! ("goal calculated 🎉" $goalList)))
      )
      $goalList
    )
)


(= (decision-action (action $a)) $a)
(= (decision-action $a) $a)


(= (goalTargets $space $decision)
    (let*
        (
            ; ── context signals ──────────────────────────────
            ($cx              (getContext $space complexity))
            ($urgent_bool     (getContext $space urgent))
            ($ambiguity       (getContext $space ambiguity))
            ($threshold       (getContext $space threshold))
            ($failure_signal  (getContext $space failure_signal))
            ($expertise       (getContext $space expertise))
            ($topic_fam       (getContext $space topic_familiarity))
            ($reflective_int  (getContext $space reflective_intent))

            ; ── decision action ─────────────────────────────
            ($action          (decision-action $decision))

            ; ── base targets ────────────────────────────────
            ($base_efficiency (+ 0.45
                                 (+ (if (== $urgent_bool True) 0.35 0.0)
                                    (* 0.20 (- 1.0 $cx)))))

            ($base_accuracy   (+ 0.45
                                 (+ (* 0.45 $cx)
                                    (+ (* 0.10 $ambiguity)
                                       (if (== $urgent_bool True) 0.0 0.05)))))

            ($base_success_moderate
                (+ 0.45
                   (+ (* 0.30 $cx)
                      (+ (* 0.25 $ambiguity)
                         (+ (* 0.25 $threshold)
                            (+ (* 0.20 $failure_signal)
                               (if (== $urgent_bool True) -0.08 0.0)))))))

            ($base_knowledge (+ 0.35
                                (+ (* 0.50 $cx)
                                   (+ (* 0.20 $ambiguity)
                                      (* 0.10 $expertise)))))

            ($base_novelty (+ 0.30
                              (+ (* 0.35 $cx)
                                 (+ (* 0.25 (- 1.0 $topic_fam))
                                    (+ (* 0.20 $reflective_int)
                                       (+ (* 0.10 $ambiguity)
                                          (if (== $urgent_bool True) -0.05 0.0)))))))

            ($base_success_breakthrough
                (+ 0.30
                   (+ (* 0.45 $cx)
                      (+ (* 0.25 $ambiguity)
                         (+ (* 0.20 $reflective_int)
                            (if (== $urgent_bool True) -0.08 0.0))))))

            ($base_coherence
                (+ 0.45
                   (+ (* 0.25 (- 1.0 $ambiguity))
                      (+ (* 0.25 (- 1.0 $failure_signal))
                         (+ (* 0.20 $threshold)
                            (if (== $urgent_bool True) 0.0 0.10))))))

            ($base_originality
                (+ 0.30
                   (+ (* 0.40 $cx)
                      (+ (* 0.25 $reflective_int)
                         (+ (* 0.20 (- 1.0 $topic_fam))
                            (+ (* 0.10 $ambiguity)
                               (if (== $urgent_bool True) -0.08 0.0)))))))

            ($base_social
                (+ 0.35
                   (+ (* 0.30 $ambiguity)
                      (+ (* 0.20 $failure_signal)
                         (+ (* 0.20 (- 1.0 $expertise))
                            (if (== $urgent_bool True) 0.10 0.0))))))

            ($base_help_short
                (+ 0.35
                   (+ (* 0.35 (- 1.0 $cx))
                      (+ (* 0.20 (- 1.0 $ambiguity))
                         (if (== $urgent_bool True) 0.10 0.0)))))

            ($base_help_long (+ 0.30
                                (+ (* 0.55 $cx)
                                   (* 0.15 (- 1.0 $ambiguity)))))

            ($base_over_beneficial
                (+ 0.45
                   (+ (* 0.35 $threshold)
                      (* 0.20 $failure_signal))))

            ($base_over_safety (+ 0.45
                                  (* 0.40 $threshold)))

            ($base_over_honesty
                (+ 0.45
                   (+ (* 0.35 $ambiguity)
                      (* 0.20 $failure_signal))))

            ; ── action-adjusted targets (case style) ────────
            ($targets
              (case $action (
                (act_search
                  (goal-vector
                    (efficiency           $base_efficiency)
                    (accuracy             (+ $base_accuracy 0.05))
                    (success_moderate     (+ $base_success_moderate 0.01))
                    (knowledge            (+ $base_knowledge 0.06))
                    (novelty              (+ $base_novelty 0.06))
                    (success_breakthrough (+ $base_success_breakthrough 0.04))
                    (coherence            (+ $base_coherence 0.01))
                    (originality          (+ $base_originality 0.03))
                    (social               (+ $base_social 0.01))
                    (help_short           (+ $base_help_short -0.02))
                    (help_long            $base_help_long)
                    (over_beneficial      $base_over_beneficial)
                    (over_safety          $base_over_safety)
                    (over_honesty         $base_over_honesty)
                  ))

                (act_verify
                  (goal-vector
                    (efficiency           $base_efficiency)
                    (accuracy             (+ $base_accuracy 0.06))
                    (success_moderate     (+ $base_success_moderate 0.06))
                    (knowledge            (+ $base_knowledge 0.03))
                    (novelty              (+ $base_novelty -0.04))
                    (success_breakthrough (+ $base_success_breakthrough 0.01))
                    (coherence            (+ $base_coherence 0.06))
                    (originality          (+ $base_originality -0.03))
                    (social               (+ $base_social 0.07))
                    (help_short           (+ $base_help_short -0.03))
                    (help_long            (+ $base_help_long 0.02))
                    (over_beneficial      (+ $base_over_beneficial 0.05))
                    (over_safety          (+ $base_over_safety 0.05))
                    (over_honesty         (+ $base_over_honesty 0.06))
                  ))

                (act_think
                  (goal-vector
                    (efficiency           $base_efficiency)
                    (accuracy             (+ $base_accuracy 0.04))
                    (success_moderate     (+ $base_success_moderate -0.02))
                    (knowledge            (+ $base_knowledge 0.05))
                    (novelty              (+ $base_novelty 0.08))
                    (success_breakthrough (+ $base_success_breakthrough 0.06))
                    (coherence            (+ $base_coherence 0.02))
                    (originality          (+ $base_originality 0.07))
                    (social               (+ $base_social 0.01))
                    (help_short           (+ $base_help_short -0.02))
                    (help_long            (+ $base_help_long 0.04))
                    (over_beneficial      (+ $base_over_beneficial 0.03))
                    (over_safety          $base_over_safety)
                    (over_honesty         (+ $base_over_honesty 0.04))
                  ))

                (act_respond
                  (goal-vector
                    (efficiency           (+ $base_efficiency 0.05))
                    (accuracy             $base_accuracy)
                    (success_moderate     (+ $base_success_moderate 0.02))
                    (knowledge            (+ $base_knowledge -0.04))
                    (novelty              (+ $base_novelty -0.04))
                    (success_breakthrough (+ $base_success_breakthrough -0.04))
                    (coherence            (+ $base_coherence 0.02))
                    (originality          (+ $base_originality -0.04))
                    (social               (+ $base_social 0.06))
                    (help_short           (+ $base_help_short 0.08))
                    (help_long            (+ $base_help_long -0.02))
                    (over_beneficial      $base_over_beneficial)
                    (over_safety          (+ $base_over_safety -0.02))
                    (over_honesty         $base_over_honesty)
                  ))

                (act_clarify
                  (goal-vector
                    (efficiency           $base_efficiency)
                    (accuracy             (+ $base_accuracy 0.03))
                    (success_moderate     (+ $base_success_moderate 0.03))
                    (knowledge            (+ $base_knowledge 0.01))
                    (novelty              (+ $base_novelty -0.01))
                    (success_breakthrough $base_success_breakthrough)
                    (coherence            (+ $base_coherence 0.05))
                    (originality          (+ $base_originality -0.02))
                    (social               (+ $base_social 0.08))
                    (help_short           (+ $base_help_short 0.03))
                    (help_long            $base_help_long)
                    (over_beneficial      (+ $base_over_beneficial 0.03))
                    (over_safety          $base_over_safety)
                    (over_honesty         (+ $base_over_honesty 0.04))
                  ))

                (act_decompose
                  (goal-vector
                    (efficiency           (+ $base_efficiency 0.01))
                    (accuracy             (+ $base_accuracy 0.04))
                    (success_moderate     (+ $base_success_moderate 0.04))
                    (knowledge            (+ $base_knowledge 0.07))
                    (novelty              (+ $base_novelty 0.05))
                    (success_breakthrough (+ $base_success_breakthrough 0.08))
                    (coherence            (+ $base_coherence 0.04))
                    (originality          (+ $base_originality 0.05))
                    (social               (+ $base_social 0.04))
                    (help_short           (+ $base_help_short -0.04))
                    (help_long            (+ $base_help_long 0.06))
                    (over_beneficial      (+ $base_over_beneficial 0.02))
                    (over_safety          $base_over_safety)
                    (over_honesty         $base_over_honesty)
                  ))

                (act_synthesize
                  (goal-vector
                    (efficiency           $base_efficiency)
                    (accuracy             (+ $base_accuracy 0.05))
                    (success_moderate     (+ $base_success_moderate 0.05))
                    (knowledge            (+ $base_knowledge 0.08))
                    (novelty              (+ $base_novelty 0.04))
                    (success_breakthrough (+ $base_success_breakthrough 0.05))
                    (coherence            (+ $base_coherence 0.05))
                    (originality          (+ $base_originality 0.08))
                    (social               (+ $base_social 0.05))
                    (help_short           (+ $base_help_short -0.03))
                    (help_long            (+ $base_help_long 0.07))
                    (over_beneficial      (+ $base_over_beneficial 0.03))
                    (over_safety          (+ $base_over_safety 0.03))
                    (over_honesty         (+ $base_over_honesty 0.04))
                  ))

                ($_
                  (goal-vector
                    (efficiency           $base_efficiency)
                    (accuracy             $base_accuracy)
                    (success_moderate     $base_success_moderate)
                    (knowledge            $base_knowledge)
                    (novelty              $base_novelty)
                    (success_breakthrough $base_success_breakthrough)
                    (coherence            $base_coherence)
                    (originality          $base_originality)
                    (social               $base_social)
                    (help_short           $base_help_short)
                    (help_long            $base_help_long)
                    (over_beneficial      $base_over_beneficial)
                    (over_safety          $base_over_safety)
                    (over_honesty         $base_over_honesty)
                  ))
              ))
            )
        )

        (let 
          (goal-vector
            (efficiency           $t_eff)
            (accuracy             $t_acc)
            (success_moderate     $t_smod)
            (knowledge            $t_kn)
            (novelty              $t_nov)
            (success_breakthrough $t_sbr)
            (coherence            $t_coh)
            (originality          $t_ori)
            (social               $t_soc)
            (help_short           $t_hs)
            (help_long            $t_hl)
            (over_beneficial      $t_ben)
            (over_safety          $t_safe)
            (over_honesty         $t_hon)
          )
          $targets
          (goal-vector
            (efficiency           (_clamp01 $t_eff))
            (accuracy             (_clamp01 $t_acc))
            (success_moderate     (_clamp01 $t_smod))
            (knowledge            (_clamp01 $t_kn))
            (novelty              (_clamp01 $t_nov))
            (success_breakthrough (_clamp01 $t_sbr))
            (coherence            (_clamp01 $t_coh))
            (originality          (_clamp01 $t_ori))
            (social               (_clamp01 $t_soc))
            (help_short           (_clamp01 $t_hs))
            (help_long            (_clamp01 $t_hl))
            (over_beneficial      (_clamp01 $t_ben))
            (over_safety          (_clamp01 $t_safe))
            (over_honesty         (_clamp01 $t_hon))
          )
        )
    )
)


; ─────────────────────────────────────────────
; antiGoalTargets – port of Python logic
; Returns an anti-goal-vector with clamped targets.
; ─────────────────────────────────────────────
(= (antiGoalTargets $space $goals)
    (let*
        (
            ($threshold      (getContext $space threshold))
            ($familiarity    (getContext $space topic_familiarity))
            ($failure_signal (getContext $space failure_signal))
            ($urgent_bool    (getContext $space urgent))
            ($urgency        (if (== $urgent_bool True) 1.0 0.0))
            ($complexity     (getContext $space complexity))
            ($ambiguity      (getContext $space ambiguity))
            ($expertise      (getContext $space expertise))

            ($help_short_now
              (let 
                (goal-vector
                  (efficiency           $g_eff)
                  (accuracy             $g_acc)
                  (success_moderate     $g_smod)
                  (knowledge            $g_kn)
                  (novelty              $g_nov)
                  (success_breakthrough $g_sbr)
                  (coherence            $g_coh)
                  (originality          $g_ori)
                  (social               $g_soc)
                  (help_short           $g_hs)
                  (help_long            $g_hl)
                  (over_beneficial      $g_ben)
                  (over_safety          $g_safe)
                  (over_honesty         $g_hon)
                )
                $goals
                $g_hs
              )
            )

            ($hallucinate_target
              (+ 0.15
                 (+ (* 0.55 $threshold)
                    (+ (* 0.25 (- 1.0 $familiarity))
                       (* 0.20 $failure_signal)))))

            ($redundant_target
              (+ 0.22
                 (+ (* 0.45 $help_short_now)
                    (+ (* 0.18 $expertise)
                       (+ (* 0.15 (- 1.0 $ambiguity))
                          (* 0.05 $urgency))))))

            ($premature_target
              (+ 0.20
                 (+ (* 0.45 $complexity)
                    (+ (* 0.30 $ambiguity)
                       (+ (* 0.20 $threshold)
                          (+ (* -0.20 $help_short_now)
                             (* 0.08 (- 1.0 $familiarity))))))))

            ($rabbit_hole_target
              (+ 0.18
                 (+ (* 0.40 $help_short_now)
                    (+ (* 0.25 $urgency)
                       (+ (* 0.20 (- 1.0 $complexity))
                          (+ (* 0.20 (- 1.0 $ambiguity))
                             (* 0.08 $expertise)))))))
        )
        (anti-goal-vector
          (hallucinate (_clamp01 $hallucinate_target))
          (redundant   (_clamp01 $redundant_target))
          (rabbit_hole (_clamp01 $rabbit_hole_target))
          (premature   (_clamp01 $premature_target))
        )
    )
)

; ── constants ───────────────────────────────────────────────
(= (ACTION-BLOCKED-SCORE) -1000000000.0)
(= (ACTION-ACTIVE-FLOOR) -100000000.0)


; ── math helpers ────────────────────────────────────────────
(= (abs $x)
    (if (< $x 0.0)
        (* $x -1.0)
        $x
    )
)


; ── tuple / dictionary helpers (2-element tuples) ───────────
(= (get-score (($k1 $v1) ($k2 $v2)) $key)
    (if (== $k1 $key)
        $v1
        (if (== $k2 $key)
            $v2
            (ACTION-BLOCKED-SCORE)
        )
    )
)

(= (update-score (($k1 $v1) ($k2 $v2)) $key $new-val)
    (if (== $k1 $key)
        (($k1 $new-val) ($k2 $v2))
        (if (== $k2 $key)
            (($k1 $v1) ($k2 $new-val))
            (($k1 $v1) ($k2 $v2))
        )
    )
)

(= (sort-scores (($k1 $v1) ($k2 $v2)))
    (if (>= $v1 $v2)
        (($k1 $v1) ($k2 $v2))
        (($k2 $v2) ($k1 $v1))
    )
)

(= (best-action (($k1 $v1) ($k2 $v2)))
    (if (>= $v1 $v2)
        $k1
        $k2
    )
)


; ── intent preference logic ─────────────────────────────────
(= (get-preferred $intent_type $low_conf $threshold)
    (if (== $intent_type factual)
        act_search
        (if (== $intent_type reflective)
            act_think
            (if (or (>= $low_conf 0.40)
                    (>= $threshold 0.45))
                act_search
                act_think
            )
        )
    )
)


; ── main action selection ───────────────────────────────────
(= (selectAction $scores $intent_type $low_conf $threshold $intent_margin)

    (let*
        (
            ; ── score extraction ───────────────────────────
            ($search_score   (get-score $scores act_search))
            ($think_score    (get-score $scores act_think))

            ; ── comparison metrics ─────────────────────────
            ($diff           (abs (- $search_score $think_score)))

            ($is_active
                (and (> $search_score (ACTION-ACTIVE-FLOOR))
                     (> $think_score  (ACTION-ACTIVE-FLOOR))))

            ($is_tie
                (and $is_active
                     (<= $diff $intent_margin)))
        )

        (if $is_tie

            ; ── tie-breaking using intent ──────────────────
            (let*
                (
                    ($preferred
                        (get-preferred $intent_type $low_conf $threshold))

                    ($new_score
                        (+ (+ (max $search_score $think_score)
                              $intent_margin)
                           0.0001))

                    ($updated_scores
                        (update-score $scores $preferred $new_score))
                )

                (
                    (best-action $updated_scores)
                    (sort-scores $updated_scores)
                )
            )

            ; ── normal selection ───────────────────────────
            (
                (best-action $scores)
                (sort-scores $scores)
            )
        )
    )
)
