
!(import! &self ../general-helper)
!(bind! &TestSpace (new-space))


!(test (_clamp01 0.5) 0.5)
!(test (_clamp01 -9) 0)
!(test (_clamp01 3) 1)
!(test (_clamp01 1) 1)
!(test (_clamp01 0) 0)

!(test (_clamp11 0) 0)
!(test (_clamp11 0.5) 0.5)
!(test (_clamp11 -9) -1)
!(test (_clamp11 3) 1)
!(test (_clamp11 1) 1)
!(test (_clamp11 -1) -1)


!(add-atom &TestSpace (state 1 2))
!(get-atoms &TestSpace)
!(test (remove-state &TestSpace) true)
 
!(test (replaceByIndex (a b c) 1 x) (a x c))
!(test (replaceByIndex (a b c) 0 x) (x b c))
!(test (replaceByIndex (a b c) 2 x) (a b x))
!(test (replaceByIndex (a) 0 x) (x))
!(test (replaceByIndex () 0 x) ())
!(test (replaceByIndex (a b c) 3 x) (a b c))
!(test (replaceByIndex (a b c) -1 x) (a b c))

  
!(test (find_by_key a ((a 1) (b 2))) 1)
!(test (find_by_key b ((a 1) (b 2))) 2)
!(test (find_by_key c ((a 1) (b 2))) ())



!(test (add-reduct &TestSpace (= x (+ 1 2))) ())
!(get-atoms &TestSpace)

 
!(test (_blend 0 0 0) 0)     
!(test (_blend 0 0 1) 0)      
!(test (_blend 1 1 0) 1)      
!(test (_blend 1 1 1) 1)      

!(test (_blend 0 1 0.5) 0.5)
!(test (_blend 0 1 0.25) 0.25)
!(test (_blend 0 1 0.75) 0.75)
