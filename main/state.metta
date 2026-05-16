; (import! &self "context.py")


; type signiture
; x=GxM where G=goal(goal) vector and M= modulator vector
;  (..................... energy affiliation competence )
(: Context Type)
; (: context (-> Atom Number Context))
(: State Type)

; Alpha values (learning rates) control update speed
    ; (= (alpha) ((urgency_alpha 0.60)         ; How fast urgency adapts
    ; (resolution_alpha 0.45)      ; How fast resolution adapts  
    ; (expertise_alpha 0.45)       ; How fast user expertise estimate adapts
    ; (threshold_alpha 0.40)       ; How fast confidence threshold adapts
    ; (familiarity_alpha 0.35)     ; How fast topic familiarity adapts
    ; (failure_alpha 0.55)         ; How fast failure wariness INCREASES
    ; (failure_decay 0.20)         ; How fast failure wariness DECAYS (opposite of alpha)
    ; (securing_alpha 0.45)        ; How fast securing/caution adapts
    ; (approach_alpha 0.40)        ; How fast approach/exploration adapts
    ; (arousal_alpha 0.40)         ; How fast arousal adapts
    ; (risk_aversion_alpha 0.45)   ; How fast risk aversion adapts
    ; (error_tolerance_alpha 0.40) ; How fast error tolerance adapts
    ; (creativity_alpha 0.40)      ; How fast creativity adapts
    ; (valence_alpha 0.40)))        ; How fast emotional valence adapts


(= (add-state $space)
    (add-atom $space $state)
)

(= (remove-state $space)
 (let $state (match $space (state $x $y $z) (state $x $y $z)) (remove-atom $space $state))
)

(= (replaceByIndex $expr $index $new)
    (if (== $expr ())
        $expr
        (let*
            (
                ($first (car-atom $expr))
                ($tail (cdr-atom $expr))
            )
            (if (== $index 0)
                (if (== $tail ())
                    ($new)
                    (cons-atom $new $tail)
                )
                (let $c (replaceByIndex $tail (- $index 1) $new)
                    (cons-atom $first $c)
                )))))





(= (update-single-mods $space $mod-list) 
(if (== () $mod-list)
      (println! ("update-completed")

      (let* (
         ($h (car-atom $mod-list))
         ($t (cdr-atom $mod-list))
         ($name (car-atom $h))
         ($val (cdr-atom $h))
         ($_ (update-modulator $space $name $val))
         )
         (update-mods $space $t)
      ))
)
)

(= (update-modulator $space $name $value)
    (let*
     (
        ($current-goal-vec (getGoals $space))
        ($current-modulator (cdr-atom (get-mods $space)))
        ($update-modulator  (case $name 
        ( 
        (m_urgency (replaceByIndex $current-modulator 0 ($name $value)))
        (m_resolution (replaceByIndex $current-modulator 1 ($name $value)))
        (m_user_expertise (replaceByIndex $current-modulator 2 ($name $value)))
        (m_threshold (replaceByIndex $current-modulator 3 ($name $value)))
        (m_topic_familiarity (replaceByIndex $current-modulator 4 ($name $value)))
        (m_failure_wariness (replaceByIndex $current-modulator 5 ($name $value)))
        (m_securing (replaceByIndex $current-modulator 6 ($name $value)))
        (m_approach (replaceByIndex $current-modulator 7 ($name $value)))
        (m_arousal (replaceByIndex $current-modulator 8 ($name $value)))
        (m_risk_aversion (replaceByIndex $current-modulator 9 ($name $value)))
        (m_error_tolerance (replaceByIndex $current-modulator 10 ($name $value)))
        (m_creativity (replaceByIndex $current-modulator 11 ($name $value)))
        (m_valence (replaceByIndex $current-modulator 12 ($name $value)))            
        
        )))
        ; here the function goes through the logic of monadic(D) computation using different formulas and logic but it is to show how the space works 
        ($updated-state (state $current-goal-vec (cons modulator-vector $update-modulator)))
        ($_ (remove-state $space))
        ($_ (add-state $space $updated-state))
        
     )
      (println! (update success 🎉))
      )
)