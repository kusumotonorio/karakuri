! Copyright (C) 2019 KUSUMOTO Norio.
! See http://factorcode.org/license.txt for BSD license.
USING: tools.test karakuri namespaces combinators accessors ;
IN: karakuri.tests

FSMS:        f1 f2 ;
STATES:      s1 s2 s3 s1-1 s1-2 ;
TRANSITIONS: t1 t2 t3 t4 t5 t6 ;
EVENTS:      e1 e2 e3 e4 e5 e6 ;

f1 { s1 s2 } set-states
s1 { f2 } set-sub-fsms
f2 { s1-1 s1-2 } set-states

t1 s1 s2   e1 setup-transition ! S1 --> S2 if event1
t2 s2 s1   e2 setup-transition
t3 s1 s1   e3 setup-transition


! t3 s2 s1-1 e2 setup-transition ! S2 --> S1 & S1-1 if event2  
! t4 s3 s1-2 e3 setup-transition

f1 { t1 t2 t3 } set-transitions

{ s1 s2 { s1 } { s2 } e1 }
[
    t1 get-global
    { [ from-state>> ] [ to-state>> ]
      [ exit-path>> ] [ entry-path>> ] [ event>> ]
    } cleave
] unit-test

{ s2 s1 { s2 } { s1 } e2 }
[
    t2 get-global
    { [ from-state>> ] [ to-state>> ]
      [ exit-path>> ] [ entry-path>> ] [ event>> ]
    } cleave
] unit-test

{ s1 s1 { s1 } { s1 } e3 }
[
    t3 get-global
    { [ from-state>> ] [ to-state>> ]
      [ exit-path>> ] [ entry-path>> ] [ event>> ]
    } cleave
] unit-test


! t5 s1-1 s1-2 e4 setup-transition
! t6 s1-2 s1-1 e5 setup-transition
! f2 { t5 t6 } set-transitions



