/*
 * Biohazard port of zp50_grenade_fire — no zp50_core / cs_weap_models required.
 *
 * GPL — Zombie Plague 5.x grenade napalm (reference):
 *   scripting/upstream/evandrocoan_MultiModServer/zp50_grenade_fire.sma
 *
 * Human HE grenade: red trail + glow → burn zombies in radius (Damage HUD + slowdown + HP drain).
 *
 * Burn puffs use sprites shipped with CS (not HL-only flame.spr — that crashes Mod_LoadModel).
 */
#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <xs>
#include <fun>

#tryinclude <biohazard>

#if !defined _biohazard_included
#error Add addons/amxmodx/scripting/include/biohazard.inc next to this file when compiling.
#endif

#define PLUGIN_NAME "[BH] zp50-derived Grenade: Fire"
#define PLUGIN_VERS "1.03"
#define PLUGIN_AUTH "ZP Dev Team / BH port"

#define TASK_BURN 9300

#define RAD_FIRE 240.0

#define PEV_NADE_TYPE pev_flTimeStepSound
#define NADE_FIRE     2222

new g_mp

new const SND_EXP[][64] =
{
	"weapons/hegrenade-2.wav",
	"weapons/rocketfire1.wav"
}

// ZP 5.0.8 napalm burn screams (zombie_plague/zombie_burn*.wav).
new const SND_BRN[][64] =
{
	"zombie_plague/zombie_burn3.wav",
	"zombie_plague/zombie_burn4.wav",
	"zombie_plague/zombie_burn5.wav",
	"zombie_plague/zombie_burn6.wav",
	"zombie_plague/zombie_burn7.wav"
}

new const MODEL_TRAIL[] = "sprites/laserbeam.spr"
new const MODEL_RING[] = "sprites/shockwave.spr"
// Vanilla cstrike includes black_smoke3.spr; flame.spr does not (Half-Life only → FATAL on load).
new const MODEL_BURN_PUFF[] = "sprites/black_smoke3.spr"

new g_idTrail
new g_idRing
new g_idPuff

new g_msgDamage

new g_cvDur
new g_cvDmg
new g_cvSlow
new g_cvHud
new g_cvVanillaExplo

new g_ticksLeft[33]

public plugin_precache()
{
	new i

	for (i = 0; i < sizeof SND_EXP; i++)
		precache_sound(SND_EXP[i])

	for (i = 0; i < sizeof SND_BRN; i++)
		precache_sound(SND_BRN[i])

	g_idTrail = precache_model(MODEL_TRAIL)
	g_idRing = precache_model(MODEL_RING)
	g_idPuff = precache_model(MODEL_BURN_PUFF)
}

public plugin_init()
{
	register_plugin(PLUGIN_NAME, PLUGIN_VERS, PLUGIN_AUTH)

	if (!is_biomod_active())
	{
		pause("ad")
		return
	}

	g_mp = get_maxplayers()

	register_forward(FM_SetModel, "H_SetModel")
	RegisterHam(Ham_Think, "grenade", "H_GrenThink")
	RegisterHam(Ham_Killed, "player", "H_Killed")

	register_event("HLTV", "EvtNewRound", "a", "1=0", "2=0")

	g_msgDamage = get_user_msgid("Damage")

	g_cvDur = register_cvar("zp_grenade_fire_duration", "10")
	g_cvDmg = register_cvar("zp_grenade_fire_damage", "5.0")
	g_cvSlow = register_cvar("zp_grenade_fire_slowdown", "0.45")
	g_cvHud = register_cvar("zp_grenade_fire_hudicon", "1")

	// If 1, leave normal HE explosion (grenade survives Think path).
	g_cvVanillaExplo = register_cvar("zp_grenade_fire_explosion", "0")
}

public EvtNewRound()
{
	static id

	for (id = 1; id <= g_mp; id++)
	{
		remove_task(id + TASK_BURN)
		g_ticksLeft[id] = 0
	}
}

public client_disconnect(id)
{
	remove_task(id + TASK_BURN)
	g_ticksLeft[id] = 0
}

public H_Killed(id)
{
	StopBurn(id)
}

stock StopBurn(id)
{
	remove_task(id + TASK_BURN)
	g_ticksLeft[id] = 0

	if (!is_user_connected(id))
		return

	static ori[3]
	get_user_origin(id, ori)

	message_begin(MSG_PVS, SVC_TEMPENTITY, ori)
	write_byte(TE_SMOKE)
	write_coord(ori[0])
	write_coord(ori[1])
	write_coord(ori[2] - 50)
	write_short(g_idPuff)
	write_byte(random_num(15, 20))
	write_byte(random_num(10, 20))
	message_end()
}

public H_SetModel(ent, const model[])
{
	if (strlen(model) < 11)
		return FMRES_IGNORED

	if (model[7] != 'w' || model[8] != '_')
		return FMRES_IGNORED

	static Float:dt

	pev(ent, pev_dmgtime, dt)
	if (dt == 0.0)
		return FMRES_IGNORED

	new oid = pev(ent, pev_owner)

	if (oid < 1 || oid > g_mp || !is_user_alive(oid) || is_user_zombie(oid))
		return FMRES_IGNORED

	if (!(model[9] == 'h' && model[10] == 'e'))
		return FMRES_IGNORED

	FmShell(ent, 200, 10, 0)

	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_BEAMFOLLOW)
	write_short(ent)
	write_short(g_idTrail)
	write_byte(10)
	write_byte(10)
	write_byte(200)
	write_byte(40)
	write_byte(0)
	write_byte(200)
	message_end()

	set_pev(ent, PEV_NADE_TYPE, NADE_FIRE)

	return FMRES_IGNORED
}

public H_GrenThink(ent)
{
	if (!pev_valid(ent))
		return HAM_IGNORED

	static Float:dt

	pev(ent, pev_dmgtime, dt)

	if (dt > get_gametime())
		return HAM_IGNORED

	if (pev(ent, PEV_NADE_TYPE) != NADE_FIRE)
		return HAM_IGNORED

	FireBurst(ent)

	if (get_pcvar_num(g_cvVanillaExplo))
	{
		set_pev(ent, PEV_NADE_TYPE, 0)
		return HAM_IGNORED
	}

	engfunc(EngFunc_RemoveEntity, ent)
	return HAM_SUPERCEDE
}

FireBurst(ent)
{
	static Float:o[3]

	pev(ent, pev_origin, o)

	if (!get_pcvar_num(g_cvVanillaExplo))
		RingsThree(o)

	new snd[64]
	copy(snd, charsmax(snd), SND_EXP[random_num(0, sizeof SND_EXP - 1)])
	emit_sound(ent, CHAN_WEAPON, snd, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)

	new vic = -1

	while ((vic = engfunc(EngFunc_FindEntityInSphere, vic, o, RAD_FIRE)))
	{
		if (vic < 1 || vic > g_mp)
			continue

		if (is_user_alive(vic) && is_user_zombie(vic))
			StartBurn(vic)
	}
}

StartBurn(id)
{
	if (get_pcvar_num(g_cvHud))
	{
		message_begin(MSG_ONE_UNRELIABLE, g_msgDamage, _, id)
		write_byte(0)
		write_byte(0)
		write_long(DMG_BURN)
		write_coord(0)
		write_coord(0)
		write_coord(0)
		message_end()
	}

	new base = get_pcvar_num(g_cvDur)
	if (base < 1)
		base = 1

	g_ticksLeft[id] += base * 5

	remove_task(id + TASK_BURN)
	set_task(0.2, "TickBurn", id + TASK_BURN, _, _, "b")
}

public TickBurn(tid)
{
	new id = tid - TASK_BURN

	if (!is_user_alive(id))
	{
		remove_task(tid)
		g_ticksLeft[id] = 0
		return
	}

	new flags = pev(id, pev_flags)

	if ((flags & FL_INWATER) || g_ticksLeft[id] < 1)
	{
		StopBurn(id)
		return
	}

	if (random_num(1, 18) == 1)
	{
		new bs[64]
		copy(bs, charsmax(bs), SND_BRN[random_num(0, sizeof SND_BRN - 1)])
		emit_sound(id, CHAN_VOICE, bs, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	}

	new Float:slow

	slow = get_pcvar_float(g_cvSlow)

	if ((flags & FL_ONGROUND) && slow > 0.01)
	{
		static Float:v[3]

		pev(id, pev_velocity, v)
		xs_vec_mul_scalar(v, slow, v)
		set_pev(id, pev_velocity, v)
	}

	static Float:h

	pev(id, pev_health, h)

	new loss = floatround(get_pcvar_float(g_cvDmg), floatround_ceil)
	new Float:next_hp = h - float(loss)

	if (next_hp <= 0.5)
	{
		remove_task(tid)
		g_ticksLeft[id] = 0
		user_kill(id)
		return
	}

	set_pev(id, pev_health, next_hp)

	static ori[3]

	get_user_origin(id, ori)

	message_begin(MSG_PVS, SVC_TEMPENTITY, ori)
	write_byte(TE_SPRITE)
	write_coord(ori[0] + random_num(-5, 5))
	write_coord(ori[1] + random_num(-5, 5))
	write_coord(ori[2] + random_num(-10, 10))
	write_short(g_idPuff)
	write_byte(random_num(5, 10))
	write_byte(200)
	message_end()

	g_ticksLeft[id]--
}

stock FmShell(ent, r, gg, b)
{
	new Float:rgb[3]

	rgb[0] = float(r)
	rgb[1] = float(gg)
	rgb[2] = float(b)

	set_pev(ent, pev_renderfx, kRenderFxGlowShell)
	set_pev(ent, pev_rendercolor, rgb)
	set_pev(ent, pev_rendermode, kRenderNormal)
	set_pev(ent, pev_renderamt, 16.0)
}

stock RingsThree(const Float:origin[3])
{
	RingCylinder(origin, 385.0, 200, 100, 0)
	RingCylinder(origin, 470.0, 200, 50, 0)
	RingCylinder(origin, 555.0, 200, 0, 0)
}

stock RingCylinder(const Float:o[3], Float:zRaise, rr, gg, bb)
{
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, o, 0)
	write_byte(TE_BEAMCYLINDER)
	engfunc(EngFunc_WriteCoord, o[0])
	engfunc(EngFunc_WriteCoord, o[1])
	engfunc(EngFunc_WriteCoord, o[2])
	engfunc(EngFunc_WriteCoord, o[0])
	engfunc(EngFunc_WriteCoord, o[1])
	engfunc(EngFunc_WriteCoord, o[2] + zRaise)
	write_short(g_idRing)
	write_byte(0)
	write_byte(0)
	write_byte(4)
	write_byte(60)
	write_byte(0)
	write_byte(rr)
	write_byte(gg)
	write_byte(bb)
	write_byte(200)
	write_byte(0)
	message_end()
}
