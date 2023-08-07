# Tapioca
## An portable, lightweight editor in nearly strict posix shell and non-GNU coreutils

## Intro
Tapioca is built to be as portable as possible out of the box, without sacrificing usability.

It was built to fill a space that doesn't really exist currently, in that there are two core concepts it fulfils:
 - The most portable software is interpreted, as it will then run on any architechture or standard implementation
 - The closest thing to a standard "interpreter" is sh (although technichally that priviledge may be given to awk)  

## Rules
 - Portability is primary, but ease of use / extensibility is also an important factor. Therefore, functions may be implemented in a way that allows them to be workarounds for limitations or bugs on certain platforms / enviroments, such as 256 / rgb colors and xterm mouse support

## Basic keybinds
 - Arrows to move around
 - Any normal key without modifiers has no effect and will just insert itself into the buffer
 - Delete, Backspace, Newline, Tab etc work as you would expect
 - Home and End go to the start and end of a file respectively
 - PageUp / PageDown go up and down by the current height of the display
 - ctrl+Q to quit
 - ctrl+O to open a new file
 - ctrl+S to save

## Shells
bash, ash, dash, ksh93, zsh - working, fast  
oksh - works, very slow  
yash - doesn't work as yash printf hasnt got padding format specifier  
