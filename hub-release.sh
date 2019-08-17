#!/usr/bin/env bash

# Find all existing manifests tag ID and create a Github release
#
# @author CJ lim@chernjie.com

_getTagPattern() {
	pwd | xargs basename | sed 's/$/-*_*/'
}

_getTagsInReverse() {
	git tag --list "$TAGPATTERN" | tail -r
}

_findLastTag() {
	git describe --match "$TAGPATTERN" --tags "$1"~1 | cut -d- -f-2
}

_dryrun() {
	echo "$(_findLastTag "$1")" "$1"
}

_createGithubRelease() {
	# _dryrun $1
	echo "$1"
	hub release show "$1" > /dev/null
	if test "$?" -gt 0
	then
		release-notes.sh "$(_findLastTag "$1")" "$1" > .altus/"$1".txt
		hub release create "$1" -F .altus/"$1".txt
	fi	
}

main() {
	_getTagsInReverse | xargs -n1 -P100 $0 _createGithubRelease
}

TAGPATTERN=$(_getTagPattern)
case $1 in
	_createGithubRelease) _createGithubRelease $2;;
	*) main ;;
esac
