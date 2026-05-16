(= (space-anti-goals $space)
   (let* (
     ($anti (get-atoms $space))
   )
   $anti
   )
)

(= (score-all-actions $space $appraisal $weights)
   (let* (
     ($scores (py-call (score_action.compute_scores
                          $appraisal
                          $weights
                          $space)))
     ($final_scores (parse $scores))
   )
   $final_scores
   )
)