#!/usr/bin/env sh
# fzf preview script: handles directories, images, videos, and text files.
# Usage: fzf_preview.sh <path>

f="$1"
preview_width="${FZF_PREVIEW_COLUMNS:-80}"
preview_height="${FZF_PREVIEW_LINES:-24}"

if [ -d "$f" ]; then
    if command -v eza >/dev/null 2>&1; then
        eza --icons=always --color=always --git-ignore "$f"
    else
        ls -la "$f"
    fi
else
    # lowercase extension matching
    fl=$(printf '%s' "$f" | tr '[:upper:]' '[:lower:]')
    case "$fl" in
        *.png|*.jpg|*.jpeg|*.gif|*.webp|*.bmp|*.ico|*.icns|*.heic|*.heif)
            chafa --format=sixel --view-size="${preview_width}x${preview_height}" --scale=max "$f"
            ;;
        *.mp4|*.webm|*.mov|*.mkv|*.avi)
            ffmpeg -ss 5 -i "$f" -vframes 1 -f image2 -vcodec mjpeg - 2>/dev/null \
                | chafa --format=sixel --view-size="${preview_width}x${preview_height}" --scale=max -
            ;;
        *)
            if command -v bat >/dev/null 2>&1; then
                bat --color=always --style=numbers --line-range=:999 "$f"
            else
                cat "$f"
            fi
            ;;
    esac
fi
