! Copyright (C) 2019 KUSUMOTO Norio.
! See http://factorcode.org/license.txt for BSD license.

USING:
accessors kernel sequences arrays words.symbol models namespaces
locals words strings quotations math fry classes.parser lists
generic assocs classes.singleton lexer combinators continuations 
combinators.short-circuit classes classes.tuple ; 

IN: karakuri


SYMBOLS: undefined-fsm ;
SYMBOLS: undefined-state initial-state ;
SYMBOLS: undefined-event event-none ;
    
TUPLE: fsm < model
    { super-state   symbol initial: undefined-state }
    { states        array  initial: { } }
    { transitions   array  initial: { } }
    { start-state   symbol initial: undefined-state }
    { state         symbol initial: initial-state }
    { event         symbol initial: event-none }
    { transitioned?        initial: f }
    { info }
    { memo }
    { label        string initial: "" } ;

TUPLE: fsm-state
    { super-fsm    symbol initial: undefined-fsm }
    { sub-fsms     array  initial: { } }
    { info }
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
    { info }
    { memo }
    { label        string initial: "" }
    { action-label string initial: "" } 
    { guard-label  string initial: "" } ;

TUPLE: fsm-event
    { info }
    { memo }
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

ERROR: secondary-fsm-transition ;
    
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
HOOK: trans-action dispatcher ( -- )
HOOK: trans-guard? dispatcher ( -- ? )

M: word state-entry ;
M: word state-do ;
M: word state-exit ;
M: word trans-action ;
M: word trans-guard? t ;

<PRIVATE

:: transitions-for ( fsm-obj state-symbol -- transitions )
    fsm-obj transitions>> 
    [ get-global from-state>> state-symbol = ]
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


:: transition ( trans-symbol fsm-obj -- )
    trans-symbol
    { [ get-global exit-path>> [
            dispatcher set state-exit
        ] each ]                 
      [ dispatcher set trans-action ]
      [ get-global entry-path>> [
            [ dispatcher set state-entry ]
            [ dup get-global super-fsm>> get-global state<< ]
            [ [ name>> ]
              [ get-global super-fsm>> get-global ]
              bi set-model ]
            tri
        ] each ]
      [ get-global exit-path>> { } = not [ ! not internal transition
            trans-symbol get-global 
            to-state>> get-global sub-fsms>> [ 
                initialise-fsm 
            ] each 
        ] when ]
    } cleave ; 


:: initial-state->start-state ( fsm-obj -- )
    fsm-obj start-state>> :> start-state
    start-state
    [ fsm-obj state<< ]
    [ name>> fsm-obj set-model ]                
    [ dispatcher set state-entry ]
    tri ;


: set-transitioned ( fsm-symbol -- )
    get-global t swap transitioned?<< ; inline


!    super-state>> dup undefined-state = not [ 
!        get-global super-fsm>> dup undefined-fsm = not [
!            set-transitioned
!        ] [ drop ] if
!    ] [ drop ] if ;

PRIVATE>

: raise-fsm-event ( fsm-symbol event-symbol -- )
    swap get-global event<< ; inline


:: update ( fsm-symbol -- )
    fsm-symbol get-global :> fsm-obj
    fsm-obj super-state>> undefined-state = [
        f fsm-obj transitioned?<<
    ] when 
    fsm-obj state>> initial-state = [
        fsm-obj initial-state->start-state
    ] when
    fsm-obj state>>
    [ dispatcher set state-do ]
    [ get-global sub-fsms>> [
          [ get-global fsm-obj
            [ transitioned?>> swap transitioned?<< ] 
            [ event>> swap event<< ]
            2bi ]
          [ update ]
          [ get-global transitioned?>> fsm-obj transitioned?<< ] 
          tri 
      ] each ]
    bi

    fsm-obj transitioned?>> not [         
        fsm-obj current-transitions
        [| trans-symbol |
         fsm-obj transitioned?>> not [         
             trans-symbol get-global event>> 
             fsm-obj event>> = [
                 trans-symbol dispatcher set trans-guard? [
                     trans-symbol fsm-obj transition
                     fsm-symbol set-transitioned
                 ] when
             ] when
         ] when
        ] each
    ] when

    fsm-obj event-none swap event<< ;


:: update-with ( fsm-symbol event-symbol -- )
    fsm-symbol event-symbol raise-fsm-event
    fsm-symbol update ; inline


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

    
:: setup-transition ( trans-symbol
                      from-state
                      to-state/f
                      event-symbol  --  )
    
    trans-symbol get-global
    [ from-state swap from-state<< ]
    [ event-symbol swap event<< ]
    [ to-state/f dup [ drop undefined-state ] unless swap to-state<< ]
    tri ;


:: setup-transitions ( trans-defines -- )
    trans-defines [ 
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


:: go-up-fsm-tree ( fsm-symbol path -- fsm-symbol' )
    fsm-symbol get-global super-state>> :> s
    s get-global sub-fsms>> first fsm-symbol = not [
        secondary-fsm-transition
    ] when
    s path push
    s get-global super-fsm>> ;

PRIVATE>
    
:: set-transitions ( fsm-symbol trans-symbols -- )
    { } clone fsm-symbol get-global transitions<<
    trans-symbols 
    [| trans-symbol |
     trans-symbol fsm-symbol get-global transitions>> swap suffix
     fsm-symbol get-global transitions<<
     
     trans-symbol get-global to-state>> :> e
     trans-symbol get-global from-state>> :> s
     V{ } clone :> exit-path!
     V{ } clone :> entry-path!

     e undefined-state = [ ! internal transition
         s trans-symbol get-global from-state<<
         s trans-symbol get-global to-state<<         
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
                         trans-symbol s e direct-descent-transition
                     ] when
                     [ branch-fsm-from exit-path go-up-fsm-tree 
                       branch-fsm-from! 
                     ] [ ] [ 
                         trans-symbol s e no-root-transition 
                     ] cleanup 
                 ] times
             ] when
             s-depth e-depth < [
                 e-depth s-depth - [
                     branch-fsm-to get-global super-state>> s = [
                         trans-symbol s e direct-descent-transition
                     ] when
                     [ branch-fsm-to entry-path go-up-fsm-tree 
                       branch-fsm-to! 
                     ] [ ] [ 
                         trans-symbol s e no-root-transition 
                     ] cleanup 
                 ] times
             ] when

             [ branch-fsm-from branch-fsm-to = not ] [
                 branch-fsm-from get-global super-state>> undefined-state =
                 branch-fsm-to get-global super-state>> undefined-state = or [
                     trans-symbol s e no-root-transition
                 ] when
                 [ branch-fsm-from exit-path go-up-fsm-tree branch-fsm-from!
                   branch-fsm-to entry-path go-up-fsm-tree branch-fsm-to! ]
                 [ ] [ 
                     trans-symbol s e no-root-transition 
                 ] cleanup 
             ] while
         ] when
     ] if

     exit-path >array trans-symbol get-global exit-path<< 
     entry-path reverse >array trans-symbol get-global entry-path<< 
    ] each ;


