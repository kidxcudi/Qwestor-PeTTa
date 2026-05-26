; ─────────────────────────────────────────────
; operators/test/homeostasis-test.metta
; ─────────────────────────────────────────────

!(import! &self ../../utils/general-helper)
!(import! &self ../../utils/utils)
!(import! &self ../appraisal)
!(import! &self ../decision)
!(import! &self ../homeostasis)

; ── default-center ───────────────────────────
!(test (default-center accuracy)   0.70)
!(test (default-center hallucinate) 0.35)
!(test (default-center threshold)  0.30)
!(test (default-center rabbit_hole) 0.28)

; ── modulator-bounds ─────────────────────────
!(test (modulator-bounds threshold) (0.20 0.95))
!(test (modulator-bounds arousal)   (0.10 0.90))
!(test (modulator-bounds securing)  (0.00 1.00))

; ── _near-boundary ───────────────────────────
!(test (_near-boundary 0.05 0.0 1.0 0.05) True)
!(test (_near-boundary 0.95 0.0 1.0 0.05) True)
!(test (_near-boundary 0.50 0.0 1.0 0.05) False)
!(test (_near-boundary 0.01 0.0 1.0 0.05) True)

; ── _clamp-range ─────────────────────────────
!(test (_clamp-range  1.5 0.0 1.0) 1.0)
!(test (_clamp-range -0.1 0.0 1.0) 0.0)
!(test (_clamp-range  0.5 0.0 1.0) 0.5)
!(test (_clamp-range 0.19 0.20 0.95) 0.20)

; ── _contract-value ──────────────────────────
!(test (_contract-value 0.02 0.0 1.0 0.05 0.10 0.35) 0.053)
!(test (_contract-value 0.50 0.0 1.0 0.05 0.10 0.35) 0.50)
!(test (_contract-value 0.97 0.0 1.0 0.05 0.10 0.35) 0.908)

; ── homeo-contract-goal ──────────────────────
!(bind! &testSpace (new-space))
!(addAlpha &testSpace (alpha))
!(addState &testSpace (state (turn 0) (default-goals) (default-mods) (default-anti-goals) (alpha)))

!(updateGoal &testSpace accuracy 0.02)
!(test (getGoal &testSpace accuracy) 0.02)

!(homeo-contract-goal &testSpace accuracy 0.0 1.0 0.05 0.10)
!(test (getGoal &testSpace accuracy) 0.088)

!(updateGoal &testSpace accuracy 0.65)
!(homeo-contract-goal &testSpace accuracy 0.0 1.0 0.05 0.10)
!(test (getGoal &testSpace accuracy) 0.65)

; ── homeo-contract-anti ──────────────────────
!(bind! &testSpaceAnti (new-space))
!(addAlpha &testSpaceAnti (alpha))
!(addState &testSpaceAnti (state (turn 0) (default-goals) (default-mods) (default-anti-goals) (alpha)))

!(let*
   (($anti (getAntiGoals &testSpaceAnti))
    ($hall (antiGoalGet $anti hallucinate))
    ($red  (antiGoalGet $anti redundant))
    ($rh   (antiGoalGet $anti rabbit_hole))
    ($prem (antiGoalGet $anti premature)))
   (updateAnti-Goals &testSpaceAnti 0.02 $red $rh $prem))

!(homeo-contract-anti &testSpaceAnti hallucinate 0.0 1.0 0.05 0.10)
!(test (antiGoalGet (getAntiGoals &testSpaceAnti) hallucinate) 0.053)

; ── apply-homeostasis (disabled) ─────────────
!(bind! &testSpaceMain (new-space))
!(addAlpha &testSpaceMain (alpha))
!(addState &testSpaceMain (state (turn 0) (default-goals) (default-mods) (default-anti-goals) (alpha)))

!(test (apply-homeostasis &testSpaceMain) true)
!(test (getGoal &testSpaceMain accuracy) 0.70)

; ── apply-homeostasis (enabled) ──────────────
!(bind! &testApplyHomeostasis (new-space))
!(addAlpha &testApplyHomeostasis (
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
    (enable_homeostasis         1)
    (homeostasis_theta_safe     0.55)
    (homeostasis_eta            0.05)
    (homeostasis_alpha_near     0.10)
))
!(addState &testApplyHomeostasis
    (state (turn 0) (default-goals) (default-mods) (default-anti-goals) ()))

!(updateGoal &testApplyHomeostasis accuracy 0.01)
!(apply-homeostasis &testApplyHomeostasis)
!(test (getGoal &testApplyHomeostasis accuracy)       0.07899999999999999)
!(test (getGoal &testApplyHomeostasis over_beneficial) 0.6000000000000001)

!(updateAnti-Goals &testApplyHomeostasis 0.01 0.3 0.3 0.3)
!(apply-homeostasis &testApplyHomeostasis)
!(test (antiGoalGet (getAntiGoals &testApplyHomeostasis) hallucinate) 0.044)

!(updateGoal &testApplyHomeostasis accuracy 0.05)
!(updateGoal &testApplyHomeostasis novelty  0.99)
!(apply-homeostasis &testApplyHomeostasis)
!(test (getGoal &testApplyHomeostasis novelty) 0.937)
