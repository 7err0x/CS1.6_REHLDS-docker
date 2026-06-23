/*
 * [BH] Smoker tongue — Biohazard port of [ZP] Class: Smoker by 4eRT (v1.3).
 * Source: https://forum.diliul.ro/viewtopic.php?t=122 (zombie_creature_smoker / 4eRT)
 * Drag/beam logic derived from yang's Scorpion harpoon (credited in original).
 *
 * No custom player model: class stats/models come from bh_zombieclass.ini only.
 *
 * Controls (usual ZP / L4D smoker binds):
 *   Hold E (+use) while Smoker — default, no client bind needed.
 *   Optional client console:
 *     bind x +smoker_tongue
 *     bind x -smoker_tongue
 *   ZP alias: +l4d_tongue / -l4d_tongue
 */
#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#tryinclude <biohazard>

#if !defined _biohazard_included
	#assert Biohazard functions file required!
#endif

#define PLUGIN "[BH] Smoker tongue"
#define VERSION "1.4"
#define AUTHOR "4eRT / BH port"

#define CLASS_NAME "Smoker"

#define DRAGINF 2

new const g_snd_drag[] = "zmbio5/smoker/tongue_drag.wav"
new const g_snd_hit[] = "zmbio5/smoker/tongue_hit.wav"
new const g_beam_sprite[] = "sprites/laserbeam.spr"

new g_smoker_class = -1
new g_Line
new g_maxplayers

new cvar_enable, cvar_range, cvar_speed, cvar_cooldown, cvar_maxtime, cvar_breakdmg
new cvar_use_key, cvar_hint, cvar_freeze_victim, cvar_bot_enable, cvar_bot_los

new g_hooked[33]
new g_hooks_left[33]
new g_ovr_dmg[33]
new Float:g_last_hook[33]
new Float:g_hook_until[33]
new g_tongue_held[33]

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	is_biomod_active() ? plugin_init2() : pause("ad")
}

public plugin_precache()
{
	precache_sound(g_snd_drag)
	precache_sound(g_snd_hit)
	g_Line = precache_model(g_beam_sprite)
}

public plugin_init2()
{
	g_maxplayers = get_maxplayers()

	cvar_enable = register_cvar("bh_smoker_enable", "1")
	cvar_range = register_cvar("bh_smoker_range", "600")
	cvar_speed = register_cvar("bh_smoker_speed", "160")
	cvar_cooldown = register_cvar("bh_smoker_cooldown", "5.0")
	cvar_maxtime = register_cvar("bh_smoker_maxtime", "10.0")
	cvar_breakdmg = register_cvar("bh_smoker_breakdmg", "300")
	cvar_use_key = register_cvar("bh_smoker_use_key", "1")
	cvar_hint = register_cvar("bh_smoker_hint", "1")
	cvar_freeze_victim = register_cvar("bh_smoker_freeze_victim", "1")
	cvar_bot_enable = register_cvar("bh_smoker_bot_enable", "1")
	cvar_bot_los = register_cvar("bh_smoker_bot_los", "1")

	register_clcmd("+smoker_tongue", "cmd_tongue_on")
	register_clcmd("-smoker_tongue", "cmd_tongue_off")
	register_clcmd("+l4d_tongue", "cmd_tongue_on")
	register_clcmd("-l4d_tongue", "cmd_tongue_off")

	register_forward(FM_PlayerPreThink, "fw_PlayerPreThink")
	register_forward(FM_StartFrame, "fwd_startframe")
	RegisterHam(Ham_TakeDamage, "player", "fw_TakeDamage", 1)
	RegisterHam(Ham_Killed, "player", "fw_PlayerKilled")

	set_task(1.0, "task_resolve_class", 0, _, _, "b")
}

public plugin_cfg()
	task_resolve_class()

public task_resolve_class()
{
	g_smoker_class = get_class_id(CLASS_NAME)

	if (g_smoker_class == -1)
		log_amx("[BH Smoker] Class ^"%s^" not found in bh_zombieclass.ini", CLASS_NAME)
}

public event_gamestart()
{
	for (new i = 1; i <= g_maxplayers; i++)
		drag_end(i)
}

public event_infect(victim, attacker)
{
	if (g_smoker_class == -1)
		return

	if (is_user_connected(victim) && get_user_class(victim) == g_smoker_class)
		g_hooks_left[victim] = 10

	if (is_user_connected(attacker) && get_user_class(attacker) == g_smoker_class)
	{
		g_hooks_left[attacker] += DRAGINF

		if (g_hooked[attacker] == victim)
			drag_end(attacker)
	}

	if (!get_pcvar_num(cvar_hint) || !is_user_connected(victim) || get_user_class(victim) != g_smoker_class)
		return

	client_print(victim, print_chat, "[Smoker] Hold E (+use) to tongue-hook survivors.")
	client_print(victim, print_chat, "[Smoker] Optional: bind v +smoker_tongue")
}

public client_disconnected(id)
{
	drag_end(id)

	for (new smoker = 1; smoker <= g_maxplayers; smoker++)
	{
		if (g_hooked[smoker] == id)
			drag_end(smoker)
	}
}

public cmd_tongue_on(id)
{
	if (!is_user_connected(id))
		return PLUGIN_HANDLED

	g_tongue_held[id] = 1
	return PLUGIN_HANDLED
}

public cmd_tongue_off(id)
{
	if (!is_user_connected(id))
		return PLUGIN_HANDLED

	g_tongue_held[id] = 0
	return PLUGIN_HANDLED
}

public fw_PlayerPreThink(id)
{
	if (!get_pcvar_num(cvar_enable) || id < 1 || id > g_maxplayers)
		return FMRES_IGNORED

	if (!is_smoker(id) || !game_started())
		return FMRES_IGNORED

	if (smoker_is_ai(id) && get_pcvar_num(cvar_bot_enable))
		bot_smoker_update_hold(id)

	if (g_hooked[id])
	{
		if (!tongue_wants_hold(id))
			drag_end(id)
	}

	if (!tongue_wants_hold(id))
		return FMRES_IGNORED

	// E-BOT reads +use from usercmd; keep IN_USE set while AI wants the tongue out.
	if (smoker_is_ai(id) && get_pcvar_num(cvar_bot_enable))
		set_pev(id, pev_button, pev(id, pev_button) | IN_USE)

	if (g_hooked[id])
	{
		if (get_pcvar_num(cvar_freeze_victim))
			set_pev(g_hooked[id], pev_maxspeed, 1.0)

		return FMRES_IGNORED
	}

	static Float:last_try[33]
	new Float:gt = get_gametime()

	if (gt - last_try[id] < 0.15)
		return FMRES_IGNORED

	last_try[id] = gt
	drag_start(id)

	return FMRES_IGNORED
}

public drag_start(id)
{
	if (g_hooks_left[id] <= 0)
		return PLUGIN_HANDLED

	new Float:cooldown = get_pcvar_float(cvar_cooldown)

	if (get_gametime() - g_last_hook[id] < cooldown)
		return PLUGIN_HANDLED

	if (g_hooked[id])
	{
		drag_end(id)
		return PLUGIN_HANDLED
	}

	new hooktarget, body

	if (smoker_is_ai(id) && get_pcvar_num(cvar_bot_enable))
	{
		hooktarget = bot_smoker_find_target(id)

		if (!hooktarget)
			return PLUGIN_HANDLED
	}
	else
	{
		get_user_aiming(id, hooktarget, body, floatround(get_pcvar_float(cvar_range)))

		if (!is_user_alive(hooktarget) || is_user_zombie(hooktarget))
			return PLUGIN_HANDLED
	}

	static Float:start[3], Float:origin[3]
	pev(id, pev_origin, start)
	pev(hooktarget, pev_origin, origin)

	if (get_distance_f(start, origin) > get_pcvar_float(cvar_range))
		return PLUGIN_HANDLED

	g_hooked[id] = hooktarget
	g_hook_until[id] = get_gametime() + get_pcvar_float(cvar_maxtime)
	g_hooks_left[id]--
	g_last_hook[id] = get_gametime()

	emit_sound(hooktarget, CHAN_BODY, g_snd_hit, 1.0, ATTN_NORM, 0, PITCH_NORM)
	emit_sound(id, CHAN_STREAM, g_snd_drag, 1.0, ATTN_NORM, 0, PITCH_NORM)

	new parm[2]
	parm[0] = id
	parm[1] = hooktarget
	set_task(0.1, "smoker_reelin", id, parm, 2, "b")
	harpoon_target(parm)

	return PLUGIN_HANDLED
}

public smoker_reelin(parm[])
{
	new id = parm[0]
	new victim = parm[1]

	if (!g_hooked[id] || g_hooked[id] != victim
		|| !is_user_alive(id) || !is_smoker(id)
		|| !is_user_alive(victim) || is_user_zombie(victim))
	{
		drag_end(id)
		return
	}

	if (get_gametime() > g_hook_until[id])
	{
		drag_end(id)
		return
	}

	new Float:fl_velocity[3]
	new id_origin[3], vic_origin[3]

	get_user_origin(victim, vic_origin)
	get_user_origin(id, id_origin)

	new distance = get_distance(id_origin, vic_origin)
	new Float:drag_speed = get_pcvar_float(cvar_speed)

	if (distance > 1)
	{
		new Float:fl_time = float(distance) / drag_speed

		fl_velocity[0] = (id_origin[0] - vic_origin[0]) / fl_time
		fl_velocity[1] = (id_origin[1] - vic_origin[1]) / fl_time
		fl_velocity[2] = (id_origin[2] - vic_origin[2]) / fl_time
	}
	else
	{
		fl_velocity[0] = 0.0
		fl_velocity[1] = 0.0
		fl_velocity[2] = 0.0
	}

	set_pev(victim, pev_velocity, fl_velocity)
}

public drag_end(id)
{
	if (!g_hooked[id])
		return

	new victim = g_hooked[id]
	g_hooked[id] = 0
	g_hook_until[id] = 0.0
	g_ovr_dmg[id] = 0

	beam_remove(id)
	remove_task(id)

	if (is_user_connected(id))
	{
		emit_sound(id, CHAN_STREAM, g_snd_drag, 0.0, ATTN_NORM, SND_STOP, PITCH_NORM)
		g_last_hook[id] = get_gametime()
	}

	if (is_user_alive(victim) && get_pcvar_num(cvar_freeze_victim))
		set_pev(victim, pev_maxspeed, 250.0)

	if (is_user_alive(victim))
	{
		new Float:zero[3]
		zero[0] = zero[1] = zero[2] = 0.0
		set_pev(victim, pev_velocity, zero)
	}
}

public fw_PlayerKilled(victim, killer, shouldgib)
{
	if (!get_pcvar_num(cvar_enable))
		return HAM_IGNORED

	// Smoker died while tongue was out — stop reel/beam before TE_BEAMENTS targets a dead ent.
	if (g_hooked[victim])
		drag_end(victim)

	// Hooked human died — release any smoker still pulling this slot.
	for (new smoker = 1; smoker <= g_maxplayers; smoker++)
	{
		if (g_hooked[smoker] == victim)
			drag_end(smoker)
	}

	return HAM_IGNORED
}

public fw_TakeDamage(victim, inflictor, attacker, Float:damage)
{
	if (!get_pcvar_num(cvar_enable))
		return HAM_IGNORED

	if (is_user_alive(attacker) && attacker != victim && is_user_alive(victim)
		&& is_smoker(victim) && g_hooked[victim])
	{
		g_ovr_dmg[victim] += floatround(damage)

		if (g_ovr_dmg[victim] >= get_pcvar_num(cvar_breakdmg))
		{
			g_ovr_dmg[victim] = 0
			drag_end(victim)
		}
	}

	return HAM_IGNORED
}

public fwd_startframe()
{
	if (!get_pcvar_num(cvar_enable))
		return FMRES_IGNORED

	for (new id = 1; id <= g_maxplayers; id++)
	{
		if (!g_hooked[id] || !is_user_connected(id))
			continue

		new target = g_hooked[id]

		if (!is_user_connected(target) || !is_user_alive(id) || !is_user_alive(target) || !is_smoker(id))
		{
			drag_end(id)
			continue
		}

		new parm[2]
		parm[0] = id
		parm[1] = target
		harpoon_target(parm)
	}

	return FMRES_IGNORED
}

public harpoon_target(parm[])
{
	new id = parm[0]
	new hooktarget = parm[1]

	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_BEAMENTS)
	write_short(id)
	write_short(hooktarget)
	write_short(g_Line)
	write_byte(0)
	write_byte(0)
	write_byte(200)
	write_byte(8)
	write_byte(1)
	write_byte(255) // R — yellow tongue beam
	write_byte(255) // G
	write_byte(0)   // B
	write_byte(10) // brightness
	write_byte(10)
	message_end()
}

public beam_remove(id)
{
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_KILLBEAM)
	write_short(id)
	message_end()
}

stock is_smoker(id)
{
	if (!is_user_alive(id) || !is_user_zombie(id) || g_smoker_class == -1)
		return 0

	return get_user_class(id) == g_smoker_class
}

stock tongue_wants_hold(id)
{
	if (g_tongue_held[id])
		return 1

	if (!get_pcvar_num(cvar_use_key))
		return 0

	return (pev(id, pev_button) & IN_USE) ? 1 : 0
}

stock bot_smoker_update_hold(id)
{
	if (g_hooked[id])
	{
		g_tongue_held[id] = 1
		return
	}

	g_tongue_held[id] = bot_smoker_find_target(id) ? 1 : 0
}

stock bot_smoker_find_target(id)
{
	new Float:maxrange = get_pcvar_float(cvar_range)
	new best
	new bestdist = floatround(maxrange) + 1

	static Float:origin[3]
	pev(id, pev_origin, origin)

	for (new i = 1; i <= g_maxplayers; i++)
	{
		if (!is_user_alive(i) || is_user_zombie(i) || i == id)
			continue

		static Float:torigin[3]
		pev(i, pev_origin, torigin)

		new dist = floatround(get_distance_f(origin, torigin))

		if (dist > floatround(maxrange) || dist >= bestdist)
			continue

		if (!smoker_can_hook_target(id, i))
			continue

		best = i
		bestdist = dist
	}

	return best
}

stock smoker_is_ai(id)
{
	if (!is_user_connected(id) || is_user_hltv(id))
		return 0

	// E-BOT / YaPB use is_user_bot(); FL_FAKECLIENT covers other fake clients.
	return is_user_bot(id) || (pev(id, pev_flags) & FL_FAKECLIENT)
}

stock bool:smoker_can_hook_target(id, target)
{
	// E-BOT zombie wall-hack knows humans behind cover; strict LOS blocks all hooks.
	if (smoker_is_ai(id) && get_pcvar_num(cvar_bot_enable) && !get_pcvar_num(cvar_bot_los))
		return true

	static Float:start[3], Float:end[3]

	pev(id, pev_origin, start)
	start[2] += 16.0
	pev(target, pev_origin, end)
	end[2] += 16.0

	new trace = create_tr2()
	engfunc(EngFunc_TraceLine, start, end, IGNORE_MONSTERS, id, trace)
	new bool:canHook = (get_tr2(trace, TR_pHit) == target)
	free_tr2(trace)

	return canHook
}
