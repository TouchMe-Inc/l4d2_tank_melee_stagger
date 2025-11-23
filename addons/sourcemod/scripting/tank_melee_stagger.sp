#pragma semicolon               1
#pragma newdecls                required

#include <sourcemod>
#include <left4dhooks>


public Plugin myinfo = {
    name        = "TankMeleeStagger",
    author      = "TouchMe",
    description = "Adds a delay to survivor melee attacks after being hit by the Tank's claw",
    version     = "build_0001",
    url         = "https://github.com/TouchMe-Inc/l4d2_tank_melee_stagger"
}


#define TEAM_SURVIVOR 2


ConVar g_cvDelay = null;

float g_fClientDelayAt[MAXPLAYERS + 1] = {0.0, ...};

public void OnPluginStart()
{
    HookEvent("player_hurt", Event_PlayerHurt);

    g_cvDelay = CreateConVar("sm_tms_delay", "1.25", .hasMin = true, .min = 1.0);
}

public void OnMapStart()
{
    for (int iClient = 1; iClient <= MaxClients; iClient++)
    {
        g_fClientDelayAt[iClient] = 0.0;
    }
}

public void Event_PlayerHurt(Event event, char[] event_name, bool dontBroadcast)
{
    int iClient = GetClientOfUserId(GetEventInt(event, "userid"));

    if (iClient <= 0 && !IsClientSurvivor(iClient)) {
        return;
    }

    char szWeaponName[32];
    GetEventString(event, "weapon", szWeaponName, sizeof(szWeaponName));

    if (!StrEqual(szWeaponName, "tank_claw")) {
        return;
    }

    int iActiveWeapon = GetActiveWeapon(iClient);

    if (IsValidEdict(iActiveWeapon))
    {
        GetEdictClassname(iActiveWeapon, szWeaponName, sizeof(szWeaponName));    

        if (StrEqual(szWeaponName[7], "melee", false))
        {
            g_fClientDelayAt[iClient] = GetGameTime();

            int iEntViewModel = GetEntPropEnt(iClient, Prop_Send, "m_hViewModel");
            if (iEntViewModel <= 0 || !IsValidEntity(iEntViewModel)) return;

            int iOldModelIndex = GetEntProp(iEntViewModel, Prop_Send, "m_nModelIndex");

            SetEntProp(iEntViewModel, Prop_Send, "m_nModelIndex", 0);

            DataPack pack;
            CreateDataTimer(g_cvDelay.FloatValue, RestoreViewModelTimer, pack, TIMER_FLAG_NO_MAPCHANGE);
            WritePackCell(pack, iClient);
            WritePackCell(pack, iEntViewModel);
            WritePackCell(pack, iOldModelIndex);
        }
    }
}

public Action RestoreViewModelTimer(Handle hTimer, DataPack pack)
{
    ResetPack(pack);

    int client = ReadPackCell(pack);
    int iEntViewModel = ReadPackCell(pack);
    int iOldModelIndex = ReadPackCell(pack);

    if (!IsClientInGame(client) || !IsValidEntity(iEntViewModel)) {
        return Plugin_Stop;
    }

    SetEntProp(iEntViewModel, Prop_Send, "m_nModelIndex", iOldModelIndex);
    return Plugin_Stop;
}

public Action L4D_OnStartMeleeSwing(int iClient, bool boolean)
{
    if (g_fClientDelayAt[iClient] == 0.0) {
        return Plugin_Continue;
    }

    return (g_cvDelay.FloatValue > GetGameTime() - g_fClientDelayAt[iClient]) ? Plugin_Handled : Plugin_Continue;
}

bool IsClientSurvivor(int client) {
    return GetClientTeam(client) == TEAM_SURVIVOR;
}

int GetActiveWeapon(int iClient) {
    return GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
}