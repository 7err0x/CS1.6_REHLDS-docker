/*
 * [BH] E-BOT schedule — adjust ebot_quota from AMXX.
 *
 * Supports:
 *   - No bots when the server has zero human players (CPU saving).
 *   - Time-of-day peak/off-peak quotas (local server time).
 *
 * Requires E-BOT (Metamod) on cs16-biohazard; no-op if ebot_quota is missing.
 */
#include <amxmodx>
#include <amxmisc>
#tryinclude <biohazard>

#if !defined _biohazard_included
	#assert Biohazard functions file required!
#endif

#define PLUGIN "[BH] E-BOT schedule"
#define VERSION "1.2"
#define AUTHOR "cs16docker"

#define TASK_APPLY_REPEAT 9100
#define TASK_APPLY_DELAY 9101

new g_maxplayers
new g_last_quota = -1
new g_last_paused = -1
new g_ebot_quota_ptr
new g_ebot_stop_ptr

new cvar_enable, cvar_require_human, cvar_quota_empty, cvar_quota_with_humans
new cvar_pause_without_humans
new cvar_use_hours, cvar_peak_start, cvar_peak_end
new cvar_quota_peak, cvar_quota_offpeak, cvar_check_secs, cvar_debug

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	is_biomod_active() ? plugin_init2() : pause("ad")
}

public plugin_init2()
{
	g_maxplayers = get_maxplayers()

	cvar_enable = register_cvar("bh_ebot_sched_enable", "1")
	cvar_require_human = register_cvar("bh_ebot_require_human", "1")
	cvar_pause_without_humans = register_cvar("bh_ebot_pause_without_humans", "1")
	cvar_quota_empty = register_cvar("bh_ebot_quota_empty", "0")
	cvar_quota_with_humans = register_cvar("bh_ebot_quota_with_humans", "8")
	cvar_use_hours = register_cvar("bh_ebot_sched_use_hours", "1")
	cvar_peak_start = register_cvar("bh_ebot_sched_peak_start", "22")
	cvar_peak_end = register_cvar("bh_ebot_sched_peak_end", "10")
	cvar_quota_peak = register_cvar("bh_ebot_sched_quota_peak", "8")
	cvar_quota_offpeak = register_cvar("bh_ebot_sched_quota_offpeak", "0")
	cvar_check_secs = register_cvar("bh_ebot_sched_check_secs", "30")
	cvar_debug = register_cvar("bh_ebot_sched_debug", "0")

	if (cvar_exists("ebot_quota"))
		g_ebot_quota_ptr = get_cvar_pointer("ebot_quota")
	else
		log_amx("[BH E-BOT schedule] ebot_quota not found — is E-BOT loaded?")

	if (cvar_exists("ebot_stop_bots"))
		g_ebot_stop_ptr = get_cvar_pointer("ebot_stop_bots")

	ebot_sched_load_config()
	schedule_recheck_task()
}

public plugin_cfg()
{
	ebot_sched_load_config()
	g_last_quota = -1
	g_last_paused = -1
	set_task(2.0, "task_apply_quota", TASK_APPLY_DELAY)
	schedule_recheck_task()
}

public plugin_end()
{
	remove_task(TASK_APPLY_REPEAT)
	remove_task(TASK_APPLY_DELAY)
}

public client_putinserver(id)
{
	if (!get_pcvar_num(cvar_enable))
		return

	set_task(1.0, "task_apply_quota", TASK_APPLY_DELAY)
}

public client_disconnected(id)
{
	if (!get_pcvar_num(cvar_enable))
		return

	set_task(1.0, "task_apply_quota", TASK_APPLY_DELAY)
}

public task_apply_quota()
{
	if (!get_pcvar_num(cvar_enable))
		return

	if (!cvar_exists("ebot_quota"))
		return

	new humans = ebot_sched_count_humans()
	new quota = ebot_sched_compute_quota()
	new pause = ebot_sched_should_pause(humans)
	new bool:changed

	if (quota != g_last_quota)
	{
		ebot_sched_apply_quota(quota)
		g_last_quota = quota
		changed = true
	}

	if (pause != g_last_paused)
	{
		ebot_sched_apply_pause(pause)
		g_last_paused = pause
		changed = true
	}

	if (get_pcvar_num(cvar_debug) && changed)
		log_amx("[BH E-BOT schedule] humans=%d quota=%d pause=%d peak=%d", humans, quota, pause, ebot_sched_in_peak_window())
}

stock ebot_sched_load_config()
{
	new file[128]
	get_configsdir(file, 63)
	format(file, charsmax(file), "%s/bh_ebot_schedule.cfg", file)

	if (!file_exists(file))
	{
		log_amx("[BH E-BOT schedule] missing %s — using register_cvar defaults", file)
		return
	}

	server_cmd("exec %s", file)
	server_exec()
}

stock schedule_recheck_task()
{
	remove_task(TASK_APPLY_REPEAT)

	new Float:interval = get_pcvar_float(cvar_check_secs)

	if (interval < 5.0)
		interval = 5.0

	set_task(interval, "task_apply_quota", TASK_APPLY_REPEAT, _, _, "b")
}

stock ebot_sched_count_humans()
{
	new count

	for (new id = 1; id <= g_maxplayers; id++)
	{
		if (is_user_connected(id) && !is_user_bot(id))
			count++
	}

	return count
}

stock bool:ebot_sched_in_peak_window()
{
	new start = clamp(get_pcvar_num(cvar_peak_start), 0, 23)
	new end = clamp(get_pcvar_num(cvar_peak_end), 0, 23)

	new shour[3]
	get_time("%H", shour, charsmax(shour))
	new hour = str_to_num(shour)

	if (start == end)
		return true

	if (start < end)
		return (hour >= start && hour < end)

	return (hour >= start || hour < end)
}

stock ebot_sched_compute_quota()
{
	if (get_pcvar_num(cvar_require_human) && ebot_sched_count_humans() < 1)
		return clamp(get_pcvar_num(cvar_quota_empty), 0, 32)

	if (get_pcvar_num(cvar_use_hours))
	{
		if (ebot_sched_in_peak_window())
			return clamp(get_pcvar_num(cvar_quota_peak), 0, 32)

		return clamp(get_pcvar_num(cvar_quota_offpeak), 0, 32)
	}

	return clamp(get_pcvar_num(cvar_quota_with_humans), 0, 32)
}

stock ebot_sched_should_pause(humans)
{
	// require_human 1 + empty server → quota_empty (usually 0 bots); no pause needed.
	if (get_pcvar_num(cvar_require_human))
		return 0

	if (!get_pcvar_num(cvar_pause_without_humans))
		return 0

	return humans < 1 ? 1 : 0
}

stock ebot_sched_apply_quota(quota)
{
	if (g_ebot_quota_ptr)
		set_pcvar_num(g_ebot_quota_ptr, quota)

	new cmd[24]
	formatex(cmd, charsmax(cmd), "ebot_quota %d", quota)
	server_cmd(cmd)
	server_exec()
}

stock ebot_sched_apply_pause(pause)
{
	if (!cvar_exists("ebot_stop_bots"))
		return

	if (g_ebot_stop_ptr)
		set_pcvar_num(g_ebot_stop_ptr, pause)

	new cmd[24]
	formatex(cmd, charsmax(cmd), "ebot_stop_bots %d", pause)
	server_cmd(cmd)
	server_exec()
}
