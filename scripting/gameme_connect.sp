#pragma semicolon 1
#include <zephstocks>
#include <EasyTrie>
#include <EasyHTTP>

#define PLUGIN_VERSION			  "1.0.0"
public Plugin myinfo = {
	name = "GameMe Connect Message",
	author = "Mitchell",
	description = "A Simple plugin that shows gameme information when connecting.",
	version = PLUGIN_VERSION,
	url = "http://mtch.tech"
};

#define CURL_AVAILABLE()		(GetFeatureStatus(FeatureType_Native, "curl_easy_init") == FeatureStatus_Available)
#define SOCKET_AVAILABLE()		(GetFeatureStatus(FeatureType_Native, "SocketCreate") == FeatureStatus_Available)
#define STEAMTOOLS_AVAILABLE()	(GetFeatureStatus(FeatureType_Native, "Steam_CreateHTTPRequest") == FeatureStatus_Available)
#define STEAMWORKS_AVAILABLE()	(GetFeatureStatus(FeatureType_Native, "SteamWorks_CreateHTTPRequest") == FeatureStatus_Available)
#define EXTENSION_ERROR		"This plugin requires one of the cURL, Socket, SteamTools, or SteamWorks extensions to function."
#define DEFFORMAT "{03}{name}{01} connected. (#{04}{rank}{01}, K{0B}{kills}{01}, D{0F}{deaths}{01}, T{10}{ftime}{01})"
ConVar hEnable;
ConVar hRedirect;
ConVar hAccount;
ConVar hFormat;
ConVar hFlag;
ConVar hGame;
bool bEnable = true;
char sRedirect[255] = "";
char sAccount[32] = "";
char sFormat[512] = DEFFORMAT;
int iFlagBits = 2;
char sGame[12] = "";
int preferedExt = 0; // Steamtools = 0
bool g_bSteamLoaded = false;

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) {
	// cURL
	MarkNativeAsOptional("curl_OpenFile");
	MarkNativeAsOptional("curl_slist");
	MarkNativeAsOptional("curl_slist_append");
	MarkNativeAsOptional("curl_easy_init");
	MarkNativeAsOptional("curl_easy_setopt_int_array");
	MarkNativeAsOptional("curl_easy_setopt_handle");
	MarkNativeAsOptional("curl_easy_setopt_string");
	MarkNativeAsOptional("curl_easy_perform_thread");
	MarkNativeAsOptional("curl_easy_strerror");
	MarkNativeAsOptional("curl_httppost");
	MarkNativeAsOptional("curl_formadd");
	MarkNativeAsOptional("curl_easy_setopt_function");
	MarkNativeAsOptional("curl_easy_setopt_int");
	MarkNativeAsOptional("curl_load_opt");
	MarkNativeAsOptional("curl_get_error_buffer");
	
	// Socket
	MarkNativeAsOptional("SocketCreate");
	MarkNativeAsOptional("SocketSetArg");
	MarkNativeAsOptional("SocketSetOption");
	MarkNativeAsOptional("SocketConnect");
	MarkNativeAsOptional("SocketSend");
	
	// SteamTools
	MarkNativeAsOptional("Steam_CreateHTTPRequest");
	MarkNativeAsOptional("Steam_SetHTTPRequestHeaderValue");
	MarkNativeAsOptional("Steam_SendHTTPRequest");
	MarkNativeAsOptional("Steam_WriteHTTPResponseBody");
	MarkNativeAsOptional("Steam_ReleaseHTTPRequest");
	MarkNativeAsOptional("Steam_SetHTTPRequestGetOrPostParameter");
	MarkNativeAsOptional("Steam_GetHTTPResponseBodySize");
	MarkNativeAsOptional("Steam_GetHTTPResponseBodyData");
	
	return APLRes_Success;
}

public OnPluginStart() {
	preferedExt = getPreferedExt();
	if(preferedExt == -1) {
		SetFailState(EXTENSION_ERROR);
	}
	
	hEnable = CreateConVar("sm_gmconnect_enable", "1", "Enable/Disable this plugin",  FCVAR_PLUGIN);
	hRedirect = CreateConVar("sm_gmconnect_redirect", "http://mtch.tech/gameme/gamemeconnect.php", "Link to the PHP script, hosted on your site",  FCVAR_PLUGIN);
	hAccount = CreateConVar("sm_gmconnect_account", "disc-ff", "The account",  FCVAR_PLUGIN);
	hFormat = CreateConVar("sm_gmconnect_format", DEFFORMAT, "The displayed message",  FCVAR_PLUGIN);
	hFlag = CreateConVar("sm_gmconnect_flag", "b", "Flag required to see the connect message",  FCVAR_PLUGIN);
	hGame = CreateConVar("sm_gmconnect_game", "", "Game to look up; Tf2- 'tf2', CSGO- 'csgo'.",  FCVAR_PLUGIN);
	HookConVarChange(hEnable, OnConVarChange);
	HookConVarChange(hRedirect, OnConVarChange);
	HookConVarChange(hAccount, OnConVarChange);
	HookConVarChange(hFormat, OnConVarChange);
	HookConVarChange(hFlag, OnConVarChange);
	HookConVarChange(hGame, OnConVarChange);
	AutoExecConfig(true, "GameMeConnect");
	

	CreateConVar("sm_gmconnect_version", PLUGIN_VERSION, "GameMe Connect Message Version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_DONTRECORD);
	
	RegConsoleCmd("sm_testconnect", Command_Connect);
	RegConsoleCmd("sm_testrequest", Command_Request);
}

public Action Command_Connect(int client, int args) {
	if(client > 0){
		formatAndDisplay(client, "16;693591;6703;3325;776");
	}
	return Plugin_Handled;
}

public Action Command_Request(int client, int args) {
	if(client > 0){
		RequestPlayerInfo(client);
	}
	return Plugin_Handled;
}

public OnConVarChange(ConVar convar, const char[] oldValue, const char[] newValue){
	if(convar == hEnable) {
		bEnable = StringToInt(newValue) != 0;
	} else if(convar == hRedirect) {
		strcopy(sRedirect, sizeof(sRedirect), newValue);
	} else if(convar == hAccount) {
		strcopy(sAccount, sizeof(sAccount), newValue);
	} else if(convar == hFormat) {
		strcopy(sFormat, sizeof(sFormat), newValue);
	} else if(convar == hFlag) {
		iFlagBits = ReadFlagString(newValue);
	} else if(convar == hGame) {
		strcopy(sGame, sizeof(sGame), newValue);
	}
}

public void OnClientAuthorized(int client, const char[] auth) {
	if(!bEnable || IsFakeClient(client) || StrEqual(sGame, "", false)) return;
	RequestPlayerInfo(client);
}

public void formatAndDisplay(int client, const char[] response) {
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
	ReplaceColors(sFormattedStr, sizeof(sFormattedStr));
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

public void ReplaceColors(char[] buffer, size) {
	char tempString[6];
	char tempChar[6];
	for(int i=1;i<=16;i++) {
		Format(tempString, 6, "{%02X}", i);
		Format(tempChar, 6, "%c", i);
		ReplaceString(buffer, size, tempString, tempChar, false);
	}
}

public void formatTime(float time, char[] buffer) {
	int Days = RoundToFloor(time / 60.0 / 60.0 / 24.0) % 60;
	int Hours = RoundToFloor(time / 60.0 / 60.0) % 60;
	int Mins = RoundToFloor(time / 60.0) % 60;
	int Secs = RoundToFloor(time) % 60;
	if(Days > 0) Format(buffer, 64, "%02d:%02d:%02d:%02d", Days, Hours, Mins, Secs);
	else if(Hours > 0) Format(buffer, 64, "%02d:%02d:%02d", Hours, Mins, Secs);
	else if(Mins > 0) Format(buffer, 64, "%02d:%02d", Mins, Secs);
	else if(Secs > 0) Format(buffer, 64, "%02ds", Secs);
	else Format(buffer, 64, "NEW");
}

public int getPreferedExt() {
	PrintToServer("getPreferedExt");
	if(STEAMWORKS_AVAILABLE()) {
		if (SteamWorks_IsLoaded()) {
			return 0;
		}
	} else if(STEAMTOOLS_AVAILABLE()) {
		if(g_bSteamLoaded) {
			return 1;
		}
	} else if(CURL_AVAILABLE()) {
		return 2;
	} else if(SOCKET_AVAILABLE()) {
		return 3;
	}
	return 10;
}

public void RequestPlayerInfo(client) {
	// Create params
	char sSteamId[32];
	int userId = GetClientUserId(client);
	GetClientAuthId(client, AuthId_Steam2, sSteamId, sizeof(sSteamId));
	new Handle:m_hParams = EasyHTTP_CreateParams();
	EasyHTTP_WriteParamString(m_hParams, "a", "disc-ff");
	EasyHTTP_WriteParamString(m_hParams, "g", "csgo");
	EasyHTTP_WriteParamString(m_hParams, "id", sSteamId);
	// Request the admin state of the client
	if(!EasyHTTP(sRedirect, POST, m_hParams, APICallback, userId))
	{
		LogError("Failed to send API query, because the EasyHTTP request failed.");
	}
	PrintToServer("Request Sent!");
	EasyHTTP_DestroyParams(m_hParams);
}

public APICallback(any:data, const String:buffer[], bool:success) {
	PrintToServer(buffer);
	formatAndDisplay(GetClientOfUserId(data), buffer);
}