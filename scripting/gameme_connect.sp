#pragma semicolon 1
#include <regex>
#include <SteamWorks>
#define PLUGIN_VERSION			  "1.2.1"
public Plugin myinfo = {
	name = "GameMe Connect Message",
	author = "Mitchell",
	description = "A Simple plugin that shows gameme information when connecting.",
	version = PLUGIN_VERSION,
	url = "http://mtch.tech"
};

#define DEFFORMAT "{03}{name}{01} connected. (#{04}{rank}{01}, K{0B}{kills}{01}, D{0F}{deaths}{01}, T{10}{time}{01})"
ConVar hEnable;
ConVar hRedirect;
ConVar hAccount;
ConVar hFormat;
ConVar hFlag;
ConVar hGame;
ConVar hMethod;
bool bEnable = true;
char sRedirect[255] = "";
char sAccount[32] = "";
char sFormat[512] = DEFFORMAT;
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
	hFormat = CreateConVar("sm_gmconnect_format", DEFFORMAT, "The displayed message");
	hFlag = CreateConVar("sm_gmconnect_flag", "", "Flag required to see the connect message");
	hGame = CreateConVar("sm_gmconnect_game", "", "Game to look up; Tf2- 'tf2', CSGO- 'csgo'.");
	hMethod = CreateConVar("sm_gmconnect_method", "0", "When the message is displayed: 0 - Auth, 1 - First Player_Spawn");

	HookConVarChange(hEnable, OnConVarChange);
	HookConVarChange(hRedirect, OnConVarChange);
	HookConVarChange(hAccount, OnConVarChange);
	HookConVarChange(hFormat, OnConVarChange);
	HookConVarChange(hFlag, OnConVarChange);
	HookConVarChange(hGame, OnConVarChange);
	HookConVarChange(hMethod, OnConVarChange);

	AutoExecConfig(true, "GameMeConnect");

	char tempString[512];
	GetConVarString(hRedirect, sRedirect, sizeof(sRedirect));
	GetConVarString(hAccount, sAccount, sizeof(sAccount));
	GetConVarString(hFormat, tempString, sizeof(tempString));
	parseFields(tempString, sFormat, sizeof(sFormat));
	GetConVarString(hGame, sGame, sizeof(sGame));
	iMthd = GetConVarInt(hMethod);
	GetConVarString(hFlag, tempString, sizeof(tempString));
	iFlagBits = ReadFlagString(tempString);

	HookEvent("player_spawn", Event_Spawn);
	
	RegAdminCmd("sm_gmc_test", Cmd_GMCTest, ADMFLAG_RCON);
}

public Action Cmd_GMCTest(int client, int args) {
	RequestPlayerInfo(client);
	return Plugin_Handled;
}

public void OnConVarChange(ConVar convar, const char[] oldValue, const char[] newValue){
	if(convar == hEnable) {
		bEnable = StringToInt(newValue) != 0;
	} else if(convar == hRedirect) {
		strcopy(sRedirect, sizeof(sRedirect), newValue);
	} else if(convar == hAccount) {
		strcopy(sAccount, sizeof(sAccount), newValue);
	} else if(convar == hFormat) {
		strcopy(sFormat, sizeof(sFormat), newValue);
		parseFields(newValue, sFormat, sizeof(sFormat));
	} else if(convar == hFlag) {
		iFlagBits = ReadFlagString(newValue);
	} else if(convar == hGame) {
		strcopy(sGame, sizeof(sGame), newValue);
	} else if(convar == hMethod) {
		iMthd = StringToInt(newValue);
	}
}

public void OnClientAuthorized(int client, const char[] auth) {
	if(!bEnable || IsFakeClient(client) || StrEqual(sGame, "", false) || iMthd != 0) {
		return;
	}
	RequestPlayerInfo(client);
}

public Action Event_Spawn(Event event, const char[] name, bool dontBroadcast) {
	if(!bEnable || StrEqual(sGame, "", false) || iMthd != 1) return Plugin_Continue;
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(client > 0 && !IsFakeClient(client) && GetClientTeam(client) == 0) {
		RequestPlayerInfo(client);
	}
	return Plugin_Continue;
}

public void formatAndDisplay(int client, KeyValues kv) {
	char sFormattedStr[512];
	Format(sFormattedStr, sizeof(sFormattedStr), "%s%s", StrEqual(sGame, "csgo") ? " " : "", sFormat);
	char tempString[64];
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
	PrintToServer(sFormattedStr);
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

public void formatAndDisplay_OLD(int client, const char[] response) {
	char buffers[5][32];
	ExplodeString(response, ";", buffers, 5, 32);	
	char sFormattedStr[512];
	Format(sFormattedStr, sizeof(sFormattedStr), "%s%s", StrEqual(sGame, "csgo") ? " " : "", sFormat);
	ReplaceString(sFormattedStr, sizeof(sFormattedStr), "{rank}", buffers[0], false);
	ReplaceString(sFormattedStr, sizeof(sFormattedStr), "{kills}", buffers[2], false);
	ReplaceString(sFormattedStr, sizeof(sFormattedStr), "{deaths}", buffers[3], false);
	ReplaceString(sFormattedStr, sizeof(sFormattedStr), "{assists}", buffers[4], false);
	if(StrContains(sFormattedStr, "{ftime}", false) >= 0) {
		char fTime[64];
		formatTime(StringToFloat(buffers[1]), fTime);
		ReplaceString(sFormattedStr, sizeof(sFormattedStr), "{ftime}", fTime, false);
	}
	if(StrContains(sFormattedStr, "{itime}", false) >= 0) {
		ReplaceString(sFormattedStr, sizeof(sFormattedStr), "{itime}", buffers[1], false);
	}
	if(StrContains(sFormattedStr, "{name}", false) >= 0) {
		char clientName[64];
		GetClientName(client, clientName, sizeof(clientName));
		ReplaceString(sFormattedStr, sizeof(sFormattedStr), "{name}", clientName, false);
	}
	PrintToServer(sFormattedStr);
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
	// Create params
	char sSteamId[32];
	int userId = GetClientUserId(client);
	GetClientAuthId(client, AuthId_Steam2, sSteamId, sizeof(sSteamId));
	RequestSteamId(userId, sSteamId);
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
		if(StrContains(response, "error") >= 0 || StrContains(response, "<br />") >= 0) {
			LogError("Steamworks client request failed, returned error:");
			LogError(response);
			return;
		}
		if(StrContains(response, "\"gmc\"") >= 0) {
			//Convert to KeyValue
			KeyValues tempKV = CreateKeyValues("gmc");
			if(StringToKeyValues(tempKV, response, "gmc")) {
				formatAndDisplay(client, tempKV);
			}
			delete tempKV;
		} else {
			formatAndDisplay_OLD(client, response);
			LogError("Something went wrong, try updating the php script.");
		}
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
	strcopy(tempBuffer, sizeof(tempBuffer), exportString);
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
