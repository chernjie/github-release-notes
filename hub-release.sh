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

_hasGhCli() {
	command -v gh > /dev/null
}

_createGithubRelease() {
	if _hasGhCli
	then
	gh release view "$1" > /dev/null
	else
	hub release show "$1" > /dev/null
	fi
	if test "$?" -gt 0
	then
		echo "$1"
		if _hasGhCli
		then
			release-notes.sh "$1" | sed 1d | tee .altus/"$1".txt
			test -z "$DRYRUN" && gh release create "$1" -F .altus/"$1".txt --title "$1"
		else
		release-notes.sh "$1" | tee .altus/"$1".txt
		test -z "$DRYRUN" && hub release create "$1" -F .altus/"$1".txt
		fi
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
