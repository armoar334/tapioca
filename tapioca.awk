# Tapioca

###########
#  Setup  #
###########

function get_env() {
	if ( index( tolower(ENVIRON["OS"]), "windows" ) > 0 ) { os = "windows" }
	else {
		"uname -a" | getline os
		os = tolower(os)
		if ( os ~ /linux/ ) { os = "linux" }
		else if ( os ~ /darwin/ ) { os = "macos" }
		else if ( os ~ /openbsd/ ) { os = "openbsd" }
		else if ( os ~ /freebsd/ ) { os = "freebsd" }
		else if ( system("test -e /dev/screen") == 0 ) { os = "plan9" }
		else { os = "unknown" }
	}
}

function setup_tty() {
	printf("\033[?1049h") # Switch buffer
	system(stty " -icanon -ixon -echo ")
	# Set non-canonical mode, disable XON/OFF, disable echoing
	# This is maybe not super portable, so should be replaced with
	# something better at some point
}

function restore_tty() {
	printf("\033[?1049l") # Switch back
	system(stty " icanon ixon echo")
}

###########
#  Input  #
###########

function getch() {
	key = ""
	temp = ""
	inputcmd | getline temp
	close(inputcmd)

	if ( temp ~ esc ) { key = esc_decode(temp) }
	else if ( temp ~ chr[127] ) { key = "backspace" }
	else if ( temp == chr[011] ) { key = "tab" }
	else if ( temp ~ /[[:print:]]/ ) { key = temp }
	else if ( temp ~ /[[:cntrl:]]/ ) { key = ord[temp]; key = key + 64; key = "ctrl+" chr[key] }
	else { key = "return" } # \n is annoying to capture, and most other things will be caught elsewhere so its fine for now

	return key
}

function esc_decode(temp) {
	# Modifiers
	code = ""
	if ( temp ~ /;2/ ) { code = "shift+" }
	else if ( temp ~ /;3/ ) { code = "alt+" }
	else if ( temp ~ /;4/ ) { code = "alt+shift+" }
	else if ( temp ~ /;5/ ) { code = "ctrl+" }
	else if ( temp ~ /;6/ ) { code = "ctrl+shift+" }
	else if ( temp ~ /;7/ ) { code = "ctrl+alt+" }
	else if ( temp ~ /;8/ ) { code = "ctrl+alt+shift+" }

	# Keys
	if ( temp == esc ) { code = "escape" }
	else if ( temp ~ /\[.*A$/ ) { code = code "up" }
	else if ( temp ~ /\[.*B$/ ) { code = code "down" }
	else if ( temp ~ /\[.*C$/ ) { code = code "right" }
	else if ( temp ~ /\[.*D$/ ) { code = code "left" }
	else if ( temp ~ /\[.*F$/ ) { code = code "end" }
	else if ( temp ~ /\[.*H$/ ) { code = code "home" }
	else if ( temp ~ /\[2.*~/ ) { code = code "insert" }
	else if ( temp ~ /\[3.*~/ ) { code = code "delete" }
	else if ( temp ~ /\[5.*~/ ) { code = code "pageup" }
	else if ( temp ~ /\[6.*~/ ) { code = code "pagedn" }
	else { key = "unknown" }

	return code
}

###############
#  Interface  #
###############

function goto(line, col) {
	printf("%s[%s;%sH", esc, line, col)
}

function checkwinsize(	temp) {
	printf("%s7%s[9999;9999H%s[6n%s8", esc, esc, esc, esc )
	inputcmd | getline temp
	close(inputcmd)
	gsub(/[^[:digit:];]/, "", temp)
	gsub(esc, "", temp)
	#printf("%s\n", temp)
	split(temp, dims, ";")
	term_lines = dims[1]
	term_cols = dims[2]
	temp = ""
	dims[1] = ""
	dims[2] = ""
}

function error_msg(message) {
	goto(term_lines, 1)
	printf("%s[41m%s%s[0m", esc, message, esc)
}

function bottom_bar(message) {
	goto(term_lines, 1)
	printf("%s[7m%*-s%s[0m", esc, term_cols, message, esc)	
}

function input_bar(prompt,		curc, text, regex) {
	while ( key != "return" ) {
		# Check cursor position
		if ( curc < 0 ) { curc = 0 }
		else if ( curc > length(text) && curc != 0 ) { curc = length(text) }

		# Print it out
		printf("\r %s%s      \r %s%s", prompt, text, prompt, substr(text, 1, curc))

		# Input
		key = getch()
		if ( key ~ /^[[:print:]]$/ ) { text = insert_at_point(text, key, curc); ++curc }
		else if ( key == "backspace" ) { text = substr(text, 1, curc - 1 ) substr(text, curc + 1); --curc }
		else if ( key == "left" ) { --curc }
		else if ( key == "right" ) { ++curc }
	}
	return text
}

#############
#  Editing  #
#############

function insert_at_point(text, insert, point) {
	text = substr(text, 1, point) insert substr(text, point + 1)
	return text
}

function editor_block(filename) {
	count = 0
	while (1) {
		status = getline record < filename
		if ( status == -1 ) { error_msg("File '" filename "' doesn't exist!"); break }
		if ( status == 0 ) break;
		file_array[++count] = record;
	}
	if ( status != -1 ) {
		bottom_bar("File loaded")
		file_len = count
		while ( key != "ctrl+Q" ) {
			# Draw screen
			checkwinsize()
			goto(1, 1)
			#printf("L: %s C: %s", term_lines, term_cols)
			for (i = 1; i < 24; i++ ) {
				printf("%s[7m%*s%s[0m %s\n", esc, length(file_len), i, esc, file_array[i])
			}
			key = getch()
			bottom_bar(" " key)
		}
	}
}

BEGIN {
	# Get various environment info
	get_env()
	if ( os == "windows" ) { print("tapioca doesn't support windows at the moment. Sorry!"); exit }
	if ( os == "unknown" ) { print("tapioca isn't aware of your specific OS and enviroment. Some things may not work!") }

	# Setup input grabber command based on OS
	if ( os != "unknown" ) {
		inputcmd = "dd bs=10 count=1 2>/dev/null"
		stty = "stty"
	}
	if ( os == "plan9" ) {
		stty = "ape/stty"
	}

	# ASCII lookup
	for(n=0;n<256;n++) { 
		ord[sprintf("%c",n)]=n
		chr[n]=sprintf("%c",n)
	}
	esc = sprintf("\033") # escape
	new = sprintf("\n") # return

	# Setup tty
	setup_tty()
	checkwinsize()

	# Main
	#editor_block("new.sh")
	input_bar("enter: ")
	#key = getch()
	restore_tty()
	#printf("%s\n%s\n", key, os)
}
