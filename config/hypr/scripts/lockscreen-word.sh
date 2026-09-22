#!/usr/bin/env bash

word="changteezy"
length=${#word}
frame=$(( $(date +%s%N) / 120000000 ))
highlight=$(( frame % length ))
output=""

for ((i = 0; i < length; i++)); do
    distance=$(( (i - highlight + length) % length ))

    case "$distance" in
        0) color="#ffffff" ;;
        1|9) color="#bdbdbd" ;;
        2|8) color="#7a7a7a" ;;
        *) color="#454545" ;;
    esac

    output+="<span foreground=\"$color\">${word:i:1}</span>"
done

printf '<span letter_spacing="3500">%s</span>\n' "$output"
