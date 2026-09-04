#!/usr/bin/env bash
# Native input-source indicator (한/A/BR...). Deliberately NOT a menu-bar
# alias: macOS draws the input icon in different windows depending on the
# source type, only the active display's copy renders, and the plain-layout
# window is anonymous with a drifting identity (verified by pixel-probing) --
# no capture-based approach survives a source switch.
# Also deliberately NOT `defaults read com.apple.HIToolbox`: that returns
# stale values from sketchybar-spawned processes (cfprefsd caching). The
# compiled TIS helper (helpers/tis_current, built by sketchybarrc) asks the
# Text Input Services API directly.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# The input_watcher daemon passes the id with its input_change trigger; the
# helper query is the fallback for freq/forced runs.
id="${INPUT_SOURCE_ID:-$("$DIR/../helpers/tis_current" 2>/dev/null)}"

case "$id" in
	*Gureum.qwerty*)                 label="Gur" ;;
	*.Roman*)                        label="A" ;;
	*Gureum.han2*)                   label="구" ;;
	*Gureum.han3*)                   label="한3" ;;
	*Gureum*|*Korean*|*han*)         label="한" ;;
	*pritype*english*)               label="Pri" ;;
	*pritype*)                       label="프" ;;
	*hiking90*Ongeul*)
		# Ongeul reports its mode late via the input source (async selectMode).
		# input_watcher passes the fork's live mode as ONGEUL_MODE; fall back to
		# the source id / defaults if absent.
		m="$ONGEUL_MODE"
		[ -z "$m" ] && m=$(defaults read io.github.hiking90.inputmethod.Ongeul currentInputMode 2>/dev/null)
		if [ -z "$m" ]; then case "$id" in *Ongeul.English*) m=english ;; *) m=korean ;; esac; fi
		[ "$m" = korean ] && label="온" || label="Ong"
		;;
	*Japanese*)                      label="あ" ;;
	*keylayout.ABC-AZERTY*)          label="AZ" ;;
	*keylayout.ABC-QWERTZ*)          label="QZ" ;;
	*keylayout.ABC*|*keylayout.US*)  label="A" ;;
	*keylayout.*)
		# Plain layout as an ISO-ish code: Spanish-ISO -> ES, Brazilian-Pro -> BR.
		base="${id##*.}"
		base="${base%%-*}"
		case "$base" in
			Spanish)    label="ES" ;;
			German)     label="DE" ;;
			French)     label="FR" ;;
			Italian)    label="IT" ;;
			Portuguese) label="PT" ;;
			Brazilian)  label="BR" ;;
			Canadian)   label="CA" ;;
			British)    label="GB" ;;
			Russian)    label="RU" ;;
			Dutch)      label="NL" ;;
			Swedish)    label="SE" ;;
			Norwegian)  label="NO" ;;
			Danish)     label="DK" ;;
			Finnish)    label="FI" ;;
			Polish)     label="PL" ;;
			Turkish)    label="TR" ;;
			Czech)      label="CZ" ;;
			Greek)      label="GR" ;;
			Ukrainian)  label="UA" ;;
			*) label="$(printf '%s' "$base" | cut -c1-2 | tr '[:lower:]' '[:upper:]')" ;;
		esac
		;;
	*)                               label="?" ;;
esac

sketchybar --set "$NAME" label="$label"
