#!/usr/bin/env -S awk --posix -f

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
	printf("\033]0;tapioca") # Xterm title for vanity
}

function restore_term(tty_defs) {
	printf("\033[?1049l") # Back to OG buffer
	printf("\033[23t")    # Restore title stack
	system("stty echo")   # Show user input
	cmd = "stty "$tty_defs
	cmd
	close(cmd)
}

function go_to(line, column) {
	if (column >= 0)
		printf("\033[%s;%sH", line, column)
	else
		printf("\033[%sH", line)
}

function getch() {
	key=""
	temp=""

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
		else if ( temp ~ /[[:cntrl:]]/)
			key = ctrl_decode(temp)
		else if ( temp ~ /[[:print:]]/)
			key = temp
		else if ( temp ~ /\t/ )
			key = "tab"
		else if ( temp == "" )
			key = "newline"
	}

	return key
}

function ctrl_decode(temp) {
	for(n=0;n<256;n++) {
		ord[sprintf("%c",n)]=n
		chr[n]=sprintf("%c",n)
	}
	temp = ord[temp]
	temp = temp + 64
	temp = chr[temp]
	temp = "ctrl+"temp
	return temp
}

function esc_decode(temp) {
	# Only if its done
	if ( temp ~ /[A-Z~]$/ ) {
		#  Modifiers
		if ( temp ~ /;2/ )
			key = "shift+"
		else if ( temp ~ /;3/ )
			key = "alt+"
		else if ( temp ~ /;4/ )
			key = "alt+shift+"
		else if ( temp ~ /;5/ )
			key = "ctrl+"
		else if ( temp ~ /;6/ )
			key = "ctrl+shift+"
		else if ( temp ~ /;7/ )
			key = "ctrl+alt+"
		else if ( temp ~ /;8/ )
			key = "ctrl+alt+shift+"

		if ( temp ~ /A$/)
			key = key"up"
		else if ( temp ~ /B$/)
			key = key"down"
		else if ( temp ~ /C$/)
			key = key"right"
		else if ( temp ~ /D$/)
			key = key"left"
		else if ( temp ~ /F$/)
			key = key"end"
		else if ( temp ~ /H$/)
			key = key"home"
		else if ( temp ~ /\[2.*~$/)
			key = key"insert"
		else if ( temp ~ /\[3.*~$/) 
			key = key"delete"
		else if ( temp ~ /\[5.*~$/)
			key = key"pageup"
		else if ( temp ~ /\[6.*~$/)
			key = key"pagedn"

		if ( length(key) > 4 ) {
			key="unknown"
		}

		return key
	}
	else {
		return ""
	}
}

# Interface

function bottom_bar(temp) {
	go_to(lines)
	printf("\033[7m%-*s\033[0m", columns, temp)
}

function landing_page() {
	go_to( int( ( lines / 2 ) - 4 ), int( ( columns / 2 ) - 9 ) )
	printf("welcome to \033[33mtapioca\033[0m")
	go_to( int( ( lines / 2 ) - 3 ), int( ( columns / 2 ) - 13 ) )
	printf("running under \033[32mawk\033[0m on \033[31m%s\033[0m", os)

	logo[1] = sprintf("\033[33m")"  .. ... . "
	logo[2] = sprintf("\033[33m")" ##########"
	logo[3] = sprintf("\033[0m")" \\________/"
	logo[4] = sprintf("\033[0m")"  \\______/ "
	logo[5] = ""
	logo[6] = sprintf("\033[0m^O Open file\033[0m")
	logo[7] = sprintf("\033[0m  ^Q Quit\033[0m")
	go_to( int( ( lines / 2 ) - 1 ) )
	for(n=1;n<=7;n++) {
		printf("\033[%sC%s\033[0m\n", int( ( columns / 2 ) - 6 ), logo[n])
	}	
	bottom_bar(" welcome to tapioca!")
}

function editing() {
	print ""
}

function main() {
	tty_defs = get_stty()
	setup_term()
	get_term()
	landing_page()
	running = "true"
	while(running == "true"){
		key = getch()
		bottom_bar(" "key)
		if(key == "q"){
			running=false
		}
	}
	restore_term(tty_defs)
}

BEGIN {	
	main()
}
