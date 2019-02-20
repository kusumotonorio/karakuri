! Copyright (C) 2019 KUSUMOTO Norio.
! See http://factorcode.org/license.txt for BSD license.

USING: accessors constructors kernel sequences arrays words.symbol models  io 
namespaces locals words strings quotations math classes.parser
classes.singleton lexer combinators continuations combinators.short-circuit ;

IN: karakuri


SYMBOLS: undefined-fsm ;
SYMBOLS: undefined-state fsm-start fsm-end ;
SYMBOLS: undefined-event event-none ;
    
TUPLE: fsm < model
    { super-state    symbol   initial: undefined-state }
    { states         sequence initial: { } }
    { transitions    sequence initial: { } }
    { start-state    symbol   initial: undefined-state }
    { current-state  symbol   initial: fsm-start }
    { raising-event  symbol   initial: event-none } 
    { label          string   initial: "" } ;

TUPLE: fsm-state
    { super-fsm      symbol   initial: undefined-fsm }
    { sub-fsms       sequence initial: { } }
    { label          string   initial: "" }
    { entry-label    string   initial: "" }
    { do-label       string   initial: "" }
    { exit-label     string   initial: "" } ;

TUPLE: fsm-transition
    { from-state     symbol   initial: undefined-state }
    { to-state       symbol   initial: undefined-state }
    { entry-path     sequence initial: { } }
    { exit-path      sequence initial: { } }
    { event          symbol   initial: undefined-event }
    { label          string   initial: "" }
    { action-label   string   initial: "" } 
    { guard?-label   string   initial: "" } ;

TUPLE: fsm-event
    { label          string   initial: "" } ;


ERROR: no-root-transition
    transition
    from-state
    to-state ;

ERROR: circular-reference-definition
    fsm
    state ;
    
<PRIVATE

: <fsm> ( -- fsm )
    fsm-start name>> fsm new-model ;

PRIVATE>

SYNTAX: FSMS:
    ";"
    [ create-class-in dup define-singleton-class
      [ <fsm> swap set ]
      \ call
      [ suffix! ] tri@
    ] each-token ;

SYNTAX: STATES:
    ";"
    [ create-class-in dup define-singleton-class
      [ fsm-state new swap set ]
      \ call
      [ suffix! ] tri@
    ] each-token ;

SYNTAX: TRANSITIONS:
    ";"
    [ create-class-in dup define-singleton-class
      [ fsm-transition new swap set ]
      \ call
      [ suffix! ] tri@
    ] each-token ;

SYNTAX: EVENTS:
    ";"
    [ create-class-in dup define-singleton-class
      [ fsm-event  new swap set ]
      \ call
      [ suffix! ] tri@
    ] each-token ;


<PRIVATE SYMBOL: dispatcher PRIVATE>

HOOK: fsm-entry dispatcher ( -- )
HOOK: fsm-do dispatcher ( -- )
HOOK: fsm-exit dispatcher ( -- )
HOOK: fsm-action dispatcher ( -- )
HOOK: fsm-guard? dispatcher ( -- ? )

M: word fsm-entry ;
M: word fsm-do ;
M: word fsm-exit ;
M: word fsm-action ;
M: word fsm-guard? t ;

<PRIVATE

: transitions-for ( fsm-obj state-symbol -- transitions )
    [ transitions>> ] dip
    [ swap get from-state>> = ] curry
    filter ;

: current-transitions ( fsm-obj -- transitions )
    dup current-state>> transitions-for ;

:: transition ( transition-symbol fsm-obj -- )
    transition-symbol
    [ get exit-path>> [
          dispatcher set fsm-exit
      ] each ]                 
    [ dispatcher set fsm-action ]
        [ get to-state>> fsm-end = not [
            transition-symbol get entry-path>> [
                [ dispatcher set fsm-entry ]
                [ dup get super-fsm>> get current-state<< ]
                [ [ name>> ]
                  [ get super-fsm>> get ]
                  bi set-model ]
                tri
            ] each
          ] when ]
    tri ;

:: fsm-start==>start-state ( fsm-obj -- )
    fsm-obj start-state>> :> start-state
    start-state fsm-end = not [
        start-state {
            [ get super-fsm>> get
              dup start-state>> swap current-state<< ]
            [ dispatcher set fsm-entry ]
            [ [ name>> ]
              [ get super-fsm>> get ]
              bi set-model ]                
            [ get sub-fsms>> [
                  get fsm-start==>start-state
              ] each ]
        } cleave
    ] when ;

PRIVATE>

: raise-fsm-event ( fsm-symbol event-symbol -- )
    swap get raising-event<< ;


:: update ( fsm-symbol -- )
    fsm-symbol get :> fsm-obj
    fsm-obj current-state>> fsm-end = not [
        fsm-obj current-state>> fsm-start = [
            fsm-obj fsm-start==>start-state
        ] [
            fsm-obj current-state>> :> current-state
            current-state 
            [ dispatcher set fsm-do ]
            [ get sub-fsms>> [ update ] each ]
            bi
            fsm-obj current-state>> current-state = [ ! no transition
                fsm-obj current-transitions           !  by sub-state
                [| transition-symbol |
                 transition-symbol get event>>
                 fsm-obj raising-event>> = [
                     transition-symbol dispatcher set
                     fsm-guard? [
                         transition-symbol fsm-obj transition
                         event-none fsm-obj raising-event<<
                     ] when
                 ] when     
                ] each
            ] when
        ] if
    ] when
    fsm-obj event-none swap raising-event<< ;


:: set-states ( fsm-symbol state-symbols  -- )
    state-symbols
    [ fsm-symbol get states<< ]
    [ first fsm-symbol get start-state<< ]
    [ [ fsm-symbol swap get super-fsm<< ] each ]
    tri ;

:: set-sub-fsms ( state-symbol sub-fsms -- )
    sub-fsms state-symbol get sub-fsms<< 
    sub-fsms [ 
        state-symbol swap get super-state<< 
    ] each

    state-symbol get super-fsm>> :> test-fsm!
    V{ } :> super-fsm-chain!
    [ { [ test-fsm undefined-fsm = not ]
        [ test-fsm get super-state>> undefined-state = not ]
        [ test-fsm get super-state>> get super-fsm>> undefined-fsm = not ]
      } 0&& ] [
        test-fsm super-fsm-chain member? [
            test-fsm state-symbol circular-reference-definition
        ] when
        test-fsm super-fsm-chain push
        test-fsm get super-state>> get super-fsm>> test-fsm!
    ] while ;

    
:: setup-transition ( transition-symbol
                      from-state
                      to-state
                      event-symbol  -- )
    
    transition-symbol get
    [ from-state swap from-state<< ]
    [ event-symbol swap event<< ]
    [ to-state swap to-state<< ]
    tri ;


<PRIVATE

:: check-fsm-depth ( state-symbol -- n )
    state-symbol get super-fsm>> get :> v-fsm-obj!
    0 :> v-depth!
    [ v-fsm-obj super-state>> undefined-state = not ] [
        v-depth 1 + v-depth! 
        v-fsm-obj super-state>> get super-fsm>> get v-fsm-obj!
    ] while
    v-depth ;

:: up-fsm-tree ( fsm-symbol path -- upped-fsm-symbol )
    fsm-symbol get super-state>> :> s
    s path push
    s get super-fsm>> ;

PRIVATE>

:: set-transitions ( fsm-symbol transition-symbols -- )
    transition-symbols 
    [| transition-symbol |
     transition-symbol fsm-symbol get transitions>> swap suffix
     fsm-symbol get transitions<<
     
     transition-symbol get to-state>> :> e
     transition-symbol get from-state>> :> s
     s check-fsm-depth :> s-depth 
     e check-fsm-depth :> e-depth
     s get super-fsm>> :> branch-fsm-from!
     e get super-fsm>> :> branch-fsm-to!
     V{ s } :> exit-path
     V{ e } :> entry-path
     
     s-depth e-depth > [
         s-depth e-depth - [ 
             branch-fsm-from exit-path up-fsm-tree 
             branch-fsm-from!
         ] times
     ] [
         s-depth e-depth < [
             e-depth s-depth - [
                 branch-fsm-to entry-path up-fsm-tree 
                 branch-fsm-to!
             ] times
         ] when
     ] if

     [ branch-fsm-from branch-fsm-to = not ] [
         branch-fsm-from get super-state>> undefined-state =
         branch-fsm-to get super-state>> undefined-state = or [
             transition-symbol s e no-root-transition
         ] when
         branch-fsm-from exit-path up-fsm-tree 
         branch-fsm-from!
         branch-fsm-to entry-path up-fsm-tree 
         branch-fsm-to!
         branch-fsm-to entry-path up-fsm-tree 
         branch-fsm-to!
     ] while

     exit-path transition-symbol get exit-path<<
     entry-path reverse! transition-symbol get entry-path<<
    ] each ;
