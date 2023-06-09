#!/usr/bin/env sh

trap 'restore_term' EXIT

# Setup functions

get_term() {
	count=1
	for word in $(stty size)
	do
		case "$count" in
			1) lines="$word" ;;
			2) columns="$word" ;;
		esac
		count=$((count+1))
	done
}

setup_term() {
	default_settings=$(stty -g)

	print_escape '[?1049h'  # Switch buffer
	print_escape '[22t'     # Save window name + icon

	print_escape '[?2004h'  # Bracketed paste
	print_escape '[?7l'     # Disable line wrapping
	#print_escape '[?25l'    # Hide cursor
	print_escape ']0;tapioca' # Window title
	clear
	stty -icanon # So we can read one at a time
	stty -ixon # Disable XON/XOFF
	stty -echo # Dont echo user input
	stty intr '' # Unbind sigint, normally ctrl-c
}

restore_term() {
	print_escape '[?1049l'  # Switch buffer
	print_escape '[23t'     # Restore window name + icon
	print_escape '[?25h'    # Show cursor
	stty "$default_settings"
}

# Interface functions

print_escape() {
	printf '\033%s' "$1"
}

go_to() {
	if [ -z "$2" ]
	then
		temp="[$1H"
	else
		temp="[$1;$2H"
	fi
	print_escape "$temp"
}

getch() {
	key=''
	temp=''

	esc=$(print_escape)
	bsp=$(printf '\177')
	new=$(printf '\n')
	tab=$(printf '\t')

	while [ -z "$key" ]
	do
		char=$(dd ibs=1 count=1 2>/dev/null)
		temp="$temp$char"
		case "$temp" in
			"$esc"*) esc_decode "$temp" ;;
			"$bsp") key='backspace' ;;
			"$new") key='newline' ;;
			"$tab") key='tab' ;;
			' ') key='space' ;;
			[[:print:]]) key="$char" ;;
			[[:cntrl:]])
				key=$(( $(printf '%d' "'$temp") + 64 ))
				key=$( printf '%03o' "$key")
				key='ctrl+'$( printf '\'"$key");;
			*) key='unknown' ;;
		esac
	done
}

esc_decode() {
	code="$*"
	dec_temp=''
	case "$code" in
		*[A-Z]|*'~') # Only process when code is done
		case "$code" in
			*';2'*) dec_temp='shift+' ;;
			*';3'*) dec_temp='alt+' ;;
			*';4'*) dec_temp='alt+shift+' ;;
			*';5'*) dec_temp='ctrl+' ;;
			*';6'*) dec_temp='ctrl+shift+' ;;
			*';7'*) dec_temp='ctrl+alt+' ;;
			*';8'*) dec_temp='ctrl+alt+shift' ;;
		esac
		case "$code" in
			$esc'['*'A')  key="$dec_temp""up" ;;
			$esc'['*'B')  key="$dec_temp""down" ;;
			$esc'['*'C')  key="$dec_temp""right" ;;
			$esc'['*'D')  key="$dec_temp""left" ;;
			$esc'['*'F')  key="$dec_temp""end" ;;
			$esc'['*'H')  key="$dec_temp""home" ;;
			$esc'[2'*'~') key="$dec_temp""insert" ;;
			$esc'[3'*'~') key="$dec_temp""delete" ;;
			$esc'[5'*'~') key="$dec_temp""pageup" ;;
			$esc'[6'*'~') key="$dec_temp""pagedn" ;;
		esac ;;
	esac

	if [ -z "$key" ] && [ "${#code}" -gt 6 ]
	then
		key='unknown'
	fi
}

landing_page() {
	logo=$(cat <<-EOF
 ${yel} .. ... . ${end}
 ${yel}##########${end}
 ${end}\________/${end}
 ${end} \______/ ${end}

^O Open file
  ^Q Quit
	EOF
	)

	# Welcome
	go_to "$(( ( lines / 2 ) - 4 ))" "$(( ( columns / 2 ) - 9 ))"
	printf "%s${yel}%s${end}\n" 'welcome to ' 'tapioca'

	# System + shell
	cursh=$(ps -p $$)
	cursh="${cursh##* }"
	if [ -h "$(which $cursh)" ]
	then
		cursh="$(readlink $(which $cursh))"
	fi
	cursh="running under $cursh"

	case "$(uname -a)" in
		Linux*)   cursh="$cursh on linux"  ;;
		Darwin*)  cursh="$cursh on macOS"  ;;
		OpenBSD*) cursh="$cursh on openbsd";;
		FreeBSD*) cursh="$cursh on freebsd";;
		Serenity) cursh="$cursh on serenityOS" ;;
		Plan9*)   cursh="$cursh on plan9" ;; # This ones a little optimistic
		*) cursh="$cursh on unknown" ;;
	esac
	go_to "$(( ( lines / 2 ) - 3 ))" "$(( ( columns / 2 ) - ( ${#cursh} / 2 ) ))"
	count=1
	for word in $(echo $cursh)
	do
		case "$count" in
			3) printf "${blu}%s${end} " "$word" ;;
			5) printf "${red}%s${end} " "$word" ;;
			*) printf "%s " "$word" ;;
		esac
		count="$((count+1))"
	done

	# logo
	count=1
	echo "$logo" | while IFS= read -r line
	do
		go_to "$(( ( lines / 2 ) - 2 + count ))" "$(( ( columns / 2 ) - 5 ))"
		echo "$line"
		count="$((count+1))"
	done
	landing=true
	while [ "$landing" = true ]
	do
		bottom_bar " welcome to tapioca!"
		getch
		case "$key" in
			*[Qq]) landing=false ;;
			'ctrl+'[Oo])
				landing=false
				open_ask
				editing_mode ;;
		esac
	done
}

# Editing

editing_mode() {
	main_running=true
	key='' # Just so it doesnt crash first time drawing bar
	while [ "$main_running" = true ]
	do
		printf '%s' "$( bottom_bar " $file_name $key $curl $curc $topl $tlen"
		draw_text )"
		getch
		case "$key" in
			'ctrl+'[Qq]) main_running=false ;;
			'ctrl+'[Oo]) open_ask ;;
			'ctrl+'[Ss]) save_ask ;;
			'up')   curl=$(( curl - 1 )) ;;
			'down') curl=$(( curl + 1 )) ;;
			'left') curc=$(( curc - 1 )) ;;
			'right')curc=$(( curc + 1 )) ;;
			'pageup') curl="$(( curl - ( lines - 1 ) ))" ;;
			'pagedn') curl="$(( curl + ( lines - 1 ) ))" ;;
			'newline')
				newline 
				curc=0
				curl=$((curl+1))
				tlen=$((tlen+1)) ;;
			'backspace')
				delete
				curc=$((curc-1)) ;;
			[[:print:]])
				insert "$key"
				curc=$((curc+1)) ;;
			'space')
				insert ' '
				curc=$((curc+1)) ;;
			*) ;;
		esac

		# This is maybe not portable but it works well enough so
		# Curl sanitize
		case 1 in
			$(( curl < 1 )) ) curl=1 ;;
			$(( curl > tlen )) ) curl="$tlen" ;;
		esac

		# Curc sanitize
		case 1 in
			$(( curc < 1 )) ) curc=1 ;;
		esac

		# Scroll check
		case 1 in
			$(( ( curl - topl ) < 0 )) ) topl="$curl" ;;
			$(( ( curl - topl ) > ( lines - 2 ) )) ) topl=$(( curl - ( lines - 2 ) )) ;;
		esac

		
		# Scroll sanitize
		if [ $(( topl + ( lines - 1 ) )) -ge  "$tlen" ]; then topl=$(( tlen - ( lines - 1 ) )); fi
		if [ "$topl" -lt 1 ]; then topl=1; fi

	done
}

save_ask() {
	saving=false
	bottom_bar " Save (y/n)?"
	getch
	case "$key" in
		[Yy]) saving=true ;;
		*) ;;
	esac
	if [ "$saving" = true ]
	then
		printf '%s\n' "$text_buffer" > "$file_name"
	fi
}

open_ask() {
	opening=true
	open_temp=''
	bottom_bar " Open:"
	while [ "$opening" = true ]
	do
		getch
		case "$key" in
			[[:print:]])
				open_temp="$open_temp$key"
				bottom_bar " Open: $open_temp" ;;
			'backspace')
				open_temp="${open_temp%?}"
				bottom_bar " Open: $open_temp" ;;
			'newline') opening=false ;;
			'tab') bottom_bar " Open: $open_temp | "$(echo "$open_temp"*) ;;
			*) bottom_bar " Open: $open_temp" ;;
		esac
	done
	open_file "$open_temp"
}

open_file() {
	open_temp="$1"
	if [ -f "$open_temp" ]
	then
		file_name="$open_temp"
		text_buffer=$(cat "$open_temp")
		curl=1
		curc=1
		topl=1
		tlen=$(printf '%s\n' "$text_buffer" | line_count )
	else
		bottom_bar "File $open_temp not found or not file"
	fi
}

line_count() (
	count=0
	while IFS= read -r line
	do
		count=$((count+1))
	done
	echo "$count"
)

draw_text() (
	go_to 1
	count="$topl"
	printf '%s' "$text_buffer" | sed -n "$topl"",$(( ( topl + lines ) - 2 ))p" | while [ "$count" -lt $(( topl + ( lines - 1 ) )) ] && IFS= read -r line
	do
		print_escape '[2K'
		printf "${inv}%*s${end} " 3 "$count"
		if [ "$count" -eq "$curl" ]
		then
			temp="$(printf '%*s' $((curc-1)) | tr ' ' '?')"
			p1="${line#""$temp""}"
			p1="${line%"$p1"}"
			
			p2="${line#""$temp""}"

			printf '%s' "$p1"
			print_escape '7'
			printf '%s\n' "$p2"
		else
			printf '%s\n' "$line"
		fi
		count="$((count+1))"
	done | sed 's/\t/    /g'
	if [ "$tlen" -lt $(( lines - 1 )) ]
	then
		count="$tlen"
		until [ "$(( count - topl ))" -eq $(( lines - 1)) ]
		do
			print_escape '[K'
			echo
			count=$((count+1))
		done
	fi
	print_escape '8'
)


insert() {
	inschar="$1"
	text_buffer=$(
	count=1
	printf '%s\n' "$text_buffer" | while IFS= read -r line
	do
		if [ "$count" -eq "$curl" ];
		then
			cunk=1
			until [ -z "$line" ]
			do
				printf '%.1s' "$line"
				line="${line#?}"
				if [ "$cunk" -eq "$curc" ]
				then
					printf '%s' "$inschar"
				fi
				cunk=$(( cunk + 1 ))
			done
			echo
		else
			printf '%s\n' "$line"
		fi
		count=$((count+1))
	done
	)	
}

delete() {
	if [ "$curc" -le 1 ]; 
	then
		text_buffer=$(
		count=1
		printf '%s\n' "$text_buffer" | while IFS= read -r line
		do
			if [ "$count" -eq "$((curl-1))" ];
			then
				printf '%s' "$line"
			else
				printf '%s\n' "$line"
			fi
			count=$((count+1))
		done
		)
		tlen=$((tlen-1))
	else
		text_buffer=$(
		count=1
		printf '%s\n' "$text_buffer" | while IFS= read -r line
		do
			if [ "$count" -eq "$curl" ];
			then
				printf '%s\n' "$line" | sed 's/.//'$((curc-1))''
			else
				printf '%s\n' "$line"
			fi
			count=$((count+1))
		done
		)
	fi
}

newline() {
	text_buffer=$(
	count=1
	printf '%s\n' "$text_buffer" | while IFS= read -r line
	do
		if [ "$count" -eq "$curl" ];
		then
			if [ -z "$line" ];
			then
				echo ''
			else
				printf '%s\n' "$line" | sed 's/^\(.\{'$((curc-1))'\}\)/\1\n/'
			fi
		else
			printf '%s\n' "$line"
		fi
		count=$((count+1))
	done
	)	
}

bottom_bar() {
	go_to "$lines"
	printf "$inv%-*s$end" "$columns" "$*"
}

# Colors

inv=$(print_escape '[7m')
red=$(print_escape '[31m')
gre=$(print_escape '[32m')
yel=$(print_escape '[33m')
blu=$(print_escape '[34m')
end=$(print_escape '[0m')

get_term
setup_term

if [ -f "$*" ]
then
	open_file "$*"
	editing_mode
else
	landing_page
fi

restore_term
