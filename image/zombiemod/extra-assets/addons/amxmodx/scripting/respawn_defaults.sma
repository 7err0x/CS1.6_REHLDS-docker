#include <amxmodx>
#include <fakemeta>

#define PLUGIN "Respawn map defaults"
#define VERSION "1.0"
#define AUTHOR "cs16docker"

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	register_event("HLTV", "event_new_round", "a", "1=0", "2=0")
}

public plugin_cfg()
{
	respawn_reset_lights()
}

public event_new_round()
{
	respawn_reset_lights()
}

stock respawn_reset_lights()
{
	// Map default ambient (brighter than Biohazard bh_lights "b").
	engfunc(EngFunc_LightStyle, 0, "m")
}
