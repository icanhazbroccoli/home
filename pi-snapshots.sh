#!/bin/bash

set -e

PIUSR=pi
PIOUT="/home/pi/snapshots"
PIACTIVEFLAG="/etc/PI_NODE_ACTIVE"
LOCALOUT="${HOME}/snapshots"
TODAY=$(date +%F)

remote_is_active() {
	local host=$1
	if ssh "${PIUSR}@${host}" stat ${PIACTIVEFLAG} \> /dev/null 2\>\&1; then
		return 0
	else
		return 1
	fi
}

local_is_active() {
	if [[ -e "${PIACTIVEFLAG}" ]]; then
		return 0
	else
		return 1
	fi
}

is_online() {
	local host=$1
	if ping -c 1 "${host}" 1>/dev/null; then
		return 0
	else
		return 1
	fi
}

take_snapshot() {
	local name=$1
	local host=$2
	local outdir=$3
	local params=$4
	local outname="${name}-$(date +%Y-%m-%d-%H-%M-%S).jpg"
	local outfile="${PIOUT}/${TODAY}/$outname"
	ssh -A "${PIUSR}@${host}" "[[ -d \"${PIOUT}/${TODAY}\" ]] || mkdir \"${PIOUT}/${TODAY}\"; raspistill -o \"${outfile}\" ${params}"
	scp "${PIUSR}@${host}:${outfile}" "${outdir}/${TODAY}/$outname"
	ssh -A "${PIUSR}@${host}" "[[ -f \"${outfile}\" ]] && rm \"${outfile}\""
}

create_today_dir() {
	local outdir="${1}/${TODAY}"
	[[ -d $outdir ]] || mkdir -p "$outdir"
}

if ! local_is_active; then
	echo "local node is disabled"
	exit 0
fi

create_today_dir "${LOCALOUT}"

echo "Snapshots are saved into ${LOCALOUT}/${TODAY}"

for hostparams in "$@"
do
	IFS=$'\t' read name host params <<< "${hostparams}"
	if ! is_online "${host}"; then
		echo "${name}[${host}] seems to be down"
		continue
	fi
	if ! remote_is_active "${host}"; then
		echo "${name}[${host}] is deactivated"
		continue
	fi
	echo "Taking a snapshot from ${name}[${host}] with params: {${params}}"
	take_snapshot "${name}" "${host}" "${LOCALOUT}" "$params"
done

echo "Done"
