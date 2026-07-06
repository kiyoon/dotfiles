#!/usr/bin/env bash
# Shared palette + env for all sketchybar plugins (tokyonight-ish).
# Sourced by sketchybarrc and every plugin.

# brew-services (launchd) runs sketchybar with a minimal PATH that lacks
# /opt/homebrew/bin, so plugins would not find `sketchybar`/`aerospace`.
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:$PATH"

# launchd also provides no locale, so `date` etc. would fall back to English.
# Follow the macOS system language, mapped onto an *installed* locale:
# AppleLocale can be a combo like fr_KR that has no locale data, which libc
# would silently replace with C (English).
_apple_locale="$(defaults read -g AppleLocale 2>/dev/null)"
_apple_locale="${_apple_locale%%@*}"
_lang="${_apple_locale%%_*}"
for _cand in "${_apple_locale}.UTF-8" \
	"${_lang}_$(printf '%s' "$_lang" | tr '[:lower:]' '[:upper:]').UTF-8" \
	/usr/share/locale/"${_lang}"_*.UTF-8; do
	_cand="${_cand##*/}"
	if [[ -e "/usr/share/locale/$_cand" ]]; then
		export LANG="$_cand"
		break
	fi
done

export BAR_COLOR=0xe61a1b26        # bar background (translucent)
export ITEM_BG_COLOR=0xff24283b    # item pill background
export ACCENT_COLOR=0xff7aa2f7     # focused workspace / highlights
export LABEL_COLOR=0xffc0caf5      # default text
export MUTED_COLOR=0xff565f89      # secondary text
export BG_DARK=0xff1a1b26          # text on accent pills
export RED=0xfff7768e
export YELLOW=0xffe0af68
export GREEN=0xff9ece6a
