#!/bin/awk -f

# Terminal

function get_term() {
	cmd = "stty size"
	cmd | getline temp
	close(cmd)
	split(temp,temparr," ")
	lines = temparr[1]
	columns = temparr[2]
}

function get_stty() {
	cmd = "stty -g"
	cmd | getline temp
	close(cmd)
	return temp
}

function setup_term() {
	cmd = "uname -a"
	cmd | getline temp
	split(temp,temparr," ")
	os = temparr[1]

	system("stty -icanon")   # Non canonical mode
	system("stty -echo")     # Don't show user input
	system("stty -ixon")     # Don't have XON/XOFF
	printf("\033[?1049h")    # Switch buffer
	printf("\033[22t")       # Xterm title stack
	printf("\033[2004h")     # Bracketed paste enable
	printf("\033]0;tapioca\007") # Xterm title for vanity
}

function restore_term(tty_defs) {
	printf("\033[?1049l") # Back to OG buffer
	printf("\033[23t")    # Restore title stack
	system("stty echo")   # Show user input
	cmd = "stty "$tty_defs
	cmd
	close(cmd)
}

# Interface

function go_to(line, column) {
	if (column >= 0)
		printf("\033[%s;%sH", line, column)
	else
		printf("\033[%sH", line)
}

function print_colored(string, colorstring) {
	printf("\033[%sm%s\033[0m", colorstring, string)
}

function draw_text(topl) {
	tlen = open_new("/home/alfie/.bashrc")
	go_to()
	for(line = topl; line < lines - topl; line++) {
		text_line = text_buffer[line]
		if (line == curl) {
			p1 = substr(text_buffer[line], 0, curc - 1)
			p2 = substr(text_buffer[line], curc, 1)
			p3 = substr(text_buffer[line], curc + 1)
			if ( p2 == "" ) { p2 = " "}
			if ( p2 ~ /\t/) { p2 = sprintf(" \033[0m   ")}
			gsub(/\t/, "    ", p1)
			gsub(/\t/, "    ", p2)
			gsub(/\t/, "    ", p3)
			
			printf("\033[7m%*s\033[0m %s\033[7m%s\033[0m%s\n", length(tlen), line, p1, p2, p3)
		}
		else {
			gsub(/\t/, "    ", text_line)
			printf("\033[7m%*s\033[0m %s\n", length(tlen), line, text_line)
		}
	}
}

# Editing

function open_new(filename) {
	count = 0
	while (1) {
		status = getline record < filename
		if (status == -1) {
			bottom_bar("Error reading file "filename)
			exit 1
		}
		if (status == 0) break
		text_buffer[++count] = record
	}
	close(filename)
	return count
}

# Input

function getch() {
	key = ""
	temp = ""

	esc = sprintf("\033")
	bsp = sprintf("\177")
	new = sprintf("\012")
	tab = sprintf("\t")

	while( key == "" ) {
		cmd = "dd ibs=1 count=1 2>/dev/null"
		cmd | getline char
		close(cmd)
		temp = sprintf("%s%s", temp, char)
		if( temp ~ esc )
			key = esc_decode(temp)
		else if( temp ~ bsp )
			key = "backspace"
		else if ( temp ~ " " )
			key = "space"
		else if ( temp ~ /\t/ )
			key = "tab"
		else if ( temp ~ /[[:cntrl:]]/)
			key = ctrl_decode(temp)
		else if ( temp ~ /[[:print:]]/)
			key = temp
		else if ( temp == "" )
			key = "newline"
	}

	return key
}

function esc_decode(temp) {
	modifier = ""
	# modifiers
	if ( temp ~ /;2/) { modifier = "shift+"}
	if ( temp ~ /;3/) { modifier = "alt+"}
	if ( temp ~ /;4/) { modifier = "alt+shift+"}
	if ( temp ~ /;5/) { modifier = "ctrl+"}
	if ( temp ~ /;6/) { modifier = "ctrl+shift+"}
	if ( temp ~ /;7/) { modifier = "ctrl+alt+"}
	if ( temp ~ /;8/) { modifier = "ctrl+alt+shift+"}

	# keycodes
	if ( temp ~ /A$/) { key = modifier"up"}
	if ( temp ~ /A$/) { key = modifier"up"}
	if ( temp ~ /B$/) { key = modifier"down"}
	if ( temp ~ /C$/) { key = modifer"right"}
	if ( temp ~ /D$/) { key = modifier"left"}
	if ( temp ~ /F$/) { key = modifier"end"}
	if ( temp ~ /H$/) { key = modifier"home"}
	if ( temp ~ /P$/) { key = modifier"f1"}
	if ( temp ~ /Q$/) { key = modifier"f2"}
	if ( temp ~ /R$/) { key = modifier"f3"}
	if ( temp ~ /S$/) { key = modifier"f4"}
	if ( temp ~ /15~$/) { key = modifier"f5"}
	if ( temp ~ /17~$/) { key = modifier"f6"}
	if ( temp ~ /18~$/) { key = modifier"f7"}
	if ( temp ~ /19~$/) { key = modifier"f8"}
	if ( temp ~ /20~$/) { key = modifier"f9"}
	if ( temp ~ /21~$/) { key = modifier"f10"}
	if ( temp ~ /23~$/) { key = modifier"f11"}
	if ( temp ~ /24~$/) { key = modifier"f12"}
	if ( temp ~ /\[200~$/) { key = modifier"bracketpastebeg"}
	if ( temp ~ /\[201~$/) { key = modifier"bracketpasteend"}
	if ( temp ~ /\[2.*~$/) { key = modifier"insert"}
	if ( temp ~ /\[3.*~$/) { key = modifier"delete"}
	if ( temp ~ /\[5.*~$/) { key = modifier"pageup"}
	if ( temp ~ /\[6.*~$/) { key = modifier"pagedn"}

	return key
}

function ctrl_decode(temp) {
	# Ascii arrays
	for(n=0;n<256;n++) {
		ord[sprintf("%c",n)]=n
		chr[n]=sprintf("%c",n)
	}
	temp = ord[temp]
	# ctrl of character is n + 64 of regular character
	temp = temp + 64
	temp = chr[temp]
	temp = "ctrl+"temp
	return temp

}

BEGIN {
	get_term()
	get_stty()
	setup_term()
	curl = 8
	curc = 3
	topl = 1
	while( key != "ctrl+Q" ) {
		draw_text(topl)
		go_to(lines)
		print_colored(key, 32)
		key = getch()
		if ( key == "up" ) { curl-- }
		if ( key == "down" ) { curl++ }
		if ( key == "left" ) { curc-- }
		if ( key == "right" ) { curc++ }
	}
	restore_term()
}
