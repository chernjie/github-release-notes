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
	hub release show "$1" > /dev/null
	if test "$?" -gt 0
	then
		echo "$1"
		release-notes.sh "$1" | tee .altus/"$1".txt
		test -z "$DRYRUN" && hub release create "$1" -F .altus/"$1".txt
	fi	
}

main() {
	_getTagsInReverse | xargs -n1 -P100 $0 create
}

TAGPATTERN=$(_getTagPattern)
case $1 in
	--dry-run) export DRYRUN=1; main;;
	create) _createGithubRelease $2;;
	*) main ;;
esac
