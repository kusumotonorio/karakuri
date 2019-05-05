! Copyright (C) 2019 KUSUMOTO Norio.
! See http://factorcode.org/license.txt for BSD license.
USING: help.markup help.syntax kernel arrays words.symbol models ;
IN: karakuri

HELP: EVENTS:
{ $description "Creates events for FSM(Finite State Machine).

New symbol words are defined and fms-event objects are assigned to these symbols in the global namespace." } ;

HELP: FSMS:
{ $description "Creates FSM(Finite State Machines)s.

New symbol words are defined and fms objects are assigned to these symbols in the global namespace." } ;

HELP: STATES:
{ $description "Creates states for FSM(Finite State Machine).

New symbol words are defined and fms-state objects are assigned to these symbols in the global namespace." } ;

HELP: event-none
{ $description "Symbol for no event." } ;

HELP: state-do
{ $description "It is a special event that represents a state." } ;

HELP: state-entry
{ $description "It is a special event represents entering a state." } ;

HELP: state-exit
{ $description "It is a special event that represents exiting  a state." } ;


HELP: circular-reference-definition
{ $values
    { "fsm" symbol } { "state" symbol }
}
{ $description "Throws a " { $link circular-reference-definition } " error." }
{ $error-description "Reports a relationship in which the FSM and the state directly or indirectly own each other." } ;

HELP: direct-descent-transition
{ $values
    { "from-state" symbol } { "to-state" symbol }
}
{ $description "Throws a " { $link direct-descent-transition } " error." }
{ $error-description "There is no transition between a state and its subdivided states because they are in the same state." } ;

HELP: fsm
{ $class-description "The class of FSM(Finite State Machine)s. 

It has possible " { $link fsm-state } "s. And It knows a current state, changes the state by interpreting the raiserd " { $link fsm-event } ".

fsm is a subclass of " { $link model } "." } ;

HELP: fsm-event
{ $class-description "The class of events given to " { $link fsm } ".

You can use the info slot to provide additional information." } ;

HELP: fsm-state
{ $class-description "The class of states of " { $link fsm } ".

States can have multiple sub-FSMs for their own tiering.

sub-FSMs are divided into one primary sub-FSM and zero or more secondary sub-FSMs. The primary sub-FSM is used for true state segmentation, while the secondary sub-FSMs are used to represent auxiliary parallel states."  } ;

HELP: fsm-transition
{ $class-description "The class of representing transitions between states.

It contains information about the starting and arrival state of the transition, as well as the events that will fire, the guard condition, and the action to take during the transition." } ;

HELP: no-root-transition
{ $values
    { "from-state" symbol } { "to-state" symbol }
}
{ $description "Throws a " { $link no-root-transition } " error." }
{ $error-description "No transition route to reach.

State transitions can only be made on routes connected by the primary FSM." } ;

HELP: raise-fsm-event
{ $values
    { "fsm-symbol" symbol } { "event-symbol" symbol }
}
{ $description "The event are sent to the FSM. The FSM does not yet evaluate the event." } ;

HELP: secondary-fsm-transition
{ $description "Throws a " { $link secondary-fsm-transition } " error." }
{ $error-description "State transitions can only be made on routes connected by the primary sub-FSM." } ;

HELP: set-memory-type
{ $values
    { "fsm-symbol" symbol } { "?" boolean }
}
{ $description "Selects the fsm type.

If f is given, the fsm starts from the start state when it transitions to its super-state. If anything other than f is supplied, the fsm continues from its previous state." } ;

HELP: set-states
{ $values
    { "fsm-symbol" symbol } { "state-symbols" array }
}
{ $description "Registes the states with the FSM.

States are given as a array.
The state written first in the array becomes the start state of the FSM.

The state written at first becomes the start state." } ;

HELP: set-sub-fsm
{ $values
    { "state-symbol" symbol } { "sub-fsm" symbol }
}
{ $description "Registes the FSM with the state as a primary sub-FSM.

See " { $link fsm-state } "." } ;

HELP: set-sub-fsms
{ $values
    { "state-symbol" symbol } { "sub-fsms" array }
}
{ $description "Registes FSMs with the state as sub FSMs.

The FSM written at first becomes the primary sub-FSM. The rest are the secandery sub-FSMs. See " { $link fsm-state } "." } ;

HELP: set-transitions
{ $values
    { "state-symbol" symbol } { "trans-defines" array }
}
{ $description "Registes the transitions with the state.

If you write f for the first element of an array that represents information about a transition, it represents an internal transition. If it is the same as the from state, it represents a self transition.

The second element is the event where the transition occurs. If you write this as f, it means unconditional. 

However, all transitions require the guard condition of the third element to be met. If the third element is f, there is no guard condition.

The fourth element is the action performed during the transition. If this is written as f, it is interpreted as having no action.

The state-entry, state-do, and state-exit are special events, each representing when a state is entered, while it is in, and when it is exited.

Example:
" }

{ $code
  "! from   to  event          guard condition  action

S1 {
    {    f   state-entry    f                S1-entry      }
    {    f   state-do       f                S1-do         }
    {    f   state-exit     f                S1-exit       }
    {    S2  E1             S1->S2-guard?    S1->S2-action }
    {    S3  E1             S1->S3-guard?    S1->S3-action }   
}
set-transitions" }
    ;


HELP: update
{ $values
    { "fsm-symbol" symbol }
}
{ $description "Drives the fsm. If an event has been received, it is evaluated." } ;

HELP: update-with
{ $values
    { "fsm-symbol" symbol } { "event-symbol" symbol }
}
{ $description "Drives the fsm with the event. " } ;

ARTICLE: "karakuri" "karakuri"
{ $vocab-link "karakuri" }

"

karakuri is a hierarchical finite state machine library for Factor.


Usage:

Create state machines, states and events.
"
{ $code
"USE: karakuri

FSMS:   FSM1 FSM2 ;
STATES: S1 S2 S3 S1-1 S1-2 ;
EVENTS: E1 E2 E3 E4 E5 ;" }
"
Assemble the machines and the states.
"
{ $code
"FSM1 { S1 S2 S3 } set-states     ! The state written at first becomes the start state.
S1 { FSM2 } set-sub-fsms         ! equivalent: S1 FSM2 set-sub-fsm
FSM2 { S1-1 S1-2 } set-states" }
"
If Graphviz is installed, FSM can be confirmed by visualizing whether it was configured as intended.
"
{ $code
"USE: karakuri.tools
 
FSM1 { { sub-fsm: t } } preview-fsm" }
"
The state machine in karakuri is quite similar to that in UML. However, Graphviz does not render state hierarchies well, so it has its own representation of hierarchy.
"
"
Wrie event handlers.
"
{ $code
"USING: kernel accessors namespaces arrays io math formatting
tools.continuations ;

SYMBOL: next-event         event-none next-event set
SYMBOLS: switch ;          switch on
SYMBOLS: wait-counter ;

: S1-entry ( trans -- ) drop                 \"S1:entry \" write
    1 wait-counter set ;
  
: S1-do ( trans -- ) drop                    wait-counter get \"S1:do(%d) \" printf
   wait-counter inc
    wait-counter get 5 > [
        E1 next-event set
    ] when ;

: S1-exit ( trans -- ) drop                  \"S1:exit \" write ;

: S2-entry ( trans -- ) drop                 \"S2:entry \" write
    switch off 
    E2 next-event set ;

: S2-do ( trans -- ) drop                    \"S2:do \" write ;

: S2-exit ( trans -- ) drop                  \"S2:exit \" write ;

: S3-entry ( trans -- ) drop                 \"S3:entry \" write
    E3 next-event set ;

: S3-do ( trans -- ) drop                    \"S3:do \" write ;

: S3-exit ( trans -- ) drop                  \"S3:exit \" write
    switch on ;

: S1-1-entry ( trans -- ) drop               \"S1-1:entry \" write
    next-event get event-none = [
        E4 next-event set
    ] when ;

: S1-1-do ( trans -- ) drop                  \"S1-1:do \" write ;

: S1-1-exit ( trans -- ) drop                \"S1-1:exit \" write ; 

: S1-2-entry ( trans -- ) drop               \"S1-2:entry \" write
    next-event get event-none = [
        E5 next-event set
    ] when ;

: S1-2-do ( trans -- ) drop                  \"S1-2:do \" write ;

: S1-2-exit ( trans -- ) drop                \"S1-2:exit \" write ;

: S1->S2-action ( trans -- ) drop            \"(S1 - >S2) \" write ;

: S1->S2-guard? ( trans -- ? )  drop
    switch get ;

: S1->S3-action ( trans -- ) drop            \"(S1 -> S3) \" write ;

: S1->S3-guard? ( trans -- ? ) drop
    switch get not ;

: S2->S1-action ( trans -- ) drop            \"(S2 -> S1) \" write ;

: S3->S1-2-action ( trans -- ) drop          \"(S3 -> S1-2) \" write ;

: S1-1->S1-2-action ( trans -- ) drop        \"(S1-1 -> S1-2) \" write ;

: S1-2->S1-1-action ( trans -- ) drop        \"(S1-2 -> S1-1) \" write ;" }
"
Set transitions to states.
"
{ $code
"
! from   to  event          guard condition  action

S1 {
    {    f   state-entry    f                S1-entry      }
    {    f   state-do       f                S1-do         }
    {    f   state-exit     f                S1-exit       }
    {    S2  E1             S1->S2-guard?    S1->S2-action }
    {    S3  E1             S1->S3-guard?    S1->S3-action }   
}
set-transitions

! from   to  event          guard condition  action

S2 {
    {    f   state-entry    f                S2-entry      }
    {    f   state-do       f                S2-do         }
    {    f   state-exit     f                S2-exit       }
    {    S1  E2             f                S2->S1-action }    
}
set-transitions

! from   to    event        guard condition  action

S3 {
    {    f     state-entry  f                S3-entry        }
    {    f     state-do     f                S3-do           }
    {    f     state-exit   f                S3-exit         }
    {    S1-2  E3           f                S3->S1-2-action }
}
set-transitions

! from   to    event        guard condition  action

S1-1 {
    {    f     state-entry   f                S1-1-entry        }
    {    f     state-do      f                S1-1-do           }
    {    f     state-exit    f                S1-1-exit         }
    {    S1-2  E4            f                S1-1->S1-2-action }
}
set-transitions

! from   to  event          guard condition  action

S1-2 {
    {    f    state-entry    f               S1-2-entry        }
    {    f    state-do       f               S1-2-do           }
    {    f    state-exit     f               S1-2-exit         }
    {    S1-1 E5             f               S1-2->S1-1-action }
}
set-transitions" }
"
If you write f for the first element of an array that represents information about a transition, it represents an internal transition. If it is the same as the from state, it represents a self transition.
The second element is the event where the transition occurs. If you write this as f, it means unconditional. However, all transitions require the guard condition of the third element to be met. If the third element is f, there is no guard condition.
The fourth element is the action performed during the transition. If this is written as f, it is interpreted as having no action.
The state-entry, state-do, and state-exit are special events, each representing when a state is entered, while it is in, and when it is exited.
"
"
If you visualize this FSM again, you will see the new additions.
"
{ $code
"FSM1 { { sub-fsm: t } } preview-fsm" }
"
Drive state machines."
{ $code
"event-none next-event set
    
20 [
    FSM1 update nl
    FSM1 next-event get raise-fsm-event
    event-none next-event set
] times" }
;

ABOUT: "karakuri"

