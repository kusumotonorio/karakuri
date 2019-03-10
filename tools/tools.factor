! Copyright (C) 2019 KUSUMOTO Norio.
! See http://factorcode.org/license.txt for BSD license.

USING: kernel sequences arrays locals namespaces accessors generic 
       assocs combinators combinators.short-circuit classes.tuple   
       formatting classes prettyprint strings
       help
       graphviz graphviz.notation graphviz.render graphviz.dot
       karakuri karakuri.help karakuri.private ;

IN: karakuri.tools


SYMBOLS: 
    label: entry-label: do-label: exit-label:
    action-label: guard-label: ; 

SYMBOLS:
    rankdir: ranksep: nodesep: size: labelfloat:
    fontname: fontsize: transition-label?: ;

<PRIVATE

SYMBOLS:
    +graphviz-fontname+ +graphviz-fontsize+
    +graphviz-labelfloat+
    +graphviz-transition-label?+ ;


:: fsm-label ( fsm-symbol -- str )
!    fsm-symbol get-global label>> :> label
!   label "" = [ fsm-symbol "%s" sprintf ] [ label ] if ;
    fsm-symbol word-help \ $label of
    [ fsm-symbol "%s" sprintf ] unless* ;


:: transition-label ( transition-symbol -- str )
!    transition-symbol get-global label>> :> label
!    label "" = [ transition-symbol "%s" sprintf ] [ label ] if ;
    transition-symbol word-help \ $label of
    [ transition-symbol "%s" sprintf ] unless* ;


:: event-label ( transition-symbol -- str )
!    transition-symbol get-global 
!    dup event>>                    :> event-symbol
!    dup event>> get-global label>> :> event-label
!    dup guard-label>>              :> guard-label
!    action-label>>                 :> action-label
    transition-symbol get-global event>> :> event-symbol
    event-symbol word-help
    \ $label of [ "" ] unless*           :> event-label
    transition-symbol word-help dup
    \ $guard-label of  [ "" ] unless*    :> guard-label
    \ $action-label of [ "" ] unless*    :> action-label
    { } clone
    event-label "" = [ 
        event-symbol "%s " sprintf 
    ] [ 
        event-label "%s " sprintf 
    ] if 
    suffix
    transition-symbol \ trans-guard? ?lookup-method [
        guard-label "" = 
        [ "[ * ] " ] 
        [ guard-label "[ %s ] " sprintf ] if suffix
    ] when
    transition-symbol \ trans-action ?lookup-method [
        action-label "" = 
        [ "/ *" ] 
        [ action-label "/ %s" sprintf ] if suffix
    ] when
    "" join ;


:: state-label ( state-symbol -- str )
!    state-symbol get-global 
!    dup label>>       :> label 
!    dup entry-label>> :> entry-label
!    dup do-label>>    :> do-label
!    exit-label>>      :> exit-label

    state-symbol word-help 
    dup \ $label of [ "" ] unless*       :> label 
    dup \ $entry-label of [ "" ] unless* :> entry-label
    dup \ $do-label of [ "" ] unless*    :> do-label
    \ $exit-label of [ "" ] unless*      :> exit-label
    
    V{ } clone         :> s-label 
    label "" = 
    [ state-symbol "%s\n\n\n" sprintf ] 
    [ label "%s\n\n\n" sprintf ] if s-label push
    state-symbol \ state-entry ?lookup-method [
        entry-label "" = 
        [ "entry / *\n" ] 
        [ entry-label "entry / %s\n" sprintf ] if s-label push
    ] when
    state-symbol \ state-do ?lookup-method [
        do-label "" = 
        [ "do / *\n" ] 
        [ do-label "do / %s\n" sprintf ] if s-label push
    ] when
    state-symbol \ state-exit ?lookup-method [
        exit-label "" = 
        [ "exit / *\n" ] 
        [ exit-label "exit / %s\n" sprintf ] if s-label push
    ] when

    state-symbol get-global super-fsm>> get-global 
    state-symbol
    transitions-for 
    [| trans |
     trans get-global exit-path>> { } = [ ! internal transition
         +graphviz-transition-label?+ get [
             trans transition-label "%s : " sprintf s-label push
         ] when
         trans event-label "%s\n" sprintf s-label push
     ] when
    ] each
    s-label "" join ;



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
     fsm-symbol get-global state>> state = [
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
     +graphviz-labelfloat+ get =labelfloat
     +graphviz-fontname+ get =fontname
     +graphviz-fontsize+ get =fontsize ];

    fsm-symbol get-global transitions>>
    [| transition-symbol |
     transition-symbol get-global exit-path>> { } = not [
         transition-symbol get-global
         [ from-state>> "%s" sprintf ]
         [ to-state>> "%s" sprintf ]
         bi
         [-> transition-symbol event-label =label 
          +graphviz-transition-label?+ get [
              transition-symbol transition-label =taillabel
          ] when
          "true" =constraint
          +graphviz-labelfloat+ get =labelfloat
          +graphviz-fontname+ get =fontname
          +graphviz-fontsize+ get =fontsize ];
     ] when
    ] each

    fsm-symbol get-global states>> [
        get-global sub-fsms>> [
            describe-transitions
        ] each
    ] each ;


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
       [ labelfloat: swap at
         [ +graphviz-labelfloat+ set ]
         [ "false" +graphviz-fontsize+ set ] if* ]
       
       [ transition-label?: swap at* 
         [ +graphviz-transition-label?+ set ]
         [ drop f +graphviz-transition-label?+ set ] if ]
     } cleave
    ];           

    fsm-symbol describe-fsm
    fsm-symbol describe-transitions
    fsm-symbol describe-super-state-sub-fsms ;


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
