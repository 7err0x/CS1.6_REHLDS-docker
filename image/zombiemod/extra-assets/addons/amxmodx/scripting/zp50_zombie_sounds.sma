/*
 * Biohazard port of [ZP] Zombie Sounds (Zombie Plague 5.0.8).
 * GPL — original by ZP Dev Team. Upstream: Gam3ronE/ZP zp50_zombie_sounds.sma
 *
 * Replaces knife/pain/die/fall sounds for zombies and plays periodic idle taunts
 * (Nihilanth + zombie_plague/zombie_brains from stock ZP defaults).
 */
#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>

#tryinclude <biohazard>

#if !defined _biohazard_included
#error Add addons/amxmodx/scripting/include/biohazard.inc when compiling.
#endif

#define PLUGIN_NAME "[BH] zp50-derived Zombie Sounds"
#define PLUGIN_VERS "1.0"
#define PLUGIN_AUTH "ZP Dev Team / BH port"

#define TASK_IDLE_SOUNDS 100
#define ID_IDLE_SOUNDS (taskid - TASK_IDLE_SOUNDS)

#define SOUND_MAX_LENGTH 64

new const sound_zombie_pain[][] =
{
	"zombie_plague/zombie_pain1.wav",
	"zombie_plague/zombie_pain2.wav",
	"zombie_plague/zombie_pain3.wav",
	"zombie_plague/zombie_pain4.wav",
	"zombie_plague/zombie_pain5.wav"
}

new const sound_zombie_die[][] =
{
	"zombie_plague/zombie_die1.wav",
	"zombie_plague/zombie_die2.wav",
	"zombie_plague/zombie_die3.wav",
	"zombie_plague/zombie_die4.wav",
	"zombie_plague/zombie_die5.wav"
}

new const sound_zombie_fall[][] = { "zombie_plague/zombie_fall1.wav" }

new const sound_zombie_miss_slash[][] =
{
	"weapons/knife_slash1.wav",
	"weapons/knife_slash2.wav"
}

new const sound_zombie_miss_wall[][] = { "weapons/knife_hitwall1.wav" }

new const sound_zombie_hit_normal[][] =
{
	"weapons/knife_hit1.wav",
	"weapons/knife_hit2.wav",
	"weapons/knife_hit3.wav",
	"weapons/knife_hit4.wav"
}

new const sound_zombie_hit_stab[][] = { "weapons/knife_stab.wav" }

new const sound_zombie_idle[][] =
{
	"nihilanth/nil_now_die.wav",
	"nihilanth/nil_slaves.wav",
	"nihilanth/nil_alone.wav",
	"zombie_plague/zombie_brains1.wav",
	"zombie_plague/zombie_brains2.wav"
}

new const sound_zombie_idle_last[][] = { "nihilanth/nil_thelast.wav" }

new g_mp
new g_cvPain, g_cvAttack, g_cvIdle

public plugin_precache()
{
	new i

	for (i = 0; i < sizeof sound_zombie_pain; i++)
		precache_sound(sound_zombie_pain[i])

	for (i = 0; i < sizeof sound_zombie_die; i++)
		precache_sound(sound_zombie_die[i])

	for (i = 0; i < sizeof sound_zombie_fall; i++)
		precache_sound(sound_zombie_fall[i])

	for (i = 0; i < sizeof sound_zombie_miss_slash; i++)
		precache_sound(sound_zombie_miss_slash[i])

	for (i = 0; i < sizeof sound_zombie_miss_wall; i++)
		precache_sound(sound_zombie_miss_wall[i])

	for (i = 0; i < sizeof sound_zombie_hit_normal; i++)
		precache_sound(sound_zombie_hit_normal[i])

	for (i = 0; i < sizeof sound_zombie_hit_stab; i++)
		precache_sound(sound_zombie_hit_stab[i])

	for (i = 0; i < sizeof sound_zombie_idle; i++)
		precache_sound(sound_zombie_idle[i])

	for (i = 0; i < sizeof sound_zombie_idle_last; i++)
		precache_sound(sound_zombie_idle_last[i])

	// knife_* / weapons/* already precached by engine; nihilanth/* lives in valve/
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

	register_forward(FM_EmitSound, "fw_EmitSound")
	RegisterHam(Ham_Killed, "player", "fw_PlayerKilled")

	g_cvPain = register_cvar("zp_zombie_sounds_pain", "1")
	g_cvAttack = register_cvar("zp_zombie_sounds_attack", "1")
	g_cvIdle = register_cvar("zp_zombie_sounds_idle", "1")
}

public client_disconnected(id)
{
	remove_task(id + TASK_IDLE_SOUNDS)
}

public event_infect(victim, attacker)
{
	remove_task(victim + TASK_IDLE_SOUNDS)

	if (!get_pcvar_num(g_cvIdle))
		return

	set_task(random_float(50.0, 70.0), "zombie_idle_sounds", victim + TASK_IDLE_SOUNDS, _, _, "b")
}

public fw_PlayerKilled(victim)
{
	remove_task(victim + TASK_IDLE_SOUNDS)
}

public fw_EmitSound(id, channel, const sample[], Float:volume, Float:attn, flags, pitch)
{
	if (!is_user_connected(id) || !is_user_zombie(id))
		return FMRES_IGNORED

	static sound[SOUND_MAX_LENGTH]

	if (get_pcvar_num(g_cvPain))
	{
		if (sample[7] == 'b' && sample[8] == 'h' && sample[9] == 'i' && sample[10] == 't')
		{
			copy(sound, charsmax(sound), sound_zombie_pain[random_num(0, sizeof sound_zombie_pain - 1)])
			emit_sound(id, channel, sound, volume, attn, flags, pitch)
			return FMRES_SUPERCEDE
		}

		if (sample[7] == 'd' && ((sample[8] == 'i' && sample[9] == 'e') || (sample[8] == 'e' && sample[9] == 'a')))
		{
			copy(sound, charsmax(sound), sound_zombie_die[random_num(0, sizeof sound_zombie_die - 1)])
			emit_sound(id, channel, sound, volume, attn, flags, pitch)
			return FMRES_SUPERCEDE
		}

		if (sample[10] == 'f' && sample[11] == 'a' && sample[12] == 'l' && sample[13] == 'l')
		{
			copy(sound, charsmax(sound), sound_zombie_fall[random_num(0, sizeof sound_zombie_fall - 1)])
			emit_sound(id, channel, sound, volume, attn, flags, pitch)
			return FMRES_SUPERCEDE
		}
	}

	if (get_pcvar_num(g_cvAttack))
	{
		if (sample[8] == 'k' && sample[9] == 'n' && sample[10] == 'i')
		{
			if (sample[14] == 's' && sample[15] == 'l' && sample[16] == 'a')
			{
				copy(sound, charsmax(sound), sound_zombie_miss_slash[random_num(0, sizeof sound_zombie_miss_slash - 1)])
				emit_sound(id, channel, sound, volume, attn, flags, pitch)
				return FMRES_SUPERCEDE
			}

			if (sample[14] == 'h' && sample[15] == 'i' && sample[16] == 't')
			{
				if (sample[17] == 'w')
				{
					copy(sound, charsmax(sound), sound_zombie_miss_wall[random_num(0, sizeof sound_zombie_miss_wall - 1)])
					emit_sound(id, channel, sound, volume, attn, flags, pitch)
					return FMRES_SUPERCEDE
				}

				copy(sound, charsmax(sound), sound_zombie_hit_normal[random_num(0, sizeof sound_zombie_hit_normal - 1)])
				emit_sound(id, channel, sound, volume, attn, flags, pitch)
				return FMRES_SUPERCEDE
			}

			if (sample[14] == 's' && sample[15] == 't' && sample[16] == 'a')
			{
				copy(sound, charsmax(sound), sound_zombie_hit_stab[random_num(0, sizeof sound_zombie_hit_stab - 1)])
				emit_sound(id, channel, sound, volume, attn, flags, pitch)
				return FMRES_SUPERCEDE
			}
		}
	}

	return FMRES_IGNORED
}

public zombie_idle_sounds(taskid)
{
	new id = ID_IDLE_SOUNDS

	if (!is_user_connected(id) || !is_user_alive(id) || !is_user_zombie(id))
	{
		remove_task(taskid)
		return
	}

	static sound[SOUND_MAX_LENGTH]

	if (bh_is_last_zombie(id))
		copy(sound, charsmax(sound), sound_zombie_idle_last[random_num(0, sizeof sound_zombie_idle_last - 1)])
	else
		copy(sound, charsmax(sound), sound_zombie_idle[random_num(0, sizeof sound_zombie_idle - 1)])

	emit_sound(id, CHAN_VOICE, sound, 1.0, ATTN_NORM, 0, PITCH_NORM)
}

stock bool:bh_is_last_zombie(id)
{
	if (!is_user_zombie(id))
		return false

	new count, i

	for (i = 1; i <= g_mp; i++)
	{
		if (is_user_alive(i) && is_user_zombie(i))
			count++
	}

	return count <= 1
}
