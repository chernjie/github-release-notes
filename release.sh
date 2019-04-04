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

use jq git curl grep tr sed xargs md5sum

_releaseMessage() {

cat <<TEMPLATE
Merge $GIT_TAG to $GIT_START_REF:
$(_showPullRequests)

\`\`\`
$(_getDiffFileList HEAD $GIT_START_REF | _fileHashes)
\`\`\`
TEMPLATE
}

_showPullRequests() {
  local GIT_REF=$(git rev-parse --quiet --verify $GIT_TAG || echo HEAD)
  local GITHUB_API_ENDPOINT=$(_findGithubApiEndpoint)
  git log $GIT_START_REF...$GIT_REF --merges --format=%s |
    grep -oE " #[0-9]+ " |
    tr -d "# " |
    xargs -n1 -I{} echo $GITHUB_API_ENDPOINT |
    xargs curl --silent --header "Authorization:token $GITHUB_TOKEN" |
    jq -r '[.number,.title] | @tsv' |
    sed "s/^/* #/g"
}

_findGithubApiEndpoint() {
  echo https://$(
    git config remote.origin.url | grep -oE '@[^:]+' | tr -d @
  )/api/v3/repos/$(
    git config remote.origin.url | grep -oE ':.+' | tr -d : | sed s,\.git$,,
  )/pulls/{}
}

_getDiffFileList() {
  git diff --name-only --ignore-submodules $1 $2
}

_fileHashes() {
  while read i
  do
    test -f $i && md5sum $i || echo deleted $i
  done
}

_findGithubToken() {
  test -n "$GITHUB_TOKEN" && return
  read -p "GITHUB_TOKEN: " GITHUB_TOKEN
  test -z "$GITHUB_TOKEN" && _error "GITHUB_TOKEN not found"
}

_findGitHeads() {
  GIT_TAG=${2:-HEAD}
  GIT_START_REF=${1:-HEAD}

  # Check if $GIT_START_REF exists
  if ! git rev-parse --quiet --verify $GIT_START_REF > /dev/null; then
    _error $GIT_START_REF branch not found. Make sure you have the branch locally.
  fi
}

main () {
  _findGitHeads $@
  _findGithubToken
  _releaseMessage
}

_usage() {
cat <<USAGE

Usage: $0 <commit> [<commit>]
  Generate release messages given two branches

USAGE
}

### OPTIONS ###

case $1 in
  h|help|--help) _usage; grep -A100 OPTIONS $0;;
  *) main $@ ;;
esac
