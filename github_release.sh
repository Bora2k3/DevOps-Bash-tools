#!/usr/bin/env bash
#  vim:ts=4:sts=4:sw=4:et
#
#  Author: Hari Sekhon
#  Date: 2022-07-12 14:18:52 +0100 (Tue, 12 Jul 2022)
#
#  https://github.com/HariSekhon/DevOps-Bash-tools
#
#  License: see accompanying Hari Sekhon LICENSE file
#
#  If you're using my code you're welcome to connect with me on LinkedIn and optionally send me feedback to help steer this or other code I publish
#
#  https://www.linkedin.com/in/HariSekhon
#

set -euo pipefail
[ -n "${DEBUG:-}" ] && set -x
srcdir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1090
. "$srcdir/lib/github.sh"

# shellcheck disable=SC2034,SC2154
usage_description="
Creates a GitHub Release and Git Tag, auto-incrementing the default vYYYY.NN release if one isn't given

Determines the GitHub repository to create a release in from the local checkout from which it is executed,
unless \$GITHUB_OWNER_REPO is set in the environment or '-R <owner>/<repo>' are given as the final args

The first argument is the version, which is recommended to set to vN.N.N eg. v1.0.0 as per semantic versioning standards

If the first argument is 'day' or 'date', will determine the next available release in the format vYYYYMMDD.NN where NN is incremented from 1
If the first argument is 'month', will determine the next available release in the format vYYYYMM.NN
If the first argument is 'year', will determine the next available release in the format vYYYY.NN (the default if no version is specified)

These formats don't have dashes in them like ISO dates so that if you move from YYYY to YYYYMM format or YYYYMMDD format, GitHub will recognize the newer format as the Latest release

If you later return to short format releases of just year or month, GitHub won't detect them as the Latest release (determined via testing).

WARNING: if you delete a GitHub release, the tag is left in the repo. If you then create a new release automatically defaulting to the version that was just deleted and it reuses the old git tag, you could end up with a release pointing to an old tag rather than the current commit


Requires GitHub CLI to be installed and configured
"

# used by usage() in lib/utils.sh
# shellcheck disable=SC2034
usage_args="[<version> <title> <description> <gh_cli_options>]"

help_usage "$@"

#min_args 1 "$@"

version="${1:-year}"
title="${2:-}"
description="${3:-}"
shift || :
shift || :
shift || :

owner_repo=()
if [ -n "${GITHUB_OWNER_REPO:-}" ]; then
    owner_repo=(-R "$GITHUB_OWNER_REPO")
fi

generate_version=0
prefix='v'
if [ -n "${NO_GITHUB_RELEASE_PREFIX:-}" ]; then
    prefix=''
fi

if [ "$version" = year ]; then
    version="${prefix}$(date '+%Y')"
    generate_version=1
elif [ "$version" = month ]; then
    version="${prefix}$(date '+%Y%m')"
    generate_version=1
elif [ "$version" = day ] [ "$version" = date ]; then
    version="${prefix}$(date '+%Y%m%d')"
    generate_version=1
fi

if [ "$generate_version" = 1 ]; then
    latest_releases="$(gh release list ${owner_repo:+"${owner_repo[@]}"} -L 200 --exclude-drafts "$@" | awk '{print $1}')"

    number="$(grep -Eo "^$version"'\.\d+' <<< "$latest_releases" | head -n 1 | sed "s/^$version\\.//" || echo 1)"

    # increment the number
    while grep -Fxq "$version.$number" <<< "$latest_releases"; do
        ((number+=1))
        if [ $number -gt 9999 ]; then
            die "FAILED to find unused release in format '$version.NN'"
        fi
    done

    version+=".$number"
fi

if is_blank "$title"; then
    title="$version"
fi

gh release create ${owner_repo:+"${owner_repo[@]}"} "$version" --title "$version" --notes "$description" "$@"
