#!/usr/bin/env dash

trap 'restore_term' EXIT # Exit gracefully

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
	# Set other things
	esc=$(printf '\033')
	bsp=$(printf '\177')
	new=$(printf '\n')
	tab=$(printf '\t')
	
	# Save stty settings
	prior="$(stty -g)"
	printf '%s[?1049h' "$escape" # Switch buffer
	#printf '%s[?25l' "$escape" # Hide cursor
	stty -icanon -ixon -echo time 1
}

restore_term() {
	printf '%s[?1049l' "$escape" # Switch buffer
	#printf '%s[?25h' "$escape" # Hide cursor
	stty "$prior"
}

getch() {
	key=''
	temp=''
	

	while [ -z "$key" ]
	do
		# This introduces a shit ton of latency, some pure posix witchcraft is a holy grail for speed here
		char=$(dd ibs=6 count=1 2>/dev/null)
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

draw_rule() {
	printf '\033[H'
	l_ruler="$l_top"
	l_screen=1
	l_blanks=0
	while [ "$l_screen" -lt "$lines" ]
	do
		if [ "$l_blanks" -gt 0 ]
		then
			printf '%s%*s%s \n' "${inv}" "${#f_leng}" '' "${end}"
			l_blanks=$(( l_blanks - 1 ))
		elif [ "$l_ruler" -lt "$f_leng" ]
		then
			printf '%s%*s%s \n' "${inv}" "${#f_leng}" "$l_ruler" "${end}"
			eval 'l_temp=$(( ${#f_line'"$l_ruler"'} / 80 ))'
			l_blanks="$l_temp"
			l_ruler=$(( l_ruler + 1 ))
		else
			printf '\033[2K\n'
		fi
		l_screen=$(( l_screen + 1 ))
	done
}

draw_text() {
	printf '\033[H'
	l_ruler="$l_top"
	l_screen=1
	l_blanks=0
	while [ "$l_screen" -lt "$lines" ] && [ "$l_ruler" -lt "$f_leng" ]
	do
		eval 'l_temp="$f_line'"$l_ruler"'"'
		replace_all "$l_temp" "$tab" '    '
		l_proc="$t_end"
		l_done=
		while [ "${#l_proc}" -gt 80 ] && [ "$l_screen" -lt "$lines" ]
		do
			l_done="$l_proc"
			while [ "${#l_done}" -gt 80 ]
			do
				l_done="${l_done%?}"
			done
			l_proc="${l_proc#"$l_done"}"
			printf '\033[%sC %s\033[K\n' "${#f_leng}" "$l_done"
			l_done=''
			l_screen=$(( l_screen + 1 ))
		done
		[ "$l_screen" -lt "$lines" ] && printf '\033[%sC %s\033[K\n' "${#f_leng}" "$l_proc"
		l_ruler=$(( l_ruler + 1 ))
		l_screen=$(( l_screen + 1 ))
	done
}

# Main

if [ -n "$1" ]
then
	file_raw="$(cat "$1")"
	f_leng=1
	while IFS= read -r line
	do
		eval "f_line""$f_leng""="'$line'
		f_leng=$(( f_leng + 1 ))
	done <<EOF
$file_raw
EOF

else
	echo "No file dickhead"
	exit
fi

setup_term
sizeof_term

l_top=1 # Top line to draw


while [ "$key" != 'ctrl+Q' ]
do
	printf '%s%s\n%s' "$(draw_rule)" "$(draw_text)" "$key"
	getch
	case "$key" in
		'up') l_top=$(( l_top - 1 )) ;;
		'down') l_top=$(( l_top + 1 )) ;;
	esac
	[ "$l_top" -lt 1 ] && l_top=1
	[ "$l_top" -ge "$f_leng" ] && l_top=$(( f_leng - 1 ))
done
restore_term
