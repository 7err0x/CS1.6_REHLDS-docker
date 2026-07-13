#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <cstrike>

#define PLUGIN "Respawn map defaults"
#define VERSION "1.2"
#define AUTHOR "cs16docker"

#define TASK_APPLY_MODE 51881
#define TASK_KILL_MONEY 51882
#define ENGINE_KILL_MONEY 300

new cvar_default_mode
new cvar_kill_money
new cvar_randomspawn
new cvar_roundtime
new g_mode[8]
new g_kill_attacker

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)

	cvar_default_mode = register_cvar("respawn_default_mode", "ffa")
	cvar_kill_money = register_cvar("respawn_kill_money", "600")
	cvar_randomspawn = register_cvar("respawn_randomspawn", "1")
	cvar_roundtime = register_cvar("respawn_roundtime", "30")

	register_event("HLTV", "event_new_round", "a", "1=0", "2=0")
	register_event("DeathMsg", "event_death_msg", "a")

	register_concmd("amx_respawn_ffa", "cmd_mode_ffa", ADMIN_RCON, "Switch to FFA respawn deathmatch")
	register_concmd("amx_respawn_tdm", "cmd_mode_tdm", ADMIN_RCON, "Switch to team respawn deathmatch")
	register_concmd("amx_respawn_mode", "cmd_mode", ADMIN_RCON, "<ffa|tdm> - switch respawn mode")
}

public plugin_cfg()
{
	respawn_reset_lights()
	respawn_schedule_apply_mode()
}

public event_new_round()
{
	respawn_reset_lights()
}

public event_death_msg()
{
	new killer = read_data(1)
	new victim = read_data(2)

	if (killer < 1 || killer > get_maxplayers() || victim < 1 || victim > get_maxplayers())
		return

	if (killer == victim || !is_user_connected(killer) || is_user_bot(killer))
		return

	if (!get_pcvar_num(cvar_kill_money))
		return

	if (!get_cvar_num("mp_freeforall") && cs_get_user_team(killer) == cs_get_user_team(victim))
		return

	g_kill_attacker = killer
	set_task(0.1, "task_kill_money_bonus", TASK_KILL_MONEY)
}

public task_kill_money_bonus()
{
	new attacker = g_kill_attacker
	g_kill_attacker = 0

	if (attacker < 1 || !is_user_connected(attacker))
		return

	new total = get_pcvar_num(cvar_kill_money)
	new extra = total - ENGINE_KILL_MONEY

	if (extra <= 0)
		return

	new money = cs_get_user_money(attacker)
	cs_set_user_money(attacker, money + extra, 1)
}

public cmd_mode_ffa(id, level, cid)
{
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED

	respawn_set_mode("ffa")
	return PLUGIN_HANDLED
}

public cmd_mode_tdm(id, level, cid)
{
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED

	respawn_set_mode("tdm")
	return PLUGIN_HANDLED
}

public cmd_mode(id, level, cid)
{
	if (!cmd_access(id, level, cid, 2))
		return PLUGIN_HANDLED

	new arg[8]
	read_argv(1, arg, charsmax(arg))

	if (equali(arg, "ffa"))
		respawn_set_mode("ffa")
	else if (equali(arg, "tdm"))
		respawn_set_mode("tdm")
	else
		console_print(id, "[Respawn] Usage: amx_respawn_mode <ffa|tdm>")

	return PLUGIN_HANDLED
}

public task_apply_mode()
{
	respawn_load_mode()
	respawn_apply_mode()
}

stock respawn_schedule_apply_mode()
{
	set_task(0.5, "task_apply_mode", TASK_APPLY_MODE)
}

stock respawn_load_mode()
{
	get_localinfo("respawn_mode", g_mode, charsmax(g_mode))

	if (!g_mode[0])
		get_pcvar_string(cvar_default_mode, g_mode, charsmax(g_mode))

	if (!g_mode[0] || (!equali(g_mode, "ffa") && !equali(g_mode, "tdm")))
		copy(g_mode, charsmax(g_mode), "ffa")
}

stock respawn_set_mode(const mode[])
{
	copy(g_mode, charsmax(g_mode), mode)
	set_localinfo("respawn_mode", g_mode)
	respawn_apply_mode()

	new label[32]
	formatex(label, charsmax(label), "%s", equali(mode, "ffa") ? "FFA" : "Team DM")
	client_print(0, print_chat, "[Respawn] Mode switched to %s (respawn on, infinite buy, infinite rounds).", label)
	log_amx("RESPAWN MODE: %s", label)
}

stock respawn_apply_mode()
{
	respawn_apply_common()

	if (equali(g_mode, "tdm"))
		respawn_apply_tdm()
	else
		respawn_apply_ffa()
}

stock respawn_apply_common()
{
	new mins[8]
	num_to_str(get_pcvar_num(cvar_roundtime), mins, charsmax(mins))

	server_cmd("mp_forcerespawn 1")
	server_cmd("mp_buytime -1")
	server_cmd("mp_round_infinite 1")
	server_cmd("mp_maxrounds 0")
	server_cmd("mp_winlimit 0")
	server_cmd("mp_fraglimit 0")
	server_cmd("mp_randomspawn %d", get_pcvar_num(cvar_randomspawn))
	server_cmd("mp_roundtime %s", mins)
	server_exec()
}

stock respawn_apply_ffa()
{
	server_cmd("mp_freeforall 1")
	server_cmd("mp_friendlyfire 0")
	server_cmd("mp_autoteambalance 0")
	server_cmd("mp_freezetime 0")
	server_exec()
}

stock respawn_apply_tdm()
{
	server_cmd("mp_freeforall 0")
	server_cmd("mp_friendlyfire 0")
	server_cmd("mp_autoteambalance 1")
	server_cmd("mp_freezetime 2")
	server_exec()
}

stock respawn_reset_lights()
{
	engfunc(EngFunc_LightStyle, 0, "m")
}
