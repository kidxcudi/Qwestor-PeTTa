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


!(bind! &space (new-space))

!(addAlpha &space (alpha))
!(addState &space (state (turn 0) (default-goals) (default-mods) (default-anti-goals) (alpha)))


(= (addContexts $space $context)
   (if (== $context ())
        (add-context $space (context))
        (add-context $space $context)))

 
(= (full-step $space $query)
   (let*
     (
       ($context-list (py-call (context_parser.wrap_parser $query)))
       ($_ (addContexts $space $context-list))
       ($_ (println! ("[STEP 1] context-list: "$context-list)))  

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
       ($result  (selectAction $guarded $intent $lc $thr $margin))

       ($_ (println! ("[STEP 6] result:" $result)))
       ($best    (car-atom $result))

       ($style
         (if (== $best act_respond)
             (determine-respond-style $space $appraisal)
             no-style))
       ($_ (println! ("[STEP 7] style:" $style)))

       ($_ (post-update $space $best))
       ($_ (println! ("[STEP 8] post-update done")))
 
      
     )
     ($best $style $appraisal)
    )
)

!(full-step &space "What is overfitting in one short sentence?")
