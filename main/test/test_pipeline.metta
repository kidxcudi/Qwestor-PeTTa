; ─────────────────────────────────────────────
; main/test/test_pipeline.metta
; End-to-end MeTTa pipeline test.
; ─────────────────────────────────────────────

!(import! &self ../../utils/general-helper)
!(import! &self ../../utils/utils)
!(import! &self ../../operators/appraisal)
!(import! &self ../../operators/decision)
!(import! &self ../../operators/action)


; ═══════════════════════════════════════════════════════════════
; TEST 1 — Utility helpers
; ═══════════════════════════════════════════════════════════════
!(println! "=== TEST 1: Utility Helpers ===")

!(test (_clamp01  0.5)  0.5)
!(test (_clamp01 -0.3)  0)
!(test (_clamp01  1.5)  1)
!(test (_clamp01  0.01) 0.01)
!(test (_clamp01  0.99) 0.99)

!(test (_clamp11  0.5)  0.5)
!(test (_clamp11 -0.5) -0.5)
!(test (_clamp11 -1.5) -1)
!(test (_clamp11  1.5)  1)

!(test (replaceByIndex (a b c) 0 x) (x b c))
!(test (replaceByIndex (a b c) 1 x) (a x c))
!(test (replaceByIndex (a b c) 2 x) (a b x))

!(test (find_by_key color ((color red) (size 10))) red)
!(test (find_by_key size  ((color red) (size 10))) 10)

!(println! "TEST 1 passed - Utility helpers")


; ═══════════════════════════════════════════════════════════════
; TEST 2 — Space setup
; ═══════════════════════════════════════════════════════════════
!(println! "=== TEST 2: Space Setup ===")

!(bind! &space (new-space))
!(addAlpha &space (alpha))
!(addState &space (state (turn 0) (default-goals) (default-mods) (default-anti-goals) (alpha)))

!(let $s (getState &space)
    (println! ("  State retrieved OK:" $s)))

!(println! "TEST 2 passed - Space setup")


; ═══════════════════════════════════════════════════════════════
; TEST 3 — Alpha retrieval
; ═══════════════════════════════════════════════════════════════
!(println! "=== TEST 3: Alpha Retrieval ===")

!(test (getAlpha &space urgency_alpha)             0.60)
!(test (getAlpha &space resolution_alpha)          0.45)
!(test (getAlpha &space expertise_alpha)           0.45)
!(test (getAlpha &space threshold_alpha)           0.40)
!(test (getAlpha &space familiarity_alpha)         0.35)
!(test (getAlpha &space failure_decay)             0.20)
!(test (getAlpha &space securing_alpha)            0.45)
!(test (getAlpha &space approach_alpha)            0.40)
!(test (getAlpha &space arousal_alpha)             0.40)
!(test (getAlpha &space risk_aversion_alpha)       0.45)
!(test (getAlpha &space error_tolerance_alpha)     0.40)
!(test (getAlpha &space creativity_alpha)          0.40)
!(test (getAlpha &space valence_alpha)             0.40)
!(test (getAlpha &space cold_start_horizon)        2.0)
!(test (getAlpha &space cold_start_strength)       0.70)
!(test (getAlpha &space goal_alpha)                0.18)
!(test (getAlpha &space anti_goal_alpha)           0.16)
!(test (getAlpha &space reflective_think_bonus)    0.14)
!(test (getAlpha &space reflective_search_penalty) 0.10)
!(test (getAlpha &space intent_margin)             0.12)

!(println! "TEST 3 passed - Alpha retrieval")


; ═══════════════════════════════════════════════════════════════
; TEST 4 — Default modulator retrieval
; ═══════════════════════════════════════════════════════════════
!(println! "=== TEST 4: Default Modulator Retrieval ===")

!(test (getMod &space m_urgency)           0.20)
!(test (getMod &space m_resolution)        0.40)
!(test (getMod &space m_user_expertise)    0.50)
!(test (getMod &space m_threshold)         0.30)
!(test (getMod &space m_topic_familiarity) 0.50)
!(test (getMod &space m_failure_wariness)  0.10)
!(test (getMod &space m_securing)          0.10)
!(test (getMod &space m_approach)          0.40)
!(test (getMod &space m_arousal)           0.40)
!(test (getMod &space m_risk_aversion)     0.40)
!(test (getMod &space m_error_tolerance)   0.45)
!(test (getMod &space m_creativity)        0.45)
!(test (getMod &space m_valence)           0.00)

!(test (getMods &space) (default-mods))

!(println! "TEST 4 passed - Default modulator retrieval")


; ═══════════════════════════════════════════════════════════════
; TEST 5 — Default goal retrieval
; ═══════════════════════════════════════════════════════════════
!(println! "=== TEST 5: Default Goal Retrieval ===")

!(test (getGoal &space efficiency)           0.60)
!(test (getGoal &space accuracy)             0.70)
!(test (getGoal &space success_moderate)     0.62)
!(test (getGoal &space knowledge)            0.52)
!(test (getGoal &space novelty)              0.46)
!(test (getGoal &space success_breakthrough) 0.44)
!(test (getGoal &space coherence)            0.58)
!(test (getGoal &space originality)          0.48)
!(test (getGoal &space social)               0.58)
!(test (getGoal &space help_short)           0.55)
!(test (getGoal &space help_long)            0.45)
!(test (getGoal &space over_beneficial)      0.60)
!(test (getGoal &space over_safety)          0.65)
!(test (getGoal &space over_honesty)         0.65)

!(println! "TEST 5 passed - Default goal retrieval")


; ═══════════════════════════════════════════════════════════════
; TEST 6 — Anti-goal retrieval
;
; The anti-goal vector should match the default.
; Example: !(getAntiGoals &space)  ; => (default-anti-goals)
; ═══════════════════════════════════════════════════════════════
!(println! "=== TEST 6: Anti-Goal Retrieval ===")

!(test (getAntiGoals &space) (default-anti-goals))

!(println! "TEST 6 passed - Anti-goal retrieval")


; ═══════════════════════════════════════════════════════════════
; TEST 7 — Context storage and retrieval
; ═══════════════════════════════════════════════════════════════
!(println! "=== TEST 7: Context Storage and Retrieval ===")

!(add-context &space (
   (complexity              0.70)
   (threshold               0.80)
   (ambiguity               0.30)
   (urgent                  0)
   (intent_type             factual)
   (expertise               0.60)
   (topic_familiarity       0.40)
   (failure_signal          0.00)
   (verify_request          1)
   (reflective_intent       0.30)
   (needs_external_evidence 0.90)
   (needs_task_plan         0.20)
   (needs_multi_source_integration 0.80)
   (valence                 0.00)
))

!(test (getContext &space complexity)               0.70)
!(test (getContext &space threshold)                0.80)
!(test (getContext &space ambiguity)                0.30)
!(test (getContext &space urgent)                   0)
!(test (getContext &space intent_type)              factual)
!(test (getContext &space expertise)                0.60)
!(test (getContext &space topic_familiarity)        0.40)
!(test (getContext &space failure_signal)           0.00)
!(test (getContext &space verify_request)           1)
!(test (getContext &space reflective_intent)        0.30)
!(test (getContext &space needs_external_evidence)  0.90)
!(test (getContext &space needs_task_plan)          0.20)
!(test (getContext &space needs_multi_source_integration) 0.80)
!(test (getContext &space valence)                  0.00)

!(println! "TEST 7 passed - Context storage and retrieval")


; ═══════════════════════════════════════════════════════════════
; TEST 8 — Goal update
; ═══════════════════════════════════════════════════════════════
!(println! "=== TEST 8: Goal Update ===")

!(updateGoal &space knowledge 0.80)
!(test (getGoal &space knowledge)  0.80)
!(test (getGoal &space efficiency) 0.60)
!(test (getGoal &space accuracy)   0.70)

!(updateGoal &space knowledge 0.52)
!(test (getGoal &space knowledge)  0.52)

!(println! "TEST 8 passed - Goal update")


; ═══════════════════════════════════════════════════════════════
; TEST 9 — Modulator batch update
; ═══════════════════════════════════════════════════════════════
!(println! "=== TEST 9: Modulator Batch Update ===")

!(update-mods &space (
   (m_urgency           0.10)
   (m_resolution        0.55)
   (m_user_expertise    0.50)
   (m_threshold         0.50)
   (m_topic_familiarity 0.60)
   (m_failure_wariness  0.10)
   (m_securing          0.20)
   (m_approach          0.50)
   (m_arousal           0.45)
   (m_risk_aversion     0.35)
   (m_error_tolerance   0.45)
   (m_creativity        0.50)
   (m_valence          -0.10)
))

!(test (getMod &space m_urgency)           0.10)
!(test (getMod &space m_resolution)        0.55)
!(test (getMod &space m_threshold)         0.50)
!(test (getMod &space m_topic_familiarity) 0.60)
!(test (getMod &space m_securing)          0.20)
!(test (getMod &space m_approach)          0.50)
!(test (getMod &space m_valence)          -0.10)

; Restore defaults
!(update-mods &space (
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
!(test (getMod &space m_urgency) 0.20)

!(println! "TEST 9 passed - Modulator batch update")


; ═══════════════════════════════════════════════════════════════
; TEST 10 — State removal and re-addition
;
; remove-state wipes the (state ...) atom; addState restores it.
; Example:
;   !(remove-state &space)
;   !(getState &space)  ; => ()
; ═══════════════════════════════════════════════════════════════
!(println! "=== TEST 10: State Remove and Re-add ===")

!(remove-state &space)

!(test (
    let* (
        ($s (getState &space))
    ) $s) ())

!(addState &space (state (turn 0) (default-goals) (default-mods) (default-anti-goals) (alpha)))

!(test (getMod &space m_urgency) 0.20)
!(test (getGoal &space accuracy) 0.70)

!(println! "TEST 10 passed - State remove and re-add")


; ═══════════════════════════════════════════════════════════════
; TEST 11 — Appraisal computation
; ═══════════════════════════════════════════════════════════════
!(println! "=== TEST 11: Appraisal Computation ===")

!(let $r (appraisalModulator &space)
    (println! ("  Appraisal returned:" $r)))

!(test (getMod &space m_urgency)           0.08000000000000002)
!(test (getMod &space m_resolution)        0.535)
!(test (getMod &space m_user_expertise)    0.545)
!(test (getMod &space m_threshold)         0.5)
!(test (getMod &space m_topic_familiarity) 0.46499999999999997)
!(test (getMod &space m_failure_wariness)  0.08000000000000002)
!(test (getMod &space m_securing)          0.262)
!(test (getMod &space m_approach)          0.492)
!(test (getMod &space m_arousal)           0.4851)
!(test (getMod &space m_risk_aversion)     0.39100000000000007)
!(test (getMod &space m_error_tolerance)   0.538)
!(test (getMod &space m_creativity)        0.554)
!(test (getMod &space m_valence)           0.0)

!(println! "TEST 11 passed - Appraisal computation")
