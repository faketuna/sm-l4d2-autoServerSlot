#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <multicolors>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "0.0.1"

#define PLUGIN_PREFIX "[AutoServerSlot] "
#define TEAM_SURVIVOR 2

ConVar g_cPrintDebugInfo;
ConVar g_cSurvivorLimit;
ConVar g_cSvMaxPlayers;

bool g_bPrintDebugInfo;

int g_iPlayerCount;

int g_iPlayerBotIndex[MAXPLAYERS];

bool g_bIsMapStarted;


public Plugin myinfo = 
{
    name = "[L4D2] Auto server slot",
    author = "faketuna",
    description = "Control surivor limit dynamically",
    version = PLUGIN_VERSION,
    url = "https://short.f2a.dev/s/github"
};

public void OnPluginStart()
{
    g_cPrintDebugInfo       = CreateConVar("sm_aslot_debug", "0", "Toggle debug information that printed to server", FCVAR_NONE, true, 0.0, true , 1.0);
    g_cSurvivorLimit        = FindConVar("survivor_limit");
    g_cSvMaxPlayers         = FindConVar("sv_maxplayers");
    if(g_cSurvivorLimit == INVALID_HANDLE)
        SetFailState("This plugin require l4d_players to run.");
    
    if(g_cSvMaxPlayers == INVALID_HANDLE)
        SetFailState("This plugin require l4dtoolz to run.");
    
    HookEvent("player_bot_replace", OnReplacePlayerToBot, EventHookMode_Pre);
    HookEvent("round_start_post_nav", OnRoundStartPostNav, EventHookMode_Post);
    HookEvent("round_end", OnRoundEnd, EventHookMode_Post);

    g_cPrintDebugInfo.AddChangeHook(OnCvarsChanged);

    g_iPlayerCount = 0;
    for(int i = 1; i <= MaxClients; i++) {
        g_iPlayerBotIndex[i] = -1;
        if(IsClientConnected(i) && !IsFakeClient(i)) {
            g_iPlayerCount++;
        }
    }
}

public void OnConfigsExecuted() {
    SyncConVarValues();
}

void SyncConVarValues() {
    g_bPrintDebugInfo       = g_cPrintDebugInfo.BoolValue;
}

public void OnCvarsChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
    SyncConVarValues();
}

public void OnMapEnd()
{
    g_bIsMapStarted = false;
}

public Action OnRoundStartPostNav(Handle event, const char[] name, bool dontBroadcast)
{
    g_bIsMapStarted = true;
    return Plugin_Continue;
}

public Action OnRoundEnd(Handle event, const char[] name, bool dontBroadcast)
{
    g_bIsMapStarted = false;
    return Plugin_Continue;
}

public void OnClientConnected(int client) {
    if(IsFakeClient(client))
        return;

    if(!g_bIsMapStarted)
        return;
    
    g_iPlayerCount++;
    g_cSvMaxPlayers.SetInt(g_iPlayerCount+1);
    int inGameClients = 0;
    for(int i = 1; i <= MaxClients; i++) {
        if(!IsClientConnected(i) || !IsClientInGame(i) || GetClientTeam(i) != TEAM_SURVIVOR)
            continue;
        inGameClients++;
    }

    PrintDebug("In game suriviros: %d", inGameClients);
    PrintDebug("Current players: %d", g_iPlayerCount);
    if(g_iPlayerCount <= inGameClients) {
        PrintDebug("Server has enough survivors entities to fit current player count.");
        return;
    }
    int bot = CreateFakeClient("Creating bot...");
    if(bot == 0) {
        PrintDebug("Tried to create a bot. but failed.");
        return;
    }
    
    ChangeClientTeam(bot, 2);
    DispatchKeyValue(bot, "classname", "SurvivorBot");
    DispatchSpawn(bot);
    if(!IsValidEntity(bot)){
        PrintDebug("Bot is not a valid entity!");
        return;
    }
    float absPos[3];
    for(int i = 1; i <= MaxClients; i++){
        if(IsClientConnected(i) && IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == TEAM_SURVIVOR) {
            GetClientAbsOrigin(i, absPos);
            TeleportEntity(bot, absPos, NULL_VECTOR, NULL_VECTOR);
            PrintDebug("Bot teleported to %N", i);
            break;
        }
    }
    PrintDebug("Kicking bot.");
    KickClient(bot, "adding survivor");
    setSurvivorLimit();
    PrintDebug("The player count increased to %d", g_iPlayerCount);
}

public void OnClientDisconnect(int client) {
    PrintDebug("%N", client);
    if(IsFakeClient(client))
        return;

    if(!g_bIsMapStarted) 
        return;

    g_iPlayerCount--;
    g_cSvMaxPlayers.SetInt(g_iPlayerCount+1);
    CreateTimer(0.4, delayedKickTimer, client, TIMER_FLAG_NO_MAPCHANGE);
    PrintDebug("The player count decreased to %d", g_iPlayerCount);
}

public Action delayedKickTimer(Handle timer, int client) {
    if(g_iPlayerBotIndex[client] != -1) {
        if(g_iPlayerCount > 4) {
            PrintDebug("Kicking disconnected player bot index at %d", g_iPlayerBotIndex[client]);
            KickClient(g_iPlayerBotIndex[client]);
        }
        g_iPlayerBotIndex[client] = -1;
    }
    return Plugin_Stop;
}

public Action OnReplacePlayerToBot(Handle event, char[] name, bool dontBroadcast)
{
    int player = GetClientOfUserId(GetEventInt(event, "player"));
    int bot    = GetClientOfUserId(GetEventInt(event, "bot"));

    if(IsFakeClient(player))
        return Plugin_Continue;
    
    if(player > 0 && IsClientInGame(player) && GetClientTeam(player) == 2) {
        PrintDebug("Player %N's bot index are set to %d", player, bot);
        g_iPlayerBotIndex[player] = bot;
    }
    
    return Plugin_Continue;
}

void PrintDebug(const char[] msg, any ...) {
    if(!g_bPrintDebugInfo)
        return;
    char buff[2048];
    VFormat(buff, sizeof(buff), msg, 2);
    PrintToServer("%s%s", PLUGIN_PREFIX, buff);
    CPrintToChatAll("%s%s", PLUGIN_PREFIX, buff);
}

void setSurvivorLimit() {
    if(g_iPlayerCount <= 4) {
        g_cSurvivorLimit.SetInt(4);
        return;
    }
    g_cSurvivorLimit.SetInt(g_iPlayerCount);
}