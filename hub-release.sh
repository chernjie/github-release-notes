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

_createGithubRelease() {
	echo "$1"
	hub release show "$1" > /dev/null
	if test "$?" -gt 0
	then
		release-notes.sh "$1" | tee .altus/"$1".txt
		hub release create "$1" -F .altus/"$1".txt
	fi	
}

main() {
	_getTagsInReverse | xargs -n1 -P100 $0 create
}

TAGPATTERN=$(_getTagPattern)
case $1 in
	create) _createGithubRelease $2;;
	*) main ;;
esac
