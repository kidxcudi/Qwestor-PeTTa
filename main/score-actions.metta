(= (space-anti-goals $space)
   (let* (
     ($anti (collapse (get-atoms $space)))
   )
   $anti
   )
)

(= (score-all-actions $space $appraisal $weights)
   (let* (
     ($space-atoms (collapse (get-atoms $space)))
     ($scores (py-call (score_action.compute_scores
                          $appraisal
                          $weights
                          $space-atoms)))
     ($final_scores (parse $scores))
   )
   $final_scores
   )
)