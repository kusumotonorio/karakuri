! Copyright (C) 2019 KUSUMOTO Norio.
! See http://factorcode.org/license.txt for BSD license.
! ver. 0.2

USING:
accessors kernel sequences arrays words.symbol models namespaces
locals words strings quotations math fry classes.parser lists
generic assocs classes.singleton lexer combinators continuations
combinators.short-circuit classes classes.tuple parser ;

IN: karakuri

<PRIVATE

SYMBOLS: undefined-fsm ;
SYMBOLS: undefined-state initial-state ;
SYMBOLS: undefined-event event-always ;
SYMBOLS: guard-none action-none ;

PRIVATE>

SYMBOL: event-none
SYMBOLS: state-entry state-exit state-do ;

TUPLE: fsm < model
    { super-state    symbol initial: undefined-state }
    { states         array  initial: { } }
    { start-state    symbol initial: undefined-state }
    { state          symbol initial: initial-state }
    { event          symbol initial: event-none }
    { memory-type?          initial: f }
    { transitioned?         initial: f } ;

TUPLE: fsm-state
    { super-fsm    symbol initial: undefined-fsm }
    { sub-fsms     array  initial: { } }
    { transitions  array  initial: { } } ;

TUPLE: fsm-transition
    { fsm          symbol initial: undefined-fsm }
    { from-state   symbol initial: undefined-state }
    { to-state     symbol initial: undefined-state }
    { entry-chain  array  initial: { } }
    { exit-chain   array  initial: { } }
    { event        symbol initial: undefined-event }
    { guard        word   initial: guard-none }
    { action       word   initial: action-none } ;

TUPLE: fsm-event
    { info } ;

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

SYNTAX: FSMS: ";"
    [
        create-word-in
        [ reset-generic ]
        [ define-symbol ]
        [ <fsm> swap set-global ] tri
    ] each-token ;

SYNTAX: STATES: ";"
    [
        create-word-in
        [ reset-generic ]
        [ define-symbol ]
        [ fsm-state new swap set-global ] tri
    ] each-token ;

SYNTAX: EVENTS: ";"
    [
        create-word-in
        [ reset-generic ]
        [ define-symbol ]
        [ fsm-event new swap set-global ] tri
    ] each-token ;

: set-memory-type ( fsm-symbol ? -- )
    swap get-global memory-type?<< ; inline

:: set-states ( fsm-symbol state-symbols  -- )
    state-symbols
    [ fsm-symbol get-global states<< ]
    [ first fsm-symbol get-global start-state<< ]
    [ [ fsm-symbol swap get-global super-fsm<< ] each ] tri ;

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

<PRIVATE

:: setup-transition ( from-state trans-define -- trans-obj )
    from-state dup trans-define first4
    fsm-transition new
    swap dup [ drop action-none ] unless >>action
    swap dup [ drop guard-none ] unless >>guard
    swap dup [ drop event-always ] unless >>event
    swap dup [ drop undefined-state ] unless >>to-state
    swap >>from-state
    swap get-global super-fsm>> >>fsm ;

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

:: go-up-fsm-tree-with-check ( fsm start-state end-state chain -- fsm' )
    fsm get-global super-state>> end-state = [
        start-state end-state direct-descent-transition
    ] when
    [ fsm chain go-up-fsm-tree ] [ ] [
        start-state end-state no-root-transition
    ] cleanup ;

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
        V{ } clone :> exit-chain!
        V{ } clone :> entry-chain!
        e undefined-state = [ ! internal transition
            s trans-obj from-state<<
            s trans-obj to-state<<
        ] [
            s exit-chain push
            e entry-chain push
            e s = not [ ! not self trantion
                s check-fsm-depth :> s-depth
                e check-fsm-depth :> e-depth
                s get-global super-fsm>> :> branch-fsm-from!
                e get-global super-fsm>> :> branch-fsm-to!
                s-depth e-depth > [
                    s-depth e-depth - [
                        branch-fsm-from s e exit-chain go-up-fsm-tree-with-check
                        branch-fsm-from!
                    ] times
                ] when
                s-depth e-depth < [
                    e-depth s-depth - [
                        branch-fsm-to s e entry-chain go-up-fsm-tree-with-check
                        branch-fsm-to!
                    ] times
                ] when
                [ branch-fsm-from branch-fsm-to = not ] [
                    branch-fsm-from get-global super-state>> undefined-state =
                    branch-fsm-to get-global super-state>> undefined-state = or [
                        s e no-root-transition
                    ] when
                    [
                        branch-fsm-from exit-chain go-up-fsm-tree branch-fsm-from!
                        branch-fsm-to entry-chain go-up-fsm-tree branch-fsm-to!
                    ] [ ] [
                        s e no-root-transition
                    ] cleanup
                ] while
            ] when
        ] if
        exit-chain >array trans-obj exit-chain<<
        entry-chain reverse! >array trans-obj entry-chain<<
    ] each ;

<PRIVATE

:: exec-trans-action ( trans-obj -- )
    trans-obj action>> action-none = not [
        trans-obj dup action>> execute( trans -- )
    ] when ;

:: exec-trans-guard? ( trans-obj -- ? )
    trans-obj guard>> guard-none =
    [ t ] [
        trans-obj dup guard>> execute( trans -- ? )
    ] if ;

:: exec-state-event ( state-symbol event -- )
    state-symbol get-global transitions>>
    [| trans-obj |
        trans-obj event>> event = [
            trans-obj exec-trans-guard? [
              trans-obj exec-trans-action
            ] when
        ] when
    ] each ;

: exec-state-do ( state-symbol -- )
    state-do exec-state-event ; inline

: exec-state-entry ( state-symbol -- )
    state-entry exec-state-event ; inline

: exec-state-exit ( state-symbol -- )
    state-exit exec-state-event ; inline

:: initialise-fsm ( fsm-symbol -- )
    fsm-symbol get-global memory-type?>> not [
        fsm-symbol get-global
        {
            [ start-state>> exec-state-entry ]
            [ dup start-state>> swap state<< ]
            [ dup start-state>> name>> swap set-model ]
            [
                states>> [
                    get-global sub-fsms>> [
                        initialise-fsm
                    ] each
                ] each ]
        } cleave
    ] when ;

:: exec-state-exit-sub-fsms ( state-symbol -- )
    state-symbol get-global
    super-fsm>> get-global memory-type?>> not [
        state-symbol get-global sub-fsms>> [
            get-global state>>
            [ exec-state-exit-sub-fsms ]
            [ exec-state-exit ] bi
        ] each
    ] when ;

:: transition ( trans-obj -- )
    trans-obj
    {
        [ from-state>> exec-state-exit-sub-fsms ]
        [ exit-chain>> [
              exec-state-exit
          ] each ]
        [ exec-trans-action ]
        [ entry-chain>> [
              {
                  [ exec-state-entry ]
                  [ dup get-global super-fsm>> get-global state<< ]
                  [
                      [ name>> ]
                      [ get-global super-fsm>> get-global ]
                      bi set-model ]
                  [
                      get-global super-fsm>> get-global states>> rest [
                          get-global sub-fsms>> [
                              initialise-fsm
                          ] each
                      ] each ]
              } cleave
          ] each ]
        [ exit-chain>> { } = not [
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
    [ exec-state-entry ] tri ;

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
          [
              get-global fsm-obj
              [ transitioned?>> swap transitioned?<< ]
              [ event>> swap event<< ] 2bi ]
          [ update ]
          [ get-global transitioned?>> fsm-obj transitioned?<< ] tri
      ] each
    ] bi

    fsm-obj transitioned?>> not [
        fsm-obj state>> get-global transitions>>
        [| trans-obj |
            fsm-obj transitioned?>> not [
                trans-obj event>>
                { [ fsm-obj event>> = ] [ event-always = ] } 1|| [
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
