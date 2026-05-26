!(import! &self ../utils)
!(import! &self ../constants)

;; ============================================================
;; Setup a test space
;; ============================================================
!(bind! &space (new-space))

;; Add state with proper structure
!(add-atom &space (state (turn 0)
                         (goal-vector (efficiency 0.6) (accuracy 0.7) (success_moderate 0.62)
                                     (knowledge 0.52) (novelty 0.46) (success_breakthrough 0.44)
                                     (coherence 0.58) (originality 0.48) (social 0.58)
                                     (help_short 0.55) (help_long 0.45) (over_beneficial 0.60)
                                     (over_safety 0.65) (over_honesty 0.65))
                         (modulator-vector (m_urgency 0.5) (m_resolution 0.5) (m_user_expertise 0.5)
                                          (m_threshold 0.5) (m_topic_familiarity 0.5)
                                          (m_failure_wariness 0.40) (m_securing 0.5)
                                          (m_approach 0.5) (m_arousal 0.5) (m_risk_aversion 0.5)
                                          (m_error_tolerance 0.5) (m_creativity 0.5) (m_valence 0.5))
                         (anti-goal-vector)
                         ()))

;; Add alpha atoms (flat in space)
!(add-atom &space (goal_alpha 0.3))
!(add-atom &space (anti_goal_alpha 0.3))

;; Add context atoms (flat key-value pairs)
!(add-atom &space (complexity 0.5))
!(add-atom &space (threshold 0.6))

;; ============================================================
;; getState
;; ============================================================
!(test (getState &space)
  (state (turn 0)
         (goal-vector (efficiency 0.6) (accuracy 0.7) (success_moderate 0.62)
                     (knowledge 0.52) (novelty 0.46) (success_breakthrough 0.44)
                     (coherence 0.58) (originality 0.48) (social 0.58)
                     (help_short 0.55) (help_long 0.45) (over_beneficial 0.60)
                     (over_safety 0.65) (over_honesty 0.65))
         (modulator-vector (m_urgency 0.5) (m_resolution 0.5) (m_user_expertise 0.5)
                          (m_threshold 0.5) (m_topic_familiarity 0.5)
                          (m_failure_wariness 0.40) (m_securing 0.5)
                          (m_approach 0.5) (m_arousal 0.5) (m_risk_aversion 0.5)
                          (m_error_tolerance 0.5) (m_creativity 0.5) (m_valence 0.5))
         (anti-goal-vector)
         ()))

;; ============================================================
;; getAlpha
;; ============================================================
!(test (getAlpha &space goal_alpha) 0.3)
!(test (getAlpha &space anti_goal_alpha) 0.3)
!(test (getAlpha &space nonexistent) ())  ; returns empty for missing

;; ============================================================
;; getGoals / getGoal
;; ============================================================
!(test (getGoal &space efficiency) 0.6)
!(test (getGoal &space accuracy) 0.7)
!(test (getGoal &space success_moderate) 0.62)
!(test (getGoal &space knowledge) 0.52)
!(test (getGoal &space novelty) 0.46)
!(test (getGoal &space success_breakthrough) 0.44)
!(test (getGoal &space coherence) 0.58)
!(test (getGoal &space originality) 0.48)
!(test (getGoal &space social) 0.58)
!(test (getGoal &space help_short) 0.55)
!(test (getGoal &space help_long) 0.45)
!(test (getGoal &space over_beneficial) 0.60)
!(test (getGoal &space over_safety) 0.65)
!(test (getGoal &space over_honesty) 0.65)

;; ============================================================
;; getMods / getMod
;; ============================================================
!(test (getMod &space m_urgency) 0.5)
!(test (getMod &space m_resolution) 0.5)
!(test (getMod &space m_user_expertise) 0.5)
!(test (getMod &space m_threshold) 0.5)
!(test (getMod &space m_topic_familiarity) 0.5)
!(test (getMod &space m_failure_wariness) 0.40)
!(test (getMod &space m_securing) 0.5)
!(test (getMod &space m_approach) 0.5)
!(test (getMod &space m_arousal) 0.5)
!(test (getMod &space m_risk_aversion) 0.5)
!(test (getMod &space m_error_tolerance) 0.5)
!(test (getMod &space m_creativity) 0.5)
!(test (getMod &space m_valence) 0.5)

;; ============================================================
;; getContext
;; ============================================================
!(test (getContext &space complexity) 0.5)
!(test (getContext &space threshold) 0.6)
!(test (getContext &space nonexistent) ())  ; missing key

;; ============================================================
;; getAntiGoals
;; ============================================================
!(test (getAntiGoals &space) (anti-goal-vector))

;; ============================================================
;; matchValue
;; ============================================================
;; ============================================================
;; matchValue - needs full modulator list for index-based access
;; ============================================================
!(test (matchValue m_urgency 
  ((m_urgency 0.5) (m_resolution 0.6) (m_user_expertise 0.7) (m_threshold 0.8)
   (m_topic_familiarity 0.9) (m_failure_wariness 0.40) (m_securing 0.5)
   (m_approach 0.5) (m_arousal 0.5) (m_risk_aversion 0.5)
   (m_error_tolerance 0.5) (m_creativity 0.5) (m_valence 0.7)))
  (m_urgency 0.5))

!(test (matchValue m_valence 
  ((m_urgency 0.5) (m_resolution 0.6) (m_user_expertise 0.7) (m_threshold 0.8)
   (m_topic_familiarity 0.9) (m_failure_wariness 0.40) (m_securing 0.5)
   (m_approach 0.5) (m_arousal 0.5) (m_risk_aversion 0.5)
   (m_error_tolerance 0.5) (m_creativity 0.5) (m_valence 0.7)))
  (m_valence 0.7))

!(test (matchValue m_failure_wariness 
  ((m_urgency 0.5) (m_resolution 0.6) (m_user_expertise 0.7) (m_threshold 0.8)
   (m_topic_familiarity 0.9) (m_failure_wariness 0.40) (m_securing 0.5)
   (m_approach 0.5) (m_arousal 0.5) (m_risk_aversion 0.5)
   (m_error_tolerance 0.5) (m_creativity 0.5) (m_valence 0.7)))
  (m_failure_wariness 0.40))

!(test (matchValue nonexistent 
  ((m_urgency 0.5) (m_resolution 0.6) (m_user_expertise 0.7) (m_threshold 0.8)
   (m_topic_familiarity 0.9) (m_failure_wariness 0.40) (m_securing 0.5)
   (m_approach 0.5) (m_arousal 0.5) (m_risk_aversion 0.5)
   (m_error_tolerance 0.5) (m_creativity 0.5) (m_valence 0.7)))
  "value not found")

;; ============================================================
;; remove-state / addState
;; ============================================================
!(bind! &space2 (new-space))
!(addState &space2 (state (turn 0) () (modulator-vector) (anti-goal-vector) ()))
!(test (getState &space2) (state (turn 0) () (modulator-vector) (anti-goal-vector) ()))
!(remove-state &space2)
!(test (getState &space2) ())  ; state removed

!(println! "All utils tests passed!")