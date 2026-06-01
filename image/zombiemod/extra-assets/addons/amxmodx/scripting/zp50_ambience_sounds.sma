/*
 * Biohazard port of [ZP] Ambience Sounds (Zombie Plague 5.0.8).
 * GPL — original by ZP Dev Team. Upstream: Gam3ronE/ZP zp50_ambience_sounds.sma
 *
 * Loops zombie_plague/ambience.wav during live infection rounds (ZP infection mode default).
 */
#include <amxmodx>

#tryinclude <biohazard>

#if !defined _biohazard_included
#error Add addons/amxmodx/scripting/include/biohazard.inc when compiling.
#endif

#define PLUGIN_NAME "[BH] zp50-derived Ambience Sounds"
#define PLUGIN_VERS "1.0"
#define PLUGIN_AUTH "ZP Dev Team / BH port"

#define TASK_AMBIENCE 200

new const AMB_SOUND[] = "zombie_plague/ambience.wav"
new const Float:AMB_DURATION = 17.0

new g_cvEnable

public plugin_precache()
{
	precache_sound(AMB_SOUND)
}

public plugin_init()
{
	register_plugin(PLUGIN_NAME, PLUGIN_VERS, PLUGIN_AUTH)

	if (!is_biomod_active())
	{
		pause("ad")
		return
	}

	register_event("30", "event_intermission", "a")
	register_event("HLTV", "event_newround", "a", "1=0", "2=0")

	g_cvEnable = register_cvar("zp_ambience_sounds", "0")
}

public event_gamestart()
{
	ambience_stop()

	if (!get_pcvar_num(g_cvEnable))
		return

	set_task(2.0, "ambience_play", TASK_AMBIENCE)
}

public event_intermission()
{
	ambience_stop()
}

public event_newround()
{
	ambience_stop()
}

public ambience_play()
{
	if (!get_pcvar_num(g_cvEnable) || !game_started())
		return

	client_cmd(0, "spk %s", AMB_SOUND)
	set_task(AMB_DURATION, "ambience_play", TASK_AMBIENCE)
}

stock ambience_stop()
{
	remove_task(TASK_AMBIENCE)
}
