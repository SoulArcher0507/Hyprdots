#!/usr/bin/env bash

query="$1"

if [[ -z "$query" ]]; then
    echo "[]"
    exit 0
fi

if [[ "$query" == /* ]]; then
    query="${query#/}"
fi

is_hidden=false
if [[ "$query" == .* ]]; then
    is_hidden=true
    query="${query#.}"
    query="${query# }"
fi


if [ "$is_hidden" = true ]; then
    files=$(rg --files "$HOME" --hidden 2>/dev/null | grep -i "$query" | grep '/\.' | head -n 25)
else
    files=$(rg --files "$HOME" 2>/dev/null | grep -i "$query" | head -n 25)
fi

json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/}"
    s="${s//$'\t'/ }"
    printf '%s' "$s"
}

printf '['
first=true
while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    if [ "$first" = false ]; then
        printf ','
    fi
    first=false
    
    basename="${f##*/}"
    icon="text-x-generic"
    
    ext="${basename##*.}"
    if [[ "$basename" != *.* ]]; then
        ext=""
    fi

    case "${ext,,}" in
        png|jpg|jpeg|gif|svg|webp) icon="image-x-generic" ;;
        mp4|mkv|webm|avi|mov) icon="video-x-generic" ;;
        mp3|wav|ogg|flac) icon="audio-x-generic" ;;
        pdf) icon="application-pdf" ;;
        zip|tar|gz|rar|7z) icon="package-x-generic" ;;
        doc|docx|odt) icon="x-office-document" ;;
        xls|xlsx|csv|ods) icon="x-office-spreadsheet" ;;
        ppt|pptx|odp) icon="x-office-presentation" ;;
        json|xml|yaml|yml|toml|conf) icon="text-x-script" ;;
        sh|py|js|ts|c|cpp|rs|go) icon="text-x-script" ;;
        *) ;;
    esac
    
    echo "{\"name\":\"$(json_escape "$basename")\",\"path\":\"$(json_escape "$f")\",\"icon\":\"$icon\"}"
done <<< "$files"
printf ']\n'
