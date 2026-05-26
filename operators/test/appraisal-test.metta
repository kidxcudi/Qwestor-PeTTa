; ─────────────────────────────────────────────
; operators/test/appraisal-test.metta
; ─────────────────────────────────────────────

!(import! &self ../../utils/general-helper)
!(import! &self ../../utils/utils)
!(import! &self ../appraisal)

; ── space setup ──────────────────────────────
!(bind! &space (new-space))
!(addAlpha &space (alpha))
!(add-context &space (context))
!(addState &space (state (turn 0) (default-goals) (default-mods) (default-anti-goals) (alpha)))

; ── getMods / getMod ─────────────────────────
!(test (getMods &space) (default-mods))
!(test (getMod &space m_urgency)          0.20)
!(test (getMod &space m_failure_wariness) 0.10)
!(test (getMod &space m_error_tolerance)  0.45)

; ── getGoals ─────────────────────────────────
!(test (getGoals &space) (default-goals))

; ── getState ─────────────────────────────────
!(test (getState &space)
       (state (turn 0) (default-goals) (default-mods) (default-anti-goals) (alpha)))

; ── remove-state / getState returns empty ────
!(test (
    let* (
        ($_ (remove-state &space))
        ($s  (getState &space))
    ) $s) ())

; Add state back for remaining tests
!(addState &space (state (turn 0) (default-goals) (default-mods) (default-anti-goals) (alpha)))

; ── getContext ───────────────────────────────
!(test (getContext &space complexity)        0.30)
!(test (getContext &space intent_type)       mixed)
!(test (getContext &space reflective_intent) 0.50)

; ── getAlpha ─────────────────────────────────
!(test (getAlpha &space urgency_alpha) 0.60)
!(test (getAlpha &space valence_alpha) 0.40)
!(test (getAlpha &space intent_margin) 0.12)

; ── update-mods ──────────────────────────────
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
        ($new-mods (getMods &space))
    ) $new-mods)
    (modulator-vector
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

; ── getAntiGoals ─────────────────────────────
!(test (getAntiGoals &space) (default-anti-goals))
