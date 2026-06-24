/*
 * [BH] /skip — player vote to restart the current round (sv_restart 1).
 */
#include <amxmodx>
#include <amxmisc>

#define PLUGIN "[BH] Skip vote"
#define VERSION "1.0"
#define AUTHOR "cs16docker"

#define TASK_VOTE_END 77441
#define MENU_KEYS (MENU_KEY_1|MENU_KEY_2)

new const g_menu_title[] = "\ySkip this round?^n\w1. Yes^n2. No^n^n\r0. Exit"

new bool:g_vote_active
new g_vote_yes
new g_vote_no
new g_vote_choice[33]
new Float:g_vote_cooldown_until
new Float:g_vote_deadline
new g_menu_id

new cvar_enable, cvar_duration, cvar_percent, cvar_cooldown

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)

	cvar_enable = register_cvar("bh_skipvote_enable", "1")
	cvar_duration = register_cvar("bh_skipvote_duration", "15")
	cvar_percent = register_cvar("bh_skipvote_percent", "51")
	cvar_cooldown = register_cvar("bh_skipvote_cooldown", "60")

	g_menu_id = register_menuid("BHSkipRoundMenu")
	register_menucmd(g_menu_id, MENU_KEYS, "skip_menu_handler")

	register_clcmd("say /skip", "cmd_skip")
	register_clcmd("say_team /skip", "cmd_skip")

	register_logevent("skip_on_round_end", 2, "1=Round_End")
}

public skip_on_round_end()
{
	if (!g_vote_active)
		return

	remove_task(TASK_VOTE_END)
	g_vote_active = false
	skip_reset_choices()
}

public client_disconnected(id)
{
	skip_remove_vote(id)
}

public cmd_skip(id)
{
	if (!get_pcvar_num(cvar_enable) || !skip_eligible(id))
		return PLUGIN_HANDLED

	if (g_vote_active)
	{
		new remaining = floatround(g_vote_deadline - get_gametime())

		if (remaining < 0)
			remaining = 0

		client_print(id, print_chat, "[Skip] Vote in progress: %d yes, %d no (%d sec left).",
			g_vote_yes, g_vote_no, remaining)
		return PLUGIN_HANDLED
	}

	if (get_gametime() < g_vote_cooldown_until)
	{
		client_print(id, print_chat, "[Skip] Please wait %d seconds before starting another vote.",
			floatround(g_vote_cooldown_until - get_gametime()))
		return PLUGIN_HANDLED
	}

	new eligible = skip_count_eligible()

	if (eligible < 1)
	{
		client_print(id, print_chat, "[Skip] No players available to vote.")
		return PLUGIN_HANDLED
	}

	skip_begin_vote(id)
	return PLUGIN_HANDLED
}

public skip_menu_handler(id, key)
{
	if (!g_vote_active || !skip_eligible(id))
		return PLUGIN_HANDLED

	if (key >= 2)
		return PLUGIN_HANDLED

	skip_set_vote(id, key + 1)
	return PLUGIN_HANDLED
}

public skip_end_vote()
{
	if (!g_vote_active)
		return

	g_vote_active = false

	new eligible = skip_count_eligible()
	new percent = get_pcvar_num(cvar_percent)

	if (percent < 1)
		percent = 1
	else if (percent > 100)
		percent = 100

	new required = (eligible * percent) / 100

	if (required < 1)
		required = 1

	if (g_vote_yes >= required && g_vote_yes > g_vote_no)
	{
		client_print(0, print_chat, "[Skip] Vote passed (%d yes, %d no). Restarting round...", g_vote_yes, g_vote_no)
		log_amx("SKIPVOTE: passed (%d yes, %d no, %d eligible)", g_vote_yes, g_vote_no, eligible)
		server_cmd("sv_restart 1")
		server_exec()
	}
	else
	{
		client_print(0, print_chat, "[Skip] Vote failed (%d yes, %d no; need %d yes at %d%%).",
			g_vote_yes, g_vote_no, required, percent)
		log_amx("SKIPVOTE: failed (%d yes, %d no, need %d)", g_vote_yes, g_vote_no, required)
	}

	g_vote_cooldown_until = get_gametime() + float(get_pcvar_num(cvar_cooldown))
	skip_reset_choices()
}

stock skip_begin_vote(initiator)
{
	skip_reset_choices()
	g_vote_active = true

	new name[MAX_NAME_LENGTH]
	get_user_name(initiator, name, charsmax(name))

	new duration = get_pcvar_num(cvar_duration)

	if (duration < 5)
		duration = 5
	else if (duration > 60)
		duration = 60

	client_print(0, print_chat, "[Skip] %s started a vote to skip the round. Choose Yes or No.", name)
	skip_show_menu_all(duration)
	g_vote_deadline = get_gametime() + float(duration)
	set_task(float(duration), "skip_end_vote", TASK_VOTE_END)
}

stock skip_show_menu_all(duration)
{
	new id

	for (id = 1; id <= get_maxplayers(); id++)
	{
		if (!skip_eligible(id))
			continue

		show_menu(id, MENU_KEYS, g_menu_title, duration, "BHSkipRoundMenu")
	}
}

stock skip_set_vote(id, choice)
{
	if (choice != 1 && choice != 2)
		return

	if (g_vote_choice[id] == 1)
		g_vote_yes--
	else if (g_vote_choice[id] == 2)
		g_vote_no--

	g_vote_choice[id] = choice

	if (choice == 1)
		g_vote_yes++
	else
		g_vote_no++

	new name[MAX_NAME_LENGTH]
	get_user_name(id, name, charsmax(name))
	client_print(0, print_chat, "[Skip] %s voted %s.", name, choice == 1 ? "Yes" : "No")
}

stock skip_remove_vote(id)
{
	if (!g_vote_choice[id])
		return

	if (g_vote_choice[id] == 1)
		g_vote_yes--
	else if (g_vote_choice[id] == 2)
		g_vote_no--

	g_vote_choice[id] = 0
}

stock skip_reset_choices()
{
	new id

	for (id = 1; id <= get_maxplayers(); id++)
		g_vote_choice[id] = 0

	g_vote_yes = 0
	g_vote_no = 0
}

stock bool:skip_eligible(id)
{
	return is_user_connected(id) && !is_user_bot(id) && !is_user_hltv(id)
}

stock skip_count_eligible()
{
	new count, id

	for (id = 1; id <= get_maxplayers(); id++)
	{
		if (skip_eligible(id))
			count++
	}

	return count
}
