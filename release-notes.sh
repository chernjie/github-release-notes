#!/usr/bin/env bash

# @author CJ lim@chernjie.com

COLOR_YELLOW(){ echo -en "\033[33m"; }
COLOR_RED()   { echo -en "\033[31m"; }
COLOR_RESET() { echo -en "\033[0m";  }

_warn() {
  COLOR_YELLOW && echo $(date) "$@" && COLOR_RESET
}

_error() {
  COLOR_RED && echo $(date) "$@" >&2 && COLOR_RESET && exit 1
}

use() {
  for i do
    if ! command -v $i > /dev/null
    then
      _error command $i not found >&2
    fi
  done
}

use git grep tr xargs

_hasGhCli() { command -v gh > /dev/null; }
_hasHub() { command -v hub > /dev/null; }
_hasGhCli || _hasHub || _error command gh-cli not found >&2

_rev-parse-verify() {
  git rev-parse --quiet --verify $1
}

_releaseMessage() {
  local _release_title="$(_make-title "$1")"
  local GIT_REF="$(_find-valid-latest-ref $1)"
  local GIT_START_REF="$(_findLastTag "$GIT_REF" "$2")"

cat <<TEMPLATE
$_release_title

[Changeset](../../compare/$GIT_START_REF...$GIT_REF)
$(_showPullRequests $GIT_START_REF...$GIT_REF)
TEMPLATE
}

_showPullRequests() {
  git log "$1" --format=%s |
    grep -oE -e "[ \(]#[0-9]+( |\)$)" -e "origin/pull/([0-9]+)/head" |
    sed -e "s,origin/pull/,(,g" -e "s,/head,),g" |
    tr -d "# ()" |
    sort -urn |
    if _hasGhCli
    then xargs -n1 -I{} gh issue view {} \
        --json 'number,title,author' \
        --jq '"* #" + (.number | tostring) +" " +.title + " @" + .author.login'
    else xargs -n1 hub issue show -f '* %i %t%n'
    fi
}

_validateGitRef() {
  if test -n "$1" && ! _rev-parse-verify $1 > /dev/null
  then _warn $1 not found, defaulting to current HEAD. >&2
  fi
  if test -n "$2" && ! _rev-parse-verify $2 > /dev/null
  then _error $2 not found. Make sure the refname is reachable. >&2
  fi
}

_make-title() {
  if test -n "$1" && _rev-parse-verify $1 > /dev/null
  then git describe --always --tags $1
  elif test -n "$1"
  then echo $1
  else git describe --always --tags HEAD
  fi
}

_find-valid-latest-ref() {
  if test -n "$1" && _rev-parse-verify $1 > /dev/null
  then git describe --always --tags $1
  else git describe --always --tags HEAD
  fi
}

# A more reliable way to find last tag
# instead of `git tag --sort=-creatordate | head -1`
_findLastTag() {
  local GIT_REF="$1"
  local lasttag="$2"

  # find last tag in current tree
  if test -z "$lasttag"; then
    lasttag=$(git describe --long --tags "$GIT_REF"~1 | tr - '\n' | sed -e \$d | sed -e \$d | xargs echo | tr \  -)
  fi

  # find first ever commit
  if test -z "$lasttag"; then
    lasttag=$(git log --format=%h | tail -1)
  fi

  echo $lasttag
}

main () {
  _validateGitRef "$@"
  _releaseMessage "$@"
}

_release() {
  case $1 in
    --draft) local _draft="--draft --prerelease" ;;
    --release) local _draft="" ;;
  esac
  shift
  if _hasGhCli
  then
    main "$@" |
      gh release create $1 \
        --title $1 \
        --target "$(_rev-parse-verify $1 || _rev-parse-verify HEAD)" \
        --notes-file - \
        $_draft
  else
    hub release create $1 --edit $_draft \
        --commitish "$(_rev-parse-verify $1 || _rev-parse-verify HEAD)" \
        --file <($0 "$@")
  fi
}

_usage() {
cat <<USAGE

Name:
  `basename $0` Generate release notes based on Github pull request title from given two git-refs

Usage:
  `basename $0` [<commit-ish>] [<lasttagname>]
  `basename $0` --release <tagname>
  `basename $0` --draft <tagname>

Options:
  -l, --list
    list tags sorted by creatordate

  -h, --help
    print this help

  <commit-ish>
    Commit-ish object names, branch or tagname represents the end of revision range. Defaults to HEAD

  <lasttagname>
    represents the beginning of revision range. Defaults to last <tagname>

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
  --release|--draft) _release "$@" ;;
  *) main "$@" ;;
esac
