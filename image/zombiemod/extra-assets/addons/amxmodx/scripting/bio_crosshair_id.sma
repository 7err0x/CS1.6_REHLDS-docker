/*
 * Crosshair player name — replaces ReGameDLL "spotted ally/enemy" hints and
 * the lower-left status-bar name with the target's name centered under the crosshair.
 * Works on respawn (CT/T colors) and Biohazard (zombie colors when biohazard.amxx is loaded).
 */
#include <amxmodx>
#include <cstrike>

#define PLUGIN "[BH] Crosshair name"
#define VERSION "1.1"
#define AUTHOR "cs16docker"

new g_msgHudTextArgs
new g_msgStatusText
new cvar_enable
new cvar_dist
new Float:g_next_hud[33]
new g_fn_is_user_zombie = -1

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)

	cvar_enable = register_cvar("bh_crosshair_id", "1")
	cvar_dist = register_cvar("bh_crosshair_id_dist", "4096")

	g_msgHudTextArgs = get_user_msgid("HudTextArgs")
	g_msgStatusText = get_user_msgid("StatusText")

	if (g_msgHudTextArgs)
		register_message(g_msgHudTextArgs, "msg_HudTextArgs")

	if (g_msgStatusText)
		register_message(g_msgStatusText, "msg_StatusText")

	set_task(0.1, "task_crosshair_id", _, _, _, "b")
}

public plugin_cfg()
{
	bh_apply_playerid_off()
}

stock bh_apply_playerid_off()
{
	if (!get_pcvar_num(cvar_enable))
		return

	new pcv = get_cvar_pointer("mp_playerid")

	if (pcv)
		set_pcvar_num(pcv, 2)
}

stock bool:bh_infection_mod_active()
{
	if (!cvar_exists("bh_enabled"))
		return false

	return (get_cvar_num("bh_enabled") != 0)
}

stock bool:bh_is_user_zombie(id)
{
	if (g_fn_is_user_zombie == -1)
	{
		new plug = find_plugin_byfile("biohazard.amxx")
		if (plug != -1)
			g_fn_is_user_zombie = get_func_id("is_user_zombie", plug)
	}

	if (g_fn_is_user_zombie == -1)
		return false

	if (callfunc_begin_i(g_fn_is_user_zombie) != 1)
		return false

	callfunc_push_int(id)

	return (callfunc_end() != 0)
}

public msg_HudTextArgs(msgid, dest, id)
{
	if (!get_pcvar_num(cvar_enable))
		return PLUGIN_CONTINUE

	static text[96]
	get_msg_arg_string(1, text, charsmax(text))

	if (containi(text, "Hint_spotted") != -1)
		return PLUGIN_HANDLED

	return PLUGIN_CONTINUE
}

public msg_StatusText(msgid, dest, id)
{
	if (!get_pcvar_num(cvar_enable))
		return PLUGIN_CONTINUE

	static text[96]
	get_msg_arg_string(2, text, charsmax(text))

	if (text[0] == 0 || equal(text, " ") || contain(text, "%p2") != -1)
		return PLUGIN_HANDLED

	return PLUGIN_CONTINUE
}

public task_crosshair_id()
{
	if (!get_pcvar_num(cvar_enable))
		return

	static dist, Float:now
	dist = get_pcvar_num(cvar_dist)
	now = get_gametime()

	static id, target, body, name[32]
	static bool:bh_active, bool:viewer_zombie, bool:target_zombie

	bh_active = bh_infection_mod_active()

	for (id = 1; id <= get_maxplayers(); id++)
	{
		if (!is_user_alive(id) || is_user_bot(id))
			continue

		if (now < g_next_hud[id])
			continue

		target = 0
		body = 0

		if (!get_user_aiming(id, target, body, dist) || !is_user_alive(target) || target == id)
			continue

		get_user_name(target, name, charsmax(name))

		new r = 255, g = 255, b = 255

		if (bh_active)
		{
			viewer_zombie = bh_is_user_zombie(id)
			target_zombie = bh_is_user_zombie(target)

			if (viewer_zombie == target_zombie)
			{
				r = 100
				g = 220
				b = 100
			}
			else
			{
				r = 255
				g = 90
				b = 90
			}
		}
		else if (cs_get_user_team(id) == cs_get_user_team(target))
		{
			r = 120
			g = 170
			b = 255
		}
		else
		{
			r = 255
			g = 90
			b = 90
		}

		set_hudmessage(r, g, b, -1.0, 0.58, 0, 0.0, 0.12, 0.02, 0.02, -1)
		show_hudmessage(id, "%s", name)
		g_next_hud[id] = now + 0.1
	}
}
