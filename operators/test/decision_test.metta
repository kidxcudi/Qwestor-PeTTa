!(import! &self ../../utils/general-helper)
!(import! &self ../../utils/utils)
!(import! &self ../appraisal)
!(import! &self ../homeostasis)
!(import! &self ../decision)


!(bind! &space (new-space))
!(bind! &StyleSpace (new-space))

!(addAlpha &space (alpha))
!(addState &space (state (turn 0) (default-goals) (default-mods) (default-anti-goals) (alpha)))
!(add-context &space (context))

; test for selectAction
!(test (selectAction 
  (
    (act_respond -100000000)
    (act_search 0.72)
    (act_verify -100000000)
    (act_clarify -100000000)
    (act_decompose -100000000)
    (act_think 0.7)
    (act_synthesize -100000000)
  )
  factual 0.35 0.44 0.03)
  (act_search ((-100000000 act_clarify) (-100000000 act_decompose) (-100000000 act_respond) (-100000000 act_synthesize) (-100000000 act_verify) (0.7 act_think) (0.7501 act_search))))

!(test (selectAction 
  (
    (act_respond -100000000)
    (act_search 0.90)
    (act_verify -100000000)
    (act_clarify -100000000)
    (act_decompose -100000000)
    (act_think 0.60)
    (act_synthesize -100000000)
  )
  factual 0.35 0.44 0.03)
  (act_search ((-100000000 act_clarify) (-100000000 act_decompose) (-100000000 act_respond) (-100000000 act_synthesize) (-100000000 act_verify) (0.6 act_think) (0.9 act_search))))

!(test (selectAction 
  (
    (act_respond -100000000)
    (act_search 0.80)
    (act_verify -100000000)
    (act_clarify -100000000)
    (act_decompose -100000000)
    (act_think 0.80)
    (act_synthesize -100000000)
  )
  reflective 0.20 0.40 0.05)
  (act_think ((-100000000 act_clarify) (-100000000 act_decompose) (-100000000 act_respond) (-100000000 act_synthesize) (-100000000 act_verify) (0.8 act_search) (0.8501000000000001 act_think))))

; test for goalWeight calculation 
!(test (goalWeight &space) ((efficiency 0.44772) (accuracy 0.6256599999999999) (success_moderate 1.02) (knowledge 0.41340000000000005) (novelty 0.3726) (success_breakthrough 0.37839999999999996) (coherence 0.5655) (originality 0.3504) (social 0.43210000000000004) (help_short 0.5142500000000001) (help_long 0.405) (over_beneficial 0.591) (over_safety 0.6174999999999999) (over_honesty 0.7214999999999999)))
 
 

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


; test for determine-respond-style
!(test (determine-respond-style
  &StyleSpace
  (
    (urgency 0.95)
    (complexity 0.10)
    (ambiguity 0.05)
    (user_expertise 0.5)
    (threshold 0.3)
    (failure_wariness 0.2)
    (low_confidence 0.2)
    (resolution 0.4)
    (approach 0.4)
    (creativity 0.3)
    (risk_aversion 0.2)
    (verify_request false)
  )
) style_concise)

!(test (determine-respond-style
  &StyleSpace
  (
    (urgency 0.1)
    (complexity 0.95)
    (ambiguity 0.4)
    (user_expertise 0.5)
    (threshold 0.4)
    (failure_wariness 0.2)
    (low_confidence 0.3)
    (resolution 0.9)
    (approach 0.4)
    (creativity 0.3)
    (risk_aversion 0.2)
    (verify_request false)
  )
) style_thorough)

!(test (determine-respond-style
  &StyleSpace
  (
    (urgency 0.2)
    (complexity 0.6)
    (ambiguity 0.5)
    (user_expertise 0.5)
    (threshold 0.2)
    (failure_wariness 0.1)
    (low_confidence 0.2)
    (resolution 0.4)
    (approach 0.95)
    (creativity 0.95)
    (risk_aversion 0.05)
    (verify_request false)
  )
) style_exploratory)

!(test (determine-respond-style
  &StyleSpace
  (
    (urgency 0.3)
    (complexity 0.4)
    (ambiguity 0.6)
    (user_expertise 0.6)
    (threshold 0.9)
    (failure_wariness 0.9)
    (low_confidence 0.95)
    (resolution 0.4)
    (approach 0.3)
    (creativity 0.3)
    (risk_aversion 0.9)
    (verify_request true)
  )
) style_cautious)

!(test (determine-respond-style
  &StyleSpace
  (
    (urgency 0.2)
    (complexity 0.3)
    (ambiguity 0.6)
    (user_expertise 0.05)
    (threshold 0.3)
    (failure_wariness 0.2)
    (low_confidence 0.2)
    (resolution 0.3)
    (approach 0.3)
    (creativity 0.3)
    (risk_aversion 0.2)
    (verify_request false)
  )
) style_tutorial)

; test for goalTarget-get

!(test
  (goalTarget-get
    (goal-vector
      (efficiency 0.10)
      (accuracy 0.20)
      (success_moderate 0.30)
      (knowledge 0.40)
      (novelty 0.50)
      (success_breakthrough 0.60)
      (coherence 0.70)
      (originality 0.80)
      (social 0.90)
      (help_short 0.15)
      (help_long 0.25)
      (over_beneficial 0.35)
      (over_safety 0.45)
      (over_honesty 0.55)
    )
    efficiency
  )
  (0.10)
)
!(test
  (goalTarget-get (goal-vector
    (efficiency 0.10)
    (accuracy 0.20)
    (success_moderate 0.30)
    (knowledge 0.40)
    (novelty 0.50)
    (success_breakthrough 0.60)
    (coherence 0.70)
    (originality 0.80)
    (social 0.90)
    (help_short 0.15)
    (help_long 0.25)
    (over_beneficial 0.35)
    (over_safety 0.45)
    (over_honesty 0.55)
  )
  accuracy)
  (0.20)
)
!(test
  (goalTarget-get
    (goal-vector
      (efficiency 0.99)
      (accuracy 0.11)
      (success_moderate 0.22)
      (knowledge 0.33)
      (novelty 0.44)
      (success_breakthrough 0.55)
      (coherence 0.66)
      (originality 0.77)
      (social 0.88)
      (help_short 0.12)
      (help_long 0.13)
      (over_beneficial 0.14)
      (over_safety 0.15)
      (over_honesty 0.16)
    )
    over_honesty
  )
  (0.16)
)

; test antiGoal-get
!(test
  (antiGoal-get
    (anti-goals
      (hallucinate 0.35)
      (redundant   0.30)
      (rabbit_hole 0.28)
      (premature   0.30)
    )
    hallucinate
  )
  (0.35)
)
!(test
  (antiGoal-get
    (anti-goals
      (hallucinate 0.35)
      (redundant   0.30)
      (rabbit_hole 0.28)
      (premature   0.30)
    )
    redundant
  )
  (0.30)
)
!(test
  (antiGoal-get
    (anti-goals
      (hallucinate 0.35)
      (redundant   0.30)
      (rabbit_hole 0.28)
      (premature   0.30)
    )
    premature
  )
  (0.30)
)

; test for updateAntiGoals
!(test (updateAntiGoals &space 0.10 0.20 0.30 0.40) true)
!(test (updateAntiGoals &space 0.50 0.50 0.50 0.50) true)
!(test (updateAntiGoals &space 0.1 0.2 0.3 0.4) true)
!(test (updateAntiGoals &space 0.9 0.8 0.7 0.6) true)

; test for increment-turn , commented out since it will affect the output of post-update
(test (increment-turn &space) 1)
(test (increment-turn &space) 2)
(test (increment-turn &space) 3)

; test for goalTargets
!(test (goalTargets &space act_search) (goal-vector (efficiency 0.59) (accuracy 0.685) (success_moderate 0.685) (knowledge 0.6100000000000001) (novelty 0.69) (success_breakthrough 0.5750000000000001) (coherence 1) (originality 0.675) (social 0.52) (help_short 0.7749999999999999) (help_long 0.615) (over_beneficial 0.615) (over_safety 0.5700000000000001) (over_honesty 0.51)))
!(test (goalTargets &space act_verify) (goal-vector (efficiency 0.59) (accuracy 0.6950000000000001) (success_moderate 0.7350000000000001) (knowledge 0.5800000000000001) (novelty 0.59) (success_breakthrough 0.545) (coherence 1) (originality 0.615) (social 0.5800000000000001) (help_short 0.7649999999999999) (help_long 0.635) (over_beneficial 0.665) (over_safety 0.6200000000000001) (over_honesty 0.5700000000000001)))
!(test (goalTargets &space act_respond) (goal-vector (efficiency 0.64) (accuracy 0.635) (success_moderate 0.6950000000000001) (knowledge 0.51) (novelty 0.59) (success_breakthrough 0.49500000000000005) (coherence 1) (originality 0.605) (social 0.5700000000000001) (help_short 0.8749999999999999) (help_long 0.595) (over_beneficial 0.615) (over_safety 0.55) (over_honesty 0.51)))

; test for antiGoalTargets
!(test (antiGoalTargets &space (goal-vector
  (efficiency 0.60)
  (accuracy 0.70)
  (success_moderate 0.62)
  (knowledge 0.52)
  (novelty 0.46)
  (success_breakthrough 0.44)
  (coherence 0.58)
  (originality 0.48)
  (social 0.58)
  (help_short 0.55)
  (help_long 0.45)
  (over_beneficial 0.60)
  (over_safety 0.65)
  (over_honesty 0.65)
)) (anti-goal-vector (hallucinate 0.5) (redundant 0.7075) (rabbit_hole 0.78) (premature 0.325)))
; test for post-update
!(test (post-update &space act_search) "post-update complete")
 
!(test
   (match &space
      (state (turn $t) $g $m $anti $alpha)
      $t)
   1)

!(test
   (getAntiGoals &space)
   (anti-goals
      (hallucinate 0.836)
      (redundant 0.788116)
      (rabbit_hole 0.715392)
      (premature 0.554704)))
!(match &space
   (state $t $g $m $a $alpha)
   ok)