#!/usr/bin/env dash

# Tapioca

trap 'restore_term' EXIT
trap 'exit' INT
trap 'sizeof_term' WINCH

sizeof_term() {
	printf '%s[9999;9999H%s[6n' "$escape" "$escape"
	running=true
	while [ "$running" = true ]
	do
		char=$(dd ibs=1 count=1 2>/dev/null)
		temp="$temp""$char"
		case "$temp" in
			*'R')
				IFS='[;R' read -r _ lines columns _ <<EOF
"$temp"
EOF
				running=false ;;
		esac
	done
	temp=
	char=
	running=
}

setup_term() {
	# Set escape sequence
	escape=$(printf '\033')
	# Set color sequences
	inv=$(printf '\033[7m')
	red=$(printf '\033[31m')
	gre=$(printf '\033[32m')
	yel=$(printf '\033[33m')
	blu=$(printf '\033[34m')
	end=$(printf '\033[0m')

	# Save stty settings
	prior="$(stty -g)"
	printf '%s[?1049h' "$escape" # Switch buffer
	#printf '%s[?25l' "$escape" # Hide cursor
	stty -icanon
	stty -ixon
	stty -echo
}

restore_term() {
	printf '%s[?1049l' "$escape" # Switch buffer
	#printf '%s[?25h' "$escape" # Hide cursor
	stty "$prior"
}

go_to() {
	if [ -z "$2" ]
	then
		temp="[$1H"
	else
		temp="[$1;$2H"
	fi
	printf '\033%s' "$temp"
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
	if [ -h "$(which "$cursh")" ]
	then
		cursh="$(readlink "$(which "$cursh")")"
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
}

bottom_bar() {
	printf '\033[%sH%s%-*s%s' "$lines" "${inv}" "$columns" "$*" "${end}"
}

getch() {
	key=''
	temp=''
	
	esc=$(printf '\033')
	bsp=$(printf '\177')
	new=$(printf '\n')
	tab=$(printf '\t')

	while [ -z "$key" ]
	do
		# This introduces a shit ton of latency, some pure posix witchcraft is a holy grail for speed here
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

# pure posix equivalent to ${var//pattern/replace}
replace_all() {
	r_side="$1"
	l_side=
	t_end=
	while [ -n "$r_side" ]
	do
		l_side="${r_side%%$2*}"
		if  [ "$l_side" = "$r_side" ]
		then
			t_end="$t_end""$r_side"
			return
		fi
		t_end="$t_end""$l_side""$3"
		r_side="${r_side#*$2}"
	done
}

# pure posix equivalent to ${var/pattern/replace}
replace_one() {
	l_side="$1"
	t_end="${l_side%%$2*}""$3""${l_side#*$2}"
}

cursor_line_highlight() {	
	temp_line="$line"
	while [ "${#temp_line}" -ge "$curc" ]
	do
		temp_line="${temp_line%?}"
	done
	line="${red}""$temp_line""${end}""$escape"'[s'"${line#"$temp_line"*}"
}

# Shell equivalent to fold -s -w $2
word_wrapper() {
	to_proc="$1"
	procd=
	t_end=
	while [ "${#to_proc}" -gt "$2" ]
	do
		procd="$to_proc"
		while [ "${#procd}" -gt "$2" ]
		do
			procd="${procd% *}"
		done
		to_proc="${to_proc#"$procd" }"
		t_end="$t_end""$procd"'
'
		# ^ once again, this is dogshit
		procd=''
	done
	t_end="$t_end""$to_proc"
}

draw_text() {
	printf '%s[H' "$escape"
	tab=$(printf '\t')
	screen_line="$toplin"
	text_line="$toplin"
	until [ "$screen_line" -ge $(( toplin + ( lines - 1 ) )) ] || [ "$text_line" -gt "$file_leng" ]
	do
		if [ "$text_line" = "$curl" ]
		then
			line="$curr_text"
		else
			eval "line=\"\${$text_line}\""
		fi
		replace_all "$line" "$tab" '    '
		line="$t_end"
		printf '%s[K%s%*s%s ' "$escape" "${inv}" "${#file_leng}" "$text_line" "${end}"
		# Line wrapping ( baaaaaaaad )
		if [ "${#line}" -gt $(( columns - ( ${#file_leng} + 1 ))) ]
		then
			word_wrapper "$line" $(( columns - ( ${#file_leng} + 1 )))
			line="$t_end"
			if [ "$text_line" = "$curl" ]
			then
				cursor_line_highlight
			fi
			
			while IFS= read -r temp_line
			do
				screen_line=$(( screen_line + 1 ))
				printf '%s\n%s%*s%s ' "$temp_line" "${inv}" ${#file_leng} '' "${end}"
			done <<EOF
$line
EOF
		printf '\033[%sD' $(( ${#file_leng} + 1 ))
		else
		# No line wrapping ( swag )
			if [ "$text_line" = "$curl" ]
			then
				cursor_line_highlight
			fi
			printf '%s\n' "$line"
		fi
		screen_line=$(( screen_line + 1 ))
		text_line=$(( text_line + 1 ))
	done
	# Clear lines if no text on them
	until [ "$screen_line" -ge $(( toplin + ( lines - 3 ) )) ] 
	do
		printf '%s[2K\n' "$escape"
		screen_line=$(( screen_line + 1 ))
	done
	printf '\033[u'
}

mini_prompt() {
	prompt="$1"
	bottom_bar ''
	entering=true
	t_end=''
	while [ "$entering" = true ]
	do
		printf '\033[%sH%s%s%s %s[D' "$lines" "${inv}" "$prompt" "$t_end" "$escape"
		getch
		case "$key" in
			[[:print:]]) t_end="$t_end""$key" ;;
			'space') t_end="$t_end " ;;
			'backspace') t_end="${t_end%?}" ;;
			'newline') entering=false ;;
		esac
	done
}

# Keep curc in bounds
curc_bound() {
	if [ "$curc" -lt 1 ]
	then
		curc=1
	fi
	if [ $(( curc - 1 )) -gt "${#curr_text}" ]
	then
		curc=$(( ${#curr_text} + 1 ))
	fi
}

curl_bound() {
	if [ "$curl" -lt 1 ]
	then
		curc=1
	fi
	if [ "$curl" -gt "$file_leng" ]
	then
		curl="$file_leng"
	fi
}

# Main

setup_term
sizeof_term

if [ -z  "$1" ]
then
	landing_page
	bottom_bar ' welcome to tapioca!'
	landing=true
	while [ "$landing" = true ]
	do
		getch
		case "$key" in
			'ctrl+'[Qq]) exit ;;
			'ctrl+'[Oo])
				mini_prompt ' open: '
				temp_file="$t_end"
				if [ -e "$temp_file" ]
				then
					set --
					set "$temp_file"
					temp_file=
					landing=false
				else
					bottom_bar ' file '"$temp_file"' does not exist!'
				fi ;;
		esac
	done
fi
# Load file into buffer
text_buff="$(cat "$1" )"
file_name="$1"
running=true

scrl_mrgn=3
toplin=1
curl=1
curc=1
#curr_text
while [ "$running" = true ]
do
	oldifs="$IFS"
	IFS='
'
	# ^ this sucks btw
	set --
	file_leng=0
	# Use positional args as a hacky array
	while IFS= read -r line
	do
		#if [ "$#" = $(( curl - 1 )) ]
		#then
		#	set -- "$@" "$curr_text"
		#else
		set -- "$@" "$line"
		#fi
		file_leng=$(( file_leng + 1 ))
	done <<EOF
$text_buff
EOF
	IFS="$oldifs"
	text_buff=$(printf '%s\n' "$@")
	editing=true
	# Current line contents
	eval "curr_text=\"\${$curl}\""
	while [ "$editing" = true ]
	do
		printf '%s' "$(
		bottom_bar " $file_name $key $curl $curc $toplin $file_leng"
		draw_text "$@"
		)"
		getch
		case "$key" in
			'ctrl+'[Qq])
				running=false
				editing=false ;;
			'ctrl+'[Gg])
				mini_prompt ' run on txt: '
				if [ -n "$t_end" ]
				then
					eval "text_buff=\$(printf '%s\n' \"\$@\" | $t_end )"
					editing=false
				fi ;;
			'ctrl+'[Oo])
				mini_prompt ' open: '
				temp_file="$t_end"
				if [ -e "$temp_file" ]
				then
					file_name="$temp_file"
					text_buff="$(cat "$temp_file")"
					temp_file=
					curc=1
					curl=1
					editing=false
				else
					bottom_bar ' file '"$temp_file"' does not exist!'
					read -r _
				fi ;;
			'up')
				if [ "$curl" -gt 1 ]
				then
					curl=$(( curl - 1 ))
					eval "curr_text=\"\${$curl}\""
				fi ;;
			'down')
				if [ "$curl" -lt "$file_leng" ]
				then
					curl=$(( curl + 1 ))
					eval "curr_text=\"\${$curl}\""
				fi ;;
			'left')
				curc=$(( curc - 1 ))
				if [ "$curl" -gt 1 ] && [ "$curc" -lt 1 ]
				then
					curc=99999999 # Bad, fix later
					curl=$(( curl - 1 ))
					eval "curr_text=\"\${$curl}\""
				fi
				curc_bound ;;
			'right')
				curc=$(( curc + 1 ))
				if [ "$curl" -lt "$file_leng" ] && [ $(( curc - 1 )) -gt "${#curr_text}" ]
				then
					curc=1
					curl=$(( curl + 1 ))
					eval "curr_text=\"\${$curl}\""
				fi
				curc_bound ;;
			'home')
				curl=1
				eval "curr_text=\"\${$curl}\"" ;;
			'end')
				curl="$file_leng"
				eval "curr_text=\"\${$curl}\"" ;;
			'backspace')
				if [ "$curc" -gt 1 ] && [ $(( curc - 1 )) -le "${#curr_text}" ]
				then
					curc=$(( curc - 1 ))
					l_side="$curr_text"
					r_side="$curr_text"
					while [ "${#l_side}" -ge "$curc" ]
					do
						l_side="${l_side%?}" # delete from end
					done
					r_side="${r_side#*"$l_side"?}" # delete from end
					curr_text="$l_side""$r_side"
				fi ;;
			[[:print:]])
				l_side="$curr_text"
				r_side="$curr_text"
				while [ "${#l_side}" -ge "$curc" ]
				do
					l_side="${l_side%?}" # delete from end
				done
				r_side="${r_side#*"$l_side"}" # delete from end
				curc=$(( curc + 1 ))
				curr_text="$l_side""$key""$r_side"
				editing=false ;;
			'space')
				l_side="$curr_text"
				r_side="$curr_text"
				while [ "${#l_side}" -ge "$curc" ]
				do
					l_side="${l_side%?}" # delete from end
				done
				r_side="${r_side#*"$l_side"}"
				curc=$(( curc + 1 ))
				curr_text="$l_side"' '"$r_side"
				editing=false ;;
			'newline')
				set --
				l_side="$curr_text"
				r_side="$curr_text"
				while [ "${#l_side}" -ge "$curc" ]
				do
					l_side="${l_side%?}" # delete from end
				done
				r_side="${r_side#*"$l_side"}"
				curr_text="${l_side}"
				curc="${#curr_text}"
				while IFS= read -r line
				do
					if [ "$#" = $(( curl - 1 )) ]
					then
						set -- "$@" "$l_side"
					elif [ "$#" = "$curl" ]
					then
						set -- "$@" "$r_side"
					else
						set -- "$@" "$line"
					fi
					file_leng=$(( file_leng + 1 ))
				done <<EOF
$text_buff
EOF
;;
			#'pageup') curl=$(( curl - ( lines - 1 ) )) ;;
			#'pagedn') curl=$(( curl + ( lines - 1 ) )) ;;
		esac
		# Sanitize
		if [ "$toplin" -lt 1 ]; then toplin=1; fi
		# Scroll
		# Up
		if [ $((curl - toplin )) -lt "$scrl_mrgn" ] && [ "$file_leng" -gt $(( lines - 1 )) ]
		then
			toplin=$((curl - scrl_mrgn))
		fi
		# Down
		if [ $((curl - toplin)) -gt $(( lines - scrl_mrgn - 2 )) ] && [ "$file_leng" -gt $(( lines - 2 )) ]
		then
			toplin=$(( curl - ( lines - scrl_mrgn - 2 ) ))
		fi

		# Sanitize again
		if [ "$toplin" -gt $(( file_leng - ( lines - 2 ) )) ]; then toplin=$(( file_leng - ( lines - 2 ) )); fi
		if [ "$toplin" -lt 1 ]; then toplin=1; fi
	done
done
restore_term
