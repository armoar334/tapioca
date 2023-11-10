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
	sav=$(printf '\033''7') # Save cursor pos
	res=$(printf '\033''8') # Restore cursor pos
	
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
			"$esc") key='escape' ;;
			"$esc"*) esc_decode "$temp" ;;
			"$bsp") key='backspace' ;;
			"$new") key='newline' ;;
			"$tab") key='tab' ;;
			' ') key='space' ;;
			[[:print:]]) key="$char" ;;
			[[:cntrl:]])
				key=$(( $(printf '%d' "'$temp") + 64 ))
				key=$( printf '%03o' "$key")
				key='ctrl+'$( printf "\\""$key");;
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
			*';8'*) dec_temp='ctrl+alt+shift+' ;;
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

# Text

# pure posix equivalent to ${var//pattern/replace}
replace_all() {
	r_side="$1"
	l_side=
	l_end=
	while [ -n "$r_side" ]
	do
		l_side="${r_side%%$2*}"
		if  [ "$l_side" = "$r_side" ]
		then
			l_end="$l_end""$r_side"
			return
		fi
		l_end="$l_end""$l_side""$3"
		r_side="${r_side#*$2}"
	done
}

insert_str() {
	eval 'l_temp="${f_line'"$c_lin"'}"'
	l_temp_two="$l_temp"
	while [ ${#l_temp_two} -gt "$c_col" ]
	do
		l_temp_two="${l_temp_two%?}"
	done
	l_temp="$l_temp_two""$1""${l_temp#"$l_temp_two"}"
	eval 'f_line'$c_lin'="$l_temp"'
}

back_space() {
	eval 'l_temp="${f_line'"$c_lin"'}"'
	l_temp_two="$l_temp"
	while [ ${#l_temp} -gt "$c_col" ]
	do
		l_temp="${l_temp%?}"
	done
	l_temp_two="${l_temp_two#"$l_temp"}"
	l_temp="${l_temp%?}"
	l_temp="$l_temp""$l_temp_two"
	eval 'f_line'$c_lin'="$l_temp"'	
}

# UI

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
			eval 'replace_all "$f_line'$l_ruler'" "$tab" "    "'
			l_temp=$(( ${#l_end} / columns ))
			l_blanks="$l_temp"
			l_ruler=$(( l_ruler + 1 ))
		#else
			#printf '\033[2K\n'
		fi
		l_screen=$(( l_screen + 1 ))
	done
}

# Todo: this is mild feces
draw_text() {
	printf '\033[H'
	l_ruler="$l_top"
	l_screen=1
	l_blanks=0
	while [ "$l_screen" -lt "$lines" ] && [ "$l_ruler" -lt "$f_leng" ]
	do
		eval 'l_done="$f_line'"$l_ruler"'"'
		# This messes with wrapping, shoul fix l8r
		if [ "$l_ruler" = "$c_lin" ]
		then
			l_temp="$l_done"
			while [ "${#l_temp}" -gt "$c_col" ]
			do
				l_temp="${l_temp%?}"
			done
			l_done="$l_temp""$sav""${l_done#"$l_temp"}"
		fi
		replace_all "$l_done" "$tab" '    '
		l_proc="$l_end"
		l_done=
		while [ "${#l_proc}" -gt "$columns" ] && [ "$l_screen" -lt "$lines" ]
		do
			l_done="$l_proc"
			while [ "${#l_done}" -gt "$columns" ]
			do
				l_done="${l_done%?}"
			done
			l_proc="${l_proc#"$l_done"}"
			printf '\033[%sC %s\033[K\n' "${#f_leng}" "$l_done"
			l_done=''
			l_screen=$(( l_screen + 1 ))
			l_subl=$(( l_subl + 1 ))
		done
		printf '\033[%sC %s\033[K\n' "${#f_leng}" "$l_proc"
		l_ruler=$(( l_ruler + 1 ))
		l_screen=$(( l_screen + 1 ))
	done
}

colorise() {
	l_left="$1"
	l_right="$1"
	l_middle="$1"
	l_word="$2"
	l_color="$3"
	while [ -n "$l_right" ]
	do
		l_left="${l_right%%}"
	done
}

bottom_bar() {
	printf '\033[%sH%s%-*s%s' "$lines" "${inv}" "$columns" "$1" "${end}"
}

error_bar() {
	printf '\033[%sH%s%-*s%s' "$lines" "${red}${inv}" "$columns" "$1" "${end}"
}

draw_logo() {
	logo=$(cat <<-EOF
 ${red} .. ... . ${end}
 ${yel}##########${end}
 ${end}\________/${end}
 ${end} \______/ ${end}

^O Open file
* Scratchpad
  ^Q Quit
	EOF
	)

	# Welcome
	printf '\033[%s;%sH' "$(( ( lines / 2 ) - 4 ))" "$(( ( columns / 2 ) - 9 ))"
	printf "%s${yel}%s${end}\n" 'welcome to ' 'tapioca'

	# System + shell
	cursh=$(ps -p $$)
	cursh="${cursh##* }"
	if [ -h "$(which "$cursh")" ]
	then
		cursh="$(readlink "$(which "$cursh")")"
	fi

	case "$(uname -a)" in
		Linux*)   curos="linux"  ;;
		Darwin*)  curos="macOS"  ;;
		OpenBSD*) curos="openbsd";;
		FreeBSD*) curos="freebsd";;
		Serenity) curos="serenityOS" ;;
		Plan9*)   curos="plan9" ;; # This ones a little optimistic
		*) cursh="unknown" ;;
	esac
	l_temp="running under $cursh on $curos"
	printf '\033[%s;%sH' "$(( ( lines / 2 ) - 3 ))" "$(( ( columns / 2 ) - ( ${#l_temp} / 2 ) ))"
	printf 'running under %s on %s' "${blu}$cursh${end}" "${red}$curos${end}"

	# logo
	printf '\033[%sH' $(( ( lines / 2 ) - 2 ))
	echo "$logo" | while IFS= read -r line
	do
		printf '\033[%sC%s\n' "$(( ( columns / 2 ) - 6 ))" "$line"
	done

}

cursor_stuff() {
	[ "$c_lin" -lt 1 ] && c_lin=1
	[ "$c_lin" -ge "$f_leng" ] && c_lin=$(( f_leng - 1 ))

	# Cursor wrapping left
	if [ "$c_col" -lt 0 ]
	then
		if [ "$c_lin" -gt 1 ]
		then
			c_lin=$(( c_lin - 1 ))
			eval 'l_temp=${f_line'"$c_lin"'}'
			c_col=${#l_temp}
		else
			c_col=0
		fi
	fi

	# Cursor wrapping right
	eval 'l_temp=${f_line'"$c_lin"'}'
	if [ "$c_col" -gt ${#l_temp} ]
	then
		if [ "$c_lin" -lt $(( f_leng - 1 )) ]
		then
			c_lin=$(( c_lin + 1 ))
			c_col=0
		else
			c_col=${#l_temp}
		fi
	fi
}

scroll_check() {
	# Scroll up
	if [ $(( c_lin - l_top )) -lt "$s_mrg" ] && [ "$f_leng" -gt $(( lines - 1 )) ]
	then
		p_top="$l_top"
		l_top=$((c_lin - s_mrg))
	fi
	# Down
	if [ $(( c_lin - l_top)) -gt $(( lines - s_mrg - 2 )) ] && [ "$f_leng" -gt $(( lines - 2 )) ]
	then
		p_top="$l_top"
		l_top=$(( c_lin - ( lines - s_mrg - 2 ) ))
	fi

	[ "$l_top" -lt 1 ] && l_top=1
	[ "$l_top" -ge "$f_leng" ] && l_top=$(( f_leng - 1 ))
}

open_file() {
	prompt ' open: '
	[ -e "$l_temp" ] && b_raw="$(cat "$l_temp")"
	reint_buff "$b_raw"
}

reint_buff() {
	b_raw="$1"
	f_leng=1
	while IFS= read -r line
	do
		eval "f_line""$f_leng""="'$line'
		f_leng=$(( f_leng + 1 ))
	done <<EOF
$b_raw
EOF
}

prompt() {
	printf '\033[%sH' "$lines"
	l_temp=
	p_col=0
	p_lin=''
	while [ "$key" != "newline" ]
	do
		printf '\r%s%-*s\r%s%s' "${inv}" "$columns" '' "$1" "$p_lin" "${end}"
		getch
 		case "$key" in
			'left'  )
				[ "$p_col" -gt 1 ] && p_col=$(( p_col - 1 )) ;;
			'right')
				[ "$p_col" -lt ${#p_lin} ] && p_col=$(( p_col + 1 )) ;;
			'backspace')
				p_lin="${p_lin%?}" ;;
			[[:print:]])
				p_lin="$p_lin""$key" ;;
			esac
	done
	l_temp="$"
}

# Main

setup_term
sizeof_term

if [ "$#" -gt 0 ]
then
	for item in "$@"
	do
		[ -e "$item" ] && b_raw="$(cat "$item")" && reint_buff "$b_raw"
	done
else
	#echo "No file DICKHEAD"
	draw_logo
	f_leng=2 # f_leng has to be lines + 1 because ???
	f_line1=''
	getch
	case "$key" in
		'ctrl+Q') exit ;;
		'ctrl+O')
			open_file ;;
		'newline') ;;
	esac
fi

l_top=1  # Top line to draw
p_top=-1 # Previos top ( to check scroll )
s_mrg=3  # Scroll margin

c_col=0 # Cursor column
c_lin=1 # Cursor lin

while [ "$key" != 'ctrl+Q' ]
do
	screen_buffer=''
	if [ "$l_top" != "$p_top" ]
	then
		screen_buffer="$(draw_rule)"
	fi
	screen_buffer="$screen_buffer""$(draw_text)$(bottom_bar " $key L: $c_lin C: $c_col T: $f_leng")"
	printf '%s' "$screen_buffer" 
	printf '\033''8'
	getch
	case "$key" in
		'up')     c_lin=$(( c_lin - 1 )) ;;
		'down')   c_lin=$(( c_lin + 1 )) ;;
		'left')   c_col=$(( c_col - 1 )) ;;
		'right')  c_col=$(( c_col + 1 )) ;;
		'pageup') c_lin=$(( c_lin - lines )) ;;
		'pagedn') c_lin=$(( c_lin + lines )) ;;
		'ctrl+O')
			open_file
			p_top=-1 ;;
		'ctrl+P') # Source current buffer
			b_raw=$(
				count=1
				while [ "$count" -lt "$f_leng" ]
				do
					eval 'printf "%s\\n" "$f_line'"$count"'"'
					count=$(( count + 1 ))
				done
			)
			eval "$b_raw" ;;
		'ctrl+Q') ;; # Just so it doesnt trap it in error
		[[:print:]])
			insert_str "$key"
			c_col=$(( c_col + 1 )) ;;
		'space')
			insert_str ' '
			c_col=$(( c_col + 1 )) ;;
		'tab')
			insert_str "$tab"
			c_col=$(( c_col + 1 )) ;;
		'backspace')
			back_space
			c_col=$(( c_col - 1 )) ;;
		'delete')
			back_space ;;
		'newline')
			b_raw=$(
				count=1
				while [ "$count" -lt "$f_leng" ]
				do
					eval 'l_temp="$f_line'"$count"'"'
					l_temp_two="$l_temp"
					if [ "$count" = "$c_lin" ]
					then
						while [ ${#l_temp} -gt "$c_col" ]
						do
							l_temp="${l_temp%?}"
						done
						printf '%s\n%s\n' "$l_temp" "${l_temp_two#"$l_temp"}"
					else
						printf '%s\n' "$l_temp"
					fi
					count=$(( count + 1 ))
				done
			)
			reint_buff "$b_raw" ;;
		*)
			error_bar " unknown key: $key"
			getch ;;
	esac

	cursor_stuff
	scroll_check

done
restore_term
