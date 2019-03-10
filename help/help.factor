USING: help.markup karakuri ;

IN: karakuri.help


: $label ( element -- )
    "Label" $heading print-element ;

: $entry-label ( element -- )
    "Entry label" $heading print-element ;

: $do-label ( element -- )
    "Do label" $heading print-element ;

: $exit-label ( element -- )
    "Exit label" $heading print-element ;

: $action-label ( element -- )
    "Action label" $heading print-element ;

: $guard-label ( element -- )
    "Guard label" $heading print-element ;

    



