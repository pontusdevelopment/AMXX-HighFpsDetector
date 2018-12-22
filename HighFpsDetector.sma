#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>

#pragma semicolon		1

#define PLUGIN_NAME		"High FPS Detector"
#define PLUGIN_VERSION		"1.0.0"
#define PLUGIN_AUTHOR		"Reavap"

#if !defined MAX_PLAYERS
	#define MAX_PLAYERS 32
#endif

#if !defined client_disconnected
	#define client_disconnected client_disconnect
#endif

#define MSEC_LOOKBACK	100
#define MAX_FPS		100.5

new g_iMinmumMsec;
new g_iMinimumAverageMsec;

new g_iCurrentMsecIndex[MAX_PLAYERS + 1];
new g_iLastMsecs[MAX_PLAYERS + 1][MSEC_LOOKBACK];
new g_iCachedMsecSum[MAX_PLAYERS + 1];

new bool:g_bAlive[MAX_PLAYERS + 1];
new bool:g_bKicked[MAX_PLAYERS + 1];

public plugin_init()
{
	register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);
	
	RegisterHam(Ham_Spawn, "player", "fwdHamSpawn",	1);
	RegisterHam(Ham_Killed, "player", "fwdHamKilled", 0);
	
	register_forward(FM_CmdStart, "fwdCmdStart");
	
	g_iMinmumMsec = floatround(1000 / MAX_FPS, floatround_floor);
	g_iMinimumAverageMsec = max(1, floatround((1000 * MSEC_LOOKBACK) / MAX_FPS, floatround_floor) - 1);
}

public client_putinserver(id)
{
	new iMsec = g_iMinmumMsec + 1;
	
	g_iCurrentMsecIndex[id] = 0;
	g_iCachedMsecSum[id] = MSEC_LOOKBACK * iMsec;
	
	for (new i = 0; i < MSEC_LOOKBACK; i++)
	{
		g_iLastMsecs[id][i] = iMsec;
	}
}

public client_disconnected(id)
{
	g_bAlive[id] = false;
	g_bKicked[id] = false;
}

public fwdHamSpawn(id)
{
	if (is_user_alive(id))
	{
		g_bAlive[id] = true;
	}

	return HAM_IGNORED;
}

public fwdHamKilled(iVictim, iAttacker, bShouldGib)
{
	g_bAlive[iVictim] = false;
	return HAM_IGNORED;
}

public fwdCmdStart(id, uc_handle)
{
	if (!g_bAlive[id] || g_bKicked[id])
	{
		return FMRES_IGNORED;
	}
	
	new iMsec = get_uc(uc_handle, UC_Msec);
	
	if (iMsec <= 0)
	{
		return FMRES_IGNORED;
	}
	
	new iIndex = g_iCurrentMsecIndex[id];
	new iSum = g_iCachedMsecSum[id] + iMsec - g_iLastMsecs[id][iIndex];
	
	g_iLastMsecs[id][iIndex] = iMsec;
	g_iCachedMsecSum[id] = iSum;
	g_iCurrentMsecIndex[id] = (iIndex + 1) % MSEC_LOOKBACK;
	
	if (iMsec < g_iMinmumMsec || iSum < g_iMinimumAverageMsec)
	{
		static szName[32], szAdminMessage[92];
		get_user_name(id, szName, charsmax(szName));
		formatex(szAdminMessage, charsmax(szAdminMessage), "%s was kicked for having to high fps", szName);
		
		static aPlayers[MAX_PLAYERS], iPlayerCount;
		get_players(aPlayers, iPlayerCount, "ch");
		
		for (new i = 0; i < iPlayerCount; i++)
		{
			new playerId = aPlayers[i];
			
			if ((get_user_flags(playerId) & ADMIN_KICK) && playerId != id)
			{
				client_print(playerId, print_chat, szAdminMessage);
			}
		}
		
		server_cmd("kick #%d  ^"You have been kicked due to having to high fps!^"", get_user_userid(id));
		
		g_bKicked[id] = true;
	}
	
	return FMRES_IGNORED;
}