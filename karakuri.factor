! Copyright (C) 2019 KUSUMOTO Norio.
! See http://factorcode.org/license.txt for BSD license.

USING: accessors constructors kernel sequences arrays words.symbol models
       namespaces locals words strings quotations math fry classes.parser 
       lists generic assocs classes.singleton lexer combinators continuations 
       combinators.short-circuit classes classes.tuple ; 

IN: karakuri


SYMBOLS: undefined-fsm ;
SYMBOLS: undefined-state initial-state ;
SYMBOLS: undefined-event event-none ;
    
TUPLE: fsm < model
    { super-state  symbol initial: undefined-state }
    { states       array  initial: { } }
    { transitions  array  initial: { } }
    { start-state  symbol initial: undefined-state }
    { state        symbol initial: initial-state }
    { event        symbol initial: event-none } 
    { label        string initial: "" } ;

TUPLE: fsm-state
    { super-fsm    symbol initial: undefined-fsm }
    { sub-fsms     array  initial: { } }
    { memo }
    { label        string initial: "" }
    { entry-label  string initial: "" }
    { do-label     string initial: "" }
    { exit-label   string initial: "" } ;

TUPLE: fsm-transition
    { from-state   symbol initial: undefined-state }
    { to-state     symbol initial: undefined-state }
    { entry-path   array  initial: { } }
    { exit-path    array  initial: { } }
    { event        symbol initial: undefined-event }
    { label        string initial: "" }
    { action-label string initial: "" } 
    { guard-label  string initial: "" } ;

TUPLE: fsm-event
    { info }
    { label        string initial: "" } ;


ERROR: no-root-transition
    transition
    from-state
    to-state ;


ERROR: direct-descent-transition
    transition
    from-state
    to-state ;


ERROR: circular-reference-definition
    fsm
    state ;
    
<PRIVATE

: <fsm> ( -- fsm )
    initial-state name>> fsm new-model ;

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
HOOK: action dispatcher ( -- )
HOOK: guard? dispatcher ( -- ? )

M: word state-entry ;
M: word state-do ;
M: word state-exit ;
M: word action ;
M: word guard? t ;

<PRIVATE

: transitions-for ( fsm-obj state-symbol -- transitions )
    [ transitions>> ] dip
    [ swap get-global from-state>> = ] curry
    filter ;


: current-transitions ( fsm-obj -- transitions )
    dup state>> transitions-for ;


: initialise-fsm ( fsm-symbol -- )
    get-global
    {
        [ state>> initial-state = not [
              dispatcher set state-exit
          ] when* ]
        [ dup start-state>> swap state<< ]
        [ dup start-state>> name>> swap set-model ]
        [ start-state>> dispatcher set state-entry ]
        [ states>> [
              get-global sub-fsms>> [
                  initialise-fsm
              ] each
          ] each ]
    } cleave ;


:: transition ( transition-symbol fsm-obj -- )
    transition-symbol
    { [ get-global exit-path>> [
            dispatcher set state-exit
        ] each ]                 
      [ dispatcher set action ]
      [ get-global entry-path>> [
            [ dispatcher set state-entry ]
            [ dup get-global super-fsm>> get-global state<< ]
            [ [ name>> ]
              [ get-global super-fsm>> get-global ]
              bi set-model ]
            tri
        ] each ]
      [ get-global exit-path>> { } = not [ ! not internal transition
            transition-symbol get-global 
            to-state>> get-global sub-fsms>> [ 
                initialise-fsm 
            ] each 
        ] when ]
    } cleave ; 


:: initial-state==>start-state ( fsm-obj -- )
    fsm-obj start-state>> :> start-state
    start-state
    [ fsm-obj state<< ]
    [ name>> fsm-obj set-model ]                
    [ dispatcher set state-entry ]
    tri ;


: set-event-none ( fsm-symbol -- )
    get-global dup event-none swap event<<
    super-state>> dup undefined-state = not [ 
        get-global super-fsm>> dup undefined-fsm = not [
            set-event-none
        ] [ drop ] if
    ] [ drop ] if ;

PRIVATE>

: raise-fsm-event ( fsm-symbol event-symbol -- )
    swap get-global event<< ;


:: update ( fsm-symbol -- )
    fsm-symbol get-global :> fsm-obj
    fsm-obj state>> initial-state = [
        fsm-obj initial-state==>start-state
    ] when
    fsm-obj state>> :> state
    state 
    [ dispatcher set state-do ]
    [ get-global sub-fsms>> [
          [ get-global fsm-symbol get-global event>> swap event<< ]
          [ update ]
          bi 
      ] each ]
    bi
    fsm-obj current-transitions
    [| transition-symbol |
     transition-symbol get-global event>> fsm-obj event>> = [
         transition-symbol dispatcher set guard? [
             transition-symbol fsm-obj transition
             fsm-symbol set-event-none
         ] when
     ] when     
    ] each
    fsm-obj event-none swap event<< ;


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


:: set-sub-fsm ( state-symbol sub-fsm -- )
    state-symbol sub-fsm 1array set-sub-fsms ;

    
:: setup-transition ( transition-symbol
                      from-state
                      to-state/f
                      event-symbol  --  )
    
    transition-symbol get-global
    [ from-state swap from-state<< ]
    [ event-symbol swap event<< ]
    [ to-state/f dup [ drop undefined-state ] unless swap to-state<< ]
    tri ;


:: setup-transitions ( transition-defines -- )
    transition-defines [ 
        [ ] clone :> x!    
        [ x swap suffix x! ] each 
        x \ setup-transition suffix call( -- ) 
    ] each ;

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
    { } clone fsm-symbol get-global transitions<<
    transition-symbols 
    [| transition-symbol |
     transition-symbol fsm-symbol get-global transitions>> swap suffix
     fsm-symbol get-global transitions<<
     
     transition-symbol get-global to-state>> :> e
     transition-symbol get-global from-state>> :> s
     V{ } clone :> exit-path!
     V{ } clone :> entry-path!

     e undefined-state = [ ! internal transition
         s transition-symbol get-global from-state<<
         s transition-symbol get-global to-state<<         
     ] [
         s exit-path push
         e entry-path push
         e s = not [
             s check-fsm-depth :> s-depth 
             e check-fsm-depth :> e-depth
             s get-global super-fsm>> :> branch-fsm-from!
             e get-global super-fsm>> :> branch-fsm-to!
             
             s-depth e-depth > [
                 s-depth e-depth - [ 
                     branch-fsm-from get-global super-state>> e = [
                         transition-symbol s e direct-descent-transition
                     ] when
                     branch-fsm-from exit-path up-fsm-tree 
                     branch-fsm-from!
                 ] times
             ] when
             s-depth e-depth < [
                 e-depth s-depth - [
                     branch-fsm-to get-global super-state>> s = [
                         transition-symbol s e direct-descent-transition
                     ] when
                     branch-fsm-to entry-path up-fsm-tree 
                     branch-fsm-to!
                 ] times
             ] when

             [ branch-fsm-from branch-fsm-to = not ] [
                 branch-fsm-from get-global super-state>> undefined-state =
                 branch-fsm-to get-global super-state>> undefined-state = or [
                     transition-symbol s e no-root-transition
                 ] when
                 branch-fsm-from exit-path up-fsm-tree branch-fsm-from!
                 branch-fsm-to entry-path up-fsm-tree branch-fsm-to!
                 branch-fsm-to entry-path up-fsm-tree branch-fsm-to!
             ] while
         ] when
     ] if

     exit-path >array transition-symbol get-global exit-path<< 
     entry-path reverse >array transition-symbol get-global entry-path<< 
    ] each ;


