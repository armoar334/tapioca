function editing_mode(filename, 	running) {
	tlen = open_new(filename)
	curl = 1
	curc = 0
	topl = 0
	ptop = 1 # Previous top to check if full redraw is necesary
	running = "true"
	while(running == "true"){
		printf("\033[?25l")
		
		bottom_bar(" "filename" "key" "curl" "curc" "topl" "tlen" "running)
		if ( ptop != topl ) { draw_text() }
		draw_cursor()

		printf("\033[?25h")
		ptop = topl
		key = getch()
		if(key == "ctrl+Q") { running = "false" }
		else if (key == "up") { curl -= 1 }
		else if (key == "down") { curl += 1 }
		else if (key == "left") { curc -= 1 }
		else if (key == "alt+left") { curc = 0 }
		else if (key == "right") { curc += 1 }
		else if (key == "alt+right") { curc = length(text_buffer[curl]) }
		else if (key == "backspace") {
			line = text_buffer[curl]
			line = substr(line, 0, curc - 1)""substr(line, curc + 1)
			text_buffer[curl] = line
			curc -= 1
		}
		else if ( key == "pagedn" ) { curl += lines - 2 }
		else if ( key == "pageup" ) { curl -= lines - 2 }
		else if (key == "delete") {
			line = text_buffer[curl]
			line = substr(line, 0, curc)""substr(line, curc + 2)
			text_buffer[curl] = line
		}
		else if (key == "tab") {
			line = text_buffer[curl]
			line = substr(line, 0, curc)""sprintf("\t")""substr(line, curc + 1)
			text_buffer[curl] = line
			curc += 1
		}
		else if (key ~ /^[[:print:]]$/) {
			line = text_buffer[curl]
			line = substr(line, 0, curc)""key""substr(line, curc + 1)
			text_buffer[curl] = line
			curc += 1
		}
		else if ( key == "bracketpastebeg") {
			pastetmp = ""
			while ( key != "bracketpasteend" ) {
				key = getch()
				pastetmp = pastetmp""key
			}
			line = text_buffer[curl]
			line = substr(line, 0, curc)""pastetmp""substr(line, curc + 1)
			text_buffer[curl] = line
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
		if ( key ~ /^[[:print:]]$/ )
			opentmp = opentmp""key
		else if ( key == "backspace" )
			opentmp = substr(opentmp, 0, -1)
		else if ( key == "newline" )
			opening = "false"
	}
	if ( system("test -f "opentmp) == 0 ) {
		editing_mode(opentmp)
	}
	else
		return 1
}
