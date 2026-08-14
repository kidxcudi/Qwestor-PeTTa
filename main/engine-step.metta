; ─────────────────────────────────────────────
; main/engine-step.metta
; Shared single-turn engine step, extracted out of main-loop.metta
; ─────────────────────────────────────────────

!(import! &self "context_parser.py")
!(import! &self ../utils/general-helper)
!(import! &self ../utils/utils)
!(import! &self ../utils/constants)
!(import! &self state)
!(import! &self ../operators/homeostasis)
!(import! &self ../operators/decision)
!(import! &self ../operators/appraisal)
!(import! &self "score_action.py")
!(import! &self score-actions)
!(import! &self ../operators/routing)

; --- Context Clearing Fix ---
; collapse catches the failure if the atom doesn't exist, returning an empty list ().
; case then ensures we return exactly one result (True) if empty, preventing branching!
(= (remove-if-exists $space $pattern)
   (let $results (collapse (match $space $pattern $pattern))
        (if (== $results ())
            True
            (let $atom (car-atom $results)
                 (remove-atom $space $atom)))))

(= (clear-context $space)
   (let* (
     ($_ (remove-if-exists $space (complexity $v)))
     ($_ (remove-if-exists $space (threshold $v)))
     ($_ (remove-if-exists $space (ambiguity $v)))
     ($_ (remove-if-exists $space (urgent $v)))
     ($_ (remove-if-exists $space (intent_type $v)))
     ($_ (remove-if-exists $space (expertise $v)))
     ($_ (remove-if-exists $space (topic_familiarity $v)))
     ($_ (remove-if-exists $space (failure_signal $v)))
     ($_ (remove-if-exists $space (verify_request $v)))
     ($_ (remove-if-exists $space (reflective_intent $v)))
     ($_ (remove-if-exists $space (needs_external_evidence $v)))
     ($_ (remove-if-exists $space (needs_task_plan $v)))
     ($_ (remove-if-exists $space (needs_multi_source_integration $v)))
     ($_ (remove-if-exists $space (valence $v)))
   )
   cleared))

(= (addContexts $space $context)
   (let* (
     ($_ (clear-context $space))
   )
   (if (== $context ())
        (add-context $space (context))
        (add-context $space $context))))


; --- Helpers to force transpiler to evaluate selectAction ---
(= (get-best $scores $intent $lc $thr $margin)
   (case (selectAction $scores $intent $lc $thr $margin)
     ( (($b $s) $b) )
   )
)

(= (get-sorted $scores $intent $lc $thr $margin)
   (case (selectAction $scores $intent $lc $thr $margin)
     ( (($b $s) $s) )
   )
)

(= (full-step $space $query)
   (let*
     (
       ($context-list (py-call (context_parser.wrap_parser $query)))
       ($_ (addContexts $space $context-list))
       ($_ (println! ("[STEP 1] context-list:" $context-list)))

       ($appraisal (appraisalModulator $space))
       ($_ (println! ("[STEP 2] appraisal:" $appraisal)))

       ($weights (goalWeight $space))
       ($_ (println! ("[STEP 3] weights:" $weights)))

       ($scores (score-all-actions $space $appraisal $weights))
       ($_ (println! ("[STEP 4] scores:" $scores)))

       ($guarded (apply-routing-guards $scores $appraisal $space))
       ($_ (println! ("[STEP 5] guarded:" $guarded)))

       ($intent  (find_by_key intent_type $appraisal))
       ($lc      (find_by_key low_confidence $appraisal))
       ($thr     (find_by_key threshold $appraisal))
       ($margin  (getAlpha $space intent_margin))

       ($best          (get-best $guarded $intent $lc $thr $margin))
       ($sorted_scores (get-sorted $guarded $intent $lc $thr $margin))

       ($_ (println! ("[STEP 6] best:" $best "sorted:" $sorted_scores)))

       ($style
         (if (== $best act_respond)
             (determine-respond-style $space $appraisal)
             no-style))
       ($_ (println! ("[STEP 7] style:" $style)))

       ($_ (post-update $space $best))
       ($_ (println! ("[STEP 8] post-update done")))
       ($_ (println! ("[Final Result]:" $best $style $appraisal)))

     )
     ($best $style $appraisal $sorted_scores)
    )
)