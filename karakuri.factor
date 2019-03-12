! Copyright (C) 2019 KUSUMOTO Norio.
! See http://factorcode.org/license.txt for BSD license.
!
! ver. 0.2

USING:
accessors kernel sequences arrays words.symbol models namespaces
locals words strings quotations math fry classes.parser lists
generic assocs classes.singleton lexer combinators continuations
combinators.short-circuit classes classes.tuple ;

IN: karakuri


SYMBOLS: undefined-fsm ;
SYMBOLS: undefined-state initial-state ;
SYMBOLS: undefined-event event-none ;
SYMBOLS: state-entry state-exit state-do ;
SYMBOLS: guard-none action-none ;


TUPLE: fsm < model
    { super-state   symbol initial: undefined-state }
    { states        array  initial: { } }
    { start-state   symbol initial: undefined-state }
    { state         symbol initial: initial-state }
    { event         symbol initial: event-none }
    { transitioned?        initial: f }
    { info                 initial: f }
    { memo                 initial: f } ;


TUPLE: fsm-state
    { super-fsm    symbol initial: undefined-fsm }
    { sub-fsms     array  initial: { } }
    { transitions  array  initial: { } }
    { info                initial: f }
    { memo                initial: f } ;


TUPLE: fsm-transition
    { from-state   symbol initial: undefined-state }
    { to-state     symbol initial: undefined-state }
    { entry-path   array  initial: { } }
    { exit-path    array  initial: { } }
    { event        symbol initial: undefined-event }
    { guard               initial: guard-none }
    { action              initial: action-none }
    { info                initial: f }
    { memo                initial: f } ;


TUPLE: fsm-event
    { info }
    { memo } ;


ERROR: no-root-transition
    from-state
    to-state ;


ERROR: direct-descent-transition
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


SYNTAX: EVENTS:
    ";"
    [ create-class-in dup define-singleton-class
      [ fsm-event  new swap set-global ]
      \ call
      [ suffix! ] tri@
    ] each-token ;


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
    V{ } clone :> super-fsm-chain!
    [ { [ test-fsm undefined-fsm = not ]
        [ test-fsm get-global super-state>> undefined-state = not ]
        [ test-fsm get-global super-state>>
          get-global super-fsm>> undefined-fsm = not ]
      } 0&& ] [
        test-fsm super-fsm-chain member? [
            test-fsm state-symbol circular-reference-definition
        ] when
        test-fsm super-fsm-chain push
        test-fsm get-global super-state>> get-global
        super-fsm>> test-fsm!
    ] while ;


:: set-sub-fsm ( state-symbol sub-fsm -- )
    state-symbol sub-fsm 1array set-sub-fsms ;


:: setup-transition ( from-state trans-define -- trans-obj )
    from-state trans-define first4
    fsm-transition new
    swap dup [ drop action-none ] unless >>action
    swap dup [ drop guard-none ] unless >>guard
    swap dup [ drop event-none ] unless >>event
    swap dup [ drop undefined-state ] unless >>to-state
    swap >>from-state ;

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

:: set-transitions ( state-symbol trans-defines -- )
    { } clone state-symbol get-global transitions<<
    trans-defines
    [| trans-define |
     state-symbol trans-define setup-transition :> trans-obj
     trans-obj state-symbol get-global transitions>> swap suffix
     state-symbol get-global transitions<<

     trans-obj to-state>> :> e
     trans-obj from-state>> :> s
     V{ } clone :> exit-path!
     V{ } clone :> entry-path!

     e undefined-state = [ ! internal transition
         s trans-obj from-state<<
         s trans-obj to-state<<
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
                         s e direct-descent-transition
                     ] when
                     [ branch-fsm-from exit-path go-up-fsm-tree
                       branch-fsm-from!
                     ] [ ] [
                         s e no-root-transition
                     ] cleanup
                 ] times
             ] when
             s-depth e-depth < [
                 e-depth s-depth - [
                     branch-fsm-to get-global super-state>> s = [
                         s e direct-descent-transition
                     ] when
                     [ branch-fsm-to entry-path go-up-fsm-tree
                       branch-fsm-to!
                     ] [ ] [
                         s e no-root-transition
                     ] cleanup
                 ] times
             ] when

             [ branch-fsm-from branch-fsm-to = not ] [
                 branch-fsm-from get-global super-state>> undefined-state =
                 branch-fsm-to get-global super-state>> undefined-state = or [
                     s e no-root-transition
                 ] when
                 [ branch-fsm-from exit-path go-up-fsm-tree branch-fsm-from!
                   branch-fsm-to entry-path go-up-fsm-tree branch-fsm-to! ]
                 [ ] [
                     s e no-root-transition
                 ] cleanup
             ] while
         ] when
     ] if

     exit-path >array trans-obj exit-path<<
     entry-path reverse >array trans-obj entry-path<<
    ] each ;

<PRIVATE

:: exec-trans-action ( trans-obj -- )
    trans-obj action>> action-none = not [
        trans-obj action>> execute( -- )
    ] when ;


:: exec-trans-guard? ( trans-obj -- ? )
    trans-obj guard>> guard-none = [
        t
    ] [
        trans-obj guard>> execute( -- ? )
    ] if ;


:: exec-state-do ( state-symbol -- )
    state-symbol get-global transitions>>
    [| trans-obj |
        trans-obj event>> state-do = [
            trans-obj exec-trans-action
        ] when
    ] each ;


:: exec-state-entry ( state-symbol -- )
    state-symbol get-global transitions>>
    [| trans-obj |
        trans-obj event>> state-entry = [
            trans-obj exec-trans-action
        ] when
    ] each ;


:: exec-state-exit ( state-symbol -- )
    state-symbol get-global transitions>>
    [| trans-obj |
        trans-obj event>> state-exit = [
            trans-obj exec-trans-action
        ] when
    ] each ;


: initialise-fsm ( fsm-symbol -- )
    get-global
    {
        [ state>> dup initial-state = not [
              exec-state-exit
          ] [
              drop
          ] if ]
        [ dup start-state>> swap state<< ]
        [ dup start-state>> name>> swap set-model ]
        [ start-state>> exec-state-entry ]
        [ states>> [
              get-global sub-fsms>> [
                  initialise-fsm
              ] each
          ] each ]
    } cleave ;


:: transition ( trans-obj -- )
    trans-obj
    { [ exit-path>> [
            exec-state-exit
        ] each ]
      [ exec-trans-action ]
      [ entry-path>> [
            [ exec-state-entry ]
            [ dup get-global super-fsm>> get-global state<< ]
            [ [ name>> ]
              [ get-global super-fsm>> get-global ]
              bi set-model ]
            tri
        ] each ]
      [ exit-path>> { } = not [
            trans-obj to-state>> get-global sub-fsms>> [
                initialise-fsm
            ] each
        ] when ]
    } cleave ;


:: initial-state->start-state ( fsm-obj -- )
    fsm-obj start-state>> :> start-state
    start-state
    [ fsm-obj state<< ]
    [ name>> fsm-obj set-model ]
    [ exec-state-entry ]
    tri ;


: set-transitioned ( fsm-symbol -- )
    get-global t swap transitioned?<< ; inline

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
    [ exec-state-do ]
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
        fsm-obj state>> get-global transitions>>
        [| trans-obj |
         fsm-obj transitioned?>> not [
             trans-obj event>>
             fsm-obj event>> = [
                 trans-obj exec-trans-guard? [
                     trans-obj transition
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
