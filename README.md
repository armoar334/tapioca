# Tapioca
## An portable, lightweight editor in nearly strict posix shell and non-GNU coreutils

## Intro
Tapioca is built to be as portable as possible out of the box, without sacrificing usability.

It was built to fill a space that doesn't really exist currently, in that there are two core concepts it fulfils:
 - The most portable software is interpreted, as it will then run on any architechture or standard implementation
 - The closest thing to a standard "interpreter" is posix sh

The best performance I have found comes from running under busybox ash

## Rules
 - Replace as many external utilities as possible with pure shell, for speed. ```sh``` is slow, calling externals is slower.
 - Nothing too far out of support from the most basic terminals. I.e no 256 color, no xterm mouse support, nothing that wouldnt work on a real vt100 (or vt200, thats probably more reasonable) WITH THE SINGLE EXCEPTION of brackted paste

## Basic keybinds
 - Arrows to move around
 - Any normal key without modifiers has no effect and will just insert itself into the buffer
 - Delete, Backspace, Newline, Tab etc work as you would expect
 - Home and End go to the start and end of a file respectively
 - PageUp / PageDown go up and down by the current height of the display
 - ctrl+q to quit
