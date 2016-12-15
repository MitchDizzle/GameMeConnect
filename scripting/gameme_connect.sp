#pragma semicolon 1
#include <regex>
#include <SteamWorks>
#define PLUGIN_VERSION			  "1.2.2"
public Plugin myinfo = {
	name = "GameMe Connect Message",
	author = "Mitchell",
	description = "A Simple plugin that shows gameme information when connecting.",
	version = PLUGIN_VERSION,
	url = "http://mtch.tech"
};

#define DEFFORMAT "{03}{name}{01} connected. (#{04}{rank}{01}, K{0B}{kills}{01}, D{0F}{deaths}{01}, T{10}{time}{01})"
#define ERRORFORMAT "{03}{name}{01} connected."
ConVar hEnable;
ConVar hRedirect;
ConVar hAccount;
ConVar hFormat[2];
ConVar hFlag;
ConVar hGame;
ConVar hMethod;
char sRedirect[255] = "";
char sAccount[32] = "";
char sFormat[2][512];
int iFlagBits = 2;
char sGame[12] = "";
int iMthd = 0;
#define MAXPOST 10
char postList[MAXPOST][2][24];
char postCount;

public OnPluginStart() {
	CreateConVar("sm_gmconnect_version", PLUGIN_VERSION, "GameMe Connect Message Version", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_DONTRECORD);
	hEnable = CreateConVar("sm_gmconnect_enable", "1", "Enable/Disable this plugin");
	hRedirect = CreateConVar("sm_gmconnect_redirect", "", "Link to the PHP script, hosted on your site");
	hAccount = CreateConVar("sm_gmconnect_account", "", "The account");
	hFormat[0] = CreateConVar("sm_gmconnect_format", DEFFORMAT, "The displayed message");
	hFormat[1] = CreateConVar("sm_gmconnect_error_format", ERRORFORMAT, "The displayed message when a player is new to the server or has an error with retireving the player's info.");
	hFlag = CreateConVar("sm_gmconnect_flag", "", "Flag required to see the connect message");
	hGame = CreateConVar("sm_gmconnect_game", "", "Game to look up; Tf2- 'tf2', CSGO- 'csgo'.");
	hMethod = CreateConVar("sm_gmconnect_method", "0", "When the message is displayed: 0 - Auth, 1 - First Player_Spawn");

	HookConVarChange(hEnable, OnConVarChange);
	HookConVarChange(hRedirect, OnConVarChange);
	HookConVarChange(hAccount, OnConVarChange);
	HookConVarChange(hFormat[0], OnConVarChange);
	HookConVarChange(hFormat[1], OnConVarChange);
	HookConVarChange(hFlag, OnConVarChange);
	HookConVarChange(hGame, OnConVarChange);
	HookConVarChange(hMethod, OnConVarChange);

	AutoExecConfig(true, "GameMeConnect");

	HookEvent("player_spawn", Event_Spawn);
	
	RegAdminCmd("sm_gmc_test", Cmd_GMCTest, ADMFLAG_RCON);
}

public void OnConfigsExecuted() {
	GetConVarString(hRedirect, sRedirect, sizeof(sRedirect));
	GetConVarString(hAccount, sAccount, sizeof(sAccount));
	
	char tempString[512];
	GetConVarString(hFormat[0], tempString, sizeof(sFormat[]));
	parseFields(tempString, sFormat[0], sizeof(sFormat[]));
	
	GetConVarString(hFormat[1], tempString, sizeof(tempString));
	parseColors(tempString, tempString, sizeof(tempString));
	strcopy(sFormat[1], sizeof(sFormat[]), tempString);
	
	GetConVarString(hGame, sGame, sizeof(sGame));
	iMthd = GetConVarInt(hMethod);
	GetConVarString(hFlag, tempString, sizeof(tempString));
	iFlagBits = ReadFlagString(tempString);
}

public Action Cmd_GMCTest(int client, int args) {
	if(args < 1) {
		if(client == 0) {
			ReplyToCommand(client, "Use 'sm_gmc_test STEAMID_X:Y:ZZZ' for a generic test, or insert authid.");
			return Plugin_Handled;
		}
		RequestPlayerInfo(client);
		return Plugin_Handled;
	}
	
	char argString[58];
	GetCmdArg(1, argString, sizeof(argString));
	RequestSteamId(GetClientUserId(client), argString);
	return Plugin_Handled;
}

public void OnConVarChange(ConVar convar, const char[] oldValue, const char[] newValue){
	if(convar == hRedirect) {
		strcopy(sRedirect, sizeof(sRedirect), newValue);
	} else if(convar == hAccount) {
		strcopy(sAccount, sizeof(sAccount), newValue);
	} else if(convar == hFormat[0]) {
		char tempString[512];
		parseFields(newValue, tempString, sizeof(tempString));
		strcopy(sFormat[0], sizeof(sFormat[]), tempString);
	} else if(convar == hFormat[1]) {
		char tempString[512];
		parseColors(newValue, tempString, sizeof(tempString));
		strcopy(sFormat[1], sizeof(sFormat[]), tempString);
	} else if(convar == hFlag) {
		iFlagBits = ReadFlagString(newValue);
	} else if(convar == hGame) {
		strcopy(sGame, sizeof(sGame), newValue);
	} else if(convar == hMethod) {
		iMthd = StringToInt(newValue);
	}
}

public void OnClientAuthorized(int client, const char[] auth) {
	if(!hEnable.BoolValue || IsFakeClient(client) || StrEqual(sGame, "", false) || iMthd != 0) {
		return;
	}
	RequestPlayerInfo(client);
}

public Action Event_Spawn(Event event, const char[] name, bool dontBroadcast) {
	if(!hEnable.BoolValue || StrEqual(sGame, "", false) || iMthd != 1) return Plugin_Continue;
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(client > 0 && !IsFakeClient(client) && GetClientTeam(client) == 0) {
		RequestPlayerInfo(client);
	}
	return Plugin_Continue;
}

public void formatAndDisplay(int client, KeyValues kv) {
	char sFormattedStr[512];
	char tempString[64];
	if(kv.JumpToKey("error", false)) {
		Format(sFormattedStr, sizeof(sFormattedStr), "%s%s", StrEqual(sGame, "csgo") ? " " : "", sFormat[1]);
		if(StrContains(sFormattedStr, "{name}", false) >= 0) {
			//Name is one of the only parameters that can be used.
			GetClientName(client, tempString, sizeof(tempString));
			ReplaceString(sFormattedStr, sizeof(sFormattedStr), "{name}", tempString, false);
		}
	} else {
		Format(sFormattedStr, sizeof(sFormattedStr), "%s%s", StrEqual(sGame, "csgo") ? " " : "", sFormat[0]);
		for(int i = 0; i < postCount; i++)	{
			if(StrEqual(postList[i][0], "{name}", false)) {
				GetClientName(client, tempString, sizeof(tempString));
			} else {
				kv.GetString(postList[i][1], tempString, sizeof(tempString), "NULL");
			}
			if(StrEqual(postList[i][0], "{time}", false)) {
				formatTime(StringToFloat(tempString), tempString);
			}
			ReplaceString(sFormattedStr, sizeof(sFormattedStr), postList[i][0], tempString, false);
		}
	}
	PrintToServer("%s", sFormattedStr);
	if(iFlagBits == 0) {
		PrintToChatAll(sFormattedStr);
	} else {
		for(new i = 1; i <= MaxClients; i++) {
			if(IsClientInGame(i) && GetUserFlagBits(i)&iFlagBits) {
				PrintToChat(i, sFormattedStr);
			}
		}
	}
}

public void RequestPlayerInfo(int client) {
	char sSteamId[32];
	GetClientAuthId(client, AuthId_Steam2, sSteamId, sizeof(sSteamId));
	RequestSteamId(GetClientUserId(client), sSteamId);
}

public void RequestSteamId(userId, const char[] steamId) {
	// Create params
	Handle hRequest = SteamWorks_CreateHTTPRequest(k_EHTTPMethodPOST, sRedirect);
	if(hRequest == INVALID_HANDLE) {
		LogError("ERROR hRequest(%i): %s", hRequest, sRedirect);
		return;
	}
	SteamWorks_SetHTTPRequestHeaderValue(hRequest, "Pragma", "no-cache");
	SteamWorks_SetHTTPRequestHeaderValue(hRequest, "Cache-Control", "no-cache");
	SteamWorks_SetHTTPRequestGetOrPostParameter(hRequest, "a", sAccount);
	SteamWorks_SetHTTPRequestGetOrPostParameter(hRequest, "g", sGame);
	SteamWorks_SetHTTPRequestGetOrPostParameter(hRequest, "id", steamId);
	for(int i = 0; i < postCount; i++)	{
		if(!StrEqual(postList[i][0], "") && !StrEqual(postList[i][0], "{name}", false)) {
			SteamWorks_SetHTTPRequestGetOrPostParameter(hRequest, postList[i][1], "");
		}
	}
	SteamWorks_SetHTTPCallbacks(hRequest, OnSteamWorksHTTPComplete);
	SteamWorks_SetHTTPRequestContextValue(hRequest, userId);
	SteamWorks_SendHTTPRequest(hRequest);
}

public int OnSteamWorksHTTPComplete(Handle hRequest, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode, any data) {
	int client = GetClientOfUserId(data);
	if(client <= 0) {
		return;
	}
	if (bRequestSuccessful && eStatusCode == k_EHTTPStatusCode200OK) {
		int length = 512;
		if(SteamWorks_GetHTTPResponseBodySize(hRequest, length) && length > 1024) {
			length = 1024;
		}
		char[] response = new char[length];
		SteamWorks_GetHTTPResponseBodyData(hRequest, response, length);
		if(StrContains(response, "<br />") >= 0) {
			LogError("Steamworks client request failed, returned error:");
			LogError(response);
			return;
		}

		//Convert to KeyValue
		KeyValues tempKV = CreateKeyValues("gmc");
		if(StringToKeyValues(tempKV, response, "gmc")) {
			formatAndDisplay(client, tempKV);
		}
		delete tempKV;
	} else {
		char sError[256];
		FormatEx(sError, sizeof(sError), "SteamWorks error (status code %i). Request successful: %s", _:eStatusCode, bRequestSuccessful ? "True" : "False");
		LogError(sError);
	}
	delete hRequest;
}

public bool parseFields(const char[] buffer, char[] exportString, int size) {
	static Regex staticRegex;
	if(!staticRegex) {
		char errorString[32];
		staticRegex = new Regex("{[a-zA-Z]+}", PCRE_UTF8|PCRE_EXTENDED|PCRE_UNGREEDY|PCRE_DOLLAR_ENDONLY, errorString, sizeof(errorString));
		if(!staticRegex) {
			SetFailState("Could not generate RegEx! %s", errorString);
		}
	}
	postCount = 0;
	char tempString[32];
	char tempBuffer[512];
	strcopy(tempBuffer, sizeof(tempBuffer), buffer);
	int matchCount = staticRegex.Match(tempBuffer);
	while(matchCount != 0) {
		for(int i = 0; i < matchCount; i++) {
			if(GetRegexSubString(staticRegex, i, tempString, 32)) {
				ReplaceString(tempBuffer, sizeof(tempBuffer), tempString, "", false);
				strcopy(postList[postCount][0], 24, tempString);
				ReplaceString(tempString, 24, "{", "");
				ReplaceString(tempString, 24, "}", "");
				strcopy(postList[postCount][1], 24, tempString);
				postCount++;
			}
		}
		matchCount = staticRegex.Match(tempBuffer);
	}
	parseColors(buffer, exportString, size);
}

public void parseColors(const char[] buffer, char[] exportString, int size) {
	char tempString[6];
	char tempChar[6];
	strcopy(exportString, size, buffer);
	for(int i=1;i<=16;i++) {
		Format(tempString, 6, "{%02X}", i);
		Format(tempChar, 6, "%c", i);
		ReplaceString(exportString, size, tempString, tempChar, false);
	}
}

public void formatTime(float time, char[] buffer) {
	int Days = RoundToFloor(time / 60.0 / 60.0 / 24.0) % 60;
	int Hours = RoundToFloor(time / 60.0 / 60.0) % 60;
	int Mins = RoundToFloor(time / 60.0) % 60;
	int Secs = RoundToFloor(time) % 60;
	if(Days > 0) Format(buffer, 64, "%d:%02d:%02d:%02d", Days, Hours, Mins, Secs);
	else if(Hours > 0) Format(buffer, 64, "%02d:%02d:%02d", Hours, Mins, Secs);
	else if(Mins > 0) Format(buffer, 64, "%02d:%02d", Mins, Secs);
	else if(Secs > 0) Format(buffer, 64, "%02ds", Secs);
	else Format(buffer, 64, "NEW");
}
