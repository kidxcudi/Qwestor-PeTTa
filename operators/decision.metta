
; ─────────────────────────────────────────────
; Helper: read one value from a goal-vector tuple
; ─────────────────────────────────────────────
(= (goalTarget-get $gvec $name)
   (case $name
     ( 
      (efficiency (cdr-atom (index-atom (cdr-atom $gvec) 0)))
      (accuracy   (cdr-atom (index-atom (cdr-atom $gvec) 1)))
      (success_moderate   (cdr-atom (index-atom (cdr-atom $gvec) 2)))
      (knowledge   (cdr-atom (index-atom (cdr-atom $gvec) 3)))
      (novelty   (cdr-atom (index-atom (cdr-atom $gvec) 4)))
      (success_breakthrough   (cdr-atom (index-atom (cdr-atom $gvec) 5)))
      (coherence   (cdr-atom (index-atom (cdr-atom $gvec) 6)))
      (originality   (cdr-atom (index-atom (cdr-atom $gvec) 7)))
      (social   (cdr-atom (index-atom (cdr-atom $gvec) 8)))
      (help_short   (cdr-atom (index-atom (cdr-atom $gvec) 9)))
      (help_long   (cdr-atom (index-atom (cdr-atom $gvec) 10)))
      (over_beneficial   (cdr-atom (index-atom (cdr-atom $gvec) 11)))
      (over_safety   (cdr-atom (index-atom (cdr-atom $gvec) 12)))
      (over_honesty   (cdr-atom (index-atom (cdr-atom $gvec) 13)))
     )
   )
)
; ─────────────────────────────────────────────
; Helper: read from anti-goal-vector
; ─────────────────────────────────────────────
(= (antiGoal-get $ag $name)
   (case $name
     (
       (hallucinate (cdr-atom (index-atom (cdr-atom $ag) 0)))
       (redundant   (cdr-atom (index-atom (cdr-atom $ag) 1)))
       (rabbit_hole (cdr-atom (index-atom (cdr-atom $ag) 2)))
       (premature   (cdr-atom (index-atom (cdr-atom $ag) 3)))
     )
   )
)

(= (antiGoalTarget-get $agvec $name)
   (antiGoal-get $agvec $name))

; ─────────────────────────────────────────────
; updateGoals – replace the entire goal list.
; ─────────────────────────────────────────────
(= (updateGoals $space $goals)
      (let* (
         ($mods     (getMods $space))
         ($_ (println! ("mods" $mods)))

         ($alpha  (match $space (state $turn $x $y $anti $alpha) $alpha))
         ($_ (println! ("alpha" $alpha)))

         ($anti  (match $space (state $turn $x $y $anti $alpha) $anti))
         ($_ (println! ("anti" $anti)))

         ($t   (match $space (state $turn $x $y $anti $alpha) $turn))
         ($_ (println! ("t" $t)))

         ($_ (remove-state-app $space))
         ($updated  (state $t (cons goal-vector $goals) $mods $anti $alpha))
         ($_ (println! ("updated" $updated)))

         ($_ (add-atom $space $updated))   
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
        ($complexity       (getContext $space complexity))
        ($_ (println! ("complex" $complexity)))
        ($failure_signal   (getContext $space failure_signal))
        ($_ (println! ("failure_signal ctx" $failure_signal)))
        ($urg_ctx          (getContext $space urgent))

        ; ── modulator values ─────────────────────────────
        ($urgency          (getMod $space m_urgency))
        ($_ (println! ("urgency ctx" $urgency)))
        ($resolution       (getMod $space m_resolution))
        ($threshold        (getMod $space m_threshold))
        ($securing         (getMod $space m_securing))
        ($valence          (getMod $space m_valence))
        ($_ (println! ("modulator values" $resolution $threshold $securing $valence)))

        ; ── derived signal ───────────────────────────────
        ($low_confidence   (- 1.0 $threshold))
        ($_ (println! ("low conf" $low_confidence)))
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
        ($_ (println! ("current values" $efficiency_goal $accuracy_goal $success_moderate_goal $knowledge_goal $novelty_goal $breakthrough_goal $coherence_goal $originality_goal $social_goal $help_short_goal $help_long_goal $over_beneficial_goal $over_safety_goal $over_honesty_goal)))
 

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

(= (goalTargets $space $decision)
    (let*
        (
            ; ── context signals ──────────────────────────────
            ($cx              (getContext $space complexity))
            ($_ (println! ("cx: "$cx)))
            ($urgent_bool     (getContext $space urgent))
            ($_ (println! ("urgent: "$urgent_bool)))

            ($ambiguity       (getContext $space ambiguity))
            ($_ (println! ("amb: "$ambiguity)))

            ($threshold       (getContext $space threshold))
            ($_ (println! ("thre: "$threshold)))

            ($failure_signal  (getContext $space failure_signal))
            ($_ (println! ("fails: "$failure_signal)))

            ($expertise       (getContext $space expertise))
            ($_ (println! ("exper: "$expertise)))

            ($topic_fam       (getContext $space topic_familiarity))
            ($_ (println! ("topicfam: "$topic_fam)))

            ($reflective_int  (getContext $space reflective_intent))
            ($_ (println! ("ref: "$reflective_int)))


            ($_ (println! ("action: "$decision)))


            ; ── base targets ────────────────────────────────
            ($base_efficiency (+ 0.45
                                 (+ (if (== $urgent_bool True) 0.35 0.0)
                                    (* 0.20 (- 1.0 $cx)))))
            ($_ (println! ("base_Eff: "$base_efficiency)))

            ($base_accuracy   (+ 0.45
                                 (+ (* 0.45 $cx)
                                    (+ (* 0.10 $ambiguity)
                                       (if (== $urgent_bool True) 0.0 0.05)))))
            ($_ (println! ("base_acc: "$base_accuracy)))

            ($base_success_moderate
                (+ 0.45
                   (+ (* 0.30 $cx)
                      (+ (* 0.25 $ambiguity)
                         (+ (* 0.25 $threshold)
                            (+ (* 0.20 $failure_signal)
                               (if (== $urgent_bool True) -0.08 0.0)))))))
            ($_ (println! ("base_success: "$base_success_moderate)))


            ($base_knowledge (+ 0.35
                                (+ (* 0.50 $cx)
                                   (+ (* 0.20 $ambiguity)
                                      (* 0.10 $expertise)))))
            ($_ (println! ("base_knowledge: "$base_knowledge)))
            ($base_novelty (+ 0.30
                              (+ (* 0.35 $cx)
                                 (+ (* 0.25 (- 1.0 $topic_fam))
                                    (+ (* 0.20 $reflective_int)
                                       (+ (* 0.10 $ambiguity)
                                          (if (== $urgent_bool True) -0.05 0.0)))))))
            ($_ (println! ("base_novelty: "$base_novelty)))
            ($base_success_breakthrough
                (+ 0.30
                   (+ (* 0.45 $cx)
                      (+ (* 0.25 $ambiguity)
                         (+ (* 0.20 $reflective_int)
                            (if (== $urgent_bool True) -0.08 0.0))))))
            ($_ (println! ("base_break: "$base_success_breakthrough)))
            ($base_coherence
                (+ 0.45
                   (+ (* 0.25 (- 1.0 $ambiguity))
                      (+ (* 0.25 (- 1.0 $failure_signal))
                         (+ (* 0.20 $threshold)
                            (if (== $urgent_bool True) 0.0 0.10))))))
            ($_ (println! ("base_coherence: "$base_coherence)))
            ($base_originality
                (+ 0.30
                   (+ (* 0.40 $cx)
                      (+ (* 0.25 $reflective_int)
                         (+ (* 0.20 (- 1.0 $topic_fam))
                            (+ (* 0.10 $ambiguity)
                               (if (== $urgent_bool True) -0.08 0.0)))))))
            ($_ (println! ("base_orig: "$base_originality)))
            ($base_social
                (+ 0.35
                   (+ (* 0.30 $ambiguity)
                      (+ (* 0.20 $failure_signal)
                         (+ (* 0.20 (- 1.0 $expertise))
                            (if (== $urgent_bool True) 0.10 0.0))))))
            ($_ (println! ("base_social: "$base_social)))
            ($base_help_short
                (+ 0.35
                   (+ (* 0.35 (- 1.0 $cx))
                      (+ (* 0.20 (- 1.0 $ambiguity))
                         (if (== $urgent_bool True) 0.10 0.0)))))
            ($_ (println! ("base_help_short: "$base_help_short)))

            ($base_help_long (+ 0.30
                                (+ (* 0.55 $cx)
                                   (* 0.15 (- 1.0 $ambiguity)))))
            ($_ (println! ("base_help_long: "$base_help_long)))

            ($base_over_beneficial
                (+ 0.45
                   (+ (* 0.35 $threshold)
                      (* 0.20 $failure_signal))))
            ($_ (println! ("base_beneficial: "$base_over_beneficial)))
            ($base_over_safety (+ 0.45
                                  (* 0.40 $threshold)))
            ($_ (println! ("base_safety: "$base_over_safety)))
            ($base_over_honesty
                (+ 0.45
                   (+ (* 0.35 $ambiguity)
                      (* 0.20 $failure_signal))))
            ($_ (println! ("base_honesty: "$base_over_honesty)))
            ; ── action-adjusted targets (case style) ────────
            
            ($targets
              (case $decision (
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

; tested- works 
; ─────────────────────────────────────────────
; antiGoalTargets – port of Python logic
; Returns an anti-goal-vector with clamped targets.
; ─────────────────────────────────────────────
(= (antiGoalTargets $space $goals)
    (let*
        (
            ($threshold      (getContext $space threshold))
            ($_ (println! ("threshold: " $threshold)))
            ($familiarity    (getContext $space topic_familiarity))
            ($_ (println! ("familiarity: " $familiarity)))
            ($failure_signal (getContext $space failure_signal))
            ($_ (println! ("failure_signal: " $failure_signal)))
            ($urgent_bool    (getContext $space urgent))
            ($_ (println! ("urgent_bool: " $urgent_bool)))
            ($urgency        (if (== $urgent_bool True) 1.0 0.0))
            ($_ (println! ("urgency: " $urgency)))
            ($complexity     (getContext $space complexity))
            ($_ (println! ("complexity: " $complexity)))
            ($ambiguity      (getContext $space ambiguity))
            ($_ (println! ("ambiguity: " $ambiguity)))
            ($expertise      (getContext $space expertise))
            ($_ (println! ("expertise: " $expertise)))
            ($help_short_now (car-atom (goalTarget-get $goals help_short)))
            ($_ (println! ("help-short: " $help_short_now)))

            ($hallucinate_target
              (+ 0.15
                 (+ (* 0.55 $threshold)
                    (+ (* 0.25 (- 1.0 $familiarity))
                       (* 0.20 $failure_signal)))))

            ($_ (println! ("hallucinate target: " $hallucinate_target)))


            ($redundant_target
              (+ 0.22
                 (+ (* 0.45 $help_short_now)
                    (+ (* 0.18 $expertise)
                       (+ (* 0.15 (- 1.0 $ambiguity))
                          (* 0.05 $urgency))))))
            ($_ (println! ("redundant target: " $redundant_target)))
            ($premature_target
              (+ 0.20
                 (+ (* 0.45 $complexity)
                    (+ (* 0.30 $ambiguity)
                       (+ (* 0.20 $threshold)
                          (+ (* -0.20 $help_short_now)
                             (* 0.08 (- 1.0 $familiarity))))))))
            ($_ (println! ("premature target: " $premature_target)))
            ($rabbit_hole_target
              (+ 0.18
                 (+ (* 0.40 $help_short_now)
                    (+ (* 0.25 $urgency)
                       (+ (* 0.20 (- 1.0 $complexity))
                          (+ (* 0.20 (- 1.0 $ambiguity))
                             (* 0.08 $expertise)))))))
            ($_ (println! ("rabbit hole target: " $rabbit_hole_target)))
        )
        (anti-goal-vector
          (hallucinate (_clamp01 $hallucinate_target))
          (redundant   (_clamp01 $redundant_target))
          (rabbit_hole (_clamp01 $rabbit_hole_target))
          (premature   (_clamp01 $premature_target))
        )
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
(= (get_score $score $key)
   (case $key
      (
          (act_respond (car-atom (cdr-atom (index-atom $score 0))))
          (act_search  (car-atom (cdr-atom (index-atom $score 1))))
          (act_verify  (car-atom (cdr-atom (index-atom $score 2))))
          (act_clarify  (car-atom (cdr-atom (index-atom $score 3))))
          (act_decompose  (car-atom (cdr-atom (index-atom $score 4))))
          (act_think  (car-atom (cdr-atom (index-atom $score 5))))
          (act_synthesize  (car-atom (cdr-atom (index-atom $score 6))))

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

(= (update_score $scores $key $new_val)
   (case $key
      (
         (act_respond
            (
               (act_respond $new_val)
               (act_search (get_score $scores act_search))
               (act_verify (get_score $scores act_verify))
               (act_clarify (get_score $scores act_clarify))
               (act_decompose (get_score $scores act_decompose))
               (act_think (get_score $scores act_think))
               (act_synthesize (get_score $scores act_synthesize))
            )
         )

         (act_search
            (
               (act_respond (get_score $scores act_respond))
               (act_search $new_val)
               (act_verify (get_score $scores act_verify))
               (act_clarify (get_score $scores act_clarify))
               (act_decompose (get_score $scores act_decompose))
               (act_think (get_score $scores act_think))
               (act_synthesize (get_score $scores act_synthesize))
            )
         )

         (act_verify
            (
               (act_respond (get_score $scores act_respond))
               (act_search (get_score $scores act_search))
               (act_verify $new_val)
               (act_clarify (get_score $scores act_clarify))
               (act_decompose (get_score $scores act_decompose))
               (act_think (get_score $scores act_think))
               (act_synthesize (get_score $scores act_synthesize))
            )
         )

         (act_clarify
            (
               (act_respond (get_score $scores act_respond))
               (act_search (get_score $scores act_search))
               (act_verify (get_score $scores act_verify))
               (act_clarify $new_val)
               (act_decompose (get_score $scores act_decompose))
               (act_think (get_score $scores act_think))
               (act_synthesize (get_score $scores act_synthesize))
            )
         )

         (act_decompose
            (
               (act_respond (get_score $scores act_respond))
               (act_search (get_score $scores act_search))
               (act_verify (get_score $scores act_verify))
               (act_clarify (get_score $scores act_clarify))
               (act_decompose $new_val)
               (act_think (get_score $scores act_think))
               (act_synthesize (get_score $scores act_synthesize))
            )
         )

         (act_think
            (
               (act_respond (get_score $scores act_respond))
               (act_search (get_score $scores act_search))
               (act_verify (get_score $scores act_verify))
               (act_clarify (get_score $scores act_clarify))
               (act_decompose (get_score $scores act_decompose))
               (act_think $new_val)
               (act_synthesize (get_score $scores act_synthesize))
            )
         )

         (act_synthesize
            (
               (act_respond (get_score $scores act_respond))
               (act_search (get_score $scores act_search))
               (act_verify (get_score $scores act_verify))
               (act_clarify (get_score $scores act_clarify))
               (act_decompose (get_score $scores act_decompose))
               (act_think (get_score $scores act_think))
               (act_synthesize $new_val)
            )
         )
      )
   )
)

(= (sort-scores (($k1 $v1) ($k2 $v2)))
    (if (>= $v1 $v2)
        (($k1 $v1) ($k2 $v2))
        (($k2 $v2) ($k1 $v1))
    )
)
(= (sort_scores $scores)

   (let*
      (
         ($respond    (get_score $scores act_respond))
         ($_ (println! ("respond : " $respond)))

         ($search     (get_score $scores act_search))
         ($_ (println! ("search : " $search)))

         ($verify     (get_score $scores act_verify))
         ($_ (println! ("verify : " $verify)))

         ($clarify    (get_score $scores act_clarify))
         ($_ (println! ("clarify : " $clarify)))

         ($decompose  (get_score $scores act_decompose))
         ($_ (println! ("decompose : " $decompose)))

         ($think      (get_score $scores act_think))
         ($_ (println! ("think : " $think)))

         ($synthesize (get_score $scores act_synthesize))
         
         ($_ (println! ("synthesize : " $synthesize)))

         ($list (($respond act_respond) ($search act_search) ($verify act_verify) ($clarify act_clarify) ($decompose act_decompose) ($think act_think) ($synthesize act_synthesize)))

         ($_ (println! ("list : " $list)))

         ($list_sorted (sort $list))
         ($_ (println! ("list_sorted : " $list_sorted)))
      )
      $list_sorted
   )
)

(= (best-action (($k1 $v1) ($k2 $v2)))
    (if (>= $v1 $v2)
        $k1
        $k2
    )
)

 
(= (best_action $scores)

   (let*
      (
         ($respond    (get_score $scores act_respond))
         ($search     (get_score $scores act_search))
         ($verify     (get_score $scores act_verify))
         ($clarify    (get_score $scores act_clarify))
         ($decompose  (get_score $scores act_decompose))
         ($think      (get_score $scores act_think))
         ($synthesize (get_score $scores act_synthesize))

         ($result
            (
               ($respond act_respond)
               ($search act_search)
               ($verify act_verify)
               ($clarify act_clarify)
               ($decompose act_decompose)
               ($think act_think)
               ($synthesize act_synthesize)
            )
         )

         ($_ (println! ("result: " $result)))

         ($sorted_res (sort $result))
         ($_ (println! ("sorted_res: " $sorted_res)))

         ($best_pair (index-atom $sorted_res 6))
         ($_ (println! ("best_pair: " $best_pair)))

         ($best_action (index-atom $best_pair 1))
         ($_ (println! ("best_action: " $best_action)))
      )

      $best_action
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

; tested-works
; ── main action selection ───────────────────────────────────
(= (selectAction $scores $intent_type $low_conf $threshold $intent_margin)

    (let*
        (
            ($search_score   (get_score $scores act_search))
            ($_ (println! ("search score: "$search_score)))

            ($think_score    (get_score $scores act_think))
            ($_ (println! ("think score: "$think_score)))

            ($diff           (abs-math (- $search_score $think_score)))
            ($_ (println! ("diff: "$diff)))

            ($is_active
                (and (> $search_score (ACTION-ACTIVE-FLOOR))
                     (> $think_score  (ACTION-ACTIVE-FLOOR))))
            ($_ (println! ("is active: "$is_active)))

            ($is_tie
                (and $is_active
                     (<= $diff $intent_margin)))
            ($_ (println! ("is tie: "$is_tie)))
        )

        (if $is_tie

            ; ── tie-breaking using intent ──────────────────
            (let*
                (
                    ($preferred
                        (get-preferred $intent_type $low_conf $threshold))
                     ($_ (println! ("preferred: "$preferred)))

                    ($new_score
                        (+ (+ (max $search_score $think_score)
                              $intent_margin)
                           0.0001))
                    ($_ (println! ("new_score: "$new_score)))

                    ($updated_scores
                        (update_score $scores $preferred $new_score))
                    ($_ (println! ("updated scores: "$updated_scores)))

                    ($best_act  (best_action $updated_scores))
 
                 )

                (   
                    (best_action $updated_scores)
                    (sort_scores $updated_scores)
 
                )
            )

            (
               (best_action $scores)
               (score_action $scores)      
            )
        )
    )
)
; ─────────────────────────────────────────────
; updateAntiGoals — replace the anti-goal block
; ─────────────────────────────────────────────

(= (updateAntiGoals $space $hall $red $rh $prem)
   (let*
     (
       ($t     (match $space (state (turn $turn) $g $m $anti $alpha) $turn))
       ($g     (match $space (state (turn $turn) $g $m $anti $alpha) $g))
       ($m     (match $space (state (turn $turn) $g $m $anti $alpha) $m))
       ($alpha (match $space (state (turn $turn) $g $m $anti $alpha) $alpha))
       ($_ (remove-state-app $space))
       ($new-anti (anti-goals
                    (hallucinate $hall)
                    (redundant   $red)
                    (rabbit_hole $rh)
                    (premature   $prem)))
       
      
      ($_ (add-atom $space (state (turn $t) $g $m $new-anti $alpha)))
     )
     (println! (anti-goals updated 🎉))
   )
)

; ─────────────────────────────────────────────
; increment-turn — bump the turn counter
; ─────────────────────────────────────────────
(= (increment-turn $space)
   (let*
     (
       ($old-turn (match $space (state (turn $n) $g $m $anti $alpha) $n))
       ($g        (match $space (state (turn $n) $g $m $anti $alpha) $g))
       ($m        (match $space (state (turn $n) $g $m $anti $alpha) $m))
       ($anti     (match $space (state (turn $n) $g $m $anti $alpha) $anti))
       ($alpha    (match $space (state (turn $n) $g $m $anti $alpha) $alpha))
       ($new-n    (+ $old-turn 1))
       ($_ (remove-state-app $space))
       ($_ (add-atom $space (state (turn $new-n) $g $m $anti $alpha)))
     )
     $new-n
   )
)

; ─────────────────────────────────────────────
; post-update
; Called after each turn to blend goals and
; anti-goals toward their targets, apply
; homeostasis, and increment turn_count.
; ─────────────────────────────────────────────

(= (post-update $space $decision)
   (let*
     (
       ($goals     (getGoals $space))
       ($_ (println! ("goals: "$goals)))
       ($anti      (getAntiGoals $space))
       ($_ (println! ("anti-goals: "$anti)))
       ($alpha     (getAlpha $space goal_alpha))
       ($_ (println! ("alpha: "$alpha)))
       ($anti-alpha (getAlpha $space anti_goal_alpha))
       ($_ (println! ("anti-alpha: "$anti-alpha)))

       ($targets   (goalTargets $space $decision))
       ($_ (println! ("targets: "$targets)))

 

       ($t-eff     (car-atom(goalTarget-get $targets efficiency)))
       ($t-acc     (car-atom (goalTarget-get $targets accuracy)))
       ($_ (println! ("t-eff: "$t-eff)))
       ($_ (println! ("t-acc: "$t-acc)))

       ($new-efficiency
         (_blend (getGoal $space efficiency)
                 (car-atom (goalTarget-get $targets efficiency)) $alpha))
       ($new-accuracy
         (_blend (getGoal $space accuracy)
                 (car-atom (goalTarget-get $targets accuracy)) $alpha))
       ($new-success-moderate
         (_blend (getGoal $space success_moderate)
                 (car-atom (goalTarget-get $targets success_moderate)) $alpha))
       ($new-knowledge
         (_blend (getGoal $space knowledge)
                 (car-atom (goalTarget-get $targets knowledge)) $alpha))
       ($new-novelty
         (_blend (getGoal $space novelty)
                 (car-atom (goalTarget-get $targets novelty)) $alpha))
       ($new-success-breakthrough
         (_blend (getGoal $space success_breakthrough)
                 (car-atom (goalTarget-get $targets success_breakthrough)) $alpha))
       ($new-coherence
         (_blend (getGoal $space coherence)
                 (car-atom (goalTarget-get $targets coherence)) $alpha))
       ($new-originality
         (_blend (getGoal $space originality)
                 (car-atom (goalTarget-get $targets originality)) $alpha))
       ($new-social
         (_blend (getGoal $space social)
                 (car-atom (goalTarget-get $targets social)) $alpha))
       ($new-help-short
         (_blend (getGoal $space help_short)
                 (car-atom (goalTarget-get $targets help_short)) $alpha))
       ($new-help-long
         (_blend (getGoal $space help_long)
                 (car-atom (goalTarget-get $targets help_long)) $alpha))
       ($new-over-beneficial
         (_blend (getGoal $space over_beneficial)
                 (car-atom (goalTarget-get $targets over_beneficial)) $alpha))
       ($new-over-safety
         (_blend (getGoal $space over_safety)
                 (car-atom (goalTarget-get $targets over_safety)) $alpha))
       ($new-over-honesty
         (_blend (getGoal $space over_honesty)
                 (car-atom (goalTarget-get $targets over_honesty)) $alpha))
       ($_ (println! ("new-over-honesty: "$new-over-honesty)))


       ($_ (updateGoals $space (
             (efficiency           $new-efficiency)
             (accuracy             $new-accuracy)
             (success_moderate     $new-success-moderate)
             (knowledge            $new-knowledge)
             (novelty              $new-novelty)
             (success_breakthrough $new-success-breakthrough)
             (coherence            $new-coherence)
             (originality          $new-originality)
             (social               $new-social)
             (help_short           $new-help-short)
             (help_long            $new-help-long)
             (over_beneficial      $new-over-beneficial)
             (over_safety          $new-over-safety)
             (over_honesty         $new-over-honesty)
           )))

       ($current-goals (getGoals $space))
       ($_ (println! ("curr-goals: "$current-goals)))

       ($ag-targets (antiGoalTargets $space $current-goals))
       ($_ (println! ("ag-targets: "$ag-targets)))


       ($new-hall
         (_blend (car-atom (antiGoal-get $anti hallucinate))
                 (car-atom (antiGoalTarget-get $ag-targets hallucinate)) $anti-alpha))
       ($_ (println! ("new-hall: "$new-hall)))

       ($new-redundant
         (_blend (car-atom (antiGoal-get $anti redundant))
                 (car-atom (antiGoalTarget-get $ag-targets redundant)) $anti-alpha))
       ($_ (println! ("new-redundant: "$new-redundant)))

       ($new-rabbit-hole
         (_blend (car-atom (antiGoal-get $anti rabbit_hole))
                 (car-atom (antiGoalTarget-get $ag-targets rabbit_hole)) $anti-alpha))
       ($_ (println! ("new-rabbit-hole: "$new-rabbit-hole)))
       ($new-premature
         (_blend (car-atom (antiGoal-get $anti premature))
                 (car-atom (antiGoalTarget-get $ag-targets premature)) $anti-alpha))
       ($_ (println! ("new-premature: "$new-premature)))
       
       ($_ (updateAntiGoals $space $new-hall $new-redundant $new-rabbit-hole $new-premature))

 
       ($_ (apply-homeostasis $space))

       ($_ (increment-turn $space))
        
      )
     "post-update complete"
   )
)

; style (works as style.py (corresponding python implementation))

; ─────────────────────────────────────────────
; determine-respond-style
; Returns one of: style_concise style_thorough
;   style_exploratory style_cautious style_tutorial
; ─────────────────────────────────────────────
(= (determine-respond-style $space $appraisal)
   (let*
     (
       ($urg  (find_by_key urgency $appraisal))
       ($cx   (find_by_key complexity $appraisal))
       ($amb  (find_by_key ambiguity $appraisal))
       ($ux   (find_by_key user_expertise $appraisal))
       ($thr  (find_by_key threshold $appraisal))
       ($fw   (getMod $space m_failure_wariness))
       ($lc   (- 1.0 $thr))
       ($res  (find_by_key resolution $appraisal))
       ($app  (find_by_key approach $appraisal))
       ($cr   (find_by_key creativity $appraisal))
       ($ra   (find_by_key risk_aversion $appraisal))
       ($vr   (find_by_key verify_request $appraisal))

       ($sc-concise
         (+ 0.40 (+ (* 0.70 $urg)
                    (+ (* 0.20 (- 1.0 $cx))
                       (* 0.15 (- 1.0 $amb))))))
       ($sc-thorough
         (+ 0.35 (+ (* 0.55 $cx)
                    (+ (* 0.45 $res)
                       (+ (* 0.15 $amb)
                          (* -0.35 $urg))))))
       ($sc-exploratory
         (+ 0.30 (+ (* 0.55 $cr)
                    (+ (* 0.40 $app)
                       (+ (* 0.20 $cx)
                          (+ (* -0.35 $thr)
                             (+ (* -0.20 $ra)
                                (* -0.20 $fw))))))))
       ($sc-cautious
         (+ 0.35 (+ (* 0.55 $thr)
                    (+ (* 0.45 $lc)
                       (+ (* 0.30 $fw)
                          (+ (* 0.20 $ra)
                             (if $vr 0.25 0.0)))))))
       ($sc-tutorial
         (+ 0.35 (+ (* 0.70 (- 1.0 $ux))
                    (+ (* 0.20 $amb)
                       (* 0.10 $cx)))))
     )
     (if (and (>= $sc-concise $sc-thorough)
              (and (>= $sc-concise $sc-exploratory)
                   (and (>= $sc-concise $sc-cautious)
                        (>= $sc-concise $sc-tutorial))))
         style_concise
         (if (and (>= $sc-thorough $sc-exploratory)
                  (and (>= $sc-thorough $sc-cautious)
                       (>= $sc-thorough $sc-tutorial)))
             style_thorough
             (if (and (>= $sc-exploratory $sc-cautious)
                      (>= $sc-exploratory $sc-tutorial))
                 style_exploratory
                 (if (>= $sc-cautious $sc-tutorial)
                     style_cautious
                     style_tutorial))))
   )
)