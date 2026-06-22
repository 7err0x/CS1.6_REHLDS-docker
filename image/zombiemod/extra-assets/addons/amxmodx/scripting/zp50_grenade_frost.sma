/*
 * Biohazard port of zp50_grenade_frost — no zp50_core required.
 *
 * Human flashbang: blue trail → freeze zombies in radius for zp_grenade_frost_duration.
 */
#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <biohazard>

#define PLUGIN_NAME "[BH] zp50-derived Grenade: Frost"
#define PLUGIN_VERS "1.06"
#define PLUGIN_AUTH "ZP Dev Team / BH port"

new g_mp

#define TASK_FRZ_RM 9100
#define TASK_CURE 9200

#define GRAVITY_HIGH_FL 999999.9
#define GRAVITY_NONE_FL 0.000001

#define NADE_RADIUS 240.0

#define PEV_NADE_TYPE pev_iuser3
#define NADE_FRZ      3333

#define SCR_FADE_SEC  (1<<12)
#define GLASS_BF      0x01
#define FF_IN         0x0000
#define FF_STAYOUT    0x0004

new const SND_EXP[] = "warcraft3/frostnova.wav"
new const SND_HIT[] = "warcraft3/impalehit.wav"
new const SND_BRK[] = "warcraft3/impalelaunch1.wav"

new const MODEL_TRAIL[] = "sprites/laserbeam.spr"
new const MODEL_RING[] = "sprites/shockwave.spr"
new const MODEL_GLASS[] = "models/glassgibs.mdl"

new Float:g_svGrav[33]
new g_SvFx[33], Float:g_SvRgb[33][3], g_SvRm[33], Float:g_SvAmt[33]

new g_msgdmg, g_msgsf
new g_idTrail, g_idRing, g_idGlass

new g_cvDur, g_cvHud

stock bool:HasFrost(id)
{
	return bh_player_is_frost_frozen(id)
}

stock SetFrostMark(id)
{
	set_pev(id, BH_PEV_FROST, BH_FROST_TAG)
}

stock ClrFrostMark(id)
{
	set_pev(id, BH_PEV_FROST, 0)
}

stock bool:bh_is_flashbang_model(const model[])
{
	return (containi(model, "flashbang") != -1)
}

stock bh_frost_set_maxspeed(id, Float:speed)
{
	if(!is_user_connected(id))
		return

	engfunc(EngFunc_SetClientMaxspeed, id, speed)
	set_pev(id, pev_maxspeed, speed)
}

stock bh_frost_kill_beam(ent)
{
	if(!pev_valid(ent))
		return

	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_KILLBEAM)
	write_short(ent)
	message_end()
}

public plugin_precache()
{
	precache_sound(SND_EXP)
	precache_sound(SND_HIT)
	precache_sound(SND_BRK)

	g_idTrail = precache_model(MODEL_TRAIL)
	g_idRing = precache_model(MODEL_RING)
	g_idGlass = precache_model(MODEL_GLASS)
}

public plugin_init()
{
	register_plugin(PLUGIN_NAME, PLUGIN_VERS, PLUGIN_AUTH)

	if(!is_biomod_active())
	{
		pause("ad")
		return
	}

	g_mp = get_maxplayers()

	RegisterHam(Ham_TakeDamage, "player", "H_TakeDamage")
	RegisterHam(Ham_TraceAttack, "player", "H_TraceAttack")
	RegisterHam(Ham_Killed, "player", "H_Killed")

	register_forward(FM_PlayerPreThink, "H_PreThink")
	register_forward(FM_SetModel, "H_SetModel")
	RegisterHam(Ham_Think, "grenade", "H_GrenThink")

	register_event("HLTV", "EvtNewRound", "a", "1=0", "2=0")

	g_msgdmg = get_user_msgid("Damage")
	g_msgsf = get_user_msgid("ScreenFade")

	g_cvDur = register_cvar("zp_grenade_frost_duration", "4.0")
	g_cvHud = register_cvar("zp_grenade_frost_hudicon", "1")
}

stock ValidPid(id)
	return (id >= 1 && id <= g_mp && is_user_connected(id)) ? 1 : 0

public EvtNewRound()
{
	static id

	for(id = 1; id <= g_mp; id++)
	{
		if(!is_user_connected(id))
			continue

		remove_task(id + TASK_FRZ_RM)
		remove_task(id + TASK_CURE)

		if(HasFrost(id))
			BHUnfreeze(id, false)
	}
}

public client_disconnected(id)
{
	remove_task(id + TASK_FRZ_RM)
	remove_task(id + TASK_CURE)
	ClrFrostMark(id)
}

public TaskUnfreeze(packed)
{
	new id = packed - TASK_FRZ_RM
	BHUnfreeze(id, true)
}

public CurePoll(packed)
{
	new id = packed - TASK_CURE

	if(!ValidPid(id) || !is_user_alive(id))
		return

	if(!HasFrost(id))
	{
		remove_task(id + TASK_CURE)
		return
	}

	if(!is_user_zombie(id))
	{
		remove_task(id + TASK_CURE)
		BHUnfreeze(id, true)
	}
}

public BHUnfreeze(id, effects)
{
	remove_task(id + TASK_FRZ_RM)

	if(!HasFrost(id))
		return

	remove_task(id + TASK_CURE)
	ClrFrostMark(id)

	if(is_user_alive(id))
	{
		set_pev(id, pev_gravity, g_svGrav[id])
		set_pev(id, pev_renderfx, g_SvFx[id])
		set_pev(id, pev_rendercolor, g_SvRgb[id])
		set_pev(id, pev_rendermode, g_SvRm[id])
		set_pev(id, pev_renderamt, g_SvAmt[id])

		if(g_msgsf)
		{
			message_begin(MSG_ONE, g_msgsf, _, id)
			write_short(SCR_FADE_SEC)
			write_short(0)
			write_short(FF_IN)
			write_byte(0)
			write_byte(50)
			write_byte(200)
			write_byte(100)
			message_end()
		}
	}

	if(!effects || !is_user_alive(id))
		return

	emit_sound(id, CHAN_BODY, SND_BRK, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)

	static ori[3]
	get_user_origin(id, ori)

	message_begin(MSG_PVS, SVC_TEMPENTITY, ori)
	write_byte(TE_BREAKMODEL)
	write_coord(ori[0])
	write_coord(ori[1])
	write_coord(ori[2] + 24)
	write_coord(16)
	write_coord(16)
	write_coord(16)
	write_coord(random_num(-50, 50))
	write_coord(random_num(-50, 50))
	write_coord(25)
	write_byte(10)
	write_short(g_idGlass)
	write_byte(10)
	write_byte(25)
	write_byte(GLASS_BF)
	message_end()
}

FreezeStart(id)
{
	if(!is_user_alive(id) || !is_user_zombie(id) || HasFrost(id))
		return

	SetFrostMark(id)

	if(get_pcvar_num(g_cvHud) && g_msgdmg)
	{
		message_begin(MSG_ONE_UNRELIABLE, g_msgdmg, _, id)
		write_byte(0)
		write_byte(0)
		write_long(DMG_DROWN)
		write_coord(0)
		write_coord(0)
		write_coord(0)
		message_end()
	}

	emit_sound(id, CHAN_BODY, SND_HIT, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)

	if(g_msgsf)
	{
		message_begin(MSG_ONE, g_msgsf, _, id)
		write_short(0)
		write_short(0)
		write_short(FF_STAYOUT)
		write_byte(0)
		write_byte(50)
		write_byte(200)
		write_byte(100)
		message_end()
	}

	g_SvFx[id] = pev(id, pev_renderfx)
	pev(id, pev_rendercolor, g_SvRgb[id])
	g_SvRm[id] = pev(id, pev_rendermode)

	new Float:amt
	pev(id, pev_renderamt, amt)
	g_SvAmt[id] = amt

	pev(id, pev_gravity, g_svGrav[id])

	shlGlow(id)

	if(pev(id, pev_flags) & FL_ONGROUND)
		set_pev(id, pev_gravity, GRAVITY_HIGH_FL)
	else
		set_pev(id, pev_gravity, GRAVITY_NONE_FL)

	remove_task(id + TASK_FRZ_RM)
	remove_task(id + TASK_CURE)

	set_task(get_pcvar_float(g_cvDur), "TaskUnfreeze", id + TASK_FRZ_RM)
	set_task(0.25, "CurePoll", id + TASK_CURE, _, _, "b")

	bh_frost_set_maxspeed(id, 1.0)
}

stock shlGlow(ent)
{
	static Float:rgb[3]
	rgb[0] = 0.0
	rgb[1] = 100.0
	rgb[2] = 200.0

	set_pev(ent, pev_renderfx, kRenderFxGlowShell)
	set_pev(ent, pev_rendercolor, rgb)
	set_pev(ent, pev_rendermode, kRenderNormal)
	set_pev(ent, pev_renderamt, 25.0)
}

public H_TakeDamage(victim, inflictor, attacker, Float:damage, damage_type)
{
	if(damage <= 0.0)
		return HAM_IGNORED

	if(!is_user_connected(attacker) || !is_user_alive(attacker))
		return HAM_IGNORED

	if(victim != attacker && HasFrost(victim))
		return HAM_SUPERCEDE

	return HAM_IGNORED
}

public H_TraceAttack(victim, attacker, Float:flDamage, Float:vecDir[3], ptr, dmg_bits)
{
	if(is_user_alive(attacker) && victim != attacker && HasFrost(victim))
		return HAM_SUPERCEDE

	return HAM_IGNORED
}

public H_Killed(id)
{
	remove_task(id + TASK_CURE)

	if(HasFrost(id))
		BHUnfreeze(id, false)
}

public H_PreThink(id)
{
	if(!is_user_alive(id) || !HasFrost(id))
		return

	bh_frost_set_maxspeed(id, 1.0)

	static Float:zero[3]
	zero[0] = 0.0
	zero[1] = 0.0
	zero[2] = 0.0
	set_pev(id, pev_velocity, zero)
}

public H_SetModel(ent, const model[])
{
	if(!pev_valid(ent) || !bh_is_flashbang_model(model))
		return FMRES_IGNORED

	static Float:dmgTime
	pev(ent, pev_dmgtime, dmgTime)
	if(dmgTime == 0.0)
		return FMRES_IGNORED

	new oid = pev(ent, pev_owner)
	if(oid < 1 || oid > g_mp || !is_user_alive(oid) || is_user_zombie(oid))
		return FMRES_IGNORED

	shlGlow(ent)

	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_BEAMFOLLOW)
	write_short(ent)
	write_short(g_idTrail)
	write_byte(10)
	write_byte(10)
	write_byte(0)
	write_byte(100)
	write_byte(200)
	write_byte(200)
	message_end()

	set_pev(ent, PEV_NADE_TYPE, NADE_FRZ)

	return FMRES_IGNORED
}

public H_GrenThink(ent)
{
	if(!pev_valid(ent))
		return HAM_IGNORED

	static Float:t
	pev(ent, pev_dmgtime, t)

	if(t > get_gametime())
		return HAM_IGNORED

	if(!bh_ent_is_frost_nade(ent))
		return HAM_IGNORED

	static Float:o[3]
	pev(ent, pev_origin, o)

	bh_frost_kill_beam(ent)
	frost_blast(o)
	emit_sound(ent, CHAN_WEAPON, SND_EXP, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	frost_freeze_in_radius(o)

	engfunc(EngFunc_RemoveEntity, ent)

	return HAM_SUPERCEDE
}

stock frost_freeze_in_radius(const Float:origin[3])
{
	static Float:player_origin[3]
	static id

	for(id = 1; id <= g_mp; id++)
	{
		if(!is_user_alive(id) || !is_user_zombie(id))
			continue

		pev(id, pev_origin, player_origin)

		if(get_distance_f(origin, player_origin) > NADE_RADIUS)
			continue

		FreezeStart(id)
	}
}

stock bool:bh_ent_is_frost_nade(ent)
{
	if(pev(ent, PEV_NADE_TYPE) == NADE_FRZ)
		return true

	static model[64]
	pev(ent, pev_model, model, charsmax(model))

	if(!bh_is_flashbang_model(model))
		return false

	new oid = pev(ent, pev_owner)

	if(oid < 1 || oid > g_mp || !is_user_connected(oid) || is_user_zombie(oid))
		return false

	return true
}

stock frost_blast(const Float:origin[3])
{
	frost_blast_ring(origin, 385.0)
	frost_blast_ring(origin, 470.0)
	frost_blast_ring(origin, 555.0)
}

stock frost_blast_ring(const Float:origin[3], Float:zRaise)
{
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, origin, 0)
	write_byte(TE_BEAMCYLINDER)
	engfunc(EngFunc_WriteCoord, origin[0])
	engfunc(EngFunc_WriteCoord, origin[1])
	engfunc(EngFunc_WriteCoord, origin[2])
	engfunc(EngFunc_WriteCoord, origin[0])
	engfunc(EngFunc_WriteCoord, origin[1])
	engfunc(EngFunc_WriteCoord, origin[2] + zRaise)
	write_short(g_idRing)
	write_byte(0)
	write_byte(0)
	write_byte(4)
	write_byte(60)
	write_byte(0)
	write_byte(0)
	write_byte(100)
	write_byte(200)
	write_byte(200)
	write_byte(0)
	message_end()
}
