#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <nexd>
#include <colorvariables>

#define PLUGIN_AUTHOR "Triggerhacks"
#define PLUGIN_VERSION "1.0"

#define MAX_PLAYERS				32

#pragma semicolon 1
#pragma newdecls required

//Plugin ConVars
ConVar krcv_roundtime;
ConVar krcv_enablealltalk;
ConVar krcv_votetime;
//SourceMod/CS:GO ConVars
ConVar krcv_BuyTimeNormal;
ConVar krcv_BuyTimeImmunity;
ConVar krcv_TalkDead;
ConVar krcv_TalkLiving;

//Plugin integers
int kri_CvarAllowAllTalk;
int kri_winningteam;
int kri_roundnumber = 0;
int kri_clientwinners = 0;
int kri_clientwinnersID[MAX_PLAYERS+1];
int kri_StayNum;
int kri_SwapNum;
//SourceMod/CS:GO integers
int kri_CvarTalkDead;
int kri_CvarTalkLiving;

//Plugin floats
float krf_CvarRoundTime;
float krf_CvarVoteTime;
//SourceMod/CS:GO floats
float krf_CvarBuyTimeNormal;
float krf_CvarBuyTimeImmunity;

//Plugin booleans
bool krb_played = false;
bool krb_matchstarted = false;
bool b_swap = false;

//Plugin Handles
Handle RestartTimer;

public Plugin myinfo = 
{
	name = "Knife Round",
	author = PLUGIN_AUTHOR,
	description = "Fixed version of the long broken Knife Round plugin",
	version = PLUGIN_VERSION,
};

public void OnPluginStart()
{
	LoadTranslations("knife_round.phrases");
	//Hooking the necessary events
	HookEvent("round_start", RoundStart);
	HookEvent("round_end", RoundEnd);
	HookEvent("player_spawn", PlayerSpawn);

	//Defining the Commands
	RegAdminCmd("sm_skipkr", command_skipkr, ADMFLAG_CHANGEMAP, "Skips the Knife Round and keeps all players in their current teams");
	
	//Defining the ConVars
	krcv_roundtime = CreateConVar("sm_kniferoundtime", "60.0", "How much time should knife round take? (0.5 to 60.0 minutes)", _, true, 0.5, true, 60.0);
	krcv_votetime = CreateConVar("sm_kniferoundvotetime", "10.0", "How much time should the vote take? (5 to 20 seconds)", _, true, 5.0, true, 20.0);
	krcv_enablealltalk = CreateConVar("sm_enablealltalk", "1", "Should alltalk be enabled while the Knife Round is running? (1 - enabled, 0 - disabled)", _, true, 0.0, true, 1.0);
	
	//Getting the SourceMod/CS:GO ConVars
	krcv_BuyTimeNormal = FindConVar("mp_buytime");
	krcv_BuyTimeImmunity = FindConVar("mp_buy_during_immunity");
	krcv_TalkDead = FindConVar("sv_talk_enemy_dead");
	krcv_TalkLiving = FindConVar("sv_talk_enemy_living");

	kri_roundnumber = 0;

	AutoExecConfig(true, "KnifeRound", "sourcemod");
}

public void OnConfigsExecuted()
{
	krf_CvarRoundTime = GetConVarFloat(krcv_roundtime);
	krf_CvarVoteTime = GetConVarFloat(krcv_votetime);
	kri_CvarAllowAllTalk = GetConVarInt(krcv_enablealltalk);
	
	krf_CvarBuyTimeNormal = GetConVarFloat(krcv_BuyTimeNormal);
	krf_CvarBuyTimeImmunity = GetConVarFloat(krcv_BuyTimeImmunity);
	kri_CvarTalkDead = GetConVarInt(krcv_TalkDead);
	kri_CvarTalkLiving = GetConVarInt(krcv_TalkLiving);
}

public void OnMapStart()
{
	krb_played = false, krb_matchstarted = false, b_swap = false;
	kri_roundnumber = 0, kri_StayNum = 0, kri_SwapNum = 0;
}

public Action command_skipkr(int client, int args)
{
	if (!krb_played)
	{
		CPrintToChatAll("%t", "Admin_Skip");
		RestartAdminSkip();
	}
}

public Action PlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{
	if ((kri_roundnumber == 2) && (!IsWarmup()) && !krb_played)
	{
		for (int i = 1;i <= MAX_PLAYERS;i++)
		{
			if (!IsValidClient(i))
				continue;
			RemovePlayerPistol(i);
			RemovePlayerPrimary(i);
		}
	}
}

public Action RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	if (krb_matchstarted)
	{
		return Plugin_Handled;
	}

	if (GetClientCount(true) < 1 || GetClientCountTeams() < 1 || GameRules_GetProp("m_bWarmupPeriod"))
	{
		kri_roundnumber = 0;
		krb_played = false;
		return Plugin_Handled;
	}

	
	if (krb_played)
		return Plugin_Handled;
	
	kri_roundnumber++;
	if (kri_roundnumber == 1)
	{
		SetKnifeRoundSettings();
	}
	else if((kri_roundnumber == 2) && !krb_played)
	{
		CPrintToChatAll("%t", "Knife_Start");
		StripPlayerWeapons();
	}
	return Plugin_Handled;
}

public Action RoundEnd(Handle event, const char[] name, bool dontBroadcast)
{
	if (krb_matchstarted)
	{
		return Plugin_Handled;
	}

	if (GetClientCount(true) < 1 || GetClientCountTeams() < 1 || GameRules_GetProp("m_bWarmupPeriod"))
	{
		krb_played = false;
		return Plugin_Handled;
	}
	if (kri_roundnumber == 2)
	{
		AfterKnifeRound();
		krb_played = true;

		kri_winningteam = GetEventInt(event, "winner");
		if (kri_winningteam != CS_TEAM_CT && kri_winningteam != CS_TEAM_T)
		{
			CPrintToChatAll("%t", "Win_None");
			
			RestartLastTime();
		}
		else
			TeamVote();
	}
	return Plugin_Handled;
}

//Vote for the side the winners want to play on.

stock void TeamVote()
{
	CPrintToChatAll("%t", "Voting_Start");
	
	kri_clientwinners = 0;
	for (int i = 1;i <= MAX_PLAYERS;i++)
	{
		if (IsValidClient(i))
		{
			if (GetClientTeam(i) == kri_winningteam)
			{
				kri_clientwinnersID[kri_clientwinners] = i;
				++kri_clientwinners;
			}
		}
	}
	
	Menu hMenu = new Menu(ShowVotingMenuHandle);
	char cTempBuffer[128];
	Format(cTempBuffer, 127, "%t", "Menu_Title");
	SetMenuTitle(hMenu, cTempBuffer);

	AddMenuItem(hMenu, "stay", "Stay");
	AddMenuItem(hMenu, "swap", "Swap");

	SetMenuExitButton(hMenu, false);
	SetMenuExitBackButton(hMenu, false);

	for(int i = 0;i < kri_clientwinners;i++)
	{
		DisplayMenu(hMenu, kri_clientwinnersID[i], MENU_TIME_FOREVER);
	}
	CreateTimer(krf_CvarVoteTime, EndTheVote);
}

public int ShowVotingMenuHandle(Menu hMenu, MenuAction action, int param1, int param2)
{
	char choice[10];
	hMenu.GetItem(param2, choice, sizeof(choice));

	if (action == MenuAction_Select)
	{
		if(StrEqual(choice, "stay", true))
		{
			++kri_StayNum;
		}
		else if(StrEqual(choice, "swap", true))
		{
			++kri_SwapNum;
		}
	}
}

public Action EndTheVote(Handle hTimer)
{
	if(kri_SwapNum >= kri_StayNum) { b_swap = true; }

	if (b_swap)
	{
		CPrintToChatAll("%t", "Winning_Swap");
		RestartSwapLastTime();
	}
	else
	{
		CPrintToChatAll("%t", "Winning_Stay");
		RestartLastTime();
	}
}

//Miscellaneous functions.

public int GetClientCountTeams()
{
	int iTempSum = 0;
	for (int i = 1; i <= MAX_PLAYERS; i++)
	{
		if (IsValidClient(i) && IsClientAuthorized(i))
		{
			++iTempSum;
		}
	}
	return iTempSum;
}

public void StripPlayerWeapons()
{
	for (int i = 1;i <= MAX_PLAYERS;i++)
	{
		if (!IsValidClient(i))
			continue;
		RemovePlayerPistol(i);
		RemovePlayerPrimary(i);
		ClientCommand(i, "slot3");
	}
}

//The settings for the knife round get set and reverted.

public void SetKnifeRoundSettings()
{
	if (kri_CvarAllowAllTalk)
	{
		ServerCommand("sv_talk_enemy_dead 1");
		ServerCommand("sv_talk_enemy_living 1");
		ServerCommand("sv_alltalk 1");
	}
	ServerCommand("mp_roundtime %f", krf_CvarRoundTime);
	ServerCommand("mp_roundtime_defuse %f", krf_CvarRoundTime);
	ServerCommand("mp_freezetime 5");
	ServerCommand("mp_buytime 0");
	ServerCommand("mp_buy_during_immunity 0");
	ServerCommand("mp_startmoney 0");
	ServerCommand("mp_restartgame 1");
	ServerCommand("mp_give_player_c4 0");
}

public void AfterKnifeRound()
{
	if (kri_CvarAllowAllTalk)
	{
		ServerCommand("sv_talk_enemy_dead %i", kri_CvarTalkDead);
		ServerCommand("sv_talk_enemy_living %i", kri_CvarTalkLiving);
	}
	ServerCommand("mp_roundtime 1.92");
	ServerCommand("mp_roundtime_defuse 1.92");
	ServerCommand("mp_pause_match");
}

public void RestartLastTime()
{
	ServerCommand("mp_buytime %f", krf_CvarBuyTimeNormal);
	ServerCommand("mp_buy_during_immunity %f", krf_CvarBuyTimeImmunity);
	ServerCommand("sv_alltalk 0");
	ServerCommand("mp_startmoney 800");
	ServerCommand("mp_unpause_match");
	ServerCommand("mp_restartgame 1");
	ServerCommand("mp_give_player_c4 1");
	krb_matchstarted = true;
}

public void RestartAdminSkip()
{
	if (kri_CvarAllowAllTalk)
	{
		ServerCommand("sv_talk_enemy_dead %i", kri_CvarTalkDead);
		ServerCommand("sv_talk_enemy_living %i", kri_CvarTalkLiving);
	}
	ServerCommand("mp_roundtime 1.92");
	ServerCommand("mp_roundtime_defuse 1.92");
	ServerCommand("mp_buytime %f", krf_CvarBuyTimeNormal);
	ServerCommand("mp_buy_during_immunity %f", krf_CvarBuyTimeImmunity);
	ServerCommand("sv_alltalk 0");
	ServerCommand("mp_freezetime 15");
	ServerCommand("mp_startmoney 800");
	ServerCommand("mp_unpause_match");
	ServerCommand("mp_restartgame 1");
	ServerCommand("mp_give_player_c4 1");
	krb_matchstarted = true;
	krb_played = true;
	RestartTimer = CreateTimer(0.5, LastRestartAdminSkip);
}

public Action LastRestartAdminSkip(Handle timer)
{
	ServerCommand("mp_restartgame 1");
	delete RestartTimer;
}

public void RestartSwapLastTime()
{
	ServerCommand("mp_buytime %f", krf_CvarBuyTimeNormal);
	ServerCommand("mp_buy_during_immunity %f", krf_CvarBuyTimeImmunity);
	ServerCommand("sv_alltalk 0");
	ServerCommand("mp_freezetime 15");
	ServerCommand("mp_startmoney 800");
	ServerCommand("mp_unpause_match");
	ServerCommand("mp_swapteams");
	ServerCommand("mp_give_player_c4 1");
	krb_matchstarted = true;
}