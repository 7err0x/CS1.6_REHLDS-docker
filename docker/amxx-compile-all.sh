#!/usr/bin/env bash
# Compile Biohazard-pack plugins only (not the whole AMXX scripting/examples tree).
set -euo pipefail

cd "${AMXX_SCRIPTING_DIR:-/amxx-kit/addons/amxmodx/scripting}"

chmod +x amxxpc

PACK=(
	respawn_defaults.sma
	lasermine.sma
	biohazard.sma
	bio_crosshair_id.sma
	customflashlight.sma
	bio_antiblock.sma
	bio_boatescape.sma
	bio_radar.sma
	bio_smokeflare.sma
	bio_smoker.sma
	bio_chatfilter.sma
	bio_phantom_cloak.sma
	bio_ebot_schedule.sma
	spawn_editor.sma
	zp50_zombie_sounds.sma
	zp50_ambience_sounds.sma
	zp50_grenade_fire.sma
	zp50_grenade_frost.sma
	cs16_mapchooser.sma
)

for sma in "${PACK[@]}"; do
	if [[ ! -f "$sma" ]]; then
		echo "missing source: ${sma}" >&2
		exit 1
	fi
	echo "==> amxxpc ${sma}"
	./amxxpc "$sma"
done

for sma in "${PACK[@]}"; do
	base="${sma%.sma}"
	if [[ ! -f "${base}.amxx" ]]; then
		echo "missing output: ${base}.amxx" >&2
		exit 1
	fi
done

echo "AMXX compile OK (${#PACK[@]} plugins)"
