!(import! &self engine-step)
!(import! &self "run_sessions.py")
!(import! &self sessions)


!(bind! &space (new-space))

!(addAlpha &space (alpha))
!(addState &space (state (turn 0) (default-goals) (default-mods) (default-anti-goals) (alpha)))

;; full-step and addContexts now live in engine-step.metta so they can be
;; shared with main/test/sessions_test.metta without re-running the
;; session sweep below on import.

;; run single query 
;;(full-step &space "What is the capital city of France")

;;run multiple queries  
!(let* (
    ($sessions (get-sessions))
    ($results (run-all-sessions &space $sessions))
  )
  $results
)