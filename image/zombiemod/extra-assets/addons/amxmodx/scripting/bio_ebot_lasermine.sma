/**
 * Human E-BOT lasermine placement for Biohazard.
 * Uses +setlaser / -setlaser client commands while bots defend chokepoints.
 */
#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <engine>
#include <fakemeta>
#include <biohazard>

#define PLUGIN "Bio E-BOT Lasermine"
#define VERSION "1.0"
#define AUTHOR "cs16docker"

#define TASK_PLANT_BASE 91000

new g_cvar_enable
new g_cvar_chance
new g_cvar_interval
new g_cvar_hold
new g_cvar_min_speed

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)

	g_cvar_enable = register_cvar("bh_ebot_lasermine", "1")
	g_cvar_chance = register_cvar("bh_ebot_lasermine_chance", "40")
	g_cvar_interval = register_cvar("bh_ebot_lasermine_interval", "22.0")
	g_cvar_hold = register_cvar("bh_ebot_lasermine_hold", "0.55")
	g_cvar_min_speed = register_cvar("bh_ebot_lasermine_max_speed", "18.0")

	set_task(12.0, "task_schedule_plants", 0, _, _, "b")
}

public task_schedule_plants()
{
	if (!get_pcvar_num(g_cvar_enable) || !game_started())
		return

	static id
	for (id = 1; id <= get_maxplayers(); id++)
	{
		if (!is_user_connected(id) || !is_user_alive(id) || !is_user_bot(id))
			continue

		if (is_user_zombie(id))
			continue

		if (task_exists(TASK_PLANT_BASE + id))
			continue

		if (random_num(1, 100) > get_pcvar_num(g_cvar_chance))
			continue

		if (!ebot_lasermine_can_plant(id))
			continue

		set_task(get_pcvar_float(g_cvar_interval) * random_float(0.15, 0.85), "task_try_plant", TASK_PLANT_BASE + id)
	}
}

public task_try_plant(taskid)
{
	new id = taskid - TASK_PLANT_BASE

	if (!is_user_connected(id) || !is_user_alive(id) || !is_user_bot(id) || is_user_zombie(id))
		return

	if (!ebot_lasermine_can_plant(id))
		return

	new Float:angles[3]
	pev(id, pev_angles, angles)
	angles[0] = 0.0

	new Float:origin[3], Float:end[3], Float:wall[3]
	pev(id, pev_origin, origin)
	origin[2] += 17.0

	angle_vector(angles, ANGLEVECTOR_FORWARD, end)
	end[0] = origin[0] + end[0] * 72.0
	end[1] = origin[1] + end[1] * 72.0
	end[2] = origin[2] + end[2] * 72.0

	if (!ebot_lasermine_find_wall(origin, end, wall))
	{
		angle_vector(angles, ANGLEVECTOR_RIGHT, end)
		end[0] = origin[0] + end[0] * 56.0
		end[1] = origin[1] + end[1] * 56.0
		end[2] = origin[2]

		if (!ebot_lasermine_find_wall(origin, end, wall))
			return
	}

	new Float:look[3]
	look[0] = wall[0]
	look[1] = wall[1]
	look[2] = wall[2]
	look[0] += (wall[0] - origin[0]) * 0.25
	look[1] += (wall[1] - origin[1]) * 0.25

	set_pev(id, pev_angles, angles)
	set_pev(id, pev_fixangle, 1)
	engfunc(EngFunc_SetOrigin, id, origin)

	client_cmd(id, "+setlaser")
	set_task(get_pcvar_float(g_cvar_hold), "task_release_laser", TASK_PLANT_BASE + id + 1000)
}

public task_release_laser(taskid)
{
	new id = taskid - TASK_PLANT_BASE - 1000

	if (is_user_connected(id))
		client_cmd(id, "-setlaser")
}

stock bool:ebot_lasermine_can_plant(id)
{
	if (!game_started())
		return false

	new Float:velocity[3]
	pev(id, pev_velocity, velocity)

	if (vector_length(velocity) > get_pcvar_float(g_cvar_min_speed))
		return false

	new Float:origin[3]
	pev(id, pev_origin, origin)

	static enemy, Float:enemyOrigin[3]
	enemy = -1

	for (new i = 1; i <= get_maxplayers(); i++)
	{
		if (!is_user_connected(i) || !is_user_alive(i) || i == id)
			continue

		if (!is_user_zombie(i))
			continue

		pev(i, pev_origin, enemyOrigin)
		if (get_distance_f(origin, enemyOrigin) < 520.0)
		{
			enemy = i
			break
		}
	}

	return enemy != -1
}

stock bool:ebot_lasermine_find_wall(const Float:start[3], const Float:end[3], Float:hit[3])
{
	engfunc(EngFunc_TraceLine, start, end, DONT_IGNORE_MONSTERS, -1, 0)

	new Float:fraction
	get_tr2(0, TR_flFraction, fraction)

	if (fraction >= 0.98)
		return false

	get_tr2(0, TR_vecEndPos, hit)
	return true
}
