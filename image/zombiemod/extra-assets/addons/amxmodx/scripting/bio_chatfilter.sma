/*
 * [BH] Chat profanity filter — mute + temp ban on blocked words (case-insensitive).
 * Word list: addons/amxmodx/configs/bh_chatfilter_words.ini
 */
#include <amxmodx>
#include <amxmisc>

#define PLUGIN "[BH] Chat filter"
#define VERSION "1.2"
#define AUTHOR "cs16docker"

#define MAX_WORDS 64
#define WORD_LEN 32

new g_words[MAX_WORDS][WORD_LEN + 1]
new g_word_count
new g_muted[33]

new cvar_enable, cvar_ban, cvar_ban_minutes, cvar_mute, cvar_admin_exempt
new g_ban_reason[96]

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)

	cvar_enable = register_cvar("bh_chatfilter_enable", "1")
	cvar_ban = register_cvar("bh_chatfilter_ban", "1")
	cvar_ban_minutes = register_cvar("bh_chatfilter_ban_minutes", "1")
	cvar_mute = register_cvar("bh_chatfilter_mute", "1")
	cvar_admin_exempt = register_cvar("bh_chatfilter_admin_exempt", "1")
	register_cvar("bh_chatfilter_ban_reason", "Banned: inappropriate language")

	register_clcmd("say", "cmd_say")
	register_clcmd("say_team", "cmd_say_team")
}

public plugin_cfg()
{
	get_cvar_string("bh_chatfilter_ban_reason", g_ban_reason, charsmax(g_ban_reason))
	filter_load_words()
}

public client_disconnected(id)
{
	g_muted[id] = 0
}

public cmd_say(id)
{
	return filter_check_chat(id)
}

public cmd_say_team(id)
{
	return filter_check_chat(id)
}

stock filter_check_chat(id)
{
	if (!get_pcvar_num(cvar_enable) || !is_user_connected(id))
		return PLUGIN_CONTINUE

	if (is_user_bot(id) || is_user_hltv(id))
		return PLUGIN_CONTINUE

	if (get_pcvar_num(cvar_admin_exempt) && (get_user_flags(id) & ADMIN_IMMUNITY))
		return PLUGIN_CONTINUE

	new said[160]
	read_args(said, charsmax(said))
	remove_quotes(said)
	trim(said)

	if (!said[0])
		return PLUGIN_CONTINUE

	if (g_muted[id])
	{
		client_print(id, print_chat, "[Chat] You are muted.")
		return PLUGIN_HANDLED
	}

	new hit[WORD_LEN + 1]

	if (!filter_has_bad_word(said, hit, charsmax(hit)))
		return PLUGIN_CONTINUE

	if (get_pcvar_num(cvar_mute))
		g_muted[id] = 1

	client_print(id, print_chat, "[Chat] Inappropriate language is not allowed.")
	log_amx("CHATFILTER: #%d <%s> matched '%s'", get_user_userid(id), said, hit)

	if (get_pcvar_num(cvar_ban))
		set_task(0.2, "filter_ban_player", id)

	return PLUGIN_HANDLED
}

public filter_ban_player(id)
{
	if (!is_user_connected(id))
		return

	new minutes = get_pcvar_num(cvar_ban_minutes)

	if (minutes < 1)
		minutes = 1

	new authid[32], ip[16], name[32]
	new userid = get_user_userid(id)

	get_user_authid(id, authid, charsmax(authid))
	get_user_ip(id, ip, charsmax(ip), 1)
	get_user_name(id, name, charsmax(name))

	client_print(id, print_chat, "[Chat] You have been temporarily banned for %d minute(s).", minutes)

	if (filter_authid_bannable(authid))
		server_cmd("banid %d #%d", minutes, userid)

	server_cmd("addip %d %s", minutes, ip)
	server_cmd("writeid")
	server_cmd("writeip")
	server_cmd("kick #%d ^"%s^"", userid, g_ban_reason)
	server_exec()

	log_amx("CHATFILTER BAN: %s <%s> <%s> %d min", name, authid, ip, minutes)
}

stock bool:filter_authid_bannable(const authid[])
{
	if (!authid[0])
		return false

	if (equal(authid, "STEAM_ID_LAN") || equal(authid, "VALVE_ID_LAN")
		|| equal(authid, "STEAM_ID_PENDING") || equal(authid, "VALVE_ID_PENDING")
		|| equal(authid, "BOT"))
		return false

	return true
}

stock filter_load_words()
{
	g_word_count = 0

	new path[192], line[WORD_LEN + 1]
	get_configsdir(path, charsmax(path))
	format(path, charsmax(path), "%s/bh_chatfilter_words.ini", path)

	new fp = fopen(path, "r")

	if (!fp)
	{
		log_amx("[BH Chat filter] Could not open %s", path)
		return
	}

	while (!feof(fp) && g_word_count < MAX_WORDS)
	{
		line[0] = 0

		if (!fgets(fp, line, charsmax(line)))
			break

		trim(line)

		if (!line[0] || line[0] == ';')
			continue

		new cut = contain(line, "//")

		if (cut != -1)
			line[cut] = 0

		trim(line)

		if (!line[0])
			continue

		copy(g_words[g_word_count], WORD_LEN, line)
		g_word_count++
	}

	fclose(fp)
	log_amx("[BH Chat filter] Loaded %d word(s)", g_word_count)
}

stock filter_has_bad_word(const msg[], hit[], hitLen)
{
	if (g_word_count < 1)
		return 0

	static padded[168]
	formatex(padded, charsmax(padded), " %s ", msg)

	static token[WORD_LEN + 4]

	for (new i = 0; i < g_word_count; i++)
	{
		formatex(token, charsmax(token), " %s ", g_words[i])

		if (containi(padded, token) != -1)
		{
			copy(hit, hitLen, g_words[i])
			return 1
		}
	}

	return 0
}
