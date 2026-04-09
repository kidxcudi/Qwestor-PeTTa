!(import! &self ../space)
!(import! &self ../appraisal)
!(import! &self ../action)
!(import! &self ../decision)
!(import! &self ../../main/main-loop)
!(import! &self ../../utils/general-helper)

; --------------- adding state and parameters to the space ---------------
!(bind! &space (new-space))
!(addAlpha &space (alpha))
!(addContexts &space (context))

!(addState &space (state (turn 0) (default-goals) (default-mods) (default-anti-goals) (alpha)))
; !(match  &space (state $x $y $z) (state $x $y $z))

; --------------- adding actions to the space -----------------------------
; !(let $x (goalWeight &space) $x)
!(addActions &space (Actions &space))
; !(update-goal &space kcnowledge 0.7)
; ── example usage ───────────────────────────────────────────
; !(selectAction ((act_think 0.7) (act_search 0.72)) factual 0.35 0.44 0.03)
; !(getGoal &space over_honesty)
; !(let $x (goalWeight &space) $x)
; !(match  &space (AG $action $params) (AG $action $params))
; !(getGoals &space)
;!(update-goal &space over_honesty 0.99997)
; !(getGoal &space over_honesty)
; !(goalWeight &space)
; !(appraisalModulator &space)

!(----------------------------------------------------------------------------------)

;; Test for getMods and getMod
!(test (getMods &space) (default-mods))
!(test (getMod &space m_urgency) 0.20)
!(test (getMod &space m_failure_wariness) 0.1)
!(test (getMod &space m_error_tolerance) 0.45)

;; Test for get-goals
!(test (get-goals &space) (default-goals))

;; Test for get_state
!(test (get_state &space) (state (turn 0) (default-goals) (default-mods) (default-anti-goals) (alpha)))

;; Test for remove-state and add-state
!(test (
      let* (
      ($_ (remove-state &space))
      ($state (get_state &space))
      ) $state) ())
; Add state back to the space for further testing
!(addState &space (state (turn 0) (default-goals) (default-mods) (default-anti-goals) (alpha)))

;; Test for getContext
!(test (getContext &space complexity) 0.30)
!(test (getContext &space intent_type) mixed)
!(test (getContext &space reflective_intent) 0.50)

;; Test for getAlpha
!(test (getAlpha &space urgency_alpha) 0.60)
!(test (getAlpha &space valence_alpha) 0.40)
!(test (getAlpha &space intent_margin) 0.12)


;; Test for update-mods
!(test (
      let* (
      ($_ (update-mods &space (
            (m_urgency           0.10)
            (m_resolution        0.40)
            (m_user_expertise    0.50)
            (m_threshold         0.30)
            (m_topic_familiarity 0.60)
            (m_failure_wariness  0.10)
            (m_securing          0.10)
            (m_approach          0.40)
            (m_arousal           0.40)
            (m_risk_aversion     0.20)
            (m_error_tolerance   0.45)
            (m_creativity        0.45)
            (m_valence           0.13)
      )))
      ($new_mods (getMods &space))
      ) $new_mods)
      (     modulator-vector
            (m_urgency           0.10)
            (m_resolution        0.40)
            (m_user_expertise    0.50)
            (m_threshold         0.30)
            (m_topic_familiarity 0.60)
            (m_failure_wariness  0.10)
            (m_securing          0.10)
            (m_approach          0.40)
            (m_arousal           0.40)
            (m_risk_aversion     0.20)
            (m_error_tolerance   0.45)
            (m_creativity        0.45)
            (m_valence           0.13)
      )
)

;; Test for calculate-mod
; TODO: add tests for calculate-modulator function

;; Test for getAntiGoals
!(test (getAntiGoals &space) (default-anti-goals))
