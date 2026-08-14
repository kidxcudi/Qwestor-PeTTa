; ─────────────────────────────────────────────
; main/session-eval.metta
;
; Shared session-grading helpers used by both main/test/sessions_test.metta
; (full run) and main/test/sessions_test_smoke.metta (single-session smoke
; test). Kept separate from engine-step.metta since these functions are
; specific to turn-by-turn evaluation/snapshotting, not the core engine
; step itself.
; ─────────────────────────────────────────────

!(import! &self engine-step)


; ── snapshot helpers ──────────────────────────
; getGoals/getMods/getAntiGoals return (tag (k1 v1) (k2 v2) ...);
; cdr-atom strips the tag so py-call receives a plain pair list.
(= (snapshot-goals $space)      (cdr-atom (getGoals $space)))
(= (snapshot-mods $space)       (cdr-atom (getMods $space)))
(= (snapshot-anti-goals $space) (cdr-atom (getAntiGoals $space)))

; Plain untagged (key value) pairs, matching context_parser.wrap_parser's
; own py-call return convention exactly (result_list.append([key, value]),
; no wrapper tag) rather than introducing an unverified new one.
(= (snapshot-context $space)
   (let* (
      ($complexity  (getContext $space complexity))
      ($threshold   (getContext $space threshold))
      ($ambiguity   (getContext $space ambiguity))
      ($urgent      (getContext $space urgent))
      ($intent      (getContext $space intent_type))
      ($expertise   (getContext $space expertise))
      ($familiarity (getContext $space topic_familiarity))
      ($failure     (getContext $space failure_signal))
      ($verify      (getContext $space verify_request))
      ($reflective  (getContext $space reflective_intent))
      ($ext_ev      (getContext $space needs_external_evidence))
      ($task_plan   (getContext $space needs_task_plan))
      ($multi_src   (getContext $space needs_multi_source_integration))
      ($valence     (getContext $space valence))
   )
   ( (complexity $complexity) (threshold $threshold) (ambiguity $ambiguity) (urgent $urgent)
     (intent_type $intent) (expertise $expertise) (topic_familiarity $familiarity)
     (failure_signal $failure) (verify_request $verify) (reflective_intent $reflective)
     (needs_external_evidence $ext_ev) (needs_task_plan $task_plan)
     (needs_multi_source_integration $multi_src) (valence $valence) )
   )
)


; case-based extractors over full-step's ($best $style $appraisal $sorted)
; return - same confirmed-working pattern as engine-step.metta's
; extract-best/extract-sorted (see reduction_probe3.metta Probe A).
; index-atom on a let*-bound call result was observed extracting from
; the unreduced call term instead of the actual returned value.
(= (step-predicted $result)
   (case $result
     (
       (($b $s $a $sc) $b)
     )
   )
)

(= (step-style $result)
   (case $result
     (
       (($b $s $a $sc) $s)
     )
   )
)

(= (step-sorted $result)
   (case $result
     (
       (($b $s $a $sc) $sc)
     )
   )
)


; ── run one turn, return a flat record tuple ──
; consumed positionally by session_logger.write_logs
(= (run-turn $space $session-name $turn-index $query $expected $acceptable)
   (let*
     (
       ($_ (println! ("[RUN-TURN] Step 1: Snapshots...")))
       ($pre-goals   (snapshot-goals $space))
       ($pre-mods    (snapshot-mods $space))
       ($pre-anti    (snapshot-anti-goals $space))

       ($_ (println! ("[RUN-TURN] Step 2: full-step...")))
       ($step-result (full-step $space $query))
       
       ($_ (println! ("[RUN-TURN] Step 3: Extracting atoms...")))
       ($predicted   (step-predicted $step-result))
       ($style       (step-style $step-result))
       ($sorted      (step-sorted $step-result))

       ($_ (println! ("[RUN-TURN] Step 4: Context...")))
       ($context     (snapshot-context $space))
       
       ($_ (println! ("[RUN-TURN] Step 5: Post snapshots...")))
       ($post-goals  (snapshot-goals $space))
       ($post-mods   (snapshot-mods $space))
       ($post-anti   (snapshot-anti-goals $space))

       ($_ (println! ("[TURN]" $session-name $turn-index $predicted "expected:" $expected)))
     )
     ($session-name $turn-index $query $expected $acceptable $predicted
      $pre-goals $pre-mods $pre-anti $context
      $post-goals $post-mods $post-anti $sorted $style)
   )
)


; ── walk one session's turns (Cons list of (Turn query expected acceptable)) ──
(= (run-session-turns $space $session-name $turns $turn-index)
   (case $turns
     (
       (() ())
       ((Cons $t $rest)
        (let*
          (
            ($query      (index-atom $t 1))
            ($expected   (index-atom $t 2))
            ($acceptable (index-atom $t 3))
            ($record     (run-turn $space $session-name $turn-index $query $expected $acceptable))
          )
          (Cons $record
                (run-session-turns $space $session-name $rest (+ $turn-index 1)))))
     )
   )
)


; ── concat two Cons-lists (no append/flatten builtin assumed) ──
(= (cons-concat $a $b)
   (case $a
     (
       (() $b)
       ((Cons $h $t) (Cons $h (cons-concat $t $b)))
     )
   )
)


; ── walk all sessions (Cons list of (Session name turns)), flatten records ──
(= (run-all-sessions-graded $space $sessions)
   (case $sessions
     (
       (() ())
       ((Cons $s $rest)
        (let*
          (
            ($name  (index-atom $s 1))
            ($turns (index-atom $s 2))
            ($session-records (run-session-turns $space $name $turns 1))
          )
          (cons-concat $session-records (run-all-sessions-graded $space $rest))))
     )
   )
)
