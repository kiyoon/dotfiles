#!/usr/bin/env sh
# fzf preview script: handles directories, images, videos, PDFs, and text files.
# Usage: fzf_preview.sh <path>
#
# Images are emitted with whichever protocol the attached terminal understands:
#   kitty  -> kitty graphics protocol via `kitten icat` (its unicode
#             placeholders survive both tmux and fzf's preview pane)
#   others -> sixel via chafa. Beware: fzf cannot host raw sixel inside tmux
#             (it redraws the pane line by line, chopping the DCS envelope,
#             so the payload prints as "!255?..." garbage) -- view through a
#             kitty client for images inside tmux.
# Force one with FZF_PREVIEW_IMG_BACKEND=kitty|sixel|symbols|none.

f="$1"
preview_width="${FZF_PREVIEW_COLUMNS:-80}"
preview_height="${FZF_PREVIEW_LINES:-24}"

# Inside tmux, TERM is whatever the server was started under (default-terminal is
# "${TERM}"), so it says "wezterm" even in a kitty pane. Ask tmux which client is
# actually attached instead.
img_backend() {
	if [ -n "$FZF_PREVIEW_IMG_BACKEND" ]; then
		printf '%s' "$FZF_PREVIEW_IMG_BACKEND"
		return
	fi
	if [ -n "$TMUX" ]; then
		_client=$(tmux display -p '#{client_termtype}' 2>/dev/null)
	elif [ -n "$KITTY_WINDOW_ID" ]; then
		_client=kitty
	else
		_client="${TERM_PROGRAM:-$TERM}"
	fi
	case "$_client" in
	kitty* | xterm-kitty | ghostty* | xterm-ghostty)
		if command -v kitten >/dev/null 2>&1; then
			printf kitty
			return
		fi
		;;
	esac
	if command -v chafa >/dev/null 2>&1; then
		printf sixel
		return
	fi
	printf none
}

img_backend=$(img_backend)

# show_image <file>   -- "-" reads the image bytes from stdin
show_image() {
	case "$img_backend" in
	kitty)
		# transfer-mode=file puts only a path in the escape sequence, keeping the
		# payload tmux has to pass through small. Switch to "stream" to preview
		# over ssh, where kitty cannot open the path itself. icat turns on
		# --passthrough and --unicode-placeholder by itself inside tmux.
		# --place is what bounds the image to the preview window; the @0x0 offset
		# is required syntax, not a position fzf honours. Do not pipe this through
		# `sed '$d'` the way fzf's own bin/fzf-preview.sh does: on kitty 0.48 the
		# last line is a row of placeholder cells, not a bare reset, so that would
		# crop the bottom of the image.
		if [ "$1" = "-" ]; then
			kitten icat --transfer-mode=file --unicode-placeholder --stdin=yes \
				--place="${preview_width}x${preview_height}@0x0"
		else
			kitten icat --transfer-mode=file --unicode-placeholder --stdin=no \
				--place="${preview_width}x${preview_height}@0x0" "$1"
		fi
		;;
	sixel)
		chafa --format=sixel --view-size="${preview_width}x${preview_height}" --scale=max "$1"
		;;
	symbols)
		chafa --format=symbols --view-size="${preview_width}x${preview_height}" --scale=max "$1"
		;;
	*)
		[ "$1" = "-" ] && cat >/dev/null
		echo "no image backend available (install kitten or chafa)"
		;;
	esac
}

# Seeking past the end of a clip makes ffmpeg emit nothing, so a fixed -ss 5
# leaves every video shorter than 5s with a blank preview.
video_seek() {
	_dur=$(LC_ALL=C ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$1" 2>/dev/null)
	case "$_dur" in
	'' | *[!0-9.]*) printf 0 ;;
	# LC_ALL=C or a comma-decimal locale prints "0,50", which ffmpeg -ss rejects.
	*) LC_ALL=C awk -v d="$_dur" 'BEGIN { s = d / 4; if (s > 5) s = 5; printf "%.2f", s }' ;;
	esac
}

if [ -d "$f" ]; then
	if command -v eza >/dev/null 2>&1; then
		if [ "$preview_width" -gt 20 ]; then
			eza -w "$preview_width" --icons=always --color=always --git-ignore "$f"
		else
			eza -w "$preview_width" --color=always --git-ignore "$f"
		fi
	else
		ls -la "$f"
	fi
else
	# lowercase extension matching
	fl=$(printf '%s' "$f" | tr '[:upper:]' '[:lower:]')
	case "$fl" in
	*.png | *.jpg | *.jpeg | *.gif | *.webp | *.bmp | *.ico | *.icns | *.heic | *.heif)
		show_image "$f"
		;;
	*.mp4 | *.webm | *.mov | *.mkv | *.avi)
		ffmpeg -ss "$(video_seek "$f")" -i "$f" -vframes 1 -f image2 -vcodec mjpeg - 2>/dev/null |
			show_image -
		;;
	*.pdf)
		# first page to PNG on stdout, no temp files
		pdftoppm -png -r 100 -f 1 -l 1 "$f" 2>/dev/null | show_image -
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
