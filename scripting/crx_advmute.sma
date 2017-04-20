#include <amxmodx>
#include <amxmisc>
#include <fakemeta>

#define PLUGIN_VERSION "2.0"

new const g_szMute[] = "buttons/blip1.wav"
new const g_szUnmute[] = "buttons/button9.wav"
new const g_szPrefix[] = "!g[!tAdvanced Mute!g]!n"

enum _:Cvars
{
	advmute_adminflag,
	advmute_mutemic,
	advmute_reopen,
	advmute_sounds
}

new g_eCvars[Cvars]
new g_iFlag
new g_iSayText
new bool:g_bMuted[33][33]

new const g_szMenuCommands[][] = 
{
	"amx_mutemenu",
	"amx_chatmutemenu",
	"say /mute",
	"say_team /mute",
	"say /mutemenu",
	"say_team /mutemenu",
	"say /chatmute",
	"say_team /chatmute",
	"say /chatmutemenu",
	"say_team /chatmutemenu"
}

public plugin_init()
{
	register_plugin("Advanced Mute", PLUGIN_VERSION, "OciXCrom")
	register_cvar("AdvancedMute", PLUGIN_VERSION, FCVAR_SERVER|FCVAR_SPONLY|FCVAR_UNLOGGED)
	register_message(get_user_msgid("SayText"), "OnPlayerMessage")
	register_forward(FM_Voice_SetClientListening, "OnPlayerTalk")
	
	register_clcmd("amx_mute", "cmdMute", ADMIN_ALL, "<nick|#userid>")
	register_clcmd("amx_chatmute", "cmdMute", ADMIN_ALL, "<nick|#userid>")
	
	for(new i; i < sizeof(g_szMenuCommands); i++)
		register_clcmd(g_szMenuCommands[i], "MuteMenu")
	
	g_eCvars[advmute_adminflag] = register_cvar("advmute_adminflag", "a")
	g_eCvars[advmute_mutemic] = register_cvar("advmute_mutemic", "1")
	g_eCvars[advmute_reopen] = register_cvar("advmute_reopen", "1")
	g_eCvars[advmute_sounds] = register_cvar("advmute_sounds", "1")
	g_iSayText = get_user_msgid("SayText")
}

public plugin_precache()
{
	precache_sound(g_szMute)
	precache_sound(g_szUnmute)
}

public plugin_cfg()
{
	new szFlag[2]
	get_pcvar_string(g_eCvars[advmute_adminflag], szFlag, charsmax(szFlag))
	g_iFlag = read_flags(szFlag)
}

public OnPlayerMessage(iMsgid, iDest, iReceiver)
{
	static iSender
	iSender = get_msg_arg_int(1)	
	return get_mute(iReceiver, iSender) ? PLUGIN_HANDLED : PLUGIN_CONTINUE
}

public OnPlayerTalk(iReceiver, iSender, iListen)
{
	if(get_pcvar_num(g_eCvars[advmute_mutemic]) == 0 || iReceiver == iSender)
		return FMRES_IGNORED
		
	if(get_mute(iReceiver, iSender))
	{
		engfunc(EngFunc_SetClientListening, iReceiver, iSender, 0)
		return FMRES_SUPERCEDE
	}
	
	return FMRES_IGNORED
}

public cmdMute(id)
{
	new szArg[32]
	read_argv(1, szArg, charsmax(szArg))
	
	new iPlayer = cmd_target(id, szArg, 0)
	
	if(!iPlayer)
		return PLUGIN_HANDLED
	
	if(get_user_flags(iPlayer) & g_iFlag)
	{
		ColorChat(id, "You !tcan't !nmute this player due to his !gimmunity!n.")
		user_spksound(id, g_szUnmute)
		return PLUGIN_HANDLED
	}
	
	switch_mute(id, iPlayer)
	display_mute_message(id, iPlayer)	
	return PLUGIN_HANDLED
}

public MuteMenu(id)
{
	new iMenu = menu_create("\yChoose a player to toggle his \rmute status\y:\d", "MuteMenu_Handler")
	menu_additem(iMenu, "\yMute all players")
	menu_additem(iMenu, "\yUnmute all players")	
	
	new iPlayers[32], iPnum
	get_players(iPlayers, iPnum)
	
	for(new szItem[40], szName[32], szUserId[16], iPlayer, i; i < iPnum; i++)
	{
		iPlayer = iPlayers[i]
		
		if(get_user_flags(iPlayer) & g_iFlag)
			continue
			
		get_user_name(iPlayer, szName, charsmax(szName))
		formatex(szUserId, charsmax(szUserId), "%i", get_user_userid(iPlayer))
		formatex(szItem, charsmax(szItem), "%s%s", get_mute(id, iPlayer) ? "\r" : "", szName)
		menu_additem(iMenu, szItem, szUserId)
	}
	
	menu_setprop(iMenu, MPROP_BACKNAME, "\yNext page")
	menu_setprop(iMenu, MPROP_NEXTNAME, "\yPrevious page")
	menu_setprop(iMenu, MPROP_EXITNAME, "\yClose the \rMute Menu")
	menu_display(id, iMenu, 0)
	return PLUGIN_HANDLED
}

public MuteMenu_Handler(id, iMenu, iItem)
{
	if(iItem == MENU_EXIT)
	{
		menu_destroy(iMenu)
		return PLUGIN_HANDLED
	}
	
	new szData[16], iUnused
	menu_item_getinfo(iMenu, iItem, iUnused, szData, charsmax(szData), .callback = iUnused)
	
	new iUserId = str_to_num(szData)
	
	if(0 <= iItem <= 1)
	{
		new iPlayers[32], iPnum, bool:bMute = iItem == 0
		get_players(iPlayers, iPnum)
		
		for(new i, iPlayer; i < iPnum; i++)
		{
			iPlayer = iPlayers[i]
			
			if(get_user_flags(iPlayer) & g_iFlag)
				continue
				
			set_mute(id, iPlayer, bMute)
		}
		
		ColorChat(id, "You have !t%smuted !gall players!n.", bMute ? "" : "un")
		
		if(get_pcvar_num(g_eCvars[advmute_sounds]))
			user_spksound(id, bMute ? g_szMute : g_szUnmute)
	}
	else
	{
		new iPlayer = find_player("k", iUserId)
		
		if(iPlayer)
		{
			switch_mute(id, iPlayer)
			display_mute_message(id, iPlayer)
		}
	}
	
	menu_destroy(iMenu)
	
	if(get_pcvar_num(g_eCvars[advmute_reopen]))
		MuteMenu(id)
	
	return PLUGIN_HANDLED
}

display_mute_message(id, iPlayer)
{
	new szName[32], bool:bMute = get_mute(id, iPlayer)
	get_user_name(iPlayer, szName, charsmax(szName))
	ColorChat(id, "You have !t%smuted !g%s!n.", bMute ? "" : "un", szName)
	
	if(get_pcvar_num(g_eCvars[advmute_sounds]) == 1)
		user_spksound(id, bMute ? g_szMute : g_szUnmute)
}

set_mute(id, iPlayer, bool:bMute)
	g_bMuted[id][iPlayer] = bMute ? true : false

bool:get_mute(id, iPlayer)
	return bool:g_bMuted[id][iPlayer]

switch_mute(id, iPlayer)
	set_mute(id, iPlayer, get_mute(id, iPlayer) ? false : true)

user_spksound(id, const szSound[])
	client_cmd(id, "spk %s", szSound)

ColorChat(const id, const szInput[], any:...)
{
	new iPlayers[32], iCount = 1
	static szMessage[191]
	vformat(szMessage, charsmax(szMessage), szInput, 3)
	format(szMessage[0], charsmax(szMessage), "%s %s", g_szPrefix, szMessage)
	
	replace_all(szMessage, charsmax(szMessage), "!g", "^4")
	replace_all(szMessage, charsmax(szMessage), "!n", "^1")
	replace_all(szMessage, charsmax(szMessage), "!t", "^3")
	
	if(id)
		iPlayers[0] = id
	else
		get_players(iPlayers, iCount, "ch")
	
	for(new i; i < iCount; i++)
	{
		if(is_user_connected(iPlayers[i]))
		{
			message_begin(MSG_ONE_UNRELIABLE, g_iSayText, _, iPlayers[i])
			write_byte(iPlayers[i])
			write_string(szMessage)
			message_end()
		}
	}
}