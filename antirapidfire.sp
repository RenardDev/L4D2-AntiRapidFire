#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

public Plugin myinfo =
{
    name        = "UserCMD AntiRapidFire",
    author      = "RenardDev",
    description = "Kicks clients for abnormal UserCMD/sec rate",
    version     = "1.0",
    url         = "https://github.com/RenardDev/L4D2-AntiRapidFire"
};

ConVar g_hCvarEnabled;
ConVar g_hCvarThreshold;
ConVar g_hCvarReason;

int   g_iCmdCount[MAXPLAYERS + 1];
float g_fWindowStart[MAXPLAYERS + 1];

const float WINDOW_DURATION = 0.2;

void ResetClientCounters(int client)
{
    g_iCmdCount[client]    = 0;
    g_fWindowStart[client] = GetEngineTime();
}

public void OnPluginStart()
{
    g_hCvarEnabled = CreateConVar(
        "sm_ucmdarp_enable", "1",
        "Enable UserCMD anti-rapidfire (0/1)",
        FCVAR_NOTIFY, true, 0.0, true, 1.0
    );

    g_hCvarThreshold = CreateConVar(
        "sm_ucmdarp_threshold", "480",
        "Maximum UserCMD per second before kick",
        FCVAR_NOTIFY, true, 1.0, true, 1000000.0
    );

    g_hCvarReason = CreateConVar(
        "sm_ucmdarp_reason",
        "UserCMD flood / suspected cheats",
        "Kick reason shown to the client",
        FCVAR_NOTIFY
    );

    for (int i = 1; i <= MaxClients; i++)
    {
        g_iCmdCount[i]    = 0;
        g_fWindowStart[i] = 0.0;
    }
}

public void OnMapStart()
{
    for (int i = 1; i <= MaxClients; i++)
    {
        g_iCmdCount[i]    = 0;
        g_fWindowStart[i] = 0.0;
    }
}

public void OnClientPutInServer(int client)
{
    if (!IsClientInGame(client))
        return;

    if (IsFakeClient(client))
        return;

    ResetClientCounters(client);
}

public void OnClientDisconnect(int client)
{
    g_iCmdCount[client]    = 0;
    g_fWindowStart[client] = 0.0;
}

public Action OnPlayerRunCmd(
    int client,
    int &buttons,
    int &impulse,
    float vel[3],
    float angles[3],
    int &weapon,
    int &subtype,
    int &cmdnum,
    int &tickcount,
    int &seed,
    int mouse[2]
)
{
    if (!g_hCvarEnabled.BoolValue)
    {
        return Plugin_Continue;
    }

    if (!IsClientInGame(client) || IsFakeClient(client))
    {
        return Plugin_Continue;
    }

    float now = GetEngineTime();

    if (g_fWindowStart[client] <= 0.0)
    {
        g_fWindowStart[client] = now;
    }

    if (now - g_fWindowStart[client] >= WINDOW_DURATION)
    {
        g_fWindowStart[client] = now;
        g_iCmdCount[client]    = 0;
    }

    g_iCmdCount[client]++;

    int thresholdPerSec = g_hCvarThreshold.IntValue;
    if (thresholdPerSec <= 0)
    {
        thresholdPerSec = 10000;
    }

    float windowThresholdF = float(thresholdPerSec) * WINDOW_DURATION;
    int windowThreshold = RoundToCeil(windowThresholdF);

    if (g_iCmdCount[client] > windowThreshold)
    {
        float ratePerSec = float(g_iCmdCount[client]) / WINDOW_DURATION;

        char reason[128];
        g_hCvarReason.GetString(reason, sizeof(reason));

        char auth[64];
        bool gotAuth = GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth), true);

        if (gotAuth)
        {
            LogMessage("[UserCMD-ARP] Kicking %N (%s) for %.1f UserCMD/sec (limit %d)",
                client, auth, ratePerSec, thresholdPerSec);
        }
        else
        {
            LogMessage("[UserCMD-ARP] Kicking %N (authid unknown) for %.1f UserCMD/sec (limit %d)",
                client, ratePerSec, thresholdPerSec);
        }

        PrintToChatAll("[UserCMD-ARP] %N was kicked for abnormal UserCMD spam (%.1f UserCMD/sec)",
            client, ratePerSec);

        KickClient(client, "%s", reason);

        return Plugin_Handled;
    }

    return Plugin_Continue;
}
