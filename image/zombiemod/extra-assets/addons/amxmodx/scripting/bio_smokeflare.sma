#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#tryinclude <biohazard>

#if !defined _biohazard_included
	#assert Biohazard functions file required!
#endif

#define pev_flare pev_iuser4
#define flare_id 1337
#define MAX_FLARES 32
// Refresh interval and TE_DLIGHT life (0.1s units) must stay in sync to avoid flicker.
#define FLARE_DLIGHT_INTERVAL 0.1
#define FLARE_DLIGHT_LIFE 10

#define write_coord_f(%1) engfunc(EngFunc_WriteCoord, %1)

new const g_flare_model[] = "models/w_flare.mdl"

new cvar_smokeflare, cvar_smokeflare_dur, cvar_smokeflare_radius
new g_flares[MAX_FLARES]
new g_flare_count
new g_maxplayers
new Float:g_flare_dlight_next

stock bool:is_ent_flare(ent)
{
	return pev(ent, pev_flare) == flare_id
}

public plugin_init()
{
	register_plugin("smoke flare", "0.8", "mini_midget/cheap_suit")
	is_biomod_active() ? plugin_init2() : pause("ad")
}

public plugin_precache()
	precache_model(g_flare_model)

public plugin_init2()
{
	g_maxplayers = get_maxplayers()

	register_forward(FM_SetModel, "fwd_setmodel")
	register_forward(FM_StartFrame, "fwd_startframe")
	RegisterHam(Ham_Think, "grenade", "ham_flare_block_think", 0)
	cvar_smokeflare = register_cvar("bh_flare_enable", "1")
	cvar_smokeflare_dur = register_cvar("bh_flare_duration", "999.9")
	cvar_smokeflare_radius = register_cvar("bh_flare_radius", "14")
	register_cvar("bh_flare_amount", "2")
}

public fwd_setmodel(ent, const model[])
{
	if (!pev_valid(ent) || !equal(model[9], "smokegrenade.mdl"))
		return FMRES_IGNORED

	static classname[32]
	pev(ent, pev_classname, classname, charsmax(classname))

	if (equal(classname, "grenade") && get_pcvar_num(cvar_smokeflare))
	{
		new Float:expires = get_gametime() + get_pcvar_float(cvar_smokeflare_dur)

		engfunc(EngFunc_SetModel, ent, g_flare_model)
		set_pev(ent, pev_flare, flare_id)
		set_pev(ent, pev_fuser1, expires)
		set_pev(ent, pev_dmgtime, 0.0)
		set_pev(ent, pev_nextthink, -1.0)
		flare_set_glow(ent)
		flare_track(ent)

		return FMRES_SUPERCEDE
	}

	return FMRES_IGNORED
}

public ham_flare_block_think(ent)
{
	if (pev_valid(ent) && is_ent_flare(ent))
		return HAM_SUPERCEDE

	return HAM_IGNORED
}

public fwd_startframe()
{
	if (!g_flare_count)
		return

	new Float:now = get_gametime()
	new bool:update_lights

	if (now >= g_flare_dlight_next)
	{
		update_lights = true
		g_flare_dlight_next = now + FLARE_DLIGHT_INTERVAL
	}

	for (new i = g_flare_count - 1; i >= 0; i--)
	{
		new ent = g_flares[i]

		if (!pev_valid(ent) || !is_ent_flare(ent))
		{
			flare_untrack_index(i)
			continue
		}

		new Float:expires
		pev(ent, pev_fuser1, expires)

		if (now >= expires)
		{
			engfunc(EngFunc_RemoveEntity, ent)
			flare_untrack_index(i)
			continue
		}

		if (update_lights)
			flare_dlight(ent)
	}
}

stock flare_untrack_index(index)
{
	g_flare_count--
	g_flares[index] = g_flares[g_flare_count]
}

stock flare_track(ent)
{
	for (new i = 0; i < g_flare_count; i++)
	{
		if (g_flares[i] == ent)
			return
	}

	if (g_flare_count >= MAX_FLARES)
		return

	g_flares[g_flare_count++] = ent
}

stock flare_set_glow(ent)
{
	static Float:color[3]
	color[0] = 150.0
	color[1] = 150.0
	color[2] = 250.0

	set_pev(ent, pev_renderfx, kRenderFxGlowShell)
	set_pev(ent, pev_rendercolor, color)
	set_pev(ent, pev_rendermode, kRenderNormal)
	set_pev(ent, pev_renderamt, 16.0)
}

stock flare_dlight(ent)
{
	static Float:origin[3]
	pev(ent, pev_origin, origin)

	new radius = get_pcvar_num(cvar_smokeflare_radius)
	if (radius < 1)
		radius = 1

	// Per-human only: zombies use TE_DLIGHT for NVG bubble (bh_nvg_bubble) and the
	// engine dynamic-light pool is small — broadcast white flare lights caused NVG flicker.
	for (new id = 1; id <= g_maxplayers; id++)
	{
		if (!is_user_alive(id) || is_user_zombie(id))
			continue

		message_begin(MSG_ONE_UNRELIABLE, SVC_TEMPENTITY, _, id)
		write_byte(TE_DLIGHT)
		write_coord_f(origin[0])
		write_coord_f(origin[1])
		write_coord_f(origin[2])
		write_byte(radius)
		write_byte(255)
		write_byte(255)
		write_byte(255)
		write_byte(FLARE_DLIGHT_LIFE)
		write_byte(0)
		message_end()
	}
}
