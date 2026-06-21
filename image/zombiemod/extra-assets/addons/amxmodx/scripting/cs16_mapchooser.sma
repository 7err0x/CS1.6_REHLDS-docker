// Stock mapchooser fork: 5 random maps from maps.ini pool; vote duration from amx_vote_time.
#include <amxmodx>
#include <amxmisc>
#include <cstrike>

#define PLUGIN "CS16 Mapchooser"
#define VERSION "1.1"
#define AUTHOR "cs16docker"

#define SELECTMAPS 5
#define TASK_VOTE_END 87654
#define TASK_VOTE_POLL 987456

new Array:g_mapName
new g_mapNums

new g_nextName[SELECTMAPS]
new g_voteCount[SELECTMAPS + 2]
new g_mapVoteNum
new g_voteDuration
new g_teamScore[2]
new g_lastMap[32]

new bool:g_selected = false

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	register_dictionary("mapchooser.txt")
	register_dictionary("common.txt")

	g_mapName = ArrayCreate(32)

	new MenuName[64]
	format(MenuName, charsmax(MenuName), "%L", "en", "CHOOSE_NEXTM")
	register_menucmd(register_menuid(MenuName), (-1 ^ (-1 << (SELECTMAPS + 2))), "countVote")

	register_cvar("amx_extendmap_max", "90")
	register_cvar("amx_extendmap_step", "15")
	register_cvar("amx_vote_time", "45")

	register_event("TeamScore", "team_score", "a")

	get_localinfo("lastMap", g_lastMap, charsmax(g_lastMap))
	set_localinfo("lastMap", "")

	new maps_ini_file[64]
	get_configsdir(maps_ini_file, charsmax(maps_ini_file))
	format(maps_ini_file, charsmax(maps_ini_file), "%s/maps.ini", maps_ini_file)

	if (!file_exists(maps_ini_file))
		get_cvar_string("mapcyclefile", maps_ini_file, charsmax(maps_ini_file))

	if (loadSettings(maps_ini_file))
		set_task(15.0, "voteNextmap", TASK_VOTE_POLL, "", 0, "b")
}

public checkVotes()
{
	new b = 0

	for (new a = 0; a < g_mapVoteNum; ++a)
	{
		if (g_voteCount[b] < g_voteCount[a])
			b = a
	}

	if (g_voteCount[SELECTMAPS] > g_voteCount[b]
		&& g_voteCount[SELECTMAPS] > g_voteCount[SELECTMAPS + 1])
	{
		new mapname[32]
		get_mapname(mapname, charsmax(mapname))
		new Float:steptime = get_cvar_float("amx_extendmap_step")
		set_cvar_float("mp_timelimit", get_cvar_float("mp_timelimit") + steptime)
		client_print(0, print_chat, "%L", LANG_PLAYER, "CHO_FIN_EXT", steptime)
		log_amx("Vote: Voting for the nextmap finished. Map %s will be extended to next %.0f minutes", mapname, steptime)
		return
	}

	new smap[32]
	if (g_voteCount[b] && g_voteCount[SELECTMAPS + 1] <= g_voteCount[b])
	{
		ArrayGetString(g_mapName, g_nextName[b], smap, charsmax(smap))
		set_cvar_string("amx_nextmap", smap)
	}

	get_cvar_string("amx_nextmap", smap, charsmax(smap))
	client_print(0, print_chat, "%L", LANG_PLAYER, "CHO_FIN_NEXT", smap)
	log_amx("Vote: Voting for the nextmap finished. The nextmap will be %s", smap)
}

public countVote(id, key)
{
	if (get_cvar_float("amx_vote_answers"))
	{
		new name[MAX_NAME_LENGTH]
		get_user_name(id, name, charsmax(name))

		if (key == SELECTMAPS)
			client_print(0, print_chat, "%L", LANG_PLAYER, "CHOSE_EXT", name)
		else if (key < SELECTMAPS)
		{
			new map[32]
			ArrayGetString(g_mapName, g_nextName[key], map, charsmax(map))
			client_print(0, print_chat, "%L", LANG_PLAYER, "X_CHOSE_X", name, map)
		}
	}

	++g_voteCount[key]
	return PLUGIN_HANDLED
}

bool:isInMenu(id)
{
	for (new a = 0; a < g_mapVoteNum; ++a)
	{
		if (id == g_nextName[a])
			return true
	}

	return false
}

public voteNextmap()
{
	new winlimit = get_cvar_num("mp_winlimit")
	new maxrounds = get_cvar_num("mp_maxrounds")

	if (winlimit)
	{
		new c = winlimit - 2

		if ((c > g_teamScore[0]) && (c > g_teamScore[1]))
		{
			g_selected = false
			return
		}
	}
	else if (maxrounds)
	{
		if ((maxrounds - 2) > (g_teamScore[0] + g_teamScore[1]))
		{
			g_selected = false
			return
		}
	}
	else
	{
		new timeleft = get_timeleft()

		if (timeleft < 1 || timeleft > 129)
		{
			g_selected = false
			return
		}
	}

	if (g_selected)
		return

	g_selected = true
	remove_task(TASK_VOTE_END)

	g_voteDuration = floatround(get_cvar_float("amx_vote_time"))
	if (g_voteDuration < 5)
		g_voteDuration = 45

	new menu[512], pos = 0, mkeys = 0
	new dmax = (g_mapNums > SELECTMAPS) ? SELECTMAPS : g_mapNums

	for (g_mapVoteNum = 0; g_mapVoteNum < dmax; ++g_mapVoteNum)
	{
		new a = random_num(0, g_mapNums - 1)

		while (isInMenu(a))
		{
			if (++a >= g_mapNums)
				a = 0
		}

		g_nextName[g_mapVoteNum] = a
		pos += format(menu[pos], charsmax(menu) - pos, "%d. %a^n", g_mapVoteNum + 1, ArrayGetStringHandle(g_mapName, a))
		mkeys |= (1 << g_mapVoteNum)
		g_voteCount[g_mapVoteNum] = 0
	}

	menu[pos++] = '^n'
	g_voteCount[SELECTMAPS] = 0
	g_voteCount[SELECTMAPS + 1] = 0

	new mapname[32]
	get_mapname(mapname, charsmax(mapname))

	if ((winlimit + maxrounds) == 0 && (get_cvar_float("mp_timelimit") < get_cvar_float("amx_extendmap_max")))
	{
		pos += format(menu[pos], charsmax(menu) - pos, "%d. %L^n", SELECTMAPS + 1, LANG_SERVER, "EXTED_MAP", mapname)
		mkeys |= (1 << SELECTMAPS)
	}

	format(menu[pos], charsmax(menu), "%d. %L", SELECTMAPS + 2, LANG_SERVER, "NONE")

	new MenuName[64]
	format(MenuName, charsmax(MenuName), "%L", "en", "CHOOSE_NEXTM")
	show_menu(0, mkeys, menu, g_voteDuration, MenuName)

	set_task(float(g_voteDuration), "checkVotes", TASK_VOTE_END)
	client_print(0, print_chat, "%L", LANG_SERVER, "TIME_CHOOSE")
	client_cmd(0, "spk Gman/Gman_Choose2")
	log_amx("Vote: Voting for the nextmap started (%d random maps, %d seconds)", g_mapVoteNum, g_voteDuration)
}

stock bool:ValidMap(mapname[])
{
	if (is_map_valid(mapname))
		return true

	new len = strlen(mapname) - 4

	if (len < 0)
		return false

	if (equali(mapname[len], ".bsp"))
	{
		mapname[len] = '^0'

		if (is_map_valid(mapname))
			return true
	}

	return false
}

loadSettings(filename[])
{
	if (!file_exists(filename))
		return 0

	new szText[32]
	new currentMap[32]
	new buff[256]

	get_mapname(currentMap, charsmax(currentMap))

	new fp = fopen(filename, "r")

	while (!feof(fp))
	{
		buff[0] = '^0'

		if (!fgets(fp, buff, charsmax(buff)))
			break

		szText[0] = '^0'
		parse(buff, szText, charsmax(szText))

		if (szText[0] != ';'
			&& ValidMap(szText)
			&& !equali(szText, g_lastMap)
			&& !equali(szText, currentMap))
		{
			ArrayPushString(g_mapName, szText)
			++g_mapNums
		}
	}

	fclose(fp)
	return g_mapNums
}

public team_score()
{
	new team[2]
	read_data(1, team, charsmax(team))
	g_teamScore[(team[0] == 'C') ? 0 : 1] = read_data(2)
}

public plugin_end()
{
	new current_map[32]
	get_mapname(current_map, charsmax(current_map))
	set_localinfo("lastMap", current_map)
	ArrayDestroy(g_mapName)
}
