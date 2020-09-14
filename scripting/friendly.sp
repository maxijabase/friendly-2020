/* Dependencies and Defines */

#include <sourcemod>
#include <sdkhooks>
#include <tf2_stocks>

#include "include/multicolors"
#include "include/soap_tournament"
#include "include/autoexecconfig"

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.0"

#define PREFIX "{green}[Friendly]{default}"

#define NORMAL 2
#define BUDDHA 1
#define GODMODE 0

/* Pugin Info */

public Plugin myinfo =  {
	
	name = "[TF2] Friendly", 
	author = "ampere", 
	description = "Make your players able to go friendly!", 
	version = PLUGIN_VERSION, 
	url = "https://github.com/ratawar"
	
};

/* Globals */

bool isFriendly[MAXPLAYERS + 1];
bool cmdAllowed = true;
bool cmdAllowedTimer[MAXPLAYERS + 1];
bool isInSpawn[MAXPLAYERS + 1];
bool wasAdvertised[MAXPLAYERS + 1];

ConVar cvEnable, cvCooldown, cvTranslucid, cvCanJump, cvRegen, cvOnlySpawn, cvAdvertise;
Handle hTimer;

/* Engine Check */

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	
	EngineVersion g_engineversion = GetEngineVersion();
	if (g_engineversion != Engine_TF2) {
		
		SetFailState("This plugin was made for use with Team Fortress 2 only.");
		
	}
	
}

/* Plugin Start */

public void OnPluginStart() {
	
	AutoExecConfig_SetCreateFile(true);
	AutoExecConfig_SetFile("Friendly");
	
	CreateConVar("sm_friendly_version", PLUGIN_VERSION, "Plugin Version.");
	cvEnable = CreateConVar("sm_friendly_enable", "1", "Enable the plugin", FCVAR_DONTRECORD | FCVAR_NOTIFY);
	
	cvCooldown = AutoExecConfig_CreateConVar("sm_friendly_cooldown", "3", "Friendly command cooldown (set to 0 for no cooldown)");
	cvTranslucid = AutoExecConfig_CreateConVar("sm_friendly_translucid", "1", "1- Set friendly players translucid | 0- Don't.", _, true, 0.0, true, 1.0);
	cvCanJump = AutoExecConfig_CreateConVar("sm_friendly_jump", "1", "1- Friendly players can jump | 0- They can't.", _, true, 0.0, true, 1.0);
	cvRegen = AutoExecConfig_CreateConVar("sm_friendly_regen", "1", "1- Friendly players regen ammo | 0- They don't.", _, true, 0.0, true, 1.0);
	cvOnlySpawn = AutoExecConfig_CreateConVar("sm_friendly_onlyspawn", "0", "1- Players can only become friendlies in spawn | 0- Players can become friendlies anywhere.", _, true, 0.0, true, 1.0);
	cvAdvertise = AutoExecConfig_CreateConVar("sm_friendly_advertise", "1", "1- Players receive information about the plugin if they attack a friendly player (only the first time they attack, not every time) | 0- They don't.", _, true, 0.0, true, 1.0);
	
	RegConsoleCmd("sm_friendly", CMD_Friendly, "Makes you unable to deal and receive damage.");
	
	HookEvent("player_death", OnPlayerRespawn);
	HookEvent("player_spawn", OnPlayerRespawn);
	
	cvEnable.AddChangeHook(OnEnableChange);
	cvTranslucid.AddChangeHook(OnTranslucidChange);
	cvCanJump.AddChangeHook(OnCanJumpChange);
	cvRegen.AddChangeHook(OnRegenChange);
	
	for (int i = 1; i <= MaxClients; i++) {
		
		if (IsClientInGame(i)) {
			
			DisableFriendly(i);
			OnClientPostAdminCheck(i);
			
		}
		
	}
	
	LoadTranslations("friendly.phrases");
	
	AutoExecConfig_CleanFile();
	AutoExecConfig_ExecuteFile();
	
}

public void OnMapStart() {
	
	CreateRegenTimer();
	
	int ent = -1;
	while ((ent = FindEntityByClassname(ent, "func_respawnroom")) != INVALID_ENT_REFERENCE) {
		
		SDKHook(ent, SDKHook_Touch, SpawnTouch);
		SDKHook(ent, SDKHook_EndTouch, SpawnEndTouch);
		
	}
	
}

/* Client Connection */

public void OnClientPostAdminCheck(int client) {
	
	wasAdvertised[client] = false;
	isInSpawn[client] = false;
	isFriendly[client] = false;
	cmdAllowedTimer[client] = true;
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	
}

/* Command */

public Action CMD_Friendly(int client, int args) {
	
	if (!cvEnable.BoolValue || !cmdAllowed) {
		
		CReplyToCommand(client, "%s %t", PREFIX, "Not Allowed");
		return Plugin_Handled;
		
	}
	
	if (!IsPlayerAlive(client)) {
		
		CReplyToCommand(client, "%s %t", PREFIX, "Must Be Alive");
		return Plugin_Handled;
		
	}
	
	if (cvOnlySpawn.BoolValue && !isInSpawn[client]) {
		
		CReplyToCommand(client, "%s %t", PREFIX, "Only Spawn");
		return Plugin_Handled;
		
	}
	
	if (cvCooldown.IntValue != 0) {
		
		if (!cmdAllowedTimer[client]) {
			
			CReplyToCommand(client, "%s %t", PREFIX, "Cooldown", cvCooldown.IntValue);
			return Plugin_Handled;
			
		}
		
	}
	
	cmdAllowedTimer[client] = false;
	CreateTimer(cvCooldown.FloatValue, AllowCommand, client);
	
	isFriendly[client] = !isFriendly[client];
	
	isFriendly[client] ? EnableFriendly(client) : DisableFriendly(client);
	
	CReplyToCommand(client, "%s %t", PREFIX, (isFriendly[client]) ? "Friendly Enabled" : "Friendly Disabled");
	return Plugin_Handled;
	
}

/* Damage Hook Callback */

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom) {
	
	if (victim == attacker) {
		
		return Plugin_Continue;
		
	}
	
	if (cvAdvertise.BoolValue && isFriendly[victim] && !wasAdvertised[attacker]) {
		
		CPrintToChat(attacker, "%s %t", PREFIX, "Advertisement", victim);
		wasAdvertised[attacker] = true;
		
	}
	
	if (isFriendly[victim] || isFriendly[attacker]) {
		
		damage = 0.0;
		return Plugin_Changed;
		
	}
	
	return Plugin_Continue;
	
}

/* Friendly Disablers */

public void OnPlayerRespawn(Handle event, const char[] name, bool dontBroadcast) {
	
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	DisableFriendly(client);
	
}

/* ConVar Change Hook Callbacks */

public void OnEnableChange(ConVar convar, const char[] oldValue, const char[] newValue) {
	
	if (!StringToInt(newValue)) {
		
		for (int i = 1; i <= MaxClients; i++) {
			
			if (IsClientInGame(i)) {
				
				DisableFriendly(i);
				
			}
			
		}
		
	}
	
}

public void OnTranslucidChange(ConVar convar, const char[] oldValue, const char[] newValue) {
	
	for (int i = 1; i <= MaxClients; i++) {
		
		if (IsClientInGame(i) && isFriendly[i]) {
			
			SetEntityRenderMode(i, StringToInt(newValue) == 0 ? RENDER_NORMAL : RENDER_TRANSCOLOR);
			SetEntityRenderColor(i, 255, 255, 255, StringToInt(newValue) == 0 ? 255 : 128);
			
		}
		
	}
	
}

public void OnCanJumpChange(ConVar convar, const char[] oldValue, const char[] newValue) {
	
	for (int i = 1; i <= MaxClients; i++) {
		
		if (IsClientInGame(i) && isFriendly[i]) {
			
			SetEntProp(i, Prop_Data, "m_takedamage", StringToInt(newValue) == 0 ? GODMODE : BUDDHA, 1);
			
		}
		
	}
	
}

public void OnRegenChange(ConVar convar, const char[] oldValue, const char[] newValue) {
	
	if (!StringToInt(newValue)) {
		
		delete hTimer;
		
	}
	
	else {
		
		CreateRegenTimer();
		
	}
	
}

/* SOAP TF2DM Support */

public void SOAP_StartDeathMatching() {
	
	cmdAllowed = true;
	
}

public void SOAP_StopDeathMatching() {
	
	cmdAllowed = false;
	
	for (int i = 1; i <= MaxClients; i++) {
		
		if (IsClientInGame(i)) {
			
			DisableFriendly(i);
			
		}
	}
	
}

/* Command Allower */

public Action AllowCommand(Handle timer, int client) {
	
	cmdAllowedTimer[client] = true;
	
}

/* Regen Function */

public void CreateRegenTimer() {
	
	hTimer = CreateTimer(2.0, Regen, TIMER_REPEAT);
	
}

public Action Regen(Handle timer) {
	
	for (int i = 1; i <= MaxClients; i++) {
		
		if (IsClientInGame(i) && isFriendly[i]) {
			
			TF2_RegeneratePlayer(i);
			
		}
		
	}
	
}

/* Spawn Hook */

public void OnEntityCreated(int entity, const char[] classname) {
	
	if (!IsValidEntity(entity)) {
		
		return;
		
	}
	
	if (StrEqual(classname, "func_respawnroom", false)) {
		
		SDKHook(entity, SDKHook_Touch, SpawnTouch);
		SDKHook(entity, SDKHook_EndTouch, SpawnEndTouch);
		
		return;
		
	}
	
}

public Action SpawnTouch(int entity, int client) {
	
	if (!IsValidClient(client)) {
		
		return Plugin_Continue;
		
	}
	
	if (GetEntProp(entity, Prop_Send, "m_iTeamNum") == GetClientTeam(client)) {
		
		isInSpawn[client] = true;
		
	}
	
	return Plugin_Continue;
	
}

public Action SpawnEndTouch(int entity, int client) {
	
	if (!IsValidClient(client)) {
		
		return Plugin_Continue;
		
	}
	
	isInSpawn[client] = false;
	
	return Plugin_Continue;
	
}

/* Friendly Functions */

public void DisableFriendly(int client) {
	
	isFriendly[client] = false;
	
	SetEntProp(client, Prop_Data, "m_takedamage", NORMAL, 1);
	SetEntityRenderMode(client, RENDER_NORMAL);
	
}

public void EnableFriendly(int client) {
	
	isFriendly[client] = true;
	
	SetEntProp(client, Prop_Data, "m_takedamage", (cvCanJump.BoolValue) ? BUDDHA : GODMODE, 1);
	
	if (cvTranslucid.BoolValue) {
		
		SetEntityRenderMode(client, RENDER_TRANSCOLOR);
		SetEntityRenderColor(client, 255, 255, 255, 128);
		
	}
	
}

/* Stock Helpers */

stock bool IsValidClient(int client) {
	
	if (client > 4096) {
		
		client = EntRefToEntIndex(client);
		
	}
	
	if (client < 1 || client > MaxClients || !IsClientInGame(client) || IsFakeClient(client) || GetEntProp(client, Prop_Send, "m_bIsCoaching")) {
		
		return false;
		
	}
	
	return true;
	
} 