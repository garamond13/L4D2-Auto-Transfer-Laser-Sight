#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#pragma newdecls required
#pragma semicolon 1

#define VERSION "2.0.1"

#define TEAM_SURVIVORS 2
#define WEAPON_SLOT_PRIMARY 0
#define WEAPON_UPGRADE_FLAG_LASER (1 << 2)

int g_client;
int g_weapon;
bool is_in_equip;

public Plugin myinfo = {
	name = "L4D2 Auto Transfer Laser Sight",
	author = "Garamond",
	description = "Auto transfer laser sight.",
	version = VERSION,
	url = "https://github.com/garamond13/L4D2-Auto-Transfer-Laser-Sight"
};

public void OnPluginStart()
{
	HookEvent("round_end", event_round_end, EventHookMode_Pre);
	HookEvent("map_transition", event_round_end, EventHookMode_Pre);
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_WeaponEquipPost, on_client_weapon_equip);
	SDKHook(client, SDKHook_WeaponDropPost, on_client_weapon_drop);
}

public void OnClientDisconnect(int client)
{
	SDKUnhook(client, SDKHook_WeaponEquipPost, on_client_weapon_equip);
	SDKUnhook(client, SDKHook_WeaponDropPost, on_client_weapon_drop);
}

void on_client_weapon_equip(int client, int weapon)
{
	if (client > 0 && IsClientInGame(client) && GetClientTeam(client) == TEAM_SURVIVORS && IsPlayerAlive(client)) {
		is_in_equip = true;

		// Get primary weapon.
		weapon = GetPlayerWeaponSlot(client, WEAPON_SLOT_PRIMARY);

		if (weapon > 0 && IsValidEntity(weapon)) {
			char netclass[128];
			GetEntityNetClass(weapon, netclass, sizeof(netclass));

			// Does this weapon support upgrades.
			if (FindSendPropInfo(netclass, "m_upgradeBitVec") > 0) {

				// Get upgrades of primary weapon.
				int upgrades = GetEntProp(weapon, Prop_Send, "m_upgradeBitVec");

				// Does primary weapon already have laser sight.
				if (remove_laser(client) && !(upgrades & WEAPON_UPGRADE_FLAG_LASER)) {
    
					// Add laser sight to primary weapon.
					SetEntProp(weapon, Prop_Send, "m_upgradeBitVec", upgrades | WEAPON_UPGRADE_FLAG_LASER);
				
				}
			}
		}
	}
	is_in_equip = false;
}

void on_client_weapon_drop(int client, int weapon)
{
    g_client = client;
    g_weapon = weapon;
    CreateTimer(1.0, invalidate_globals, 0, TIMER_FLAG_NO_MAPCHANGE);
}

bool remove_laser(int client)
{
	if (client == g_client && g_weapon > 0 && IsValidEntity(g_weapon)) {
		char netclass[128];
		GetEntityNetClass(g_weapon, netclass, sizeof(netclass));

		// This weapon does not support upgrades.
		if (FindSendPropInfo(netclass, "m_upgradeBitVec") > 0) {

			// Get upgrades of dropped weapon.
			int upgrades = GetEntProp(g_weapon, Prop_Send, "m_upgradeBitVec");

			// Does weapon have laser sight.
			if (upgrades & WEAPON_UPGRADE_FLAG_LASER) {

				// Remove laser sight from weapon.
				SetEntProp(g_weapon, Prop_Send, "m_upgradeBitVec", upgrades ^ WEAPON_UPGRADE_FLAG_LASER);

				return true;
			}
		}
	}
	return false;
}

Action invalidate_globals(Handle timer)
{
	if (!is_in_equip) {
		g_client = 0;
		g_weapon = 0;
	}
	else
		CreateTimer(1.0, invalidate_globals, 0, TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Continue;
}

Action event_round_end(Event event, const char[] name, bool dontBroadcast)
{
	g_client = 0;
	g_weapon = 0;
	is_in_equip = false;
	return Plugin_Continue;
}

public void OnMapEnd()
{
	g_client = 0;
	g_weapon = 0;
	is_in_equip = false;
}