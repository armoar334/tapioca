# Tapioca

function get_env() {
	print("cock haha")
}

function setup_tty() {
	printf("\033[?1049h") # Switch buffer
	system("stty -icanon -ixon -echo")
	# Set non-canonical mode, disable XON/OFF, disable echoing
	# and set stdin timeout to 1
	# This is maybe not super portable, so should be replaced with
	# something better at some point
}

function restore_tty() {
	printf("\033[?1049l") # Switch back
	system("stty icanon ixon echo")
}

function getch() {
	cmd = "dd ibs=6 count=1 2>/dev/null"
	cmd | getline temp
	# ^ This isn't portable, fix
	if ( temp ~ chr[033] ) { key = esc_decode(temp) }
	else if ( temp ~ bsp ) { key = "backspace" }
	else if ( temp ~ /[[:cntrl:]]/ ) {
		key = ord[temp]
		key = key + 64
		key = "ctrl+" chr[key]
	}
	else if ( temp ~ /[[:print:]]/ ) { key = temp }
	else { key = "unknown"; }

	return key
}

function esc_decode(code,	temp) {
	# Modifiers
	temp = ""
	if ( code ~ /;2/ ) { temp = "shift+" }
	else if ( code ~ /;3/ ) { temp = "alt+" }
	else if ( code ~ /;4/ ) { temp = "alt+shift+" }
	else if ( code ~ /;5/ ) { temp = "ctrl+" }
	else if ( code ~ /;6/ ) { temp = "ctrl+shift+" }
	else if ( code ~ /;7/ ) { temp = "ctrl+alt+" }
	else if ( code ~ /;8/ ) { temp = "ctrl+alt+shift+" }

	# Keys
	if ( code ~ /\[.*A$/ ) { temp = temp "up" }
	else if ( code ~ /\[.*B$/ ) { temp = temp "down" }
	else if ( code ~ /\[.*C$/ ) { temp = temp "right" }
	else if ( code ~ /\[.*D$/ ) { temp = temp "left" }
	else if ( code ~ /\[.*F$/ ) { temp = temp "end" }
	else if ( code ~ /\[.*H$/ ) { temp = temp "home" }
	else if ( code ~ /\[2.*~/ ) { temp = temp "insert" }
	else if ( code ~ /\[3.*~/ ) { temp = temp "delete" }
	else if ( code ~ /\[5.*~/ ) { temp = temp "pageup" }
	else if ( code ~ /\[6.*~/ ) { temp = temp "pagedn" }

	return temp
}

BEGIN {
	# Setup tty
	setup_tty()
	# Define keys
	bsp = sprintf("\177")
	new = sprintf("\n")
	tab = sprintf("\t")
	# ASCII lookup
	for(n=0;n<256;n++) { 
		ord[sprintf("%c",n)]=n
		chr[n]=sprintf("%c",n)
	}
	# Main
	key = getch()
	restore_tty()
	printf("%s\n", key )
}
