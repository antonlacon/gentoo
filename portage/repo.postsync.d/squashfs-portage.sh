#!/bin/bash
# squashfs-portage.sh version 20160115
#
# Copyright 2014-2016: Ian Leonard <antonlacon@gmail.com
#
# This file is squashfs-portage.sh
#
# squashfs-portage.sh is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, version 3 of the License.
#
# squashfs-portage.sh is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with squashfs-portage.sh. If not, see <http://www.gnu.org/licenses/>.
#
# squashfs-portage.sh creates and timestamps a squashfs image of the portage tree.
# It is intended for cron jobs or post emerge --sync calling.

# die(msg, code) - exit with message and code
die() {
	echo "$1" # provide death report
	if [ -n "$2" ]; then # use exit code if provided
		exit "$2"
	else
		exit 1
	fi
}

# month_to_int(arg) - convert 3-ltr month code to number value
month_to_int() {
	local MONTH="${1}"
	if [[ "$MONTH" == "Jan" ]]; then
		MONTH="1"
	elif [[ "$MONTH" == "Feb" ]]; then
		MONTH="2"
	elif [[ "$MONTH" == "Mar" ]]; then
		MONTH="3"
	elif [[ "$MONTH" == "Apr" ]]; then
		MONTH="4"
	elif [[ "$MONTH" == "May" ]]; then
		MONTH="5"
	elif [[ "$MONTH" == "Jun" ]]; then
		MONTH="6"
	elif [[ "$MONTH" == "Jul" ]]; then
		MONTH="7"
	elif [[ "$MONTH" == "Aug" ]]; then
		MONTH="8"
	elif [[ "$MONTH" == "Sep" ]]; then
		MONTH="9"
	elif [[ "$MONTH" == "Oct" ]]; then
		MONTH="10"
	elif [[ "$MONTH" == "Nov" ]]; then
		MONTH="11"
	elif [[ "$MONTH" == "Dec" ]]; then
		MONTH="12"
	else
		die "Abort: Unknown month in timestamp" "1"
	fi
	echo "$MONTH"
}

# script variables
SQUASHFS_REPO="/mnt/services/gentoo/squashfs"

# portage variables
REPOSITORY_NAME=${1}
#SYNC_URI=${2}
#REPOSITORY_PATH=${3}

# Only want to do work on Gentoo's portage tree
if [ "${REPOSITORY_NAME}" != "gentoo" ]; then
	die "Non-Gentoo tree sync." "0"
fi

# setup
mkdir -p "${SQUASHFS_REPO}" || die "Abort: Failed to make SQUASHFS_REPO."

# compare timestamp of portage to squashfs to see if new image should be built
# timestamp.chk does not exist if tree is updated with emerge-webrsync
if [ -e "/usr/portage/metadata/timestamp.chk" ] && [ -e "$SQUASHFS_REPO""/portage-timestamp.chk" ]; then
	PORTAGE_TIMESTAMP=$( cat "/usr/portage/metadata/timestamp.chk" )

	PORTAGE_YEAR=$( echo "$PORTAGE_TIMESTAMP" | cut -d ' ' -f 4 )
	PORTAGE_MONTH=$( month_to_int $( echo "$PORTAGE_TIMESTAMP" | cut -d ' ' -f 3 ) )
	PORTAGE_DAY=$( echo "$PORTAGE_TIMESTAMP" | cut -d ' ' -f 2 )
	PORTAGE_HOUR=$( echo "$PORTAGE_TIMESTAMP" | cut -d ' ' -f 5 | cut -d ':' -f 1 )
	PORTAGE_MINUTE=$( echo "$PORTAGE_TIMESTAMP" | cut -d ' ' -f 5 | cut -d ':' -f 2 )

	SQUASHFS_TIMESTAMP=$( cat "$SQUASHFS_REPO""/portage-timestamp.chk" )

	SQUASHFS_YEAR=$( echo "$SQUASHFS_TIMESTAMP" | cut -d ' ' -f 4 )
	SQUASHFS_MONTH=$( month_to_int $( echo "$SQUASHFS_TIMESTAMP" | cut -d ' ' -f 3 ) )
	SQUASHFS_DAY=$( echo "$SQUASHFS_TIMESTAMP" | cut -d ' ' -f 2 )
	SQUASHFS_HOUR=$( echo "$SQUASHFS_TIMESTAMP" | cut -d ' ' -f 5 | cut -d ':' -f 1 )
	SQUASHFS_MINUTE=$( echo "$SQUASHFS_TIMESTAMP" | cut -d ' ' -f 5 | cut -d ':' -f 2 )

# Timestamp comparison
# FIXME rewrite this to nest the if's instead of being sequential testing over n over
	if [[ "$SQUASHFS_YEAR" -gt "$PORTAGE_YEAR" ]]; then
		die "Abort: Existing squashfs image is newer."
	elif [[ "$SQUASHFS_YEAR" -eq "$PORTAGE_YEAR" ]] && [[ "$SQUASHFS_MONTH" -gt "$PORTAGE_MONTH" ]]; then
		die "Abort: Existing squashfs image is newer."
	elif [[ "$SQUASHFS_MONTH" -eq "$PORTAGE_MONTH" ]] && [[ "$SQUASHFS_DAY" -gt "$PORTAGE_DAY" ]]; then
		die "Abort: Existing squashfs image is newer."
	elif [[ "$SQUASHFS_MONTH" -eq "$PORTAGE_MONTH" ]] && [[ "$SQUASHFS_DAY" -eq "$PORTAGE_DAY" ]] && [[ "$SQUASHFS_HOUR" -gt "$PORTAGE_HOUR" ]]; then
		die "Abort: Existing squashfs image is newer."
	elif [[ "$SQUASHFS_MONTH" -eq "$PORTAGE_MONTH" ]] && [[ "$SQUASHFS_DAY" -eq "$PORTAGE_DAY" ]] && [[ "$SQUASHFS_HOUR" -eq "$PORTAGE_HOUR" ]] && [[ "$SQUASHFS_MINUTE" -gt "$PORTAGE_MINUTE" ]]; then
		die "Abort: Existing squashfs image is newer."
	fi
fi

# build squashfs image
mksquashfs /usr/portage "${SQUASHFS_REPO}"/portage.sqfs.new -comp xz || die "Abort: mksquashfs failed." "1"

# put squashfs image into circulation
if [ -e "${SQUASHFS_REPO}"/portage.sqfs ]; then
	rm "${SQUASHFS_REPO}"/portage.sqfs || die "Abort: Failed to delete prior portage.sqfs"
fi

mv "${SQUASHFS_REPO}"/portage.sqfs.new "${SQUASHFS_REPO}"/portage.sqfs || die "Abort: Failed to substitute portage.sqfs files." "1"
date -u +%a\,\ %d\ %b\ %Y\ %T\ %z > "${SQUASHFS_REPO}"/portage-timestamp.chk || die "Abort: Failed to create timestamp." "1"

exit 0
