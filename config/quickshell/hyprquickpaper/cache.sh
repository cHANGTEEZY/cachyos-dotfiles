#!/usr/bin/env bash


CONFIG="$1/config.json"



expand_home() {
    local value="$1"
    value="${value//\$HOME/$HOME}"
    if [[ "$value" == "~"* ]]; then
        value="${HOME}${value:1}"
    fi
    printf '%s\n' "$value"
}

wallpaper_path="$(expand_home "$(jq -r '.wallpaper_path' "$CONFIG")")"
cache_path="$(expand_home "$(jq -r '.cache_path' "$CONFIG")")"
cache_batch_size=$(jq -r '.cache_batch_size' "$CONFIG")

mkdir -p "$cache_path"

echo "Wallpaper path: $wallpaper_path"
echo "Cache path: $cache_path"

if [[ ! -d "$wallpaper_path" ]]; then
    echo "Wallpaper path does not exist: $wallpaper_path" >&2
    exit 1
fi

find "$wallpaper_path" -type f \( \
    -iname "*.jpg" -o \
    -iname "*.jpeg" -o \
    -iname "*.png" -o \
    -iname "*.webp" \
\) | while read -r img; do

    filename=$(basename "$img")
    out="$cache_path/$filename"

    if [[ -f "$out" ]]; then
        continue
    fi

    echo "Generating thumbnail for $filename"


    convert "$img" -thumbnail x500 -strip -quality 85 "$out" &

    # Only limit jobs if batch_size > 0
    if (( cache_batch_size > 0 )); then
        while (( $(jobs -rp | wc -l) >= cache_batch_size )); do
            wait -n
        done
    fi

done

wait

echo "Thumbnail generation complete."
