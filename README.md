# Tapioca
## An portable, lightweight editor in nearly strict posix shell and non-GNU coreutils

## Intro
Tapioca is built to be as portable as possible out of the box, without sacrificing usability.
tapioca.sh is the original, posix sh version, although it was too slow and inflexible to be brought up to standard. It is kept here for reference

It was built to fill a space that doesn't really exist currently, in that there are two core concepts it fulfils:
 - The most portable software is interpreted, as it will then run on any architechture or standard implementation
 - The closest thing to a standard "interpreter" is awk

## Rules
 - Nothing too far out of support from the most basic terminals. I.e no 256 color, no xterm mouse support, nothing that wouldnt work on a real vt100 (or vt200, thats probably more reasonable) WITH THE SINGLE EXCEPTION of brackted paste
 - No implementation specific workaround! no testing for version for any reason other than to show on the landing page. Compatability, not Concessions!


## Basic keybinds
 - Arrows to move around
 - Any normal key without modifiers has no effect and will just insert itself into the buffer
 - Delete, Backspace, Newline, Tab etc work as you would expect
 - Home and End go to the start and end of a file respectively
 - PageUp / PageDown go up and down by the current height of the display
 - ctrl+Q to quit
 - ctrl+O to open a new file
 - ctrl+S to save
