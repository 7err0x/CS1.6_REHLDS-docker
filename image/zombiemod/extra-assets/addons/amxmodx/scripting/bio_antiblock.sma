/*
 * Teammate semiclip while holding +use (E). Blocked near enemy lasermine beams/bodies.
 */
#include <amxmodx>
#include <fakemeta>
#include <cstrike>
#tryinclude <biohazard>

#if !defined _biohazard_included
	#assert Biohazard functions file required!
#endif

#define LM_CLASSNAME        "lasermine"
#define LM_OWNER            pev_iuser1
#define LM_STEP             pev_iuser2
#define LM_BEAMEND          pev_vuser1
#define LM_STEP_BEAMUP      1

#define LM_BODY_BLOCK_DIST  36.0
#define LM_BEAM_BLOCK_DIST  32.0

new cvar_antiblock, cvar_laser_guard
new Float:g_lasttimetouched[33]

public plugin_init()
{
	register_plugin("anti block", "0.3", "cheap_suit / cs16docker")
	is_biomod_active() ? plugin_init2() : pause("ad")
}

public plugin_init2()
{
	register_forward(FM_Touch, "fwd_touch")
	register_forward(FM_PlayerPreThink, "fwd_playerprethink")

	cvar_antiblock = register_cvar("bh_antiblock", "1")
	cvar_laser_guard = register_cvar("bh_antiblock_laser_guard", "1")
}

public fwd_playerprethink(id)
{
	if (!is_user_alive(id))
		return FMRES_IGNORED

	if (pev(id, pev_solid) != SOLID_NOT)
		return FMRES_IGNORED

	if (get_pcvar_num(cvar_laser_guard) && antiblock_blocked_by_enemy_lasermine(id))
	{
		set_pev(id, pev_solid, SOLID_SLIDEBOX)
		return FMRES_IGNORED
	}

	if ((get_gametime() - g_lasttimetouched[id]) > 0.34)
		set_pev(id, pev_solid, SOLID_SLIDEBOX)

	return FMRES_IGNORED
}

public fwd_touch(blocker, id)
{
	if (!is_user_alive(blocker) || !is_user_alive(id) || !get_pcvar_num(cvar_antiblock))
		return FMRES_IGNORED

	if (!(pev(id, pev_button) & IN_USE) && !(pev(blocker, pev_button) & IN_USE))
		return FMRES_IGNORED

	if (cs_get_user_team(id) != cs_get_user_team(blocker))
		return FMRES_IGNORED

	if (get_pcvar_num(cvar_laser_guard)
		&& (antiblock_blocked_by_enemy_lasermine(id) || antiblock_blocked_by_enemy_lasermine(blocker)))
		return FMRES_IGNORED

	set_pev(blocker, pev_solid, SOLID_NOT)
	set_pev(id, pev_solid, SOLID_NOT)

	new Float:gametime = get_gametime()
	g_lasttimetouched[id] = gametime
	g_lasttimetouched[blocker] = gametime

	return FMRES_IGNORED
}

stock bool:antiblock_blocked_by_enemy_lasermine(id)
{
	if (!is_user_alive(id))
		return false

	new ent = -1

	while ((ent = engfunc(EngFunc_FindEntityByString, ent, "classname", LM_CLASSNAME)) > 0)
	{
		if (!pev_valid(ent))
			continue

		if (pev(ent, LM_STEP) < LM_STEP_BEAMUP)
			continue

		new owner = pev(ent, LM_OWNER)

		if (!is_user_connected(owner) || cs_get_user_team(owner) == cs_get_user_team(id))
			continue

		if (antiblock_player_hits_lasermine(id, ent))
			return true
	}

	return false
}

stock bool:antiblock_player_hits_lasermine(id, mine)
{
	static Float:origin[3], Float:beamEnd[3], Float:playerOrigin[3]

	pev(mine, pev_origin, origin)
	pev(mine, LM_BEAMEND, beamEnd)
	pev(id, pev_origin, playerOrigin)

	if (get_distance_f(origin, playerOrigin) <= LM_BODY_BLOCK_DIST)
		return true

	if (antiblock_dist_to_segment(playerOrigin, origin, beamEnd) <= LM_BEAM_BLOCK_DIST)
		return true

	return false
}

stock Float:antiblock_dist_to_segment(const Float:point[3], const Float:start[3], const Float:end[3])
{
	new Float:seg[3], Float:toPoint[3]

	seg[0] = end[0] - start[0]
	seg[1] = end[1] - start[1]
	seg[2] = end[2] - start[2]

	new Float:segLenSq = seg[0] * seg[0] + seg[1] * seg[1] + seg[2] * seg[2]

	if (segLenSq < 1.0)
		return get_distance_f(point, start)

	toPoint[0] = point[0] - start[0]
	toPoint[1] = point[1] - start[1]
	toPoint[2] = point[2] - start[2]

	new Float:t = (toPoint[0] * seg[0] + toPoint[1] * seg[1] + toPoint[2] * seg[2]) / segLenSq

	if (t < 0.0)
		t = 0.0
	else if (t > 1.0)
		t = 1.0

	new Float:closest[3]
	closest[0] = start[0] + seg[0] * t
	closest[1] = start[1] + seg[1] * t
	closest[2] = start[2] + seg[2] * t

	return get_distance_f(point, closest)
}
