# Generetate Changelog or Release Notes

Generate release notes based on Github pull request title from given two git-refs

## Usage:

  release-notes.sh [<lasttagname>] [<commit-ish>]

### Options:

  -l, --list
    list tags sorted by creatordate

  -h, --help
    print this help

  <lasttagname>
    represents the beginning of revision range. Defaults to last <tagname>

  <commit-ish>
    Commit-ish object names, branch or tagname represents the end of revision range. Defaults to HEAD

## Example:

```
  release-notes.sh

  [Changeset](../../compare/<lasttagname>...<commit-ish>)
  * #9 Use short ref instead of HEAD in changelog message
  * #8 support other git remote standards for determining API endpoint
  * #4 Update changelog message
  * #3 If no variable is provided, default to the last tag
  * #2 Add support for using tags as GIT_START_REF
```

### Example to create a Github Release tag

```shell
git tag $tagname
hub release create $tagname -F <(release-notes.sh)
```
