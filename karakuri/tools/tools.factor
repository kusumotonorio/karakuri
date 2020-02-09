! Copyright (C) 2019 KUSUMOTO Norio.
! See http://factorcode.org/license.txt for BSD license.

USING: kernel sequences arrays locals namespaces accessors generic
       assocs combinators combinators.short-circuit classes.tuple
       formatting classes prettyprint strings help
       graphviz graphviz.notation graphviz.render graphviz.dot
       karakuri karakuri.help karakuri.private ;

IN: karakuri.tools

SYMBOLS:
    rankdir: ranksep: nodesep: size: labelfloat:
    fontname: fontsize: sub-fsm: ;

<PRIVATE

SYMBOLS:
    *graphviz-fontname* *graphviz-fontsize*
    *graphviz-labelfloat*
    *sub-fsm?* ;

SYMBOL: state-members

:: fsm-label ( fsm-symbol -- str )
    fsm-symbol word-help \ $label of
    [ fsm-symbol "%s" sprintf ] unless* ;

:: event-label ( trans-obj -- str )
    trans-obj event>> :> event
    event word-help \ $label of [ event ] unless* :> event-label
    trans-obj guard>> :> guard
    guard word-help \ $label of [ guard ] unless* :> guard-label
    trans-obj action>> :> action
    action word-help \ $label of [ action ] unless* :> action-label
    { } clone
    event event-always = not [
        event-label "" = [
            event "%s" sprintf
        ] [
            event-label "%s" sprintf
        ] if
        suffix
    ] when
    guard guard-none = not [
        guard-label "" = [
            guard " [ %s ]" sprintf
        ] [
            guard-label " [ %s ]" sprintf
        ] if
        suffix
    ] when
    action action-none = not [
        action-label "" = [
            action " / %s" sprintf
        ] [
            action-label " / %s" sprintf
        ] if
        suffix
    ] when
    "" join ;

:: state-label ( state-symbol -- str )
    state-symbol word-help \ $label of [ "" ] unless* :> label
    V{ } clone :> s-label
    label "" =
    [ state-symbol "%s\n\n\n" sprintf ]
    [ label "%s\n\n\n" sprintf ] if s-label push
    state-symbol get-global transitions>>
    [ event>> state-entry = ] filter
    [| trans-obj |
        trans-obj action>> :> action
        action action-none = not [
            trans-obj action>> :> action
            action word-help \ $label of [ action ] unless*
            "entry / %s\n" sprintf
            s-label push
        ] when
    ] each
    state-symbol get-global transitions>>
    [ event>> state-do = ] filter
    [| trans-obj |
        trans-obj action>> :> action
        action action-none = not [
            action word-help \ $label of [ action ] unless*
            "do / %s\n" sprintf
            s-label push
        ] when
    ] each
    state-symbol get-global transitions>>
    [ event>> state-exit = ] filter
    [| trans-obj |
        trans-obj action>> :> action
        action action-none = not [
            action word-help \ $label of [ action ] unless*
            "exit / %s\n" sprintf
            s-label push
        ] when
    ] each
    state-symbol get-global transitions>>
    [| trans-obj |
        trans-obj exit-chain>> empty? [ ! internal transition
            trans-obj event>> { [ state-entry = not ]
                                [ state-do = not ]
                                [ state-exit = not ] } 1&& [
                trans-obj event-label "%s\n" sprintf s-label push
            ] when
        ] when
    ] each
    s-label "" join ;

:: describe-fsm ( graph fsm-symbol -- graph' )
    graph
    fsm-symbol <cluster>
    [graph fsm-symbol fsm-label =label "20.0" =margin
     *graphviz-fontname* get =fontname
     *graphviz-fontsize* get =fontsize ];
     [node
         "circle" =shape "rounded,filled" =style "black" =fillcolor
         "0.2" =width "" =label
         *graphviz-fontname* get =fontname
         *graphviz-fontsize* get =fontsize ];
    fsm-symbol "%s-initial-state" sprintf add-node
    fsm-symbol get-global states>>
    [| state |
        "white" :> color!
        fsm-symbol get-global state>> state = [
            "gray" color!
        ] when
        [node
            "box" =shape "rounded,filled" =style color =fillcolor
            *graphviz-fontname* get =fontname
            *graphviz-fontsize* get =fontsize ];
        state [add-node state state-label =label ];
        state state-members get push
    ] each
    add
    *sub-fsm?* get [
      fsm-symbol get-global states>> [
          get-global sub-fsms>> [
              describe-fsm
          ] each
      ] each
    ] when ;

:: describe-super-state-sub-fsms ( graph fsm-symbol -- graph' )
    graph
    *sub-fsm?* get [
        fsm-symbol get-global states>>
        [| state |
            state get-global sub-fsms>>
            [| fsm |
                state "%s" sprintf
                fsm get-global start-state>> "%s" sprintf
                [->
                    fsm "cluster_%s"
                    sprintf =lhead "back" =dir
                    "odiamond" =arrowtail "true" =constraint
                    *graphviz-fontname* get =fontname
                    *graphviz-fontsize* get =fontsize ];
                fsm describe-super-state-sub-fsms
            ] each
        ] each
    ] when ;

:: describe-transitions ( graph fsm-symbol -- graph' )
    graph
    fsm-symbol "%s-initial-state" sprintf
    fsm-symbol get-global start-state>> "%s" sprintf
    [-> "false" =constraint
        *graphviz-labelfloat* get =labelfloat
        *graphviz-fontname* get =fontname
        *graphviz-fontsize* get =fontsize ];
    fsm-symbol get-global states>> [
        get-global transitions>>
        [| trans-obj |
            trans-obj exit-chain>> empty? not [
                trans-obj to-state>> state-members get member? not [
                    [node
                        "box" =shape "rounded,filled" =style
                        "white" =fillcolor
                        *graphviz-fontname* get =fontname
                        *graphviz-fontsize* get =fontsize ];
                    trans-obj to-state>>
                    [add-node trans-obj to-state>> state-label =label ];
                ] when
                trans-obj
                [ from-state>> "%s" sprintf ]
                [ to-state>> "%s" sprintf ] bi
                [->
                    trans-obj
                    event-label =label
                    "true" =constraint
                    *graphviz-labelfloat* get =labelfloat
                    *graphviz-fontname* get =fontname
                    *graphviz-fontsize* get =fontsize ];
            ] when
        ] each
    ] each
    *sub-fsm?* get [
        fsm-symbol get-global states>> [
            get-global sub-fsms>> [
                describe-transitions
            ] each
        ] each
    ] when ;

:: fsm-graph ( fsm-symbol options/f -- graph )
    V{ } clone state-members set
    <digraph>
    [graph
        "dot" =layout
        "true" =compound
        options/f
        dup { [ f = not ] [ first assoc? not ] } 1&& [ 1array ] when
        {
            [ rankdir: swap at [ =rankdir ] [ "LR" =rankdir ] if* ]
            [ ranksep: swap at [ =ranksep ] [ "0.3" =ranksep ] if* ]
            [ nodesep: swap at [ =nodesep ] [ "0.5" =nodesep ] if* ]
            [ size: swap at [ =size ] when* ]
            [
                fontname: swap at [
                    *graphviz-fontname* set
                ] [
                    "sans-serif" *graphviz-fontname* set
                ] if* ]
            [
                fontsize: swap at [
                    *graphviz-fontsize* set
                ] [ "12.0" *graphviz-fontsize* set
                  ] if* ]
            [
                labelfloat: swap at [
                    *graphviz-labelfloat* set
                ] [ "false" *graphviz-fontsize* set ]
                if* ]
            [
                sub-fsm: swap at* [
                    *sub-fsm?* set
                ] [
                    drop f *sub-fsm?* set
                ] if ]
        } cleave ];
    fsm-symbol describe-fsm
    fsm-symbol describe-transitions
    fsm-symbol describe-super-state-sub-fsms ;

PRIVATE>

: preview-fsm ( fsm-symbol options/f -- )
    fsm-graph preview ;

: preview-fsm-window ( fsm-symbol options/f -- )
    fsm-graph preview-window ;

:: write-fsm-dot ( fsm-symbol options/f path encording -- )
    fsm-symbol options/f fsm-graph
    path encording write-dot ;
