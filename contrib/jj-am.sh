#!/usr/bin/env bash
# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0
set -Eeuo pipefail #-x
SCRIPTNAME=`basename $0` && function die  { [ -n "$*" ] && echo "$SCRIPTNAME: **ERROR**: ${*:-aborting}" >&2; exit 127 ; }
VERSION=0.2.0

# == Help ==
show_help()
{
  cat <<-__EOF__
	Usage: $SCRIPTNAME [OPTIONS...] PATCHFILE...

	Apply one or more patch files (from git-format-patch) to a jj repository.

	Options:
	  -h, --help     Display this help and exit
	  --version      Display version information and exit
	Arguments:
	  PATCHFILE      Path to a patch file containing commit message and diff
	__EOF__
}

# == Parse Options ==
MBOXES=()
while test $# -ne 0 ; do
  case "$1" in \
    --version)  echo "$SCRIPTNAME $VERSION"; exit ;;
    -h|--help)	show_help; exit 0 ;;
    -*)		die "unknown option: $1" ;;
    *)		MBOXES+=("$1") ;;
  esac
  shift
done

# == Functions ==
# Create temporary dir, assigns $TEMPD
temp_dir()
{
  test -n "${TEMPD:-}" || {
    TEMPD="`mktemp --tmpdir -d $SCRIPTNAME-XXXXXX`" || die "mktemp failed"
    trap "rm -rf '$TEMPD'" 0 HUP INT QUIT TRAP USR1 PIPE TERM
    echo "$$" > $TEMPD/$SCRIPTNAME.pid
  }
}
# Create new commit
jj_commit()
(
  # collect commit infor from header
  HEADER="$1" BODY="$(<"$2")" PATCH="$3"
  AUTHOR="$(sed -nr '/^Author: /{ s/^[^:]*: //; p; q; }' < $HEADER)"
  EMAIL="$(sed -nr '/^Email: /{ s/^[^:]*: //; p; q; }' < $HEADER)"
  DATE="$(sed -nr '/^Date: /{ s/^[^:]*: //; p; q; }' < $HEADER)"
  DATE="$(date --rfc-3339=ns -d "$DATE")"
  SUBJECT="$(sed -nr '/^Subject: /{ s/^[^:]*: //; p; q; }' < $HEADER)"
  export JJ_TIMESTAMP="$DATE"
  test -z "$BODY" && NL='' || NL=$'\n\n'
  ARGS=(
    --config-toml "user.name=\"$AUTHOR\""
    --config-toml "user.email=\"$EMAIL\""
    --message="$SUBJECT$NL$BODY"
  )
  # create commit
  jj new "${ARGS[@]}"
  # try patch
  patch -p1 < "$PATCH"
)

# == Process ==
temp_dir	# for $TEMPD
for mbox in "${MBOXES[@]}" ; do
  echo "Apply: ${mbox##*/}"
  rm -f "$TEMPD/header" "$TEMPD/body" "$TEMPD/patch"
  git mailinfo -b -u --encoding=POSIX.UTF-8 "$TEMPD/body" "$TEMPD/patch" > "$TEMPD/header" < "$mbox"
  jj_commit "$TEMPD/header" "$TEMPD/body" "$TEMPD/patch"
done
# snapshot last patch
jj status
