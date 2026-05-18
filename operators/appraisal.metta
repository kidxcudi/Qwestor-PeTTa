; ─────────────────────────────────────────────
; appraisal.metta
;
; Defines modulators, alpha hyper-parameters,
; goal/context defaults, and the calculate-mod
; update function.
;
; ─────────────────────────────────────────────

(= (addItems $baseCase $space $items)
   (if (== $items ())
        $baseCase
        (let* (
               ($h (car-atom $items))
               ($t (cdr-atom $items))
               ($_ (add-atom $space $h))
               )
          (addItems $baseCase $space $t)
          )
     )
)

(= (addAlpha $space $list)    (addItems () $space $list))
(= (add-context $space $list) (addItems () $space $list))


; ─────────────────────────────────────────────
; calculate-mod
; Computes the new modulator vector via
; incremental blending:  new = (1-α)·old + α·target
; ─────────────────────────────────────────────

(= (_effective $smoothed $rawSignal $coldWeight)
    (eval (_clamp01 
        (+ 
            (* (- 1.0 $coldWeight) $smoothed)
            (* $coldWeight $rawSignal)
        )
    ))
)

(= (appraisalModulator $space)
    (let*
      (
        ($_ (println! ("inside calculate-mod")))

        ; ── convenience shorthands ─────────────────────────
        ($cx (getContext $space complexity))
        ($amb (getContext $space ambiguity))
        ($exp (getContext $space expertise))
        ($thr (getContext $space threshold))
        ($fs (getContext $space failure_signal))
        ($fam (getContext $space topic_familiarity))
        ($ri (getContext $space reflective_intent))
        ($vr (getContext $space verify_request))
        ($urg (getContext $space urgent))
        ($val (getContext $space valence))
        ($target_u (if (== $urg 1) 1.0 0.0))


        ($_ (println! ("complexity: " $cx " ambiguity: " $amb " expertise: " $exp " threshold: " $thr " failure_signal: " $fs " topic_familiarity: " $fam " reflective_intent: " $ri " verify_request: " $vr)))
        ($_ (println! ("urgent: " $urg)))
        ($_ (println! ("valence: " $val)))
        ($_ (println! ("target_u: " $target_u)))
        ($_ (println! ("ALL VALUES EXTRACTED")))


        ; ; ── 1. m_urgency ────────────────────────────────────
        ($m_urgency
          (eval (_clamp01 (+
            (* (- 1.0 (getAlpha $space urgency_alpha))    (getMod $space m_urgency))
            (* (getAlpha $space urgency_alpha)            $target_u)))))
        
        ($_ (println! ("m_urgency: " $m_urgency)))



        ; ── 2. m_resolution ─────────────────────────────────
        ($m_resolution
          (eval (_clamp01 (+
            (* (- 1.0 (getAlpha $space resolution_alpha)) (getMod $space m_resolution))
            (* (getAlpha $space resolution_alpha)         $cx)))))
        
        ($_ (println! ("m_resolution: " $m_resolution)))




        ; ── 3. m_user_expertise ─────────────────────────────
        ($m_user_expertise
          (eval (_clamp01 (+
            (* (- 1.0 (getAlpha $space expertise_alpha))  (getMod $space m_user_expertise))
            (* (getAlpha $space expertise_alpha)          $exp)))))
        
        ($_ (println! ("m_user_expertise: " $m_user_expertise)))

        ; ── 4. m_threshold ──────────────────────────────────
        ($m_threshold
          (eval (_clamp01 (+
            (* (- 1.0 (getAlpha $space threshold_alpha))  (getMod $space m_threshold))
            (* (getAlpha $space threshold_alpha)          $thr)))))

        ($_ (println! ("m_threshold: " $m_threshold)))

        ; ── 5. m_topic_familiarity ──────────────────────────
        ($m_topic_familiarity
          (eval (_clamp01 (+
            (* (- 1.0 (getAlpha $space familiarity_alpha)) (getMod $space m_topic_familiarity))
            (* (getAlpha $space familiarity_alpha)         $fam)))))

        ($_ (println! ("m_topic_familiarity: " $m_topic_familiarity))) 

        ; ── 6. m_failure_wariness ───────────────────────────
        ($m_failure_wariness
          (eval (_clamp01 (+
            (* (- 1.0 (getAlpha $space failure_decay))    (getMod $space m_failure_wariness))
            (* (getAlpha $space failure_decay)            $fs)))))
        
         ($_ (println! ("m_failure_wariness: " $m_failure_wariness)))

        ; ── 7. m_securing ───────────────────────────────────
        ($securing_target
          (eval (_clamp01 (+
            (* 0.50 $thr)
            (+ (* 0.30 $fs)
               (* 0.20 $amb))))))
        ($_ (println! ("securing_target: " $securing_target)))


        ($m_securing
          (eval (_clamp01 (+
            (* (- 1.0 (getAlpha $space securing_alpha))   (getMod $space m_securing))
            (* (getAlpha $space securing_alpha)           $securing_target)))))

        ($_ (println! ("m_securing: " $m_securing)))
        
        ; ── 8. m_approach ───────────────────────────────────
        ($approach_target
          (eval (_clamp01 (+
            (* 0.45 $cx)
            (+ (* 0.25 (- 1.0 $amb))
               (+ (* 0.20 (- 1.0 $thr))
                  (* 0.10 (- 1.0 $fs))))))))
        ($_ (println! ("approach_target: " $approach_target)))

        ($m_approach
          (eval (_clamp01 (+
            (* (- 1.0 (getAlpha $space approach_alpha))   (getMod $space m_approach))
            (* (getAlpha $space approach_alpha)           $approach_target)))))
        
        ($_ (println! ("m_approach: " $m_approach)))

        ; ── 9. m_arousal ────────────────────────────────────
        ($novelty_signal
          (eval (_clamp01 (+
            (* 0.35 $cx)
            (+ (* 0.35 (- 1.0 $fam))
               (+ (* 0.20 $ri)
                  (* 0.10 $amb)))))))
        ($_ (println! ("novelty_signal: " $novelty_signal)))
        ($arousal_target
          (eval (_clamp01 (+
            0.25
            (+ (* 0.40 $m_urgency)
               (+ (* 0.35 $novelty_signal)
                  (* 0.20 $cx)))))))

        ($_ (println! ("arousal_target: " $arousal_target)))

        ($m_arousal
          (eval (_clamp01 (+
            (* (- 1.0 (getAlpha $space arousal_alpha))    (getMod $space m_arousal))
            (* (getAlpha $space arousal_alpha)            $arousal_target)))))
        ($_ (println! ("arousal: " $m_arousal)))

        ; ── 10. m_risk_aversion ─────────────────────────────
        ($risk_aversion_target
          (eval (_clamp01 (+
            (* 0.40 $thr)
            (+ (* 0.30 $fs)
               (+ (* 0.20 $amb)
                  (* 0.10 (if (== $urg 1) 1 0))))))))
        ($_ (println! ("risk_aversion_target: " $risk_aversion_target)))

        ($m_risk_aversion
          (eval (_clamp01 (+
            (* (- 1.0 (getAlpha $space risk_aversion_alpha)) (getMod $space m_risk_aversion))
            (* (getAlpha $space risk_aversion_alpha)         $risk_aversion_target)))))
                
        ($_ (println! ("risk_aversion_: " $m_risk_aversion)))

        ; ── 11. m_error_tolerance ───────────────────────────
        ($error_tolerance_target
          (eval (_clamp01 (+
            0.45
            (+ (* 0.25 (- 1.0 $thr))
               (+ (* 0.20 $fam)
                  (+ (* 0.15 (- 1.0 $fs))
                     (- (* -0.20 $amb)
                        (* 0.10 (if (== $urg 1) 1 0))))))))))
        ($_ (println! ("error_tolerance_target: " $error_tolerance_target)))

        ($m_error_tolerance
          (eval (_clamp01 (+
            (* (- 1.0 (getAlpha $space error_tolerance_alpha)) (getMod $space m_error_tolerance))
            (* (getAlpha $space error_tolerance_alpha)         $error_tolerance_target)))))
        ($_ (println! ("m_error_tolerance: " $m_error_tolerance)))

        ; ── 12. m_creativity ────────────────────────────────
        ($creativity_target
          (eval (_clamp01 (+
            0.30
            (+ (* 0.30 (- 1.0 $fam))
               (+ (* 0.20 $cx)
                  (+ (* 0.15 (- 1.0 $thr))
                     (- (* 0.20 $ri)
                        (* 0.10 $fs)))))))))
        
        ($_ (println! ("creativity_target: " $creativity_target)))

        ($m_creativity
          (eval (_clamp01 (+
            (* (- 1.0 (getAlpha $space creativity_alpha))     (getMod $space m_creativity))
            (* (getAlpha $space creativity_alpha)             $creativity_target)))))

        ($_ (println! ("m_creativity: " $m_creativity)))

        ; ── 13. m_valence ───────────────────────────────────
        ($valence_target
          (eval (_clamp11 (- $val (* 0.10 $fs)))))
        
        ($_ (println! ("valence_target: " $valence_target)))


        ($m_valence
          (eval(_clamp11 (+
            (* (- 1.0 (getAlpha $space valence_alpha))        (getMod $space m_valence))
            (* (getAlpha $space valence_alpha)                $valence_target)))))
        
        ($_ (println! ("m_valence: " $m_valence)))

        ($t (match $space (state (turn $turn)  $x $y $z $alpha) $turn))
        ($_ (println! ("turn: " $t "m_urgency: " $m_urgency " m_resolution: " $m_resolution " m_user_expertise: " $m_user_expertise " m_threshold: " $m_threshold " m_topic_familiarity: " $m_topic_familiarity " m_failure_wariness: " $m_failure_wariness " m_securing: " $m_securing " m_approach: " $m_approach " m_arousal: " $m_arousal " m_risk_aversion: " $m_risk_aversion " m_error_tolerance: " $m_error_tolerance " m_creativity: " $m_creativity " m_valence: " $m_valence)))

        ($cold_start_horizon (getAlpha $space cold_start_horizon))
        ($turn_count (match $space (state (turn $turn)  $x $y $z $alpha) $turn))
        ($cold_start_strength (getAlpha $space cold_start_horizon))
        ($_ (println! ("cold_start_values: " $cold_start_horizon $cold_start_strength $turn_count)))

        ($cold_phase (/ (- $cold_start_horizon $t) $cold_start_horizon))

        ($coldWeight (if (and (> $cold_start_horizon 0.0) (> $cold_start_strength $t)) 
                       (eval (_clamp01 (* $cold_start_strength $cold_phase))) 
                        0.0))
        ($_ (println! ("cold_start_horizon: " $cold_start_horizon " cold_start_strength: " $cold_start_strength "cold_phase: " $cold_phase " cold_weight: " $coldWeight)))
       
        ($cx (getContext $space complexity))
        ($u (_effective $m_urgency $target_u $coldWeight))
        ($res (_effective $m_resolution $cx $coldWeight))
        ($ux (_effective $m_user_expertise $exp $coldWeight))
        ($_ (println! ("After cold weighting: urgency: " $u " resolution: " $res " user experience: " $ux " threshold: " $thre)))

        ($threshold (_effective $m_threshold $thr $coldWeight))
        ($urgent (getContext $space urgent))
        ($_ (println! ("urgent " $urgent)))
        ($intentType (getContext $space intent_type))
        ($needsExternalEvidence (getContext $space needs_external_evidence))
        ($needsTaskPlan (getContext $space needs_task_plan))
        ($needsMultiSourceIntegration (getContext $space needs_multi_source_integration))
        ($verify_request (getContext $space verify_request))
        ($creativity (_effective $m_creativity $creativity_target $coldWeight))
        ($securing (_effective $m_securing $securing_target $coldWeight))
        ($approach (_effective $m_approach $approach_target $coldWeight))
        ($arousal (_effective $m_arousal $arousal_target $coldWeight))
        ($risk_aversion (_effective $m_risk_aversion $risk_aversion_target $coldWeight))
        ($error_tolerance (_effective $m_error_tolerance $error_tolerance_target $coldWeight))
        ($creativity (_effective $m_creativity $creativity_target $coldWeight))
        ; ($_ (println! ("After cold weighting: u: " $u " res: " $res " ux: " $ux " threshold: " $threshold " securing:" $securing " approach: " $approach " arousal: " $arousal " risk_aversion: " $risk_aversion " error_tolerance: " $error_tolerance " creativity: " $creativity)))
        ($valence (eval (_clamp11 (* (- 1.0 $coldWeight) (* (+ (getContext $space valence)
            $coldWeight) (getContext $space valence))))))
        ($_ (println! ("Calculated effective signals: u: " $u " res: " $res " ux: " $ux " threshold: " $threshold " securing: " $securing " approach: " $approach " arousal: " $arousal " risk_aversion: " $risk_aversion " error_tolerance: " $error_tolerance " creativity: " $creativity " valence: " $valence)))
        
        ($_ (println! ("values : threshold: " $threshold " urgent: " $urgent " intentType: " $intentType " needsExternalEvidence: " $needsExternalEvidence " needsTaskPlan: " $needsTaskPlan " needsMultiSourceIntegration: " $needsMultiSourceIntegration " arousal: " $arousal " risk_aversion: " $risk_aversion " error_tolerance: " $error_tolerance " creativity: " $creativity " valence: " $valence)))

        ($updatedMods (
        (m_urgency           $m_urgency)
        (m_resolution        $m_resolution)
        (m_user_expertise    $m_user_expertise)
        (m_threshold         $m_threshold)
        (m_topic_familiarity $m_topic_familiarity)
        (m_failure_wariness  $m_failure_wariness)
        (m_securing          $m_securing)
        (m_approach          $m_approach)
        (m_arousal           $m_arousal)
        (m_risk_aversion     $m_risk_aversion)
        (m_error_tolerance   $m_error_tolerance)
        (m_creativity        $m_creativity)
        (m_valence           $m_valence)))
        
        ($_ (println! ("updated mods: " $updatedMods)))

        ($_ (update-mods $space $updatedMods))

        ($results (     (turn $turn)
                        (cold_weight $coldWeight)
                        (complexity $cx)
                        (ambiguity $amb)
                        (expertise $exp)
                        (threshold_signal $thr)
                        (familiarity_signal $fam)
                        (failure_signal $fs)
                        (urgent_flag $urg)
                        (intent_type $intentType)
                        (verify_request $vr)
                        (reflective_intent $ri)
                        (needs_external_evidence $needsExternalEvidence)
                        (needs_task_plan $needsTaskPlan)
                        (needs_multi_source_integration $needsMultiSourceIntegration)
                        (urgency $u)
                        (resolution $res)
                        (user_expertise $ux)
                        (threshold $threshold)
                        (securing $securing)
                        (approach $approach)
                        (arousal $arousal)
                        (risk_aversion $risk_aversion)
                        (error_tolerance $error_tolerance)
                        (creativity $creativity)
                        (valence $valence))
        )

      )
      ; ── return the full updated modulator-vector ──────────
        $results 
    )
)

; ─────────────────────────────────────────────
; Alpha hyper-parameters (learning rates)
; ─────────────────────────────────────────────
(= (alpha)
  (
    (urgency_alpha              0.60)
    (resolution_alpha           0.45)
    (expertise_alpha            0.45)
    (threshold_alpha            0.40)
    (familiarity_alpha          0.35)
    (failure_alpha              0.55)
    (failure_decay              0.20)
    (securing_alpha             0.45)
    (approach_alpha             0.40)
    (arousal_alpha              0.40)
    (risk_aversion_alpha        0.45)
    (error_tolerance_alpha      0.40)
    (creativity_alpha           0.40)
    (valence_alpha              0.40)
    (goal_alpha                 0.18)
    (anti_goal_alpha            0.16)
    (cold_start_horizon         2.0)
    (cold_start_strength        0.70)
    (decompose_min_complexity   0.60)
    (decompose_urgent_min_complexity 0.70)
    (decompose_max_ambiguity    0.70)
    (reflective_think_bonus     0.14)
    (reflective_search_penalty  0.10)
    (intent_margin              0.12)
    (enable_homeostasis         0)
    (homeostasis_theta_safe     0.55)
    (homeostasis_eta            0.05)
    (homeostasis_alpha_near     0.10)
  )
)


; ─────────────────────────────────────────────
; Default modulator vector (13 modulators)
; ─────────────────────────────────────────────
(= (default-mods) (
         modulator-vector
        (m_urgency           0.20)
        (m_resolution        0.40)
        (m_user_expertise    0.50)
        (m_threshold         0.30)
        (m_topic_familiarity 0.50)
        (m_failure_wariness  0.10)
        (m_securing          0.10)
        (m_approach          0.40)
        (m_arousal           0.40)
        (m_risk_aversion     0.40)
        (m_error_tolerance   0.45)
        (m_creativity        0.45)
        (m_valence           0.00)
))

; ─────────────────────────────────────────────
; Default context values
; ─────────────────────────────────────────────
(= (context)(
   ; core signals
   (complexity              0.30)
   (threshold               0.30)
   (ambiguity               0.00)
   (urgent                  0.00)
   (intent_type             mixed)
   ; user and topic
   (expertise               0.50)
   (topic_familiarity       0.50)   
   (failure_signal          0.30)
   (verify_request          False)  
   ; advanced signals
   (reflective_intent       0.50)
   (needs_external_evidence 0.30)
   (needs_task_plan         0.20)
   (needs_multi_source_integration 0.30)
   (valence                 0.00)
))


; ─────────────────────────────────────────────
; Default goal vector
; ─────────────────────────────────────────────
(= (default-goals) (goal-vector
 (efficiency           0.60)
 (accuracy             0.70)
 (success_moderate     0.62)
 (knowledge            0.52)
 (novelty              0.46)           
 (success_breakthrough  0.44)          
 (coherence            0.58)
 (originality          0.48)
 (social               0.58)
 (help_short           0.55)
 (help_long            0.45)
 (over_beneficial      0.60)
 (over_safety          0.65)
 (over_honesty         0.65)
))

; ─────────────────────────────────────────────
; Default anti-goal vector
; ─────────────────────────────────────────────
(= (default-anti-goals)(anti-goals
    (hallucinate 0.35)
    (redundant   0.30)
    (rabbit_hole 0.28)
    (premature   0.30)
))
