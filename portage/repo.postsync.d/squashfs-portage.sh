#!/bin/bash
# squashfs-portage.sh version 20160411
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

# script variables
SQUASHFS_REPO="/mnt/services/gentoo/squashfs"

# portage's repo.postsync.d variables
REPOSITORY_NAME="${1}"
REPOSITORY_PATH="${3}"

# die(msg, code) - exit with message and code
die() {
	echo "${1}" # provide death report
	if [ -n "${2}" ]; then # use exit code if provided
		exit "${2}"
	else
		exit 1
	fi
}

# month_to_int(arg) - convert 3-ltr month code to number value
month_to_int() {
	local MONTH="${1}"
	if [[ "${MONTH}" == "Jan" ]]; then
		MONTH="1"
	elif [[ "${MONTH}" == "Feb" ]]; then
		MONTH="2"
	elif [[ "${MONTH}" == "Mar" ]]; then
		MONTH="3"
	elif [[ "${MONTH}" == "Apr" ]]; then
		MONTH="4"
	elif [[ "${MONTH}" == "May" ]]; then
		MONTH="5"
	elif [[ "${MONTH}" == "Jun" ]]; then
		MONTH="6"
	elif [[ "${MONTH}" == "Jul" ]]; then
		MONTH="7"
	elif [[ "${MONTH}" == "Aug" ]]; then
		MONTH="8"
	elif [[ "${MONTH}" == "Sep" ]]; then
		MONTH="9"
	elif [[ "${MONTH}" == "Oct" ]]; then
		MONTH="10"
	elif [[ "${MONTH}" == "Nov" ]]; then
		MONTH="11"
	elif [[ "${MONTH}" == "Dec" ]]; then
		MONTH="12"
	else
		die "Abort: Unknown month in timestamp" "1"
	fi
	echo "${MONTH}"
}

# Only want to do work on Gentoo's portage tree
if [ "${REPOSITORY_NAME}" != "gentoo" ]; then
	exit 0
fi

# setup
mkdir -p "${SQUASHFS_REPO}" || die "Abort: Failed to make SQUASHFS_REPO."

# compare timestamp of portage to squashfs to see if new image should be built
# timestamp.chk does not exist if tree is updated with emerge-webrsync
if [ -e "${REPOSITORY_PATH}/metadata/timestamp.chk" ] && [ -e "${SQUASHFS_REPO}/${REPOSITORY_NAME}-timestamp.chk" ]; then
	PORTAGE_TIMESTAMP=$( <"${REPOSITORY_PATH}/metadata/timestamp.chk" )

	PORTAGE_YEAR=$( echo "${PORTAGE_TIMESTAMP}" | cut -d ' ' -f 4 )
	PORTAGE_MONTH=$( month_to_int $( echo "${PORTAGE_TIMESTAMP}" | cut -d ' ' -f 3 ) )
	PORTAGE_DAY=$( echo "${PORTAGE_TIMESTAMP}" | cut -d ' ' -f 2 )
	PORTAGE_HOUR=$( echo "${PORTAGE_TIMESTAMP}" | cut -d ' ' -f 5 | cut -d ':' -f 1 )
	PORTAGE_MINUTE=$( echo "${PORTAGE_TIMESTAMP}" | cut -d ' ' -f 5 | cut -d ':' -f 2 )

	SQUASHFS_TIMESTAMP=$( <"${SQUASHFS_REPO}/${REPOSITORY_NAME}-timestamp.chk" )

	SQUASHFS_YEAR=$( echo "${SQUASHFS_TIMESTAMP}" | cut -d ' ' -f 4 )
	SQUASHFS_MONTH=$( month_to_int $( echo "${SQUASHFS_TIMESTAMP}" | cut -d ' ' -f 3 ) )
	SQUASHFS_DAY=$( echo "${SQUASHFS_TIMESTAMP}" | cut -d ' ' -f 2 )
	SQUASHFS_HOUR=$( echo "${SQUASHFS_TIMESTAMP}" | cut -d ' ' -f 5 | cut -d ':' -f 1 )
	SQUASHFS_MINUTE=$( echo "${SQUASHFS_TIMESTAMP}" | cut -d ' ' -f 5 | cut -d ':' -f 2 )

# Timestamp comparison
# Bash if test comparisons are performed left to right with equal weighting between && and || operators
# Assumes each test piece does not need to be repeated in full as the test would fail in earlier groupings
# Bash treats numbers with leading zeroes as octal; strip leading zero prior to evaluating
	if [[ "${SQUASHFS_YEAR}" -gt "${PORTAGE_YEAR}" ]] || \
	   [[ "${SQUASHFS_YEAR}" -eq "${PORTAGE_YEAR}" ]] && [[ "${SQUASHFS_MONTH}" -gt "${PORTAGE_MONTH}" ]] || \
	   [[ "${SQUASHFS_MONTH}" -eq "${PORTAGE_MONTH}" ]] && [[ "${SQUASHFS_DAY#0}" -gt "${PORTAGE_DAY#0}" ]] || \
	   [[ "${SQUASHFS_DAY#0}" -eq "${PORTAGE_DAY#0}" ]] && [[ "${SQUASHFS_HOUR#0}" -gt "${PORTAGE_HOUR#0}" ]] || \
	   [[ "${SQUASHFS_HOUR#0}" -eq "${PORTAGE_HOUR#0}" ]] && [[ "${SQUASHFS_MINUTE#0}" -gt "${PORTAGE_MINUTE#0}" ]]; then
		die "Exiting: Squashfs image is current or newer; nothing to do." "0"
	fi
fi

# build squashfs image
mksquashfs "${REPOSITORY_PATH}" "${SQUASHFS_REPO}/${REPOSITORY_NAME}.sqfs.new" -comp xz || die "Abort: mksquashfs failed." "1"

# put squashfs image into circulation
if [ -e "${SQUASHFS_REPO}/${REPOSITORY_NAME}.sqfs" ]; then
	rm "${SQUASHFS_REPO}/${REPOSITORY_NAME}.sqfs" || die "Abort: Failed to delete prior squashfs image"
fi

mv "${SQUASHFS_REPO}/${REPOSITORY_NAME}.sqfs.new" "${SQUASHFS_REPO}/${REPOSITORY_NAME}.sqfs" || die "Abort: Failed to substitute squashfs files." "1"
date -u +%a\,\ %d\ %b\ %Y\ %T\ %z > "${SQUASHFS_REPO}/${REPOSITORY_NAME}-timestamp.chk" || die "Abort: Failed to create timestamp." "1"

exit 0
