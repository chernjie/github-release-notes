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

_findEnvironmentVariable() {
  local variableName=$1
  local hint=""
  test -n "$2" && hint="(Hint: $2)
"
  test -n "${!variableName}" && return
  read -p "$hint$variableName=" "$variableName"
  test -z "${!variableName}" && _error "$variableName not found"
}

use jq git curl grep tr sed xargs md5sum

_releaseMessage() {

cat <<TEMPLATE
Changelog from $GIT_START_REF to $GIT_TAG:
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
    xargs curl --disable --silent --header "Authorization:token $GITHUB_TOKEN" |
    jq -r '[.number,.title] | @tsv' |
    sed "s/^/* #/g"
}

_findGithubApiEndpoint() {
  case $(git config remote.origin.url) in
    http*)
      echo https://$(
        git config remote.origin.url | cut -d/ -f3
      )/api/v3/repos/$(
        git config remote.origin.url | cut -d/ -f4-5 | sed s,\.git$,,
      )/pulls/{}
      ;;
    ssh://*)
      echo https://$(
        git config remote.origin.url | grep -oE '@[^/]+' | tr -d @
      )/api/v3/repos/$(
        git config remote.origin.url | cut -d/ -f4-5 | sed s,\.git$,,
      )/pulls/{}
      ;;
    git@*)
      echo https://$(
        git config remote.origin.url | grep -oE '@[^:]+' | tr -d @
      )/api/v3/repos/$(
        git config remote.origin.url | grep -oE ':.+' | tr -d : | sed s,\.git$,,
      )/pulls/{}
    ;;
  esac
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

_findGitHeads() {
  local last_tag=$(git tag --sort=-creatordate | head -1)
  GIT_TAG=${2:-HEAD}
  GIT_START_REF=${1:-$last_tag}

  # Check if $GIT_START_REF exists
  if ! git rev-parse --quiet --verify $GIT_START_REF > /dev/null; then
    _error $GIT_START_REF not found. Make sure you have the refname is reachable.
  fi
}

main () {
  _findGitHeads $@
  _findEnvironmentVariable GITHUB_TOKEN
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
  l|list|--list) git tag --sort=-creatordate ;;
  *) main $@ ;;
esac
