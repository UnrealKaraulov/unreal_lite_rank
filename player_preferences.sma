//Based on plugin: https://dev-cs.ru/resources/984/ by GM-X Team

#include <amxmodx>
#include <sqlx>
#include <json>

new bool: DEBUG = false;

public const PluginName[] = "Player preferences";
public const PluginVersion[] = "1.0.12";
public const PluginAuthor[] = "GM-X Team, cpctrl, karaulov";
public const PluginURL[] = "";

#define CHECK_NATIVE_ARGS_NUM(%1,%2,%3) \
	if (%1 < %2) { \
		DEBUG && log_to_file("PLAYER_PREF_DEBUG.log", "Invalid num of arguments %d. Expected %d", %1, %2); \
		return %3; \
	}

#define CHECK_NATIVE_PLAYER(%1,%2) \
	if (!g_bConnected[%1]) { \
		DEBUG && log_to_file("PLAYER_PREF_DEBUG.log", "Invalid player %d", %1); \
		return %2; \
	}
	
#define CHECK_PLAYER(%1) \
	if (!g_bConnected[%1]) { \
		DEBUG && log_to_file("PLAYER_PREF_DEBUG.log", "Invalid player for save %d", %1); \
	}

const MAX_KEY_LENGTH = 256;
const MAX_VALUE_STRING_LENGTH = 1024;
const MAX_DATA_BUFFER = 102400; // 100KB

new g_sTmpBuf[MAX_DATA_BUFFER], g_sJsonDataBuf[MAX_DATA_BUFFER], g_sJsonDataBufEscaped[MAX_DATA_BUFFER];
new g_sTmpKey[MAX_KEY_LENGTH];

enum sqlx_e {
	table[32],
	host[32],
	user[128],
	pass[128],
	db[32],
	save_type[16]
};

enum fwdStruct  {
	Fwd_Loaded,
	Fwd_UnLoaded,
	Fwd_KeyChanged,
	Fwd_PreSaving
};

new g_eForwards[fwdStruct];

new Handle: g_hTuple;

new Handle: sConnection;

new dbdata[sqlx_e];

new bool: g_bConnected[MAX_PLAYERS + 1] = {false,...};

new Trie: g_tPlayerPreferences[MAX_PLAYERS + 1];

new JSON: g_jObject[MAX_PLAYERS + 1] = {Invalid_JSON,...};

new g_sUserNames[MAX_PLAYERS + 1][MAX_NAME_LENGTH];
new g_sUserIps[MAX_PLAYERS + 1][MAX_IP_LENGTH];
new g_sUserAuths[MAX_PLAYERS + 1][MAX_AUTHID_LENGTH];

new g_iSaveType = 0;

public plugin_init()    
{
	register_plugin(PluginName, PluginVersion, PluginAuthor);

	g_eForwards[Fwd_Loaded] = CreateMultiForward("player_loaded", ET_IGNORE, FP_CELL);
	g_eForwards[Fwd_UnLoaded] = CreateMultiForward("player_unloaded", ET_IGNORE, FP_CELL);
	g_eForwards[Fwd_KeyChanged] = CreateMultiForward("player_key_changed", ET_IGNORE, FP_CELL, FP_STRING);
	g_eForwards[Fwd_PreSaving] = CreateMultiForward("player_save", ET_IGNORE, FP_CELL);

	read_json();
	
	sql_test_init();
	load_player(0);
}

//public plugin_pause()
//{
//
//}

// При снятии плагина с паузы, отправить все данные в бд
// И перезагрузить игроков
public plugin_unpause()
{
	if (g_jObject[0] != Invalid_JSON)
		save_values(0);
	for(new i = 1; i <= MAX_PLAYERS;i++)
	{
		if (g_bConnected[i] && g_jObject[i] != Invalid_JSON)
		{
			save_values(i);
		}
		if (is_user_connected(i) && !is_user_bot(i) && !is_user_hltv(i))
		{
			client_putinserver(i);
		}
	}
}

public read_json()   
{
	new filePath[PLATFORM_MAX_PATH];
	get_localinfo("amxx_configsdir", filePath, charsmax(filePath));

	add(filePath, charsmax(filePath), "/plugins/player_prefs/preferences.json");

	if (!file_exists(filePath)) 
	{
		set_fail_state("Configuration file '%s' not found", filePath);
		return;
	}

	new JSON: config = json_parse(filePath, true);

	if (config == Invalid_JSON)    
	{
		set_fail_state("Configuration file '%s' read error", filePath);
		return;
	}

	json_object_get_string(config, "sql_table", dbdata[table], charsmax(dbdata[table]));

	json_object_get_string(config, "sql_host", dbdata[host], charsmax(dbdata[host]));

	json_object_get_string(config, "sql_user", dbdata[user], charsmax(dbdata[user]));

	json_object_get_string(config, "sql_password", dbdata[pass], charsmax(dbdata[pass]));

	json_object_get_string(config, "sql_db", dbdata[db], charsmax(dbdata[db]));
	
	json_object_get_string(config, "save_type", dbdata[save_type], charsmax(dbdata[save_type]));
	
	g_iSaveType = str_to_num(dbdata[save_type]);

	json_free(config);

	server_print("Preferences config has been loaded");

}

public sql_test_init() 
{
	g_hTuple = SQL_MakeDbTuple(
		dbdata[host],
		dbdata[user],
		dbdata[pass],
		dbdata[db]
	);

	new errCode, error[512];
	sConnection = SQL_Connect(g_hTuple, errCode, error, charsmax(error));

	if (sConnection == Empty_Handle)    
	{
		SQL_FreeHandle(g_hTuple);
		g_hTuple = Empty_Handle;

		DEBUG && log_to_file("PLAYER_PREF_DEBUG.log","[PP] Error connecting to db '%s': #%d: %s", dbdata[db], errCode, error);

		return;
	}

	server_print("[PP] Connection to '%s' database success", dbdata[db]);
	
	new Handle:query = SQL_PrepareQuery(sConnection,"CREATE TABLE IF NOT EXISTS `%s` (`auth` varchar(128) NOT NULL PRIMARY KEY,`data` text NOT NULL, UNIQUE(`auth`)) ENGINE=InnoDB DEFAULT CHARSET=utf8;",dbdata[table]);
	
	if (!SQL_Execute(query))
	{
		new buffererror[2048];
		SQL_QueryError(query,buffererror,2047);
		log_to_file("PLAYER_PREF_DEBUG.log","[USC] '%s'[ %s ] SQL ERROR %s!", PluginName, PluginVersion, buffererror);
	}
	else 
	{
		DEBUG && log_to_file("PLAYER_PREF_DEBUG.log","Execute query: %s Success!", "player_preferences.sql");
	}
	
	SQL_FreeHandle(query);
}

public plugin_natives() 
{
	register_native("pp_has_key", "native_has_key");

	register_native("pp_get_number", "native_get_number");
	register_native("pp_get_float", "native_get_float");
	register_native("pp_get_bool", "native_get_bool");
	register_native("pp_get_string", "native_get_string");
	
	register_native("pp_get_auth", "native_get_auth");

	register_native("pp_set_number", "native_set_number");
	register_native("pp_set_float", "native_set_float");
	register_native("pp_set_bool", "native_set_bool");
	register_native("pp_set_string", "native_set_string");
	
	register_native("pp_clear", "native_clear");
	
	register_native("pp_has_key_global", "native_has_key_global");

	register_native("pp_get_number_global", "native_get_number_global");
	register_native("pp_get_float_global", "native_get_float_global");
	register_native("pp_get_bool_global", "native_get_bool_global");
	register_native("pp_get_string_global", "native_get_string_global");

	register_native("pp_set_number_global", "native_set_number_global");
	register_native("pp_set_float_global", "native_set_float_global");
	register_native("pp_set_bool_global", "native_set_bool_global");
	register_native("pp_set_string_global", "native_set_string_global");
}

public bool: native_has_key(plugin, argc) 
{
	enum    
	{
		arg_player = 1,
		arg_key
	};

	CHECK_NATIVE_ARGS_NUM(argc, 2, false)

	new id = get_param(arg_player);
	CHECK_NATIVE_PLAYER(id, false)

	get_string(arg_key, g_sTmpKey, charsmax(g_sTmpKey));

	return TrieKeyExists(g_tPlayerPreferences[id], g_sTmpKey);
}

public native_get_number(plugin, argc)  
{
	enum    
	{
		arg_player = 1,
		arg_key,
		arg_default
	};

	CHECK_NATIVE_ARGS_NUM(argc, 2, 0)

	new id = get_param(arg_player);
	CHECK_NATIVE_PLAYER(id, 0)

	get_string(arg_key, g_sTmpKey, charsmax(g_sTmpKey));

	if (!TrieKeyExists(g_tPlayerPreferences[id], g_sTmpKey))  
	{
		return argc >= arg_default ? get_param(arg_default) : 0;
	}

	new value;
	TrieGetCell(g_tPlayerPreferences[id], g_sTmpKey, value);

	return value;
}

public Float: native_get_float(plugin, argc)  
{
	enum    
	{
		arg_player = 1,
		arg_key,
		arg_default
	};

	CHECK_NATIVE_ARGS_NUM(argc, 2, 0.0)

	new id = get_param(arg_player);
	CHECK_NATIVE_PLAYER(id, 0.0)

	get_string(arg_key, g_sTmpKey, charsmax(g_sTmpKey));

	if (!TrieKeyExists(g_tPlayerPreferences[id], g_sTmpKey))  
	{
		return argc >= arg_default ? get_param_f(arg_default) : 0.0;
	}

	new Float:value;
	TrieGetCell(g_tPlayerPreferences[id], g_sTmpKey, value);

	return value;
}

public bool: native_get_bool(plugin, argc)  
{
	enum    
	{
		arg_player = 1,
		arg_key,
		arg_default
	};

	CHECK_NATIVE_ARGS_NUM(argc, 2, false)

	new id = get_param(arg_player);
	CHECK_NATIVE_PLAYER(id, false)

	get_string(arg_key, g_sTmpKey, charsmax(g_sTmpKey));

	if (!TrieKeyExists(g_tPlayerPreferences[id], g_sTmpKey))  
	{
		return bool: (argc >= arg_default ? get_param(arg_default) : 0);
	}

	new value;
	TrieGetCell(g_tPlayerPreferences[id], g_sTmpKey, value);

	return bool: value;
}

public native_get_string(plugin, argc)  
{
	enum    
	{
		arg_player = 1,
		arg_key,
		arg_dest,
		arg_length,
		arg_default
	};

	CHECK_NATIVE_ARGS_NUM(argc, 4, 0)

	new id = get_param(arg_player);
	CHECK_NATIVE_PLAYER(id, 0)

	new value[MAX_VALUE_STRING_LENGTH];

	get_string(arg_key, g_sTmpKey, charsmax(g_sTmpKey));

	if (TrieKeyExists(g_tPlayerPreferences[id], g_sTmpKey))  
	{
		TrieGetString(g_tPlayerPreferences[id], g_sTmpKey, value, charsmax(value));
	}
	else if (argc >= arg_default)  {
		get_string(arg_default, value, charsmax(value));
	}

	return set_string(arg_dest, value, get_param(arg_length));
}

public native_get_auth(plugin, argc)  
{
	enum    
	{
		arg_player = 1,
		arg_dest,
		arg_length
	};

	CHECK_NATIVE_ARGS_NUM(argc, 3, 0)

	new id = get_param(arg_player);
	CHECK_NATIVE_PLAYER(id, 0)

	new g_sTmpBuf[128];
	new hash[128];
	hash_string(g_sUserNames[id],Hash_Crc32,hash,charsmax(hash));

	if (g_iSaveType == 1)
		formatex(g_sTmpBuf, charsmax(g_sTmpBuf), "%s-%s", dbdata[table], g_sUserAuths[id], hash);
	else if (g_iSaveType == 2)
		formatex(g_sTmpBuf, charsmax(g_sTmpBuf), "%s", dbdata[table], g_sUserAuths[id]);
	else
		formatex(g_sTmpBuf, charsmax(g_sTmpBuf), "%s", dbdata[table], hash);

	return set_string(arg_dest, g_sTmpBuf, get_param(arg_length));
}

public native_set_number(plugin, argc)  
{
	enum    
	{
		arg_player = 1,
		arg_key,
		arg_value
	};

	CHECK_NATIVE_ARGS_NUM(argc, 3, 0)

	new id = get_param(arg_player);
	CHECK_NATIVE_PLAYER(id, 0)

	get_string(arg_key, g_sTmpKey, charsmax(g_sTmpKey));

	new value = get_param(arg_value);
	TrieSetCell(g_tPlayerPreferences[id], g_sTmpKey, value);
	json_object_set_number(g_jObject[id],g_sTmpKey,value);
	new retval = setValue(id, g_sTmpKey);
	return retval;
}

public native_set_bool(plugin, argc)  
{
	enum    
	{
		arg_player = 1,
		arg_key,
		arg_value
	};

	CHECK_NATIVE_ARGS_NUM(argc, 3, 0)

	new id = get_param(arg_player);
	CHECK_NATIVE_PLAYER(id, 0)
	
	get_string(arg_key, g_sTmpKey, charsmax(g_sTmpKey));

	new bool: value = bool: get_param(arg_value);
	TrieSetCell(g_tPlayerPreferences[id], g_sTmpKey, value ? 1 : 0);
	json_object_set_bool(g_jObject[id],g_sTmpKey,value);
	new retval = setValue(id, g_sTmpKey);
	return retval;
}

public native_set_float(plugin, argc)  
{
	enum    
	{
		arg_player = 1,
		arg_key,
		arg_value
	};

	CHECK_NATIVE_ARGS_NUM(argc, 3, 0)

	new id = get_param(arg_player);
	CHECK_NATIVE_PLAYER(id, 0)

	get_string(arg_key, g_sTmpKey, charsmax(g_sTmpKey));

	new Float: value = get_param_f(arg_value);
	TrieSetCell(g_tPlayerPreferences[id], g_sTmpKey, value);
	json_object_set_real(g_jObject[id],g_sTmpKey,value);
	new retval = setValue(id, g_sTmpKey);
	return retval;
}

public native_set_string(plugin, argc)  
{
	enum    
	{
		arg_player = 1,
		arg_key,
		arg_value
	};

	CHECK_NATIVE_ARGS_NUM(argc, 3, 0)

	new id = get_param(arg_player);
	CHECK_NATIVE_PLAYER(id, 0)

	new value[MAX_VALUE_STRING_LENGTH];
	get_string(arg_key, g_sTmpKey, charsmax(g_sTmpKey));
	get_string(arg_value, g_sTmpKey, charsmax(g_sTmpKey));

	TrieSetString(g_tPlayerPreferences[id], g_sTmpKey, value);
	json_object_set_string(g_jObject[id],g_sTmpKey,value);
	new retval = setValue(id, g_sTmpKey);
	return retval;
}

public native_clear(plugin, argc)  
{
	enum    
	{
		arg_player = 1
	};
	CHECK_NATIVE_ARGS_NUM(argc, 1, 0)

	new id = get_param(arg_player);
	CHECK_NATIVE_PLAYER(id, 0)

	
	json_free(g_jObject[id]);
	g_jObject[id] = Invalid_JSON;
	TrieDestroy(g_tPlayerPreferences[id]);
	
	g_jObject[id] = json_init_object();
	g_tPlayerPreferences[id] = TrieCreate();
	
	return PLUGIN_HANDLED;
}

public bool: native_has_key_global(plugin, argc) 
{
	enum    
	{
		arg_key = 1
	};

	CHECK_NATIVE_ARGS_NUM(argc, 1, false)

	get_string(arg_key, g_sTmpKey, charsmax(g_sTmpKey));

	return TrieKeyExists(g_tPlayerPreferences[0], g_sTmpKey);
}

public native_get_number_global(plugin, argc)  
{
	enum    
	{
		arg_key = 1,
		arg_default
	};

	CHECK_NATIVE_ARGS_NUM(argc, 1, 0)
	
	get_string(arg_key, g_sTmpKey, charsmax(g_sTmpKey));

	if (!TrieKeyExists(g_tPlayerPreferences[0], g_sTmpKey))  
	{
		return argc >= arg_default ? get_param(arg_default) : 0;
	}

	new value;
	TrieGetCell(g_tPlayerPreferences[0], g_sTmpKey, value);

	return value;
}

public Float: native_get_float_global(plugin, argc)  
{
	enum    
	{
		arg_key = 1,
		arg_default
	};

	CHECK_NATIVE_ARGS_NUM(argc, 1, 0.0)

	get_string(arg_key, g_sTmpKey, charsmax(g_sTmpKey));

	if (!TrieKeyExists(g_tPlayerPreferences[0], g_sTmpKey))  
	{
		return argc >= arg_default ? get_param_f(arg_default) : 0.0;
	}

	new Float:value;
	TrieGetCell(g_tPlayerPreferences[0], g_sTmpKey, value);

	return value;
}

public bool: native_get_bool_global(plugin, argc)  
{
	enum    
	{
		arg_key = 1,
		arg_default
	};

	CHECK_NATIVE_ARGS_NUM(argc, 1, false)

	get_string(arg_key, g_sTmpKey, charsmax(g_sTmpKey));

	if (!TrieKeyExists(g_tPlayerPreferences[0], g_sTmpKey))  
	{
		return bool: (argc >= arg_default ? get_param(arg_default) : 0);
	}

	new value;
	TrieGetCell(g_tPlayerPreferences[0], g_sTmpKey, value);

	return bool: value;
}

public native_get_string_global(plugin, argc)  
{
	enum    
	{
		arg_key = 1,
		arg_dest,
		arg_length,
		arg_default
	};

	CHECK_NATIVE_ARGS_NUM(argc, 3, 0)

	new value[MAX_VALUE_STRING_LENGTH];

	get_string(arg_key, g_sTmpKey, charsmax(g_sTmpKey));

	if (TrieKeyExists(g_tPlayerPreferences[0], g_sTmpKey))  
	{
		TrieGetString(g_tPlayerPreferences[0], g_sTmpKey, value, charsmax(value));
	}
	else if (argc >= arg_default)  
	{
		get_string(arg_default, value, charsmax(value));
	}

	return set_string(arg_dest, value, get_param(arg_length));
}

public native_set_number_global(plugin, argc)  
{
	enum    
	{
		arg_key = 1,
		arg_value
	};

	CHECK_NATIVE_ARGS_NUM(argc, 2, 0)

	get_string(arg_key, g_sTmpKey, charsmax(g_sTmpKey));

	new value = get_param(arg_value);
	TrieSetCell(g_tPlayerPreferences[0], g_sTmpKey, value);
	json_object_set_number(g_jObject[0],g_sTmpKey,value);
	new retval = setValue(0, g_sTmpKey);
	return retval;
}

public native_set_bool_global(plugin, argc)  
{
	enum    
	{
		arg_key = 1,
		arg_value
	};

	CHECK_NATIVE_ARGS_NUM(argc, 2, 0)

	get_string(arg_key, g_sTmpKey, charsmax(g_sTmpKey));

	new bool: value = bool: get_param(arg_value);
	TrieSetCell(g_tPlayerPreferences[0], g_sTmpKey, value ? 1 : 0);
	json_object_set_bool(g_jObject[0],g_sTmpKey,value);
	new retval = setValue(0, g_sTmpKey);
	return retval;
}

public native_set_float_global(plugin, argc)  
{
	enum    
	{
		arg_key = 1,
		arg_value
	};

	CHECK_NATIVE_ARGS_NUM(argc, 2, 0)

	get_string(arg_key, g_sTmpKey, charsmax(g_sTmpKey));

	new Float: value = get_param_f(arg_value);
	TrieSetCell(g_tPlayerPreferences[0], g_sTmpKey, value);
	json_object_set_real(g_jObject[0],g_sTmpKey, value);
	new retval = setValue(0, g_sTmpKey);
	return retval;
}

public native_set_string_global(plugin, argc)  
{
	enum    
	{
		arg_key = 1,
		arg_value
	};

	CHECK_NATIVE_ARGS_NUM(argc, 2, 0)
	
	new value[MAX_VALUE_STRING_LENGTH];
	get_string(arg_key, g_sTmpKey, charsmax(g_sTmpKey));
	get_string(arg_value, g_sTmpKey, charsmax(g_sTmpKey));

	TrieSetString(g_tPlayerPreferences[0], g_sTmpKey, value);
	json_object_set_string(g_jObject[0],g_sTmpKey,value);
	new retval = setValue(0, g_sTmpKey);
	return retval;
}

public setValue(const id, const g_sTmpKey[])    
{
	new fwReturn = PLUGIN_HANDLED;
	if (g_bConnected[id])
	{
		ExecuteForward(g_eForwards[Fwd_KeyChanged], fwReturn, id, g_sTmpKey);
	}
	if (g_hTuple == Empty_Handle || fwReturn == PLUGIN_HANDLED) 
	{
		return -1;
	}
	return 1;
}

public client_putinserver(id)   
{
	DEBUG && log_to_file("PLAYER_PREF_DEBUG.log", "User putinserver %d",id);
	if (is_user_hltv(id) || is_user_bot(id))    
	{
		g_bConnected[id] = false;
		return;
	}
	
	get_user_name(id,g_sUserNames[id],charsmax(g_sUserNames[]))
	get_user_authid(id, g_sUserAuths[id], charsmax(g_sUserAuths[]));
	get_user_ip(id, g_sUserIps[id], charsmax(g_sUserIps[]),true);
	
	load_player(id);
	if (g_jObject[0] == Invalid_JSON)
		load_player(0);
	
	DEBUG && log_to_file("PLAYER_PREF_DEBUG.log", "User putinserver END %d",id);
}

public client_disconnected(id)  
{
	DEBUG && log_to_file("PLAYER_PREF_DEBUG.log", "User disconnect %d",id);
	if (g_jObject[0] != Invalid_JSON)
		save_values(0);
	
	CHECK_PLAYER(id)
	
	if (id != 0)
		save_values(id);
	DEBUG && log_to_file("PLAYER_PREF_DEBUG.log", "User disconnect END %d",id);
}

public ChallengeClear(id)   
{
	if (g_bConnected[id])
		ExecuteForward(g_eForwards[Fwd_UnLoaded], _, id);
	g_bConnected[id] = false;
	json_free(g_jObject[id]);
	g_jObject[id] = Invalid_JSON;
	TrieDestroy(g_tPlayerPreferences[id]);
}

	
save_values(const id)  
{
	if (g_hTuple == Empty_Handle)
	{
		if (id != 0)
			ChallengeClear(id);
		return;
	}
	
	if (id != 0 && g_bConnected[id])
	{
		ExecuteForward(g_eForwards[Fwd_PreSaving], _, id);
	}

	if (id == 0)
	{
		json_serial_to_string(g_jObject[0], g_sJsonDataBuf, charsmax(g_sJsonDataBuf));
		
		SQL_QuoteString(sConnection ,g_sJsonDataBufEscaped, charsmax(g_sJsonDataBufEscaped), g_sJsonDataBuf);
	
		formatex(g_sTmpBuf, charsmax(g_sTmpBuf), "REPLACE INTO `%s` (`auth`, `data`) VALUES ('global', '%s')", dbdata[table], g_sJsonDataBufEscaped);
		new data[2];
		data[0] = 0;
		data[1] = -3;
		SQL_ThreadQuery(g_hTuple, "ThreadHandler", g_sTmpBuf, data, sizeof data);
		return;
	}

	new hash[128];
	hash_string(g_sUserNames[id],Hash_Crc32,hash,charsmax(hash));
	json_serial_to_string(g_jObject[id], g_sJsonDataBuf, charsmax(g_sJsonDataBuf));
	
	SQL_QuoteString(sConnection ,g_sJsonDataBufEscaped, charsmax(g_sJsonDataBufEscaped), g_sJsonDataBuf);
	
	if (g_iSaveType == 1)
		formatex(g_sTmpBuf, charsmax(g_sTmpBuf), "REPLACE INTO `%s` (`auth`, `data`) VALUES ('%s-%s', '%s')", dbdata[table], g_sUserAuths[id], hash, g_sJsonDataBufEscaped);
	else if (g_iSaveType == 2)
		formatex(g_sTmpBuf, charsmax(g_sTmpBuf), "REPLACE INTO `%s` (`auth`, `data`) VALUES ('%s', '%s')", dbdata[table], g_sUserAuths[id], g_sJsonDataBufEscaped);
	else 
		formatex(g_sTmpBuf, charsmax(g_sTmpBuf), "REPLACE INTO `%s` (`auth`, `data`) VALUES ('%s', '%s')", dbdata[table], hash, g_sJsonDataBufEscaped);
		
	DEBUG && log_to_file("PLAYER_PREF_DEBUG.log", "QUERY SAVE %d: %s",id, g_sTmpBuf);

	new data[2];
	data[0] = 0;
	data[1] = -1;
	SQL_ThreadQuery(g_hTuple, "ThreadHandler", g_sTmpBuf, data, sizeof data);
	ChallengeClear(id);
}

public load_player(id)  
{
	if (id != 0)
		g_bConnected[id] = true;
	
	if (g_jObject[id] == Invalid_JSON)
	{
		g_jObject[id] = json_init_object();
		g_tPlayerPreferences[id] = TrieCreate();
	}
	
	if (g_hTuple == Empty_Handle)   
	{
		return;
	}
	
	if (id == 0)
	{
		formatex(g_sTmpBuf, charsmax(g_sTmpBuf), "SELECT `auth`, `data` FROM `%s` WHERE auth = 'global'", dbdata[table]);
		new data[2];
		data[0] = 0;
		data[1] = -2;
		SQL_ThreadQuery(g_hTuple, "ThreadHandler", g_sTmpBuf, data, sizeof data);
		DEBUG && log_to_file("PLAYER_PREF_DEBUG.log", "QUERY LOAD GLOBAL %d: %s",id, g_sTmpBuf);
		return;
	}
	
	new hash[128];
	hash_string(g_sUserNames[id],Hash_Crc32,hash,charsmax(hash));

	if (g_iSaveType == 1)
		formatex(g_sTmpBuf, charsmax(g_sTmpBuf), "SELECT `auth`, `data` FROM `%s` WHERE auth = '%s-%s'", dbdata[table], g_sUserAuths[id], hash);
	else if (g_iSaveType == 2)
		formatex(g_sTmpBuf, charsmax(g_sTmpBuf), "SELECT `auth`, `data` FROM `%s` WHERE auth = '%s'", dbdata[table], g_sUserAuths[id]);
	else
		formatex(g_sTmpBuf, charsmax(g_sTmpBuf), "SELECT `auth`, `data` FROM `%s` WHERE auth = '%s'", dbdata[table], hash);
	DEBUG && log_to_file("PLAYER_PREF_DEBUG.log", "QUERY LOAD %d: %s",id, g_sTmpBuf);
	new data[2];
	data[0] = id;
	data[1] = 1;
	SQL_ThreadQuery(g_hTuple, "ThreadHandler", g_sTmpBuf, data, sizeof data);
}

public ThreadHandler(failstate, Handle: query, error[], errnum, data[], size, Float: queuetime)   
{
	if (failstate)  
	{
		log_to_file("PLAYER_PREF_DEBUG.log", "[PP] [%d]: %s", errnum, error);
		return PLUGIN_HANDLED;
	}
	
	if (data[1] == -1 || data[1] == -3)
	{
		return PLUGIN_HANDLED;
	}

	new id = data[0];

	if (SQL_NumResults(query))  
	{
		SQL_ReadResult(query, SQL_FieldNameToNum(query, "data"), g_sJsonDataBuf, charsmax(g_sJsonDataBuf));

		new JSON: jsonValue = json_parse(g_sJsonDataBuf);

		if (jsonValue == Invalid_JSON || g_sJsonDataBuf[0] != '{' || g_sJsonDataBuf[strlen(g_sJsonDataBuf) - 1] != '}')   
		{
			json_free(jsonValue);

			if (DEBUG)  
			{
				new auth[128];
				SQL_ReadResult(query, SQL_FieldNameToNum(query, "auth"), auth, charsmax(auth));

				DEBUG && log_to_file("PLAYER_PREF_DEBUG.log", "[PP] Skipped load from bad format json `auth` = %s", auth);
			}
		}
		else 
		{
			DEBUG && log_to_file("PLAYER_PREF_DEBUG.log", "[PP] FULL RESPONSE:%s", g_sJsonDataBuf);
			new numsc = 0,strings = 0,booleans = 0;
			new values = json_object_get_count(jsonValue);
			new bool: bSomeBoolean, iSomeNumber;
			new value[MAX_VALUE_STRING_LENGTH];
			new JSON: element;
			new JSONType: jstype;
			for (new i = 0; i < values; i++)  
			{ 
				json_object_get_name(jsonValue, i, g_sTmpKey, charsmax(g_sTmpKey));
				element = json_object_get_value_at(jsonValue, i);
				
				jstype = json_get_type(element);
				switch  (jstype) 
				{
					case JSONString:    
					{
						strings++;
						json_get_string(element, value, charsmax(value));
						iSomeNumber = str_to_num(value);
						DEBUG && log_to_file("PLAYER_PREF_DEBUG.log", "[PP] JSON NAME: %s. JSTYPE: %i. VALUE:%s",g_sTmpKey, jstype,value);
						TrieSetString(g_tPlayerPreferences[id], g_sTmpKey, value);
						json_object_set_string(g_jObject[id], g_sTmpKey, value);
					}
					case JSONNumber:   
					{
						numsc++;
						iSomeNumber = json_get_number(element);
						TrieSetCell(g_tPlayerPreferences[id], g_sTmpKey, iSomeNumber);
						json_object_set_number(g_jObject[id], g_sTmpKey, iSomeNumber);
						DEBUG && log_to_file("PLAYER_PREF_DEBUG.log", "[PP] JSON NAME: %s. JSTYPE: %i. VALUE:%d",g_sTmpKey, jstype,iSomeNumber);
					}
					case JSONBoolean:   
					{
						booleans++;
						bSomeBoolean = json_get_bool(element);
						TrieSetCell(g_tPlayerPreferences[id], g_sTmpKey, bSomeBoolean ? 1 : 0);
						json_object_set_bool(g_jObject[id], g_sTmpKey, bSomeBoolean);
						DEBUG && log_to_file("PLAYER_PREF_DEBUG.log", "[PP] JSON NAME: %s. JSTYPE: %i. VALUE:%d",g_sTmpKey, jstype,bSomeBoolean);
					}
				}
				json_free(element);
			}
			
			DEBUG && log_to_file("PLAYER_PREF_DEBUG.log", "[PP] Loaded objects:%i. Nums:%i. Strings:%i. Booleans:%i.", json_object_get_count(jsonValue),numsc,strings,booleans);
		}
		json_free(jsonValue);
	}
	else 
	{
		DEBUG && log_to_file("PLAYER_PREF_DEBUG.log", "[PP] No results in query!");
	}
	
	if (id != 0)
	{
		new username2[64];
		SQL_QuoteString(sConnection ,username2, charsmax(username2), g_sUserNames[id]);
		
		TrieSetString(g_tPlayerPreferences[id], "name", username2);
		json_object_set_string(g_jObject[id],"name", username2);
		
		if (g_bConnected[id])
		{
			ExecuteForward(g_eForwards[Fwd_Loaded], _, id);
		}
	}
	return PLUGIN_HANDLED;
}

public plugin_end() 
{
	if (g_hTuple != Empty_Handle) 
	{
		SQL_FreeHandle(g_hTuple);
	}
	
	if (sConnection != Empty_Handle)
	{
		SQL_FreeHandle(sConnection);
	}
}