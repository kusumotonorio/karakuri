! Copyright (C) 2019 Your name.
! See http://factorcode.org/license.txt for BSD license.
USING: help.markup help.syntax kernel strings ;
IN: karakuri.help

HELP: $label
{ $values
    { "element" string }
}
{ $description "You can replace a label of FSM, state, event, guard condition, and action in the preview image in which it by declaring the use of karakuri.help and using $label in its HELP: in the document file.

Example:"
{ $code "USING: help.markup help.syntax kernel karakuri karakuri.help ;
IN: karakuri-lab

HELP: FSM2
{ $class-description \"\" }
{ $label \"Sub State Machine\" } ;

HELP: S1-1
{ $class-description \"\" }
{ $label \"Start State\" } ;

HELP: E1
{ $class-description \"\" }
{ $label \"event #1\" } ;

HELP: S1->S2-guard?
{ $values
    { \"trans\" fsm-transition }
    { \"?\" boolean }
}
{ $description \"\" }
{ $label \"Is Switch-RED on?\" } ;

HELP: S2->S1-action
{ $values
    { \"trans\" fsm-transition }
}
{ $description \"\" }
{ $label \"Do the right thing\" } ;
" }
} ;

ARTICLE: "karakuri.help" "karakuri.help"
{ $vocab-link "karakuri.help" }
"Extend the Help system to make documents easier to understand."
;

ABOUT: "karakuri.help"
