! Copyright (C) 2019 KUSUMOTO Norio.
! See http://factorcode.org/license.txt for BSD license.
USING: help.markup help.syntax kernel ;
IN: karakuri

HELP: EVENTS:
{ $description "イベントの名称をシングルトンとして定義する。fsm-eventオブジェクトがセットされる。" } ;

HELP: FSMS:
{ $description "FSMの名称をシングルトンとして定義する。fsmオブジェクトがセットされる。" } ;

HELP: STATES:
{ $description "状態の名称をシングルトンとして定義する。fsm-stateオブジェクトがセットされる。" } ;

HELP: circular-reference-definition
{ $values
    { "fsm" "a singleton of fsm" } { "state" "a singleton of state" }
}
{ $description "Throws a " { $link circular-reference-definition } " error." }
{ $error-description "The hierarchy definition of the fsm and the state is circular reference." } ;

HELP: event-none
{ $var-description "イベントが無いことを表すシンボル。" } ;

HELP: fsm
{ $class-description "fsmタプル。" $slot } ;

HELP: fsm-event
{ $class-description "イベントタプル" } ;

HELP: state-exit
{ $description "状態を抜けるときに実行する処理を記述する。" } ;

HELP: initial-state
{ $var-description "初期状態" } ;

HELP: fsm-state
{ $class-description "状態タプル" } ;

HELP: fsm-transition
{ $class-description "遷移タプル" } ;

HELP: no-root-transition
{ $values
    { "transition" "a singleton of transition" } { "from-state" "a singleton of state" } { "to-state" "a singleton of state" }
}
{ $description "Throws a " { $link no-root-transition } " error." }
{ $error-description "遷移を行う経路がない。" } ;

HELP: raise-fsm-event
{ $values
    { "fsm-symbol" null } { "event-symbol" null }
}
{ $description "fsmにイベントを上げる。" } ;

HELP: set-states
{ $values
    { "fsm-symbol" null } { "state-symbols" null }
}
{ $description "fsmに状態を設定する。状態のリストを与える。" } ;

HELP: set-sub-fsms
{ $values
    { "state-symbol" null } { "sub-fsms" null }
}
{ $description "階層化fsmとするため、状態に下層fsmを設定する。fsmのリストを与える。fsmが複数ならば、それらのfsmは並列動作を行う。" } ;

HELP: set-transitions
{ $values
    { "fsm-symbol" null } { "transition-symbols" null }
}
{ $description "fsmに遷移を設定する。" } ;

HELP: undefined-event
{ $var-description "イベントが設定されていないことを表すシンボル。" } ;

HELP: undefined-fsm
{ $var-description "fsmが設定されていないことを表すシンボル。" } ;

HELP: undefined-state
{ $var-description "状態が設定されていないことを表すシンボル。" } ;

HELP: update
{ $values
    { "fsm-symbol" null }
}
{ $description "fsmを動かす。" } ;

ARTICLE: "karakuri" "karakuri"
{ $vocab-link "karakuri" }
;

ABOUT: "karakuri"
