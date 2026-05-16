

; this file is the metta code for the utils/shared-helper.py file in the original codebase

; ─────────────────────────────────────────────
; Clamp helpers
; ─────────────────────────────────────────────

; Clamp a value to [0, 1] 
; this corresponds to the python clamp_to_unit_interval function 
(= (_clamp01 $x)
  (if (and (< $x 1) (> $x 0))
     $x
     (if (>= $x 1)
      1
      0
      )
   )
)
; this corresponds to the python clamp_to_signed_unit_interval function 
; Clamp a value to [-1, 1]
(= (_clamp11 $x)
  (if (and (< $x 1) (> $x -1))
     $x
     (if (>= $x 1)
      1
      -1
      )
   )
)
; remove all states from a space
(= (remove-state $space)
 (let $state (match $space (state $x $y) (state $x $y)) (remove-atom $space $state))
)

; ─────────────────────────────────────────────
; replaceByIndex
; Replace the element at position $index in expression $expr with $new.
; ─────────────────────────────────────────────
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


(= (find_by_key $key $dic_list)
(if (== $dic_list ())
     ()
        (let* (
                (($pair $next) (decons $dic_list))
                ($k (car-atom $pair))
                ($v (cdr-atom $pair))
            )
            (if (== $k $key)
                (superpose $v)
                (find_by_key $key $next)
            )
        )

)
)


; (: add-reduct (-> %Undefined% Expression Bool))
(= (add-reduct $space $f)
   (let* (($headbody (cdr-atom $f))
          ($head (car-atom $headbody))
          ($body (cdr-atom $headbody))
          ($bodyreduced (eval $body)))
         (add-atom $space (= $head $bodyreduced))))
; this corresponds to the python _blend function (core/state/constants.py)
(= (_blend $prev $target $alpha)
   (eval (_clamp01 (+ (* (- 1.0 $alpha) $prev)
                      (* $alpha $target)))))