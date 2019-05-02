<div align="center">
<img src="/images/karakuri.png" title="からくり">
</div>


# Karakuri

A hierarchical finite state machine library for Factor



## Usage

### Create state machines, states and events.

```
USE: karakuri

FSMS:   FSM1 FSM2 ;
STATES: S1 S2 S3 S1-1 S1-2 ;
EVENTS: E1 E2 E3 E4 E5 ;
```

### Assemble the machines and the states.

```
FSM1 { S1 S2 S3 } set-states     ! The state written at first becomes the start state.
S1 { FSM2 } set-sub-fsms         ! equivalent: S1 FSM2 set-sub-fsm
FSM2 { S1-1 S1-2 } set-states
```

If Grraphviz is installed, FSM can be confirmed by visualizing whether it was configured as intended.

```
USE: karakuri.tools
 
FSM1 { { sub-fsm: t } } preview-fsm
```

<div align="center">
<img src="/images/karakuri-usage1.png" >
</div>



The state machine in karakuri is quite similar to that in UML. However, Graphviz does not render state hierarchies well, so it has its own representation of hierarchy.

### Wrie event handlers.

```
USING: kernel accessors namespaces arrays io math formatting
tools.continuations ;

SYMBOL: next-event         event-none next-event set
SYMBOLS: switch ;          switch on
SYMBOLS: wait-counter ;

: S1-entry ( trans -- ) drop                 "S1:entry " write
    1 wait-counter set ;
  
: S1-do ( trans -- ) drop                    wait-counter get "S1:do(%d) " printf
   wait-counter inc
    wait-counter get 5 > [
        E1 next-event set
    ] when ;

: S1-exit ( trans -- ) drop                  "S1:exit " write ;

: S2-entry ( trans -- ) drop                 "S2:entry " write
    switch off 
    E2 next-event set ;

: S2-do ( trans -- ) drop                    "S2:do " write ;

: S2-exit ( trans -- ) drop                  "S2:exit " write ;

: S3-entry ( trans -- ) drop                 "S3:entry " write
    E3 next-event set ;

: S3-do ( trans -- ) drop                    "S3:do " write ;

: S3-exit ( trans -- ) drop                  "S3:exit " write
    switch on ;

: S1-1-entry ( trans -- ) drop               "S1-1:entry " write
    next-event get event-none = [
        E4 next-event set
    ] when ;

: S1-1-do ( trans -- ) drop                  "S1-1:do " write ;

: S1-1-exit ( trans -- ) drop                "S1-1:exit " write ; 

: S1-2-entry ( trans -- ) drop               "S1-2:entry " write
    next-event get event-none = [
        E5 next-event set
    ] when ;

: S1-2-do ( trans -- ) drop                  "S1-2:do " write ;

: S1-2-exit ( trans -- ) drop                "S1-2:exit " write ;

: S1->S2-action ( trans -- ) drop            "(S1 - >S2) " write ;

: S1->S2-guard? ( trans -- ? )  drop
    switch get ;

: S1->S3-action ( trans -- ) drop            "(S1 -> S3) " write ;

: S1->S3-guard? ( trans -- ? ) drop
    switch get not ;

: S2->S1-action ( trans -- ) drop            "(S2 -> S1) " write ;

: S3->S1-2-action ( trans -- ) drop          "(S3 -> S1-2) " write ;

: S1-1->S1-2-action ( trans -- ) drop        "(S1-1 -> S1-2) " write ;

: S1-2->S1-1-action ( trans -- ) drop        "(S1-2 -> S1-1) " write ;
```

### Set transitions to states.

```
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
set-transitions
```

If you write f for the first element of an array that represents information about a transition, it represents an internal transition. If it is the same as the from state, it represents a self transition.

The second element is the event where the transition occurs. If you write this as f, it means unconditional.

However, all transitions require the guard condition of the third element to be met. If the third element is f, there is no guard condition.

The fourth element is the action performed during the transition. If this is written as f, it is interpreted as having no action.

The state-entry, state-do, and state-exit are special events, each representing when a state is entered, while it is in, and when it is exited.

If you visualize this FSM again, you will see the new additions.

```
USE: karakuri.tools
 
FSM1 { { sub-fsm: t } } preview-fsm
```

<div align="center">
<img src="/images/karakuri-usage2.png" >
</div>


### Drive state machines.

```
event-none next-event set
    
10 [
    FSM1 update nl
    FSM1 next-event get raise-fsm-event
    event-none next-event set
] times
```

```
S1:entry S1:do(1) S1-1:entry S1-1:do 
S1:do(2) S1-1:do S1-1:exit (S1-1 -> S1-2) S1-2:entry 
S1:do(3) S1-2:do S1-2:exit (S1-2 -> S1-1) S1-1:entry 
S1:do(4) S1-1:do S1-1:exit (S1-1 -> S1-2) S1-2:entry 
S1:do(5) S1-2:do S1-2:exit (S1-2 -> S1-1) S1-1:entry 
S1:do(6) S1-1:do S1-1:exit S1:exit (S1 - >S2) S2:entry 
S2:do S2:exit (S2 -> S1) S1:entry S1-1:entry 
S1:do(1) S1-1:do S1-1:exit (S1-1 -> S1-2) S1-2:entry 
S1:do(2) S1-2:do S1-2:exit (S1-2 -> S1-1) S1-1:entry 
S1:do(3) S1-1:do S1-1:exit (S1-1 -> S1-2) S1-2:entry 
```