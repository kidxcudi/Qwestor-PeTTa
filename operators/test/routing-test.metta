!(import! &self ../routing)
!(import! &self ../../utils/constants)
!(import! &self ../../utils/utils)  

!(bind! &space (new-space))

;; Clean up any existing state and set up properly
;; Proper state structure with modulator-vector containing all 13 modulators
!(add-atom &space (state (turn 0) 
                         (goal-vector (efficiency 0.5) (accuracy 0.5) (success_moderate 0.5) 
                                     (knowledge 0.5) (novelty 0.5) (success_breakthrough 0.5) 
                                     (coherence 0.5) (originality 0.5) (social 0.5) 
                                     (help_short 0.5) (help_long 0.5) (over_beneficial 0.5) 
                                     (over_safety 0.5) (over_honesty 0.5))
                         (modulator-vector (m_urgency 0.5) (m_resolution 0.5) (m_user_expertise 0.5) 
                                          (m_threshold 0.5) (m_topic_familiarity 0.5) 
                                          (m_failure_wariness 0.40) (m_securing 0.5) 
                                          (m_approach 0.5) (m_arousal 0.5) (m_risk_aversion 0.5) 
                                          (m_error_tolerance 0.5) (m_creativity 0.5) (m_valence 0.5))
                         (anti-goal-vector)
                         ()))

;; Alpha atoms as top-level
!(add-atom &space (decompose_min_complexity 0.4))
!(add-atom &space (decompose_urgent_min_complexity 0.7))
!(add-atom &space (decompose_max_ambiguity 0.8))

; test-case for get-action-score
!(test (get-action-score ((act_search 10) (act_attack 5)) act_search) 10)
!(test (get-action-score ((act_search 10)) act_search) 10)
!(test (get-action-score ((act_search 10) (act_attack 5)) act_attack) 5)
!(test (get-action-score ((act_search 10) (act_attack 5)) act_defend) (ACTION-BLOCKED-SCORE))
!(test (get-action-score () act_search) (ACTION-BLOCKED-SCORE))
!(test (get-action-score ((act_search 10) (act_search 20)) act_search) 10)
!(test (get-action-score ((act_search 10.5) (act_attack 5.2)) act_search) 10.5)
!(test (get-action-score ((act_search 10.5) (act_attack 5.2)) act_attack) 5.2)



!(test (set-action-score () act_search 10) ((act_search 10)))
!(test (set-action-score ((act_search 10) (act_attack 5)) act_search 15) ((act_search 15) (act_attack 5)))
!(test (set-action-score ((act_search 10) (act_attack 5)) act_attack 8) ((act_search 10) (act_attack 8)))
; if the action is not in the list, it should be added
!(test (set-action-score ((act_search 10) (act_attack 5)) act_search 15) ((act_search 15) (act_attack 5)))
!(test (set-action-score ((act_search 10) (act_search 20)) act_search 15) ((act_search 15) (act_search 20)))
 
; test-case for adjust-action-score
!(test (adjust-action-score ((act_search 10) (act_attack 5)) act_search 5) ((act_search 15) (act_attack 5)))
!(test (adjust-action-score ((act_search 10) (act_attack 5)) act_attack -2) ((act_search 10) (act_attack 3)))
!(test (adjust-action-score ((act_search 10) (act_attack 5)) act_defend 3) ((act_search 10) (act_attack 5)))
!(test (adjust-action-score () act_search 5) ())
!(test (adjust-action-score ((act_search 10) (act_search 20)) act_search 5) ((act_search 15) (act_search 20)))      


; test-case for get-context-value
!(test (ctx-val () act_search) 0.0)
!(test (ctx-val ((act_search 10) (act_attack 5)) act_search) 10)
!(test (ctx-val ((act_search 10) (act_attack 5)) act_attack) 5)
!(test (ctx-val ((act_search 10) (act_attack 5)) act_defend) 0.0)
!(test (ctx-val ((act_search 10) (act_search 20)) act_search) 10)   


; test-case for guard-decompose

; test-case for guard-decompose with non-blocking conditions
!(test (guard-decompose ((act_decompose 10)) ((complexity 0.5) (ambiguity 0.2) (urgent_flag true) (needs_task_plan 0.3) (reflective_intent 0.8) (needs_external_evidence 0.4) (decompose_min_complexity 0.4) (decompose_urgent_min_complexity 0.7) (decompose_max_ambiguity 0.8)) &space) act_decompose -1000000000.0)
!(test (guard-decompose ((act_decompose 10)) ((complexity 0.3) (ambiguity 0.2) (urgent_flag true) (needs_task_plan 0.3) (reflective_intent 0.8) (needs_external_evidence 0.4) (decompose_min_complexity 0.4) (decompose_urgent_min_complexity 0.7) (decompose_max_ambiguity 0.8)) &space) act_decompose -1000000000.0)
!(test (guard-decompose ((act_decompose 10)) ((complexity 0.5) (ambiguity 0.9) (urgent_flag true) (needs_task_plan 0.3) (reflective_intent 0.8) (needs_external_evidence 0.4) (decompose_min_complexity 0.4) (decompose_urgent_min_complexity 0.7) (decompose_max_ambiguity 0.8)) &space) act_decompose -1000000000.0)
!(test (guard-decompose ((act_decompose 10)) ((complexity 0.5) (ambiguity 0.2) (urgent_flag true) (needs_task_plan 0.3) (reflective_intent 0.8) (needs_external_evidence 0.4) (decompose_min_complexity 0.6) (decompose_urgent_min_complexity 0.7) (decompose_max_ambiguity 0.8)) &space) act_decompose -1000000000.0)
!(test (guard-decompose ((act_decompose 10)) ((complexity 0.5) (ambiguity 0.2) (urgent_flag true) (needs_task_plan 0.3) (reflective_intent 0.8) (needs_external_evidence 0.4) (decompose_min_complexity 0.4) (decompose_urgent_min_complexity 0.8) (decompose_max_ambiguity 0.8)) &space) act_decompose -1000000000.0)

!(test
  (guard-decompose
    ((act_decompose 10))
    (
      (complexity 0.8)
      (ambiguity 0.2)
      (urgent_flag false)
      (needs_task_plan 0.50)
      (reflective_intent 0.8)
      (needs_external_evidence 0.4)
      (decompose_min_complexity 0.4)
      (decompose_urgent_min_complexity 0.7)
      (decompose_max_ambiguity 0.8)
    )
    &space
  )
  act_decompose 10
)
!(test
  (guard-decompose
    ((act_decompose 10))
    (
      (complexity 0.8)
      (ambiguity 0.2)
      (urgent_flag false)
      (needs_task_plan 0.65)
      (reflective_intent 0.8)
      (needs_external_evidence 0.4)
      (decompose_min_complexity 0.4)
      (decompose_urgent_min_complexity 0.7)
      (decompose_max_ambiguity 0.8)
    )
    &space
  )
  act_decompose 10.1
)
!(test
  (guard-decompose
    ((act_decompose 10))
    (
      (complexity 0.8)
      (ambiguity 0.2)
      (urgent_flag false)
      (needs_task_plan 0.50)
      (reflective_intent 0.8)
      (needs_external_evidence 0.8)
      (decompose_min_complexity 0.4)
      (decompose_urgent_min_complexity 0.7)
      (decompose_max_ambiguity 0.8)
    )
    &space
  )
  act_decompose 9.7
)

; test-case for guard-search-synth

!(test
  (guard-search-synth
    (
      (act_search 10)
      (act_synthesize 10)
    )
    (
      (needs_external_evidence 0.70)
      (needs_task_plan 0.40)
      (needs_multi_source_integration 0.80)
      (verify_request false)
    )
  )
  (
    (act_search 10.42)
    (act_synthesize 10.2)
  )
)

!(test
  (guard-search-synth
    (
      (act_search 10)
      (act_synthesize 10)
    )
    (
      (needs_external_evidence 0.70)
      (needs_task_plan 0.40)
      (needs_multi_source_integration 0.80)
      (verify_request false)
    )
  )
  (
    (act_search 10.42)
    (act_synthesize 10.2)
  )
)


!(test
  (guard-search-synth
    (
      (act_search 10)
      (act_synthesize 10)
    )
    (
      (needs_external_evidence 0.20)
      (needs_task_plan 0.50)
      (needs_multi_source_integration 0.40)
      (verify_request false)
    )
  )
  (
    (act_search 9.82)
    (act_synthesize -1000000000.0)
  )
)

!(test
  (guard-search-synth
    (
      (act_search 10)
      (act_synthesize 10)
    )
    (
      (needs_external_evidence 0.20)
      (needs_task_plan 0.50)
      (needs_multi_source_integration 0.40)
      (verify_request true)
    )
  )
  (
    (act_search 10)
    (act_synthesize 10)
  )
)


!(test
  (guard-search-synth
    (
      (act_search 10)
      (act_synthesize 10)
    )
    (
      (needs_external_evidence 0.40)
      (needs_task_plan 0.50)
      (needs_multi_source_integration 0.80)
      (verify_request true)
    )
  )
  (
    (act_search 10)
    (act_synthesize 10.2)
  )
)

!(test
  (guard-search-synth
    (
      (act_search 10)
      (act_synthesize 10)
    )
    (
      (needs_external_evidence 0.40)
      (needs_task_plan 0.50)
      (needs_multi_source_integration 0.50)
      (verify_request false)
    )
  )
  (
    (act_search 10)
    (act_synthesize -1000000000.0)
  )
)
; guard-search-synth

!(test
  (guard-search-synth
    (
      (act_search 10)
      (act_synthesize 10)
    )
    (
      (needs_external_evidence 0.70)
      (needs_task_plan 0.40)
      (needs_multi_source_integration 0.80)
      (verify_request false)
    )
  )
  (
    (act_search 10.42)
    (act_synthesize 10.2)
  )
)

!(test
  (guard-search-synth
    (
      (act_search 10)
      (act_synthesize 10)
    )
    (
      (needs_external_evidence 0.20)
      (needs_task_plan 0.50)
      (needs_multi_source_integration 0.40)
      (verify_request false)
    )
  )
  (
    (act_search 9.82)
    (act_synthesize -1000000000.0)
  )
)


!(test
  (guard-search-synth
    (
      (act_search 10)
      (act_synthesize 10)
    )
    (
      (needs_external_evidence 0.20)
      (needs_task_plan 0.50)
      (needs_multi_source_integration 0.40)
      (verify_request true)
    )
  )
  (
    (act_search 10)
    (act_synthesize 10)
  )
)
!(test
  (guard-search-synth
    (
      (act_search 10)
      (act_synthesize 10)
    )
    (
      (needs_external_evidence 0.70)
      (needs_task_plan 0.75)
      (needs_multi_source_integration 0.70)
      (verify_request false)
    )
  )
  (
    (act_search 10.3)
    (act_synthesize 9.979999999999999)
  )
)
; here 
; test for apply_search_arbitration
!(test
  (guard-search-arb
    (
      (act_search 10)
      (act_decompose 10)
      (act_synthesize 10)
    )
    (
      (needs_external_evidence 0.20)
      (needs_task_plan 0.50)
      (needs_multi_source_integration 0.40)
    )
  )
  (
    (act_search 10)
    (act_decompose 10)
    (act_synthesize 10)
  )
)
 
!(test
  (guard-search-arb
    (
      (act_search 10)
      (act_decompose 10)
      (act_synthesize 10)
    )
    (
      (needs_external_evidence 0.90)
      (needs_task_plan 0.50)
      (needs_multi_source_integration 0.80)
    )
  )
  (
    (act_search 10.26)
    (act_decompose 9.74)
    (act_synthesize 9.88)
  )
)

!(test
  (guard-search-arb
    (
      (act_search 5)
      (act_decompose 5)
      (act_synthesize 5)
    )
    (
      (needs_external_evidence 0.40)
      (needs_task_plan 0.75)
      (needs_multi_source_integration 0.50)
    )
  )
  (
    (act_search 4.88)
    (act_decompose 5.18)
    (act_synthesize 4.9)
  )
)

!(test
  (guard-search-arb
    (
      (act_search 7)
      (act_decompose 7)
      (act_synthesize 7)
    )
    (
      (needs_external_evidence 0.50)
      (needs_task_plan 0.40)
      (needs_multi_source_integration 0.72)
    )
  )
  (
    (act_search 7)
    (act_decompose 6.84)
    (act_synthesize 7.16)
  )
)
!(test
  (guard-search-arb
    (
      (act_search 10)
      (act_decompose 10)
      (act_synthesize 10)
    )
    (
      (needs_external_evidence 0.20)
      (needs_task_plan 0.50)
      (needs_multi_source_integration 0.40)
    )
  )
  (
    (act_search 10)
    (act_decompose 10)
    (act_synthesize 10)
  )
)
!(test
  (guard-search-arb
    (
      (act_search 3)
      (act_decompose 3)
      (act_synthesize 3)
    )
    (
      (needs_external_evidence 0.70)
      (needs_task_plan 0.55)
      (needs_multi_source_integration 0.72)
    )
  )
  (
    (act_search 3)
    (act_decompose 2.84)
    (act_synthesize 3.16)
  )
)
!(test
  (guard-search-arb
    (
      (act_search 10)
      (act_decompose 10)
      (act_synthesize -1000000000)
    )
    (
      (needs_external_evidence 0.90)
      (needs_task_plan 0.50)
      (needs_multi_source_integration 0.80)
    )
  )
  (
    (act_search 10.26)
    (act_decompose 9.74)
    (act_synthesize -1000000000.0)
  )
)
;

; test for guard-verify
; NOTE: guard-verify takes 3 args: scores ctx space

!(test
  (guard-verify
    (
      (act_verify 10)
      (act_synthesize 10)
    )
    (
      (ambiguity 0.90)
      (threshold 0.60)
      (low_confidence 0.50)
      (failure_wariness 0.40)
      (verify_request true)
      (complexity 0.80)
      (intent_type mixed)
    )
    &space
  )
  (
    (act_verify -1000000000.0)
    (act_synthesize 10)
  )
)

!(test
  (guard-verify
    (
      (act_verify 10)
    )
    (
      (ambiguity 0.40)
      (threshold 0.50)
      (low_confidence 0.30)
      (failure_wariness 0.40)
      (verify_request false)
      (complexity 0.60)
      (intent_type reflective)
    )
    &space
  )
  (
    (act_verify -1000000000.0)
  )
)

!(test
  (guard-verify
    (
      (act_verify 10)
      (act_synthesize 10)
    )
    (
      (ambiguity 0.50)
      (threshold 0.60)
      (low_confidence 0.50)
      (failure_wariness 0.40)
      (verify_request true)
      (complexity 0.60)
      (intent_type mixed)
    )
    &space
  )
  (
    (act_verify 10.45)
    (act_synthesize 9.65)
  )
)
!(test
  (guard-verify
    (
      (act_verify 10)
    )
    (
      (ambiguity 0.50)
      (threshold 0.60)
      (low_confidence 0.50)
      (failure_wariness 0.40)
      (verify_request false)
      (complexity 0.80)
      (intent_type reflective)
    )
    &space
  )
  (
    (act_verify 9.8)
  )
)

!(test
  (guard-verify
    (
      (act_verify 10)
    )
    (
      (ambiguity 0.50)
      (threshold 0.60)
      (low_confidence 0.50)
      (failure_wariness 0.40)
      (verify_request true)
      (complexity 0.60)
      (intent_type mixed)
    )
    &space
  )
  (
    (act_verify 10.45)
  )
)
; test guard-fast-lane
; NOTE: guard-fast-lane takes 3 args: scores ctx space
!(test
  (guard-fast-lane
    (
      (act_verify 10)
      (act_search 10)
      (act_clarify 10)
      (act_think 10)
      (act_respond 10)
    )
    (
      (complexity 0.20)
      (ambiguity 0.20)
      (threshold_signal 0.20)
      (failure_signal 0.20)
      (familiarity_signal 0.80)
      (low_confidence 0.20)
      (verify_request false)
      (help_short 0.50)
    )
    &space
  )
  (
      (act_verify -1000000000.0)
      (act_search -1000000000.0)
      (act_clarify -1000000000.0)
      (act_think -1000000000.0)
      (act_respond 10.60)
  )
)

!(test
  (guard-fast-lane
    (
      (act_verify 10)
      (act_search 10)
      (act_clarify 10)
      (act_think 10)
      (act_respond 10)
    )
    (
      (complexity 0.40)
      (ambiguity 0.30)
      (threshold_signal 0.20)
      (failure_signal 0.20)
      (familiarity_signal 0.85)
      (low_confidence 0.25)
      (verify_request false)
      (help_short 0.60)
    )
    &space
  )
  (
      (act_verify 10)
      (act_search -1000000000.0)
      (act_clarify -1000000000.0)
      (act_think 10)
      (act_respond 10.40)
  )
)
!(test
  (guard-fast-lane
    (
      (act_verify 10)
      (act_search 10)
      (act_clarify 10)
      (act_think 10)
      (act_respond 10)
    )
    (
      (complexity 0.60)
      (ambiguity 0.20)
      (threshold_signal 0.20)
      (failure_signal 0.20)
      (familiarity_signal 0.90)
      (low_confidence 0.20)
      (verify_request false)
      (help_short 0.80)
    )
    &space
  )
  (
      (act_verify 10)
      (act_search 10)
      (act_clarify 10)
      (act_think 10)
      (act_respond 10)
  )
)
!(test
  (guard-fast-lane
    (
      (act_verify 10)
      (act_search 10)
      (act_clarify 10)
      (act_think 10)
      (act_respond 10)
    )
    (
      (complexity 0.10)
      (ambiguity 0.10)
      (threshold_signal 0.10)
      (failure_signal 0.10)
      (familiarity_signal 0.90)
      (low_confidence 0.10)
      (verify_request true)
      (help_short 0.80)
    )
    &space
  )
  (
      (act_verify 10)
      (act_search 10)
      (act_clarify 10)
      (act_think 10)
      (act_respond 10)
  )
)

; test get-preferred
!(test
  (get-preferred factual 0.10 0.10)
  act_search
)
!(test
  (get-preferred reflective 0.10 0.10)
  act_think
)
!(test
  (get-preferred exploratory 0.40 0.10)
  act_search
)
!(test
  (get-preferred exploratory 0.39 0.44)
  act_think
)
!(abs-math 99)

; select-action with tie-breaking
!(test
  (select-action
    (
      (act_search 15)
      (act_think 10)
    )
    (
      (intent_type factual)
      (low_confidence 0.20)
      (threshold 0.30)
    )
    0.10
  )
  (Result (act_search 15)
          (
            (act_search 15)
            (act_think 10)
          )
  )
)
!(test
  (select-action
    (
      (act_search 10)
      (act_think 10)
    )
    (
      (intent_type reflective)
      (low_confidence 0.30)
      (threshold 0.40)
    )
    0.20
  )
  (Result (act_think 10.2001)
          (
            (act_search 10)
            (act_think 10.2001)
          )
  )
)

!(test
  (select-action
    (
      (act_search 12)
      (act_think 12)
    )
    (
      (intent_type factual)
      (low_confidence 0.30)
      (threshold 0.40)
    )
    0.10
  )
  (Result (act_search 12.1001)
          (
            (act_search 12.1001)
            (act_think 12)
          )
  )
)

!(test
  (select-action
    (
      (act_search 20)
      (act_think 10)
    )
    (
      (intent_type reflective)
      (low_confidence 0.50)
      (threshold 0.50)
    )
    0.10
  )
  (Result (act_search 20)
          (
            (act_search 20)
            (act_think 10)
          )
  )
)
; test for get-best-score

!(test
  (get-best-score
    (
      (act_search 10)
      (act_think 5)
    )
  )
  (act_search 10)
)

!(test
  (get-best-score
    (
      (act_search 3)
      (act_think 12)
      (act_decompose 7)
    )
  )
  (act_think 12)
)

!(test
  (get-best-score
    (
      (act_search 8)
      (act_think 8)
    )
  )
  (act_think 8)
)

; test for routing pipeline with guard conditions
;; 1. Full activation path (all guards active, normal routing)
!(test
  (apply-routing-guards
    (
      (act_search 10)
      (act_decompose 10)
      (act_synthesize 10)
      (act_verify 10)
    )
    (
      (needs_external_evidence 0.90)
      (needs_task_plan 0.50)
      (needs_multi_source_integration 0.80)
      (ambiguity 0.50)
      (threshold 0.60)
      (low_confidence 0.50)
      (failure_wariness 0.40)
      (verify_request true)
      (complexity 0.70)
      (intent_type mixed)
      (urgent_flag false)
      (decompose_min_complexity 0.4)
      (decompose_urgent_min_complexity 0.7)
      (decompose_max_ambiguity 0.8)
      (cx 0.60)
      (threshold_signal 0.30)
      (failure_signal 0.30)
      (familiarity_signal 0.60)
      (help_short 0.40)
    )
    &space
  )
  (
    (act_search 10.56)
    (act_decompose 9.44)
    (act_synthesize 9.73)
    (act_verify 10.45)
  )
)
;; 2. Weak external evidence → synth slightly down, search stable
!(test
  (apply-routing-guards
    (
      (act_search 8)
      (act_decompose 8)
      (act_synthesize 8)
      (act_verify 8)
    )
    (
      (needs_external_evidence 0.30)
      (needs_task_plan 0.70)
      (needs_multi_source_integration 0.40)
      (ambiguity 0.40)
      (threshold 0.50)
      (low_confidence 0.30)
      (failure_wariness 0.30)
      (verify_request false)
      (complexity 0.60)
      (intent_type factual)
      (urgent_flag false)
      (decompose_min_complexity 0.4)
      (decompose_urgent_min_complexity 0.7)
      (decompose_max_ambiguity 0.8)
      (cx 0.50)
      (threshold_signal 0.20)
      (failure_signal 0.20)
      (familiarity_signal 0.50)
      (help_short 0.30)
    )
    &space
  )
  (
    (act_search 8)
    (act_decompose 8.1)
    (act_synthesize -1000000000.0)
    (act_verify -1000000000.0)
  )
)