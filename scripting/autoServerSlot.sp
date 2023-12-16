#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <multicolors>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.0.1"

#define PLUGIN_PREFIX "[AutoServerSlot] "
#define TEAM_SURVIVOR 2

ConVar g_cvPrintDebugInfo,
    g_cvSurvivorLimit,
    g_cvFixedSurvivorLimit,
    g_cvSvMaxPlayers,
    g_cvFixedSvMaxPlayers,
    g_cvMDStartMedCount,
    g_cvMDSafeRoomMedCount,
    g_cvAutoKick;

bool g_bPrintDebugInfo;
bool g_bAutoKick;
bool g_bDependHasMedkitDencity;

int g_iPlayerCount;

int g_iFixedSurvivorCount;
int g_iFixedSvMaxPlayers;

int g_iPlayerBotIndex[MAXPLAYERS];

bool g_bRoundInitialized;

// Workaround for hookevent fire twice
bool g_bPlayerDisconnectTriggered[MAXPLAYERS];

public Plugin myinfo = 
{
    name = "[L4D2] Auto server slot",
    author = "faketuna",
    description = "Control surivor count and sv_maxplayers dynamically",
    version = PLUGIN_VERSION,
    url = "https://short.f2a.dev/s/github"
};

public void OnPluginStart()
{
    CreateConVar("sm_aslot_version", PLUGIN_VERSION, "Auto server slot version.", FCVAR_DONTRECORD);
    g_cvPrintDebugInfo       = CreateConVar("sm_aslot_debug", "0", "Toggle debug information that printed to server", FCVAR_NONE, true, 0.0, true , 1.0);
    g_cvAutoKick             = CreateConVar("sm_aslot_kick", "0", "Toggle auto kick when player disconnected", FCVAR_NONE, true, 0.0, true , 1.0);
    g_cvFixedSurvivorLimit   = CreateConVar("sm_aslot_fixed_survivor_limit", "24", "Fix survivor_limit as this number. If set to -1 (not recommended) It will adjust survivor_limit dynamically", FCVAR_NOTIFY, true, -1.0, true, 32.0);
    g_cvFixedSvMaxPlayers    = CreateConVar("sm_aslot_fixed_server_slot", "-1", "Fix sv_maxplayers as this number. If set to -1 It will adjust sv_maxplayers dynamically based from player count + 1", FCVAR_NOTIFY, true, -1.0, true, 32.0);

    
    HookEvent("player_bot_replace", OnReplacePlayerToBot, EventHookMode_Pre);
    HookEvent("round_start_post_nav", OnRoundStartPostNav, EventHookMode_Post);
    HookEvent("round_end", OnRoundEnd, EventHookMode_Post);
    HookEvent("player_disconnect", OnPlayerDisconnect, EventHookMode_Post);

    g_cvPrintDebugInfo.AddChangeHook(OnCvarsChanged);
    g_cvAutoKick.AddChangeHook(OnCvarsChanged);
    g_cvFixedSurvivorLimit.AddChangeHook(OnCvarsChanged);
    g_cvFixedSvMaxPlayers.AddChangeHook(OnCvarsChanged);

    g_iPlayerCount = 0;
    for(int i = 1; i <= MaxClients; i++) {
        g_iPlayerBotIndex[i] = -1;
        if(IsClientConnected(i) && !IsFakeClient(i)) {
            g_iPlayerCount++;
        }
    }
    g_bRoundInitialized = true;
    AutoExecConfig(true, "autoServerSlot");
}

public void OnAllPluginsLoaded() {
    g_bDependHasMedkitDencity = false;
    g_cvSurvivorLimit        = FindConVar("survivor_limit");
    SetConVarBounds(g_cvSurvivorLimit, ConVarBound_Upper, true, 32.0);
    g_cvSvMaxPlayers         = FindConVar("sv_maxplayers");
    g_cvMDStartMedCount      = FindConVar("sm_md_start_medkitcount");
    g_cvMDSafeRoomMedCount   = FindConVar("sm_md_saferoom_medkitcount");    
    if(g_cvSvMaxPlayers == INVALID_HANDLE)
        SetFailState("This plugin require l4dtoolz to run.");
    
    if(g_cvMDStartMedCount != INVALID_HANDLE && g_cvMDSafeRoomMedCount != INVALID_HANDLE) {
        g_bDependHasMedkitDencity = true;
        updateMedKitCount(g_iPlayerCount);
    }
}

public void OnConfigsExecuted() {
    SyncConVarValues();
}

void SyncConVarValues() {
    g_bPrintDebugInfo       = g_cvPrintDebugInfo.BoolValue;
    g_bAutoKick             = g_cvAutoKick.BoolValue;

    g_iFixedSurvivorCount = g_cvFixedSurvivorLimit.IntValue;
    if(g_iFixedSurvivorCount == 0) {
        g_iFixedSurvivorCount = 1;
        g_cvFixedSurvivorLimit.SetInt(1);
    }
    if(g_iFixedSurvivorCount == -1) {
        g_cvSurvivorLimit.SetInt((g_iPlayerCount < 4) ? 4 : g_iPlayerCount, true, false);
    }
    else {
        g_cvSurvivorLimit.SetInt(g_iFixedSurvivorCount, true, false);
    }

    g_iFixedSvMaxPlayers = g_cvFixedSvMaxPlayers.IntValue;
    if(g_iFixedSvMaxPlayers == 0) {
        g_iFixedSvMaxPlayers = 1;
        g_cvFixedSvMaxPlayers.SetInt(1);
    }
    if(g_iFixedSvMaxPlayers == -1) {
        g_cvSvMaxPlayers.SetInt((g_iPlayerCount < 4) ? 4 : g_iPlayerCount + 1);
    }
    else {
        g_cvSvMaxPlayers.SetInt(g_iFixedSvMaxPlayers);
    }
}

public void OnCvarsChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
    SyncConVarValues();
}

public void OnMapEnd()
{
    g_iPlayerCount = 0;
    g_bRoundInitialized = false;
    if(g_iFixedSurvivorCount != -1) {
        g_cvSurvivorLimit.SetInt(g_iFixedSurvivorCount);
    }
}

public Action OnRoundStartPostNav(Handle event, const char[] name, bool dontBroadcast)
{
    if(!g_bRoundInitialized){
        CreateTimer(13.0, DelayedMapStartTimer, _, TIMER_FLAG_NO_MAPCHANGE);
    }
    return Plugin_Continue;
}

public Action DelayedMapStartTimer(Handle timer) {
    g_bRoundInitialized = true;
    CreateTimer(0.5, PlayerBotSpawnTimer, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
    return Plugin_Stop;
}

public Action PlayerBotSpawnTimer(Handle timer) {
    int survivors = GetTeamClientCount(TEAM_SURVIVOR);

    PrintDebug("Survivor ent: %d | Player count: %d", survivors, g_iPlayerCount);
    if(survivors < g_iPlayerCount) {
        AddSurvivor();
        return Plugin_Continue;
    }
    return Plugin_Stop;
}

public Action OnRoundEnd(Handle event, const char[] name, bool dontBroadcast)
{
    g_bRoundInitialized = false;
    return Plugin_Continue;
}

public void OnClientPutInServer(int client) {
    if(IsFakeClient(client))
        return;


    if(!g_bRoundInitialized)
        return;

    int survivors = GetTeamClientCount(TEAM_SURVIVOR);

    PrintDebug("In game suriviros: %d", survivors);
    PrintDebug("Current players: %d", g_iPlayerCount);
    if(g_iPlayerCount <= survivors) {
        PrintDebug("Server has enough survivors entities to fit current player count.");
        return;
    }
    AddSurvivor();
}

public void OnClientConnected(int client) {
    if(IsFakeClient(client))
        return;

    g_iPlayerCount++;
    setServerSlotLimit();
    setSurvivorLimit();
    PrintDebug("The player count increased to %d", g_iPlayerCount);
    g_bPlayerDisconnectTriggered[client] = false;
}

public void OnPlayerDisconnect(Handle event, const char[] name, bool dontBroadcast) {
    int client = GetClientOfUserId(GetEventInt(event, "userid", 0));

    if(client == 0) {
        PrintDebug("Event key userid is not found in player_disconnect event.");
        return;
    }

    if(IsFakeClient(client))
        return;

    if(g_bPlayerDisconnectTriggered[client])
        return;

    g_bPlayerDisconnectTriggered[client] = true;
    g_iPlayerCount--;
    setServerSlotLimit();
    setSurvivorLimit();
    PrintDebug("The player count decreased to %d", g_iPlayerCount);

    char reason[128];
    GetEventString(event, "reason", reason, sizeof(reason), "");
    PrintDebug("REASON: %s", reason);
    if(StrEqual(reason, ""))
        return;
    
    if(StrContains(reason, "by user", false) != -1) {
        CreateTimer(0.4, delayedKickTimer, client, TIMER_FLAG_NO_MAPCHANGE);
    }
    return;
}

public Action delayedKickTimer(Handle timer, int client) {
    PrintDebug("Delayed kick timer fired.");
    if(g_iPlayerBotIndex[client] != -1 && g_bAutoKick && g_iPlayerCount > 0) {
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
    int player = GetClientOfUserId(GetEventInt(event, "player", 0));
    int bot    = GetClientOfUserId(GetEventInt(event, "bot", 0));

    if(player == 0) {
        PrintDebug("Event key player is not found in player_bot_replace event.");
        return Plugin_Continue;
    }

    if(bot == 0) {
        PrintDebug("Event key bot is not found in player_bot_replace event.");
        return Plugin_Continue;
    }

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
        if(g_iFixedSurvivorCount == -1) {
            PrintDebug("Player count is lower than 4, setting survivor limit to 4");
            updateMedKitCount(4);
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
        if(g_iFixedSvMaxPlayers == -1) {
            PrintDebug("Player count is lower than 4, setting server slot to 4");
            g_cvSvMaxPlayers.SetInt(4);
        }
        return;
    }
    if(g_iFixedSvMaxPlayers == -1) {
        g_cvSvMaxPlayers.SetInt(g_iPlayerCount+1);
    }
}

void updateMedKitCount(int medKitCount) {
    if(!g_bDependHasMedkitDencity)
        return;
    g_cvMDStartMedCount.SetInt(medKitCount);
    g_cvMDSafeRoomMedCount.SetInt(medKitCount);

}

void AddSurvivor() {
    PrintDebug("AddSurvivor() called");
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