! Copyright (C) 2019 KUSUMOTO Norio.
! See http://factorcode.org/license.txt for BSD license.

USING: accessors constructors kernel sequences arrays words.symbol models  io 
namespaces locals words strings quotations math classes.parser classes.singleton
lexer combinators continuations combinators.short-circuit lists generic assocs
classes.tuple graphviz graphviz.notation graphviz.render graphviz.dot
formatting fry classes prettyprint ;

IN: karakuri

SYMBOLS: undefined-fsm ;
SYMBOLS: undefined-state initial-state ;
SYMBOLS: undefined-event event-none ;
    
TUPLE: fsm < model
    { super-state    symbol initial: undefined-state }
    { states         array  initial: { } }
    { transitions    array  initial: { } }
    { start-state    symbol initial: undefined-state }
    { current-state  symbol initial: initial-state }
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
    { guard-label    string initial: "" } ;

TUPLE: fsm-event
    { info }
    { label          string initial: "" } ;


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


: initialise-fsm ( fsm-symbol -- )
    get-global
    {
        [ current-state>> initial-state = not [
              dispatcher set state-exit
          ] when* ]
        [ initial-state swap current-state<< ]
        [ initial-state name>> swap set-model ]                
        [ states>> [
              get-global sub-fsms>> [
                  initialise-fsm
              ] each
          ] each ]
    } cleave ;


:: transition ( transition-symbol fsm-obj -- )
    transition-symbol
    [ get-global exit-path>> [
          dispatcher set state-exit
      ] each ]                 
    [ dispatcher set transition-action ]
    [ get-global entry-path>> [
          { [ get-global sub-fsms>> [ 
                  initialise-fsm 
              ] each ] 
            [ dispatcher set state-entry ]
            [ dup get-global super-fsm>> get-global current-state<< ]
            [ [ name>> ]
              [ get-global super-fsm>> get-global ]
              bi set-model ]
          } cleave
      ] each ]
    tri ; 


:: initial-state==>start-state ( fsm-obj -- )
    fsm-obj start-state>> :> start-state
    start-state
    [ fsm-obj current-state<< ]
    [ name>> fsm-obj set-model ]                
    [ dispatcher set state-entry ]
    tri ;

PRIVATE>

: raise-fsm-event ( fsm-symbol event-symbol -- )
    swap get-global raising-event<< ;


:: update ( fsm-symbol -- )
    fsm-symbol get-global :> fsm-obj
    fsm-obj current-state>> initial-state = [
        fsm-obj initial-state==>start-state
    ] when
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

:: set-sub-fsm ( state-symbol sub-fsm -- )
    state-symbol sub-fsm 1array set-sub-fsms ;
    
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
         ] [
             s-depth e-depth < [
                 e-depth s-depth - [
                     branch-fsm-to get-global super-state>> s = [
                         transition-symbol s e direct-descent-transition
                     ] when
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
             branch-fsm-from exit-path up-fsm-tree branch-fsm-from!
             branch-fsm-to entry-path up-fsm-tree branch-fsm-to!
             branch-fsm-to entry-path up-fsm-tree branch-fsm-to!
         ] while
     ] when

     exit-path >array transition-symbol get-global exit-path<<
     entry-path reverse >array transition-symbol get-global entry-path<<
    ] each ;


<PRIVATE

SYMBOLS:
    +graphviz-fontname+ +graphviz-fontsize+
    +graphviz-transition-label?+ ;


:: fsm-label ( fsm-symbol -- str )
    fsm-symbol get-global label>> :> label
    label "" = [ fsm-symbol "%s" sprintf ] [ label ] if ;


:: state-label ( state-symbol -- str )
    state-symbol get-global 
    dup label>>       :> label 
    dup entry-label>> :> entry-label
    dup do-label>>    :> do-label
    exit-label>>      :> exit-label
    { } clone
    label "" = 
    [ state-symbol "%s\n\n\n" sprintf ] 
    [ label "%s\n\n\n" sprintf ] if suffix
    state-symbol \ state-entry ?lookup-method [
        entry-label "" = 
        [ "entry / *\n" ] 
        [ entry-label "entry / %s\n" sprintf ] if suffix
    ] when
    state-symbol \ state-do ?lookup-method [
        do-label "" = 
        [ "do / *\n" ] 
        [ do-label "do / %s\n" sprintf ] if suffix
    ] when
    state-symbol \ state-exit ?lookup-method [
        exit-label "" = 
        [ "exit / *\n" ] 
        [ exit-label "exit / %s\n" sprintf ] if suffix
    ] when
    "" join ;


:: transition-label ( transition-symbol -- str )
    transition-symbol get-global label>> :> label
    label "" = [ transition-symbol "%s" sprintf ] [ label ] if ;


:: event-label ( transition-symbol -- str )
    transition-symbol get-global 
    dup event>>                    :> event-symbol
    dup event>> get-global label>> :> event-label
    dup guard-label>>              :> guard-label
    action-label>>                 :> action-label
    { } clone
    event-label "" = [ 
        event-symbol "%s " sprintf 
    ] [ 
        event-label "%s " sprintf 
    ] if 
    suffix
    transition-symbol \ transition-guard? ?lookup-method [
        guard-label "" = 
        [ "[ * ] " ] 
        [ guard-label "[ %s ] " sprintf ] if suffix
    ] when
    transition-symbol \ transition-action ?lookup-method [
        action-label "" = 
        [ "/ *" ] 
        [ action-label "/ %s" sprintf ] if suffix
    ] when
    "" join ;


:: describe-fsm ( graph fsm-symbol -- graph' )
    graph
    fsm-symbol <cluster>
    [graph fsm-symbol fsm-label =label "20.0" =margin
     +graphviz-fontname+ get =fontname
     +graphviz-fontsize+ get =fontsize ];

    [node "circle" =shape "rounded,filled" =style "black" =fillcolor
     "0.2" =width "" =label
     +graphviz-fontname+ get =fontname
     +graphviz-fontsize+ get =fontsize ];
    fsm-symbol "%s-initial-state" sprintf add-node

    fsm-symbol get-global states>>
    [| state |
     "white" :> color!
     fsm-symbol get-global current-state>> state = [
         "gray" color!
     ] when
     [node "box" =shape "rounded,filled" =style color =fillcolor
      +graphviz-fontname+ get =fontname
      +graphviz-fontsize+ get =fontsize ];
     state [add-node state state-label =label ];
    ] each
    add
    
    fsm-symbol get-global states>> [
        get-global sub-fsms>> [
            describe-fsm
        ] each
    ] each ;


:: describe-super-state-sub-fsms ( graph fsm-symbol -- graph' )
    graph
    fsm-symbol get-global states>>
    [| state |
     state get-global sub-fsms>>
     [| fsm |
      state "%s" sprintf
      fsm get-global start-state>> "%s" sprintf
      [-> fsm "cluster_%s" sprintf =lhead "back" =dir 
       "odiamond" =arrowtail "true" =constraint
       +graphviz-fontname+ get =fontname
       +graphviz-fontsize+ get =fontsize ];
      fsm describe-super-state-sub-fsms
     ] each
    ] each ;

         
:: describe-transitions ( graph fsm-symbol -- graph' )
    graph
    fsm-symbol "%s-initial-state" sprintf
    fsm-symbol get-global start-state>> "%s" sprintf
    [-> "false" =constraint
     +graphviz-fontname+ get =fontname
     +graphviz-fontsize+ get =fontsize ];

    fsm-symbol get-global transitions>>
    [| transition-symbol |
     transition-symbol get-global
     [ from-state>> "%s" sprintf ]
     [ to-state>> "%s" sprintf ]
     bi 
     [-> transition-symbol event-label =label 
      +graphviz-transition-label?+ get [
          transition-symbol transition-label =taillabel
      ] when
      "true" =constraint
      +graphviz-fontname+ get =fontname
      +graphviz-fontsize+ get =fontsize ];
    ] each

    fsm-symbol get-global states>> [
        get-global sub-fsms>> [
            describe-transitions
        ] each
    ] each ;

PRIVATE>

SYMBOLS:
    rankdir: ranksep: nodesep: size:
    fontname: fontsize: transition-label?: ;

<PRIVATE

:: fsm-graph ( fsm-symbol options/f -- graph )
    <digraph>
    [graph
     "dot" =layout 
     "true" =compound
     options/f
     dup { [ f = not ] [ first assoc? not ] } 1&& [ 1array ] when
     { [ rankdir:  swap at [ =rankdir ] [ "LR" =rankdir ] if* ]
       [ ranksep:  swap at [ =ranksep ] [ "0.3" =ranksep ] if* ]
       [ nodesep:  swap at [ =nodesep ] [ "0.5" =nodesep ] if* ]
       [ size:     swap at [ =size ]    when* ]
       [ fontname: swap at
         [ +graphviz-fontname+ set ]
         [ "Times-Roman" +graphviz-fontname+ set ] if* ]
       [ fontsize: swap at
         [ +graphviz-fontsize+ set ]
         [ "12.0" +graphviz-fontsize+ set ] if* ]
       [ transition-label?: swap at* 
         [ +graphviz-transition-label?+ set ]
         [ drop t +graphviz-transition-label?+ set ] if ]
     } cleave
    ];           

    fsm-symbol describe-fsm
    fsm-symbol describe-transitions
    fsm-symbol describe-super-state-sub-fsms ;

PRIVATE>


SYMBOLS: label: entry-label: do-label: exit-label:
         action-label: guard-label: ; 

<PRIVATE

:: set-label-if-exist ( assoc label-symbol label-key obj -- )  
    label-symbol assoc at [
        label-key swap 2array 1array obj set-slots
    ] when* ;


GENERIC#: (set-labels) 1 ( obj assoc -- )

M:: fsm (set-labels) ( obj assoc -- )
    assoc label: "label" obj set-label-if-exist ;

M:: fsm-state (set-labels) ( obj assoc -- )
    assoc label:       "label"       obj set-label-if-exist
    assoc entry-label: "entry-label" obj set-label-if-exist
    assoc do-label:    "do-label"    obj set-label-if-exist
    assoc exit-label:  "exit-label"  obj set-label-if-exist ;

M:: fsm-transition (set-labels) ( obj assoc -- )
    assoc label:        "label"        obj set-label-if-exist
    assoc action-label: "action-label" obj set-label-if-exist
    assoc guard-label:  "guard-label"  obj set-label-if-exist ;

M:: fsm-event (set-labels) ( obj assoc -- )
    assoc label: "label" obj set-label-if-exist ;
    
PRIVATE>

:: set-labels ( symbol assoc -- )
    symbol get-global assoc (set-labels) ;

: set-label ( symbol assoc-elt -- )
    dup string? [
        label: swap 2array
    ] when
    1array set-labels ;


: preview-fsm ( fsm-symbol options/f -- )
    fsm-graph preview ;


: preview-fsm-window ( fsm-symbol options/f -- )
    fsm-graph preview-window ;


:: write-fsm-dot ( fsm-symbol options/f path encording -- )
    fsm-symbol options/f fsm-graph
    path encording write-dot ;
