; ─────────────────────────────────────────────
; main/test/sessions_test_smoke.metta
; ─────────────────────────────────────────────

; --- FORCE IMPORTS IN ORDER SO TRANSPILER RECOGNIZES FUNCTIONS ---
!(import! &self ../../utils/general-helper)
!(import! &self ../../utils/utils)
!(import! &self ../../utils/constants)
!(import! &self state)
!(import! &self ../../operators/homeostasis)
!(import! &self ../../operators/decision)
!(import! &self ../../operators/appraisal)
!(import! &self "../score_action.py")
!(import! &self ../score-actions)
!(import! &self ../../operators/routing)
!(import! &self ../context_parser.py)
!(import! &self ../engine-step)
!(import! &self ../session-eval)
!(import! &self "../run_sessions.py")
!(import! &self "../session_logger.py")

!(bind! &space (new-space))
!(addAlpha &space (alpha))
!(addState &space (state (turn 0) (default-goals) (default-mods) (default-anti-goals) (alpha)))

!(println! "=== SESSIONS SMOKE TEST: Session A only ===")


!(let*
  (
    ($raw (py-call (run_sessions.load_session_a_smoke)))
    ($parsed (parse $raw))
    ($all-records (run-all-sessions-graded &space $parsed))
    ($run-result (py-call (session_logger.write_logs $all-records ".")))
    
    ($run-id (index-atom $run-result 0))
    ($strict-count (index-atom $run-result 1))
    ($turn-count (index-atom $run-result 2))
    
    ($_ (println! ("Logs written under run id:" $run-id)))
    ($_ (println! ("Strict correct:" $strict-count "/" $turn-count)))
  )
  $strict-count
)


!(println! "=== SESSIONS SMOKE TEST complete ===")
