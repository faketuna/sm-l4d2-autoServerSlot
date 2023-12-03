#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <multicolors>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "0.0.1a"

#define PLUGIN_PREFIX "[AutoServerSlot] "
#define TEAM_SURVIVOR 2

ConVar g_cvPrintDebugInfo,
    g_cvSurvivorLimit,
    g_cvFixedSurvivorLimit,
    g_cvSvMaxPlayers,
    g_cvMDStartMedCount,
    g_cvMDSafeRoomMedCount,
    g_cvAutoKick;

bool g_bPrintDebugInfo;
bool g_bAutoKick;
bool g_bDependHasMedkitDencity;

int g_iPlayerCount;

int g_iFixedSurvivorCount;

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
    g_cvPrintDebugInfo       = CreateConVar("sm_aslot_debug", "0", "Toggle debug information that printed to server", FCVAR_NONE, true, 0.0, true , 1.0);
    g_cvAutoKick             = CreateConVar("sm_aslot_kick", "0", "Toggle auto kick when player disconnected", FCVAR_NONE, true, 0.0, true , 1.0);
    g_cvFixedSurvivorLimit   = CreateConVar("sm_aslot_fixed_slot", "24", "Fix survivor_limit as this number. If set to -1 (not recommended) It will adjust survivor_limit dynamically", FCVAR_NOTIFY, true, -1.0, true, 32.0);

    
    HookEvent("player_bot_replace", OnReplacePlayerToBot, EventHookMode_Pre);
    HookEvent("round_start_post_nav", OnRoundStartPostNav, EventHookMode_Post);
    HookEvent("round_end", OnRoundEnd, EventHookMode_Post);

    g_cvPrintDebugInfo.AddChangeHook(OnCvarsChanged);
    g_cvAutoKick.AddChangeHook(OnCvarsChanged);
    g_cvFixedSurvivorLimit.AddChangeHook(OnCvarsChanged);

    g_iPlayerCount = 0;
    for(int i = 1; i <= MaxClients; i++) {
        g_iPlayerBotIndex[i] = -1;
        if(IsClientConnected(i) && !IsFakeClient(i)) {
            g_iPlayerCount++;
        }
    }
    g_bIsMapStarted = true;
}

public void OnAllPluginsLoaded() {
    g_bDependHasMedkitDencity = false;
    g_cvSurvivorLimit        = FindConVar("survivor_limit");
    g_cvSvMaxPlayers         = FindConVar("sv_maxplayers");
    g_cvMDStartMedCount      = FindConVar("sm_md_start_medkitcount");
    g_cvMDSafeRoomMedCount   = FindConVar("sm_md_saferoom_medkitcount");
    if(g_cvSurvivorLimit == INVALID_HANDLE)
        SetFailState("This plugin require l4d_players to run.");
    
    if(g_cvSvMaxPlayers == INVALID_HANDLE)
        SetFailState("This plugin require l4dtoolz to run.");
    
    if(g_cvMDStartMedCount != INVALID_HANDLE && g_cvMDSafeRoomMedCount != INVALID_HANDLE)
        g_bDependHasMedkitDencity = true;
}

public void OnConfigsExecuted() {
    SyncConVarValues();
}

void SyncConVarValues() {
    g_bPrintDebugInfo       = g_cvPrintDebugInfo.BoolValue;
    g_bAutoKick             = g_cvAutoKick.BoolValue;
    if(g_iFixedSurvivorCount != g_cvFixedSurvivorLimit.IntValue) {
        g_iFixedSurvivorCount = g_cvFixedSurvivorLimit.IntValue;
        if(g_iFixedSurvivorCount == 0) {
            g_iFixedSurvivorCount = 1;
            g_cvFixedSurvivorLimit.SetInt(1);
        }
    }
}

public void OnCvarsChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
    SyncConVarValues();
}

public void OnMapEnd()
{
    g_iPlayerCount = 0;
    g_bIsMapStarted = false;
    if(g_iFixedSurvivorCount != -1) {
        g_cvSurvivorLimit.SetInt(g_iFixedSurvivorCount);
    }
}

public Action OnRoundStartPostNav(Handle event, const char[] name, bool dontBroadcast)
{
    CreateTimer(10.0, DelayedMapStartTimer, _, TIMER_FLAG_NO_MAPCHANGE);
    return Plugin_Continue;
}

public Action DelayedMapStartTimer(Handle timer) {
    g_bIsMapStarted = true;
    return Plugin_Stop;
}

public Action OnRoundEnd(Handle event, const char[] name, bool dontBroadcast)
{
    g_bIsMapStarted = false;
    return Plugin_Continue;
}

public void OnClientConnected(int client) {
    if(IsFakeClient(client))
        return;

    g_iPlayerCount++;
    setServerSlotLimit();
    setSurvivorLimit();
    PrintDebug("The player count increased to %d", g_iPlayerCount);

    if(!g_bIsMapStarted)
        return;

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
}

public void OnClientDisconnect(int client) {
    if(IsFakeClient(client))
        return;

    g_iPlayerCount--;
    setServerSlotLimit();
    setSurvivorLimit();
    PrintDebug("The player count decreased to %d", g_iPlayerCount);

    if(!g_bIsMapStarted) 
        return;

    CreateTimer(0.4, delayedKickTimer, client, TIMER_FLAG_NO_MAPCHANGE);
}

public Action delayedKickTimer(Handle timer, int client) {
    if(g_iPlayerBotIndex[client] != -1 && g_bAutoKick) {
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
    if(g_iPlayerCount < 4) {
        PrintDebug("Player count is lower than 4, setting survivor limit to 4");
        updateMedKitCount(4);
        if(g_iFixedSurvivorCount == -1) {
            g_cvSurvivorLimit.SetInt(4);
        }
        return;
    }
    if(g_iFixedSurvivorCount == -1) {
        g_cvSurvivorLimit.SetInt(g_iPlayerCount);
    }
    updateMedKitCount(g_iPlayerCount);
}

void setServerSlotLimit() {
    if(g_iPlayerCount < 4) {
        PrintDebug("Player count is lower than 4, setting server slot to 4");
        g_cvSvMaxPlayers.SetInt(4);
        return;
    }
    g_cvSvMaxPlayers.SetInt(g_iPlayerCount+1);
}

void updateMedKitCount(int medKitCount) {
    if(!g_bDependHasMedkitDencity)
        return;
    g_cvMDStartMedCount.SetInt(medKitCount);
    g_cvMDSafeRoomMedCount.SetInt(medKitCount);

}