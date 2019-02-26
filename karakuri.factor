! Copyright (C) 2019 KUSUMOTO Norio.
! See http://factorcode.org/license.txt for BSD license.

USING: accessors constructors kernel sequences arrays words.symbol models  io 
namespaces locals words strings quotations math classes.parser classes.singleton
lexer combinators continuations combinators.short-circuit lists
graphviz graphviz.notation graphviz.render formatting fry prettyprint ;

IN: karakuri

SYMBOLS: undefined-fsm ;
SYMBOLS: undefined-state fsm-start ;
SYMBOLS: undefined-event event-none ;
    
TUPLE: fsm < model
    { super-state    symbol initial: undefined-state }
    { states         array  initial: { } }
    { transitions    array  initial: { } }
    { start-state    symbol initial: undefined-state }
    { current-state  symbol initial: fsm-start }
    { raising-event  symbol initial: event-none } 
    { label          string initial: "" } ;

TUPLE: fsm-state
    { super-fsm      symbol initial: undefined-fsm }
    { sub-fsms       array  initial: { } }
    { label          string initial: "" }
    { entry-label    string initial: "" }
    { do-label       string initial: "" }
    { exit-label     string initial: "" } ;

TUPLE: fsm-transition
    { from-state     symbol initial: undefined-state }
    { to-state       symbol initial: undefined-state }
    { entry-path     array  initial: { } }
    { exit-path      array  initial: { } }
    { event          symbol initial: undefined-event }
    { label          string initial: "" }
    { action-label   string initial: "" } 
    { guard?-label   string initial: "" } ;

TUPLE: fsm-event
    { info }
    { label          string initial: "" } ;


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
      [ <fsm> swap set-global ]
      \ call
      [ suffix! ] tri@
    ] each-token ;

SYNTAX: STATES:
    ";"
    [ create-class-in dup define-singleton-class
      [ fsm-state new swap set-global ]
      \ call
      [ suffix! ] tri@
    ] each-token ;

SYNTAX: TRANSITIONS:
    ";"
    [ create-class-in dup define-singleton-class
      [ fsm-transition new swap set-global ]
      \ call
      [ suffix! ] tri@
    ] each-token ;

SYNTAX: EVENTS:
    ";"
    [ create-class-in dup define-singleton-class
      [ fsm-event  new swap set-global ]
      \ call
      [ suffix! ] tri@
    ] each-token ;


<PRIVATE SYMBOL: dispatcher PRIVATE>

HOOK: state-entry dispatcher ( -- )
HOOK: state-do dispatcher ( -- )
HOOK: state-exit dispatcher ( -- )
HOOK: transition-action dispatcher ( -- )
HOOK: transition-guard? dispatcher ( -- ? )

M: word state-entry ;
M: word state-do ;
M: word state-exit ;
M: word transition-action ;
M: word transition-guard? t ;

<PRIVATE

: transitions-for ( fsm-obj state-symbol -- transitions )
    [ transitions>> ] dip
    [ swap get-global from-state>> = ] curry
    filter ;

: current-transitions ( fsm-obj -- transitions )
    dup current-state>> transitions-for ;

:: transition ( transition-symbol fsm-obj -- )
    transition-symbol
    [ get-global exit-path>> [
          dispatcher set state-exit
      ] each
    ]                 
    [ dispatcher set transition-action ]
    [ get-global entry-path>> [
          [ dispatcher set state-entry ]
          [ dup get-global super-fsm>> get-global current-state<< ]
          [ [ name>> ]
            [ get-global super-fsm>> get-global ]
            bi set-model ]
          tri
      ] each
    ]
    tri ;

:: fsm-start==>start-state ( fsm-obj -- )
    fsm-obj start-state>> :> start-state
    start-state {
        [ get-global super-fsm>> get-global
          dup start-state>> swap current-state<< ]
        [ dispatcher set state-entry ]
        [ [ name>> ]
          [ get-global super-fsm>> get-global ]
          bi set-model ]                
        [ get-global sub-fsms>> [
              get-global fsm-start==>start-state
          ] each ]
    } cleave ;

PRIVATE>

: raise-fsm-event ( fsm-symbol event-symbol -- )
    swap get-global raising-event<< ;


:: update ( fsm-symbol -- )
    fsm-symbol get-global :> fsm-obj
    fsm-obj current-state>> fsm-start = [
        fsm-obj fsm-start==>start-state
    ] [
        fsm-obj current-state>> :> current-state
        current-state 
        [ dispatcher set state-do ]
        [ get-global sub-fsms>> [ update ] each ]
        bi
        fsm-obj current-state>> current-state = [ ! no transition
            fsm-obj current-transitions           !  by sub-state
            [| transition-symbol |
             transition-symbol get-global event>>
             fsm-obj raising-event>> = [
                 transition-symbol dispatcher set
                 transition-guard? [
                     transition-symbol fsm-obj transition
                     event-none fsm-obj raising-event<<
                 ] when
             ] when     
            ] each
        ] when
    ] if
    fsm-obj event-none swap raising-event<< ;


:: set-states ( fsm-symbol state-symbols  -- )
    state-symbols
    [ fsm-symbol get-global states<< ]
    [ first fsm-symbol get-global start-state<< ]
    [ [ fsm-symbol swap get-global super-fsm<< ] each ]
    tri ;

:: set-sub-fsms ( state-symbol sub-fsms -- )
    sub-fsms state-symbol get-global sub-fsms<< 
    sub-fsms [ 
        state-symbol swap get-global super-state<< 
    ] each

    state-symbol get-global super-fsm>> :> test-fsm!
    { } clone :> super-fsm-chain!
    [ { [ test-fsm undefined-fsm = not ]
        [ test-fsm get-global super-state>> undefined-state = not ]
        [ test-fsm get-global super-state>>
          get-global super-fsm>> undefined-fsm = not ]
      } 0&& ] [
        test-fsm super-fsm-chain member? [
            test-fsm state-symbol circular-reference-definition
        ] when
        test-fsm super-fsm-chain push
        test-fsm get-global super-state>> get-global super-fsm>> test-fsm!
    ] while ;

    
:: setup-transition ( transition-symbol
                      from-state
                      to-state
                      event-symbol  -- )
    
    transition-symbol get-global
    [ from-state swap from-state<< ]
    [ event-symbol swap event<< ]
    [ to-state swap to-state<< ]
    tri ;


<PRIVATE

:: check-fsm-depth ( state-symbol -- n )
    state-symbol get-global super-fsm>> get-global :> v-fsm-obj!
    0 :> v-depth!
    [ v-fsm-obj super-state>> undefined-state = not ] [
        v-depth 1 + v-depth! 
        v-fsm-obj super-state>>
        get-global super-fsm>> get-global v-fsm-obj!
    ] while
    v-depth ;

:: up-fsm-tree ( fsm-symbol path -- upped-fsm-symbol )
    fsm-symbol get-global super-state>> :> s
    s path push
    s get-global super-fsm>> ;

PRIVATE>

:: set-transitions ( fsm-symbol transition-symbols -- )
    transition-symbols 
    [| transition-symbol |
     transition-symbol fsm-symbol get-global transitions>> swap suffix
     fsm-symbol get-global transitions<<
     
     transition-symbol get-global to-state>> :> e
     transition-symbol get-global from-state>> :> s
     V{ } clone :> exit-path!
     V{ } clone :> entry-path!
     
     e s = not [
         s check-fsm-depth :> s-depth 
         e check-fsm-depth :> e-depth
         s get-global super-fsm>> :> branch-fsm-from!
         e get-global super-fsm>> :> branch-fsm-to!
         s exit-path push
         e entry-path push
     
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
             branch-fsm-from get-global super-state>> undefined-state =
             branch-fsm-to get-global super-state>> undefined-state = or [
                 transition-symbol s e no-root-transition
             ] when
             branch-fsm-from exit-path up-fsm-tree 
             branch-fsm-from!
             branch-fsm-to entry-path up-fsm-tree 
             branch-fsm-to!
             branch-fsm-to entry-path up-fsm-tree 
             branch-fsm-to!
         ] while
     ] when

     exit-path >array transition-symbol get-global exit-path<<
     entry-path reverse >array transition-symbol get-global entry-path<<
    ] each ;


:: describe-fsm ( graph fsm-symbol -- graph' )
    graph
    "true" =newrank
    fsm-symbol <cluster>
    "same" =rank
    [node "circle" =shape "rounded,filled" =style "black" =fillcolor
     "0.2" =width "" =label  ];
    fsm-symbol "%s-fsm-start" sprintf 1array add-nodes

    fsm-symbol get-global states>>
    [| state |
     [node "box" =shape "rounded,filled" =style "white" =fillcolor "" =width
      state =label ];
     state add-node
    ] each

    fsm-symbol  =label
    fsm-symbol get-global states>> [
        get-global sub-fsms>> [
            describe-fsm
        ] each
    ] each
    "max" =rank
    add ;

:: describe-super-state-sub-fsms ( fsm-symbol -- )
    fsm-symbol get-global states>>
    [| state |
     state get-global sub-fsms>>
     [| fsm |
      state
      fsm get-global start-state>>
      fsm "cluster_%s" sprintf
      '[ _ _ [-> _ =lhead "back" =dir 
              "odiamond" =arrowtail "true" =constraint ]; ] call( -- )
      fsm describe-super-state-sub-fsms
     ] each
    ] each ;
         
:: describe-transitions ( fsm-symbol -- )
    fsm-symbol "%s-fsm-start" sprintf
    fsm-symbol get-global start-state>>
    '[ _ _ [-> "false" =constraint ]; ] call( -- )

    fsm-symbol get-global transitions>>
    [| transition-symbol |
     transition-symbol get-global
     [ from-state>> ]
     [ to-state>> ]
     bi 
     transition-symbol get-global event>>
     '[ _ _ [-> _ =label "false" =constraint ]; ] call( -- )
    ] each

    fsm-symbol get-global states>> [
        get-global sub-fsms>> [
            describe-transitions
        ] each
    ] each ;

:: preview-fsm ( fsm-symbol size/f -- )
    <digraph>
    "true" =compound
    "TB" =rankdir
    "true" =newrank
    "dot" =layout
    size/f [ =size ] when*

    "false" =newrank
    [node "circle" =shape "rounded,filled" =style "black" =fillcolor
     "0.2" =width "" =label  ];
    fsm-symbol "%s-fsm-start" sprintf add-node

    fsm-symbol get-global states>>
    [| state |
     [node "box" =shape "rounded,filled" =style "white" =fillcolor "" =width
      state =label ];
     state add-node
    ] each

    fsm-symbol  =label
    fsm-symbol get-global states>> [
        get-global sub-fsms>> [
            describe-fsm
        ] each
    ] each

    fsm-symbol describe-transitions
    fsm-symbol describe-super-state-sub-fsms
    
    preview ;
