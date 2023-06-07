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

		if ( length(temp) > 8 ) {
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

	landing = "true"
	while( landing == "true" ) {
		key = getch()
		if ( key == "ctrl+Q" )
			landing = "false"
		else if ( key ~ /[Qq]/ )
			landing = "false"
		bottom_bar(" welcome to tapioca! "key)
	}
}

function editing_mode(filename) {
	tlen = open_new(filename)
	curl = 1
	curc = 0
	topl = 0
	ptop = 1 # Previous top to check if full redraw is necesary
	running = "true"
	while(running == "true"){
		printf("\033[?25l")
		
		bottom_bar(" "filename" "key" "curl" "curc" "topl" "tlen" "ARGC)
		if ( ptop != topl ) { draw_text() }
		draw_cursor()

		printf("\033[?25h")
		ptop = topl
		key = getch()
		if(key == "ctrl+Q")
			running=false
		else if (key == "up")
			curl -= 1
		else if (key == "down")
			curl += 1
		else if (key == "left")
			curc -= 1
		else if (key == "alt+left")
			curc = 0
		else if (key == "right")
			curc += 1
		else if (key == "alt+right")
			curc = length(text_buffer[curl])
		else if (key == "backspace") {
			line = text_buffer[curl]
			line = substr(line, 0, curc - 1)""substr(line, curc + 1)
			text_buffer[curl] = line
			curc -= 1
		}
		else if ( key == "pagedn" )
			curl += lines - 2
		else if ( key == "pageup" )
			curl -= lines - 2

		else if (key == "delete") {
			line = text_buffer[curl]
			line = substr(line, 0, curc)""substr(line, curc + 2)
			text_buffer[curl] = line
		}
		else if (key ~ /^[[:print:]]$/) {
			line = text_buffer[curl]
			line = substr(line, 0, curc)""key""substr(line, curc + 1)
			text_buffer[curl] = line
			curc += 1
		}



		if ( curc < 0 ) {
			if ( curl > 1 ) {
				curl -= 1
				curc = length(text_buffer[curl])
			}
			else
				curc = 0
		}
		if ( curc > length(text_buffer[curl]) ) {
			if ( curl < tlen ) {
				curl += 1
				curc = 0
			}
			else
				curc = length(text_buffer[curl])
		}

		if ( curl < 1 ) { curl = 1 }
		if ( curl > tlen) { curl = tlen }

		if ( curl - topl < 1 ) { topl = curl - 1 }
		if ( curl - topl > lines - 1 ) { topl = curl - ( lines - 1 ) }

		
	}
}

function draw_text() {
	go_to(1)
	for(n=1;n<lines;n++) {
		printf("\033[7m%*s\033[0m ", length(tlen), n + topl)
		line = text_buffer[n + topl]
		if ( length(line) > columns - length(tlen) + 1 ) {
			line = substr(line, 0, columns - length(tlen) - 2 )""sprintf("\033[7m>\033[0m")
		}
		gsub(/\t/, "    ", line)
		printf("%-*s\n", columns - length(tlen) - 1, line)
	}
}

function draw_cursor() {
	go_to(curl - topl)
	printf("\033[7m%*s\033[0m ", length(tlen), curl)
	line = text_buffer[curl]
	line = substr(line, 0, curc)""sprintf("\033""7")""substr(line, curc + 1)
	gsub(/\t/, "    ", line)
	printf("%-*s\n", columns - length(tlen) + 1, line)
	printf("\033""8")
}

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

function open_ask() {
	opening = "true"
	opentmp = ""
	while ( opening == "true" ) {
		bottom_bar(" Open: "opentmp)
		key = getch()
		if ( key ~ /[[:print:]]/ )
			opentmp = opentmp""key
		else if ( key == "backspace" )
			opentmp = substr(opentmp, 0, -1)
	}
}

function main() {
	tty_defs = get_stty()
	setup_term()
	get_term()
	if ( ARGC > 1 ) {
		if ( system("test -f "ARGV[1]) == 0 )
			editing_mode(ARGV[1])
		else
			landing_page()
	}
	else {
		landing_page()
	}
	restore_term(tty_defs)
}

BEGIN {	
	main()
}
