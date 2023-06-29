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
	system("stty -isig")     # Disable signals
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

function go_to(line, column) {
	if (column >= 0)
		printf("\033[%s;%sH", line, column)
	else
		printf("\033[%sH", line)
}
