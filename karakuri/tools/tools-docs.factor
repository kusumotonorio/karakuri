! Copyright (C) 2019 Your name.
! See http://factorcode.org/license.txt for BSD license.
USING: help.markup help.syntax kernel words.symbol ;
IN: karakuri.tools

HELP: fontname:
{ $var-description "Sets the fontname for Graphviz." } ;

HELP: fontsize:
{ $var-description "Sets the fontname for Graphviz." } ;

HELP: labelfloat:
{ $var-description "Sets the labelfloat for Graphviz." } ;

HELP: nodesep:
{ $var-description "Sets the nodesep for Graphviz." } ;

HELP: preview-fsm
{ $values
    { "fsm-symbol" symbol } { "options/f" "an assoc, or f if no option is given" }
}
{ $description "Displays a graph which expresses the fsm in the UI listener. If f is supplied instead of options, the graph is displayed with default options." } ;

HELP: preview-fsm-window
{ $values
    { "fsm-symbol" symbol } { "options/f" "an assoc, or f if no option is given" }
}
{ $description "Displays a graph which expresses the fsm in a new window.  If f is supplied instead of options, the graph is displayed with default options." } ;

HELP: rankdir:
{ $var-description "Sets the rankdir for Graphviz." } ;

HELP: ranksep:
{ $var-description "Sets the ranksep for Graphviz." } ;

HELP: size:
{ $var-description "Sets the size for Graphviz." } ;

HELP: sub-fsm:
{ $var-description "If anything other than f is given, the underlying fsm is drawn as well, starting at that fsm." } ;

HELP: write-fsm-dot
{ $values
    { "fsm-symbol" symbol } { "options/f" "an assoc, or f if no option is given" } { "path" "a pathname string" } { "encording" "a character encoding" }
}
{ $description "Saves a graph which expresses the fsm as DOT code to path using the given character encoding.
If f is supplied instead of options, the graph is saved with default options." } ;

ARTICLE: "karakuri.tools" "karakuri.tools"
{ $vocab-link "karakuri.tools" }
;

ABOUT: "karakuri.tools"
