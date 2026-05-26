; ─────────────────────────────────────────────
; utils/test/general-helper-test.metta
; ─────────────────────────────────────────────

!(import! &self ../general-helper)
!(import! &self ../utils)

!(bind! &TestSpace (new-space))

; ── _clamp01 ─────────────────────────────────
!(test (_clamp01  0.5)  0.5)
!(test (_clamp01   -9)  0)
!(test (_clamp01    3)  1)
!(test (_clamp01    1)  1)
!(test (_clamp01    0)  0)

; ── _clamp11 ─────────────────────────────────
!(test (_clamp11    0)  0)
!(test (_clamp11  0.5)  0.5)
!(test (_clamp11   -9) -1)
!(test (_clamp11    3)  1)
!(test (_clamp11    1)  1)
!(test (_clamp11   -1) -1)

; ── replaceByIndex ───────────────────────────
!(test (replaceByIndex (a b c) 0 x) (x b c))
!(test (replaceByIndex (a b c) 1 x) (a x c))
!(test (replaceByIndex (a b c) 2 x) (a b x))
!(test (replaceByIndex (a) 0 x)     (x))
!(test (replaceByIndex () 0 x)      ())
!(test (replaceByIndex (a b c) 3 x) (a b c))
!(test (replaceByIndex (a b c) -1 x) (a b c))

; ── find_by_key ──────────────────────────────
!(test (find_by_key color ((color red) (size 10))) red)
!(test (find_by_key size  ((color red) (size 10))) 10)
!(test (find_by_key c ((a 1) (b 2))) ())

; ── _blend ───────────────────────────────────
; ── _blend ───────────────────────────────────
!(test (_blend 0 0 0)    0)
!(test (_blend 0 0 1)    0)
!(test (_blend 1 1 0)    1)
!(test (_blend 1 1 1)    1)
!(test (_blend 0 1 0.5)  0.5)
!(test (_blend 0 1 0.25) 0.25)
!(test (_blend 0 1 0.75) 0.75)


; ── remove-state ─────────────────────────────
; FIX: old test added (state 1 2) — a 2-field atom.
; remove-state matches the real 5-field shape.
!(add-atom &TestSpace (state (turn 0) (goal-vector) (modulator-vector) (anti-goals) ()))
!(remove-state &TestSpace)
!(test (getState &TestSpace) ())
