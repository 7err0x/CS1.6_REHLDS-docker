/*
 * [BH] Phantom cloak — zombie class hides from survivors when no human is in range.
 * Zombies always see cloaked phantoms (FM_AddToFullPack per viewer, not global EF_NODRAW).
 */
#include <amxmodx>
#include <fakemeta>
#include <engine>
#tryinclude <biohazard>

#if !defined _biohazard_included
	#assert Biohazard functions file required!
#endif

#define PLUGIN "[BH] Phantom cloak"
#define VERSION "1.1"
#define AUTHOR "cs16docker"

#define CLASS_NAME "Phantom"
#define MODEL_CLASSNAME "player_model"

new const g_class_hint[] = "[Phantom] You become invisible to survivors when no one is within range."

new g_phantom_class = -1
new g_maxplayers

new cvar_enable, cvar_range, cvar_interval, cvar_hint

new bool:g_cloaked[33]

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	is_biomod_active() ? plugin_init2() : pause("ad")
}

public plugin_init2()
{
	g_maxplayers = get_maxplayers()

	cvar_enable = register_cvar("bh_phantom_enable", "1")
	cvar_range = register_cvar("bh_phantom_range", "250.0")
	cvar_interval = register_cvar("bh_phantom_interval", "0.15")
	cvar_hint = register_cvar("bh_phantom_hint", "1")

	register_forward(FM_AddToFullPack, "fw_AddToFullPack", 0)

	set_task(get_pcvar_float(cvar_interval), "task_cloak_tick", 0, _, _, "b")
	set_task(1.0, "task_resolve_class", 0, _, _, "b")
}

public plugin_cfg()
	task_resolve_class()

public task_resolve_class()
{
	g_phantom_class = get_class_id(CLASS_NAME)

	if (g_phantom_class == -1)
		log_amx("[BH Phantom] Class ^"%s^" not found in bh_zombieclass.ini", CLASS_NAME)
}

public event_gamestart()
{
	for (new i = 1; i <= g_maxplayers; i++)
		g_cloaked[i] = false
}

public event_infect(victim, attacker)
{
	if (g_phantom_class == -1 || !is_user_connected(victim))
		return

	if (get_user_class(victim) != g_phantom_class)
		return

	if (get_pcvar_num(cvar_hint))
		client_print(victim, print_chat, "%s", g_class_hint)

	task_cloak_player(victim)
}

public client_disconnected(id)
{
	g_cloaked[id] = false
}

public task_cloak_tick()
{
	if (!get_pcvar_num(cvar_enable) || g_phantom_class == -1)
		return

	for (new id = 1; id <= g_maxplayers; id++)
		task_cloak_player(id)
}

public fw_AddToFullPack(es_handle, e, ent, host, hostflags, player, pSet)
{
	if (!get_pcvar_num(cvar_enable) || g_phantom_class == -1)
		return FMRES_IGNORED

	if (!pev_valid(ent) || !is_user_connected(host) || is_user_hltv(host))
		return FMRES_IGNORED

	// Survivors only: cloaked phantom third-person models are omitted from the snapshot.
	if (is_user_zombie(host))
		return FMRES_IGNORED

	static classname[32]
	pev(ent, pev_classname, classname, charsmax(classname))

	if (!equal(classname, MODEL_CLASSNAME))
		return FMRES_IGNORED

	new owner = pev(ent, pev_owner)

	if (owner < 1 || owner > g_maxplayers)
		return FMRES_IGNORED

	if (!g_cloaked[owner])
		return FMRES_IGNORED

	return FMRES_SUPERCEDE
}

stock task_cloak_player(id)
{
	if (!is_user_alive(id) || !is_user_zombie(id) || get_user_class(id) != g_phantom_class)
	{
		g_cloaked[id] = false
		return
	}

	if (bh_player_is_frost_frozen(id))
	{
		g_cloaked[id] = false
		phantom_ensure_model_drawn(id)
		return
	}

	new bool:near_human = phantom_near_human(id, get_pcvar_float(cvar_range))
	new bool:should_cloak = !near_human

	if (should_cloak != g_cloaked[id])
	{
		g_cloaked[id] = should_cloak
		phantom_ensure_model_drawn(id)
	}
}

stock bool:phantom_near_human(id, Float:range)
{
	static Float:origin[3], Float:other[3]
	pev(id, pev_origin, origin)

	for (new human = 1; human <= g_maxplayers; human++)
	{
		if (human == id || !is_user_alive(human) || is_user_zombie(human))
			continue

		pev(human, pev_origin, other)

		if (get_distance_f(origin, other) <= range)
			return true
	}

	return false
}

// Keep the follow-model entity visible on the server; humans are filtered in AddToFullPack.
stock phantom_ensure_model_drawn(id)
{
	new ent = fm_find_ent_by_owner(-1, MODEL_CLASSNAME, id)

	if (!pev_valid(ent))
		return

	set_pev(ent, pev_effects, pev(ent, pev_effects) & ~EF_NODRAW)
}

stock fm_find_ent_by_owner(index, const classname[], owner)
{
	static ent
	ent = index

	while ((ent = engfunc(EngFunc_FindEntityByString, ent, "classname", classname)) && pev(ent, pev_owner) != owner) {}

	return ent
}
