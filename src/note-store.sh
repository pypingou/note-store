#!/bin/bash

# Copyright (C) 2012 Jason A. Donenfeld <Jason@zx2c4.com> and
# Copyright (C) 2012 Pierre-Yves Chibon <pingou@pingoured.fr>. All Rights Reserved.
# This file is licensed under the GPLv2+. Please see COPYING for more information.

umask 077

PREFIX="${NOTE_STORE_DIR:-$HOME/.note-store}"
GIT_DIR="${NOTE_STORE_GIT:-$PREFIX}/.git"
GPG_OPTS="--quiet --yes --batch"

export GIT_DIR
export GIT_WORK_TREE="${NOTE_STORE_GIT:-$PREFIX}"

version() {
	cat <<_EOF
|-----------------------|
|      Note Store       |
|        v.0.1          |
|      by pingou        |
|                       |
|  pingou@pingoured.fr  |
|  Pierre-Yves Chibon   |
|-----------------------|
_EOF
}
usage() {
	version
	cat <<_EOF

Usage:
    $program [ls] [subfolder]
        List notes.
    $program [show] note-name
        Show existing note.
    $program insert notes-name [--force,-f]
        Insert new note. It will be multiline. Prompt
        before overwriting existing note unless forced.
    $program edit note-name
        Insert a new note or edit an existing note using ${EDITOR:-vi}.
    $program rm [--recursive,-r] [--force,-f] pass-name
        Remove existing note or directory, optionally forcefully.
    $program git git-command-args...
        If the note store is a git repository, execute a git command
        specified by git-command-args.
    $program help
        Show this text.
    $program version
        Show version information.

More information may be found in the pass(1) man page.
_EOF
}
is_command() {
	case "$1" in
		init|ls|list|show|insert|edit|remove|rm|delete|git|help|--help|version|--version) return 0 ;;
		*) return 1 ;;
	esac
}
git_add_file() {
	[[ -d $GIT_DIR ]] || return
	git add "$1" || return
	[[ -n $(git status --porcelain "$1") ]] || return
	git commit -m "$2"
}
yesno() {
	read -p "$1 [y/N] " response
	[[ $response == "y" || $response == "Y" ]] || exit 1
}
#
# BEGIN Platform definable
#
GETOPT="getopt"

# source /path/to/platform-defined-functions
#
# END Platform definable
#

program="$(basename "$0")"
command="$1"
if is_command "$command"; then
	shift
else
	command="show"
fi

case "$command" in
	help|--help)
		usage
		exit 0
		;;
	version|--version)
		version
		exit 0
		;;
esac


case "$command" in
	show|list|ls)

		if [[ $err -ne 0 ]]; then
			echo "Usage: $program $command [pass-name]"
			exit 1
		fi

		path="$1"
		if [[ -d $PREFIX/$path ]]; then
			if [[ -z $path ]]; then
				echo "Notes Store"
			else
				echo $path
			fi
			tree --noreport "$PREFIX/$path" | tail -n +2 | sed 's/\(.*\)\.txt$/\1/'
		else
			passfile="$PREFIX/$path.txt"
			if [[ ! -f $passfile ]]; then
				echo "$path is not in the note store."
				exit 1
			fi
				cat "$passfile"
				[[ -n $pass ]] || exit 1
		fi
		;;
	insert)
		force=0

		opts="$($GETOPT -o mef -l multiline,force -n "$program" -- "$@")"
		err=$?
		eval set -- "$opts"
		while true; do case $1 in
			-m|--multiline) multiline=1; shift ;;
			-f|--force) force=1; shift ;;
			--) shift; break ;;
		esac done

		if [[ $err -ne 0 || $# -ne 1 ]]; then
			echo "Usage: $program $command [--multiline,-m] [--force,-f] note-name"
			exit 1
		fi
		path="$1"
		passfile="$PREFIX/$path.txt"

		[[ $force -eq 0 && -e $passfile ]] && yesno "An entry already exists for $path. Overwrite it?"

		mkdir -p -v "$PREFIX/$(dirname "$path")"

		echo "Enter contents of $path and press Ctrl+D when finished:"
		echo
		tee "$passfile" > /dev/null

		git_add_file "$passfile" "Added given note for $path to store."
		;;
	edit)
		if [[ $# -ne 1 ]]; then
			echo "Usage: $program $command pass-name"
			exit 1
		fi

		path="$1"
		mkdir -p -v "$PREFIX/$(dirname "$path")"
		passfile="$PREFIX/$path.txt"

		action="Added"
		if [[ -f $passfile ]]; then
			action="Edited"
		fi
		${EDITOR:-vi} "$passfile"
		git_add_file "$passfile" "$action note for $path using ${EDITOR:-vi}."
		;;

	delete|rm|remove)
		recursive=""
		force=0

		opts="$($GETOPT -o rf -l recursive,force -n "$program" -- "$@")"
		err=$?
		eval set -- "$opts"
		while true; do case $1 in
			-r|--recursive) recursive="-r"; shift ;;
			-f|--force) force=1; shift ;;
			--) shift; break ;;
		esac done
		if [[ $# -ne 1 ]]; then
			echo "Usage: $program $command [--recursive,-r] [--force,-f] pass-name"
			exit 1
		fi
		path="$1"

		passfile="$PREFIX/${path%/}"
		if [[ ! -d $passfile ]]; then
			passfile="$PREFIX/$path.txt"
			if [[ ! -f $passfile ]]; then
				echo "$path is not in the note store."
				exit 1
			fi
		fi

		[[ $force -eq 1 ]] || yesno "Are you sure you would like to delete $path?"

		rm $recursive -f -v "$passfile"
		if [[ -d $GIT_DIR && ! -e $passfile ]]; then
			git rm -qr "$passfile"
			git commit -m "Removed $path from store."
		fi
		;;

	git)
		if [[ $1 == "init" ]]; then
			git "$@" || exit 1
			git_add_file "$PREFIX" "Added current contents of note store."
		elif [[ -d $GIT_DIR ]]; then
			exec git "$@"
		else
			echo "Error: the note store is not a git repository."
			exit 1
		fi
		;;
	*)
		usage
		exit 1
		;;
esac
exit 0
