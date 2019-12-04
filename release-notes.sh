#!/usr/bin/env bash

# @author CJ lim@chernjie.com

COLOR_RED()   { echo -en "\033[31m"; }
COLOR_RESET() { echo -en "\033[0m";  }

_error() {
  COLOR_RED && echo $(date) "$@" && COLOR_RESET && exit 1
}

use() {
  for i do
    if ! command -v $i > /dev/null
    then
      _error command $i not found
    fi
  done
}

use git grep tr xargs hub

_releaseMessage() {

cat <<TEMPLATE
$GIT_TAG

[Changeset](../../compare/$GIT_START_REF...$GIT_TAG)
$(_showPullRequests)
TEMPLATE
}

_showPullRequests() {
  local GIT_REF=$(git rev-parse --quiet --verify $GIT_TAG)
  git log $GIT_START_REF...$GIT_REF --merges --format=%s |
    grep -oE "[ \(]#[0-9]+[ \)$]" |
    tr -d "# ()" |
    xargs -n1 hub issue show -f '* %i %t%n'
}

_validateGitRef() {
  for i in
  do
    if ! git rev-parse --quiet --verify $i > /dev/null
    then
      _error $i not found. Make sure the refname is reachable.
    fi
  done
}

_findGitHeads() {

  GIT_TAG=${2:-HEAD}

  if test "HEAD" = "$GIT_TAG"
  then
    GIT_TAG=$(git describe --always --tags "$GIT_TAG")
  fi

  GIT_START_REF=$(_findLastTag "$1" "$GIT_TAG")
}

# A more reliable way to find last tag
# instead of `git tag --sort=-creatordate | head -1`
_findLastTag() {
  local lasttag="$1"

  # find last tag in current tree
  if test -z "$lasttag"; then
    lasttag=$(git describe --long --tags "$GIT_TAG"~1 | tr - '\n' | sed -e \$d | sed -e \$d | xargs echo | tr \  -)
  fi

  # find first ever commit
  if test -z "$lasttag"; then
    lasttag=$(git log --format=%h | tail -1)
  fi

  echo $lasttag
}

main () {
  _validateGitRef "$@"
  _findGitHeads "$@"
  _releaseMessage
}

_usage() {
cat <<USAGE

Name:
  `basename $0` Generate release notes based on Github pull request title from given two git-refs

Usage:
  `basename $0` [<lasttagname>] [<commit-ish>]

Options:
  -l, --list
    list tags sorted by creatordate

  -h, --help
    print this help

  <lasttagname>
    represents the beginning of revision range. Defaults to last <tagname>

  <commit-ish>
    Commit-ish object names, branch or tagname represents the end of revision range. Defaults to HEAD

Example:

  `basename $0`

  [Changeset](../../compare/<lasttagname>...<commit-ish>)
  * #9 Use short ref instead of HEAD in changelog message
  * #8 support other git remote standards for determining API endpoint
  * #4 Update changelog message
  * #3 If no variable is provided, default to the last tag
  * #2 Add support for using tags as GIT_START_REF

USAGE
}

### OPTIONS ###

case $1 in
  h|help|--help) _usage ;;
  l|list|--list) git tag --sort=-creatordate ;;
  *) main "$@" ;;
esac
