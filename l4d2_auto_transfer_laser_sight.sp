#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define PLUGIN_VERSION "1.0.0"

#define TEAM_SURVIVORS 2
#define WEAPON_SLOT_PRIMARY 0
#define WEAPON_UPGRADE_FLAG_LASER (1 << 2)

bool was_laser_removed;
bool player_death;
int g_client;
int g_weapon;

public Plugin myinfo =
{
    name = "L4D2 Auto Transfer Laser Sight",
    author = "Garamond",
    description = "Auto transfer laser sight.",
    version = PLUGIN_VERSION,
    url = "https://github.com/garamond13/L4D2-Auto-Transfer-Laser-Sight"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) 
{	
	if (GetEngineVersion() != Engine_Left4Dead2) {
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success; 
}

public void OnPluginStart()
{
	CreateConVar("l4d2_transfer_laser_version", PLUGIN_VERSION, "L4D2 auto transfer laser sight version", FCVAR_NOTIFY | FCVAR_DONTRECORD);
    HookEvent("player_death", on_player_death, EventHookMode_Pre);
}

public void on_player_death(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client > 0 && IsClientInGame(client) && GetClientTeam(client) == TEAM_SURVIVORS)
        player_death = true;
}

public void OnClientPutInServer(int client)
{
	if (client > 0) {
	    SDKHook(client, SDKHook_WeaponEquipPost, on_client_weapon_equip);
	    SDKHook(client, SDKHook_WeaponDropPost, on_client_weapon_drop);
    }
}

public void OnClientDisconnect(int client)
{
	if (client > 0) {
	    SDKUnhook(client, SDKHook_WeaponEquipPost, on_client_weapon_equip);
	    SDKUnhook(client, SDKHook_WeaponDropPost, on_client_weapon_drop);
    }
}

//has to be delayed after on_client_weapon_drop()
public void on_client_weapon_equip(int client, int weapon)
{
    g_client = client;
    CreateTimer(0.2, on_client_weapon_equip_delayed);
}

public Action on_client_weapon_equip_delayed(Handle timer)
{
	if (g_client > 0 && IsClientInGame(g_client) && GetClientTeam(g_client) == TEAM_SURVIVORS && IsPlayerAlive(g_client)) {
        
        //get primary weapon
	    g_weapon = GetPlayerWeaponSlot(g_client, WEAPON_SLOT_PRIMARY);

	    if (g_weapon > 0 && IsValidEntity(g_weapon)) {
            char netclass[128];
	        GetEntityNetClass(g_weapon, netclass, 128);

            //does this weapon support upgrades
	        if (FindSendPropInfo(netclass, "m_upgradeBitVec") > 0) {
            
                //get upgrades of primary weapon
	            int upgrades = GetEntProp(g_weapon, Prop_Send, "m_upgradeBitVec");

                //does primary weapon already have laser sight
	            if (was_laser_removed && !(upgrades & WEAPON_UPGRADE_FLAG_LASER)){
                    
                    //add laser sight to primary weapon
	                SetEntProp(g_weapon, Prop_Send, "m_upgradeBitVec", upgrades | WEAPON_UPGRADE_FLAG_LASER);

                    was_laser_removed = false;
                }
            }
        }
    }
    return Plugin_Continue;
}

//has to be delayed after on_player_death()
public void on_client_weapon_drop(int client, int weapon)
{
    g_client = client;
    g_weapon = weapon;
    CreateTimer(0.1, on_client_weapon_drop_delayed);
}

public Action on_client_weapon_drop_delayed(Handle timer)
{
    //dont remove laser sight when player dies
    if (player_death) {
        player_death = false;
        return Plugin_Continue;
    }

	if (g_client > 0 && IsClientInGame(g_client) && GetClientTeam(g_client) == TEAM_SURVIVORS && g_weapon > 0 && IsValidEntity(g_weapon)) {
	    char netclass[128];
	    GetEntityNetClass(g_weapon, netclass, 128);

        //this weapon does not support upgrades
	    if (FindSendPropInfo(netclass, "m_upgradeBitVec") > 0) {
            
            //get upgrades of dropped weapon
	        int upgrades = GetEntProp(g_weapon, Prop_Send, "m_upgradeBitVec");

            //does weapon have laser sight
	        if (upgrades & WEAPON_UPGRADE_FLAG_LASER) {
                
                //remove laser sight from weapon
	            SetEntProp(g_weapon, Prop_Send, "m_upgradeBitVec", upgrades ^ WEAPON_UPGRADE_FLAG_LASER);
                
                was_laser_removed = true;
            }
        }
    }
    return Plugin_Continue;
}
