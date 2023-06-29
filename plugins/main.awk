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
