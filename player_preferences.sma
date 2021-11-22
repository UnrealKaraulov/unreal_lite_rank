//Based on plugin: https://dev-cs.ru/resources/984/ by GM-X Team

#include <amxmodx>
#include <sqlx>
#include <json>

new bool: DEBUG = false;

public stock const PluginName[] = "Player preferences";
public stock const PluginVersion[] = "1.0.9";
public stock const PluginAuthor[] = "GM-X Team, cpctrl, karaulov";
public stock const PluginURL[] = "https://goldsrc.ru/members/3085/";

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

const MAX_KEY_LENGTH = 256;
const MAX_VALUE_STRING_LENGTH = 1024;
const MAX_DATA_BUFFER = 102400; // 100KB

new queryBuffer[MAX_DATA_BUFFER], jsonDataBuffer[MAX_DATA_BUFFER];


enum sqlx_e {
	table[32],
	host[32],
	user[128],
	pass[128],
	db[32]
};

enum fwdStruct  {
	Fwd_Loaded,
	Fwd_UnLoaded,
	Fwd_KeyChanged
};

new g_eForwards[fwdStruct];

new Handle: g_hTuple;
new dbdata[sqlx_e];

new bool: g_bConnected[MAX_PLAYERS + 1];
new Trie: g_tPlayerPreferences[MAX_PLAYERS + 1];
new JSON: g_jObject[MAX_PLAYERS + 1];
new g_iSaveType = 0;

public plugin_init()    {
	register_plugin(PluginName, PluginVersion, PluginAuthor);

	g_eForwards[Fwd_Loaded] = CreateMultiForward("player_loaded", ET_IGNORE, FP_CELL);
	g_eForwards[Fwd_UnLoaded] = CreateMultiForward("player_unloaded", ET_IGNORE, FP_CELL);
	g_eForwards[Fwd_KeyChanged] = CreateMultiForward("player_key_changed", ET_IGNORE, FP_CELL, FP_STRING);

	read_json();
	
	if (bool: (plugin_flags() & AMX_FLAG_DEBUG))
		DEBUG = true;
	
	sql_test_init();
	load_player(0);
}

public read_json()   {
	new filePath[PLATFORM_MAX_PATH];
	get_localinfo("amxx_configsdir", filePath, charsmax(filePath));

	add(filePath, charsmax(filePath), "/preferences.json");

	if (!file_exists(filePath)) {
		set_fail_state("Configuration file '%s' not found", filePath);
		return;
	}

	new JSON: config = json_parse(filePath, true);

	if (config == Invalid_JSON)    {
		set_fail_state("Configuration file '%s' read error", filePath);
		return;
	}

	new temp[128];

	json_object_get_string(config, "sql_table", temp, charsmax(temp));
	copy(dbdata[table], charsmax(dbdata[table]), temp);

	json_object_get_string(config, "sql_host", temp, charsmax(temp));
	copy(dbdata[host], charsmax(dbdata[host]), temp);

	json_object_get_string(config, "sql_user", temp, charsmax(temp));
	copy(dbdata[user], charsmax(dbdata[user]), temp);

	json_object_get_string(config, "sql_password", temp, charsmax(temp));
	copy(dbdata[pass], charsmax(dbdata[pass]), temp);

	json_object_get_string(config, "sql_db", temp, charsmax(temp));
	copy(dbdata[db], charsmax(dbdata[db]), temp);
	
	json_object_get_string(config, "save_type", temp, charsmax(temp));
	g_iSaveType = str_to_num(temp);

	json_free(config);

	server_print("Preferences config has been loaded");

}

public sql_test_init() {
	new Handle: sConnection;

	g_hTuple = SQL_MakeDbTuple(
		dbdata[host],
		dbdata[user],
		dbdata[pass],
		dbdata[db]
	);

	new errCode, error[512];
	sConnection = SQL_Connect(g_hTuple, errCode, error, charsmax(error));

	if (sConnection == Empty_Handle)    {
		SQL_FreeHandle(g_hTuple);
		g_hTuple = Empty_Handle;

		DEBUG && log_to_file("PLAYER_PREF_DEBUG.log","[PP] Error connecting to db '%s': #%d: %s", dbdata[db], errCode, error);

		return;
	}

	server_print("[PP] Connection to '%s' database success", dbdata[db]);
	
	new Handle:query = SQL_PrepareQuery(sConnection,"CREATE TABLE IF NOT EXISTS `%s` (`auth` varchar(128) NOT NULL PRIMARY KEY,`data` text NOT NULL,UNIQUE(`auth`) ) ENGINE=InnoDB DEFAULT CHARSET=utf8;",dbdata[table]);
	
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
	SQL_FreeHandle(sConnection);
}

public plugin_natives() {
	register_native("pp_has_key", "native_has_key");

	register_native("pp_get_number", "native_get_number");
	register_native("pp_get_float", "native_get_float");
	register_native("pp_get_bool", "native_get_bool");
	register_native("pp_get_string", "native_get_string");

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

public bool: native_has_key(plugin, argc) {
	enum    {
		arg_player = 1,
		arg_key
	};

	CHECK_NATIVE_ARGS_NUM(argc, 2, false)

	new id = get_param(arg_player);
	CHECK_NATIVE_PLAYER(id, false)

	new key[MAX_KEY_LENGTH];
	get_string(arg_key, key, charsmax(key));

	return TrieKeyExists(g_tPlayerPreferences[id], key);
}

public native_get_number(plugin, argc)  {
	enum    {
		arg_player = 1,
		arg_key,
		arg_default
	};

	CHECK_NATIVE_ARGS_NUM(argc, 2, 0)

	new id = get_param(arg_player);
	CHECK_NATIVE_PLAYER(id, 0)

	new key[MAX_KEY_LENGTH];
	get_string(arg_key, key, charsmax(key));

	if (!TrieKeyExists(g_tPlayerPreferences[id], key))  {
		return argc >= arg_default ? get_param(arg_default) : 0;
	}

	new value;
	TrieGetCell(g_tPlayerPreferences[id], key, value);

	return value;
}

public Float: native_get_float(plugin, argc)  {
	enum    {
		arg_player = 1,
		arg_key,
		arg_default
	};

	CHECK_NATIVE_ARGS_NUM(argc, 2, 0.0)

	new id = get_param(arg_player);
	CHECK_NATIVE_PLAYER(id, 0.0)

	new key[MAX_KEY_LENGTH];
	get_string(arg_key, key, charsmax(key));

	if (!TrieKeyExists(g_tPlayerPreferences[id], key))  {
		return argc >= arg_default ? get_param_f(arg_default) : 0.0;
	}

	new value;
	TrieGetCell(g_tPlayerPreferences[id], key, value);

	return float(value);
}

public bool: native_get_bool(plugin, argc)  {
	enum    {
		arg_player = 1,
		arg_key,
		arg_default
	};

	CHECK_NATIVE_ARGS_NUM(argc, 2, false)

	new id = get_param(arg_player);
	CHECK_NATIVE_PLAYER(id, false)

	new key[MAX_KEY_LENGTH];
	get_string(arg_key, key, charsmax(key));

	if (!TrieKeyExists(g_tPlayerPreferences[id], key))  {
		return bool: (argc >= arg_default ? get_param(arg_default) : 0);
	}

	new value;
	TrieGetCell(g_tPlayerPreferences[id], key, value);

	return bool: value;
}

public native_get_string(plugin, argc)  {
	enum    {
		arg_player = 1,
		arg_key,
		arg_dest,
		arg_length,
		arg_default
	};

	CHECK_NATIVE_ARGS_NUM(argc, 2, 0)

	new id = get_param(arg_player);
	CHECK_NATIVE_PLAYER(id, 0)

	new key[MAX_KEY_LENGTH], value[MAX_VALUE_STRING_LENGTH];

	get_string(arg_key, key, charsmax(key));

	if (TrieKeyExists(g_tPlayerPreferences[id], key))  {
		TrieGetString(g_tPlayerPreferences[id], key, value, charsmax(value));
	}
	else if (argc >= arg_default)  {
		get_string(arg_default, value, charsmax(value));
	}

	return set_string(arg_dest, value, get_param(arg_length));
}

public native_set_number(plugin, argc)  {
	enum    {
		arg_player = 1,
		arg_key,
		arg_value
	};

	CHECK_NATIVE_ARGS_NUM(argc, 3, 0)

	new id = get_param(arg_player);
	CHECK_NATIVE_PLAYER(id, 0)

	new key[MAX_KEY_LENGTH];
	get_string(arg_key, key, charsmax(key));

	new value = get_param(arg_value);
	TrieSetCell(g_tPlayerPreferences[id], key, value);
	json_object_set_number(g_jObject[id],key,value);
	new retval = setValue(id, key);
	return retval;
}

public native_set_bool(plugin, argc)  {
	enum    {
		arg_player = 1,
		arg_key,
		arg_value
	};

	CHECK_NATIVE_ARGS_NUM(argc, 3, 0)

	new id = get_param(arg_player);
	CHECK_NATIVE_PLAYER(id, 0)

	new key[MAX_KEY_LENGTH];
	get_string(arg_key, key, charsmax(key));

	new bool: value = bool: get_param(arg_value);
	TrieSetCell(g_tPlayerPreferences[id], key, value ? 1 : 0);
	json_object_set_bool(g_jObject[id],key,value);
	new retval = setValue(id, key);
	return retval;
}

public native_set_float(plugin, argc)  {
	enum    {
		arg_player = 1,
		arg_key,
		arg_value
	};

	CHECK_NATIVE_ARGS_NUM(argc, 3, 0)

	new id = get_param(arg_player);
	CHECK_NATIVE_PLAYER(id, 0)

	new key[MAX_KEY_LENGTH];
	get_string(arg_key, key, charsmax(key));

	new Float: value = get_param_f(arg_value);
	TrieSetCell(g_tPlayerPreferences[id], key, value);
	json_object_set_number(g_jObject[id],key,cell: value);
	new retval = setValue(id, key);
	return retval;
}

public native_set_string(plugin, argc)  {
	enum    {
		arg_player = 1,
		arg_key,
		arg_value
	};

	CHECK_NATIVE_ARGS_NUM(argc, 3, 0)

	new id = get_param(arg_player);
	CHECK_NATIVE_PLAYER(id, 0)

	new key[MAX_KEY_LENGTH], value[MAX_VALUE_STRING_LENGTH];
	get_string(arg_key, key, charsmax(key));
	get_string(arg_value, key, charsmax(key));

	TrieSetString(g_tPlayerPreferences[id], key, value);
	json_object_set_string(g_jObject[id],key,cell: value);
	new retval = setValue(id, key);
	return retval;
}

public native_clear(plugin, argc)  {
	enum    {
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

public bool: native_has_key_global(plugin, argc) {
	enum    {
		arg_key = 1
	};

	CHECK_NATIVE_ARGS_NUM(argc, 1, false)

	new id = 0;
	CHECK_NATIVE_PLAYER(id, false)

	new key[MAX_KEY_LENGTH];
	get_string(arg_key, key, charsmax(key));

	return TrieKeyExists(g_tPlayerPreferences[id], key);
}

public native_get_number_global(plugin, argc)  {
	enum    {
		arg_key = 1,
		arg_default
	};

	CHECK_NATIVE_ARGS_NUM(argc, 1, 0)

	new id = 0;
	CHECK_NATIVE_PLAYER(id, 0)

	new key[MAX_KEY_LENGTH];
	get_string(arg_key, key, charsmax(key));

	if (!TrieKeyExists(g_tPlayerPreferences[id], key))  {
		return argc >= arg_default ? get_param(arg_default) : 0;
	}

	new value;
	TrieGetCell(g_tPlayerPreferences[id], key, value);

	return value;
}

public Float: native_get_float_global(plugin, argc)  {
	enum    {
		arg_key = 1,
		arg_default
	};

	CHECK_NATIVE_ARGS_NUM(argc, 1, 0.0)

	new id = 0;
	CHECK_NATIVE_PLAYER(id, 0.0)

	new key[MAX_KEY_LENGTH];
	get_string(arg_key, key, charsmax(key));

	if (!TrieKeyExists(g_tPlayerPreferences[id], key))  {
		return argc >= arg_default ? get_param_f(arg_default) : 0.0;
	}

	new value;
	TrieGetCell(g_tPlayerPreferences[id], key, value);

	return float(value);
}

public bool: native_get_bool_global(plugin, argc)  {
	enum    {
		arg_key = 1,
		arg_default
	};

	CHECK_NATIVE_ARGS_NUM(argc, 1, false)

	new id = 0;
	CHECK_NATIVE_PLAYER(id, false)

	new key[MAX_KEY_LENGTH];
	get_string(arg_key, key, charsmax(key));

	if (!TrieKeyExists(g_tPlayerPreferences[id], key))  {
		return bool: (argc >= arg_default ? get_param(arg_default) : 0);
	}

	new value;
	TrieGetCell(g_tPlayerPreferences[id], key, value);

	return bool: value;
}

public native_get_string_global(plugin, argc)  {
	enum    {
		arg_key = 1,
		arg_dest,
		arg_length,
		arg_default
	};

	CHECK_NATIVE_ARGS_NUM(argc, 1, 0)

	new id = 0;
	CHECK_NATIVE_PLAYER(id, 0)

	new key[MAX_KEY_LENGTH], value[MAX_VALUE_STRING_LENGTH];

	get_string(arg_key, key, charsmax(key));

	if (TrieKeyExists(g_tPlayerPreferences[id], key))  {
		TrieGetString(g_tPlayerPreferences[id], key, value, charsmax(value));
	}
	else if (argc >= arg_default)  {
		get_string(arg_default, value, charsmax(value));
	}

	return set_string(arg_dest, value, get_param(arg_length));
}

public native_set_number_global(plugin, argc)  {
	enum    {
		arg_key = 1,
		arg_value
	};

	CHECK_NATIVE_ARGS_NUM(argc, 2, 0)

	new id = 0;
	CHECK_NATIVE_PLAYER(id, 0)

	new key[MAX_KEY_LENGTH];
	get_string(arg_key, key, charsmax(key));

	new value = get_param(arg_value);
	TrieSetCell(g_tPlayerPreferences[id], key, value);
	json_object_set_number(g_jObject[id],key,value);
	new retval = setValue(id, key);
	return retval;
}

public native_set_bool_global(plugin, argc)  {
	enum    {
		arg_key = 1,
		arg_value
	};

	CHECK_NATIVE_ARGS_NUM(argc, 2, 0)

	new id = 0;
	CHECK_NATIVE_PLAYER(id, 0)

	new key[MAX_KEY_LENGTH];
	get_string(arg_key, key, charsmax(key));

	new bool: value = bool: get_param(arg_value);
	TrieSetCell(g_tPlayerPreferences[id], key, value ? 1 : 0);
	json_object_set_bool(g_jObject[id],key,value);
	new retval = setValue(id, key);
	return retval;
}

public native_set_float_global(plugin, argc)  {
	enum    {
		arg_key = 1,
		arg_value
	};

	CHECK_NATIVE_ARGS_NUM(argc, 2, 0)

	new id = 0;
	CHECK_NATIVE_PLAYER(id, 0)

	new key[MAX_KEY_LENGTH];
	get_string(arg_key, key, charsmax(key));

	new Float: value = get_param_f(arg_value);
	TrieSetCell(g_tPlayerPreferences[id], key, value);
	json_object_set_number(g_jObject[id],key,cell: value);
	new retval = setValue(id, key);
	return retval;
}

public native_set_string_global(plugin, argc)  {
	enum    {
		arg_key = 1,
		arg_value
	};

	CHECK_NATIVE_ARGS_NUM(argc, 2, 0)

	new id = 0;
	CHECK_NATIVE_PLAYER(id, 0)

	new key[MAX_KEY_LENGTH], value[MAX_VALUE_STRING_LENGTH];
	get_string(arg_key, key, charsmax(key));
	get_string(arg_value, key, charsmax(key));

	TrieSetString(g_tPlayerPreferences[id], key, value);
	json_object_set_string(g_jObject[id],key,cell: value);
	new retval = setValue(id, key);
	return retval;
}

stock setValue(const id, const key[])    {
	new fwReturn;
	ExecuteForward(g_eForwards[Fwd_KeyChanged], fwReturn, id, key);

	if (g_hTuple == Empty_Handle || fwReturn == PLUGIN_HANDLED) {
		return -1;
	}
	return 1;
}

public client_connect(id)   {
	load_player(id);
	if (g_jObject[0] == Invalid_JSON)
		load_player(0);
}

public client_disconnected(id)  {
	if (g_bConnected[id])   {
		save_values(id);
	}
	if (g_jObject[0] != Invalid_JSON)
		save_values(0);
}

public ChallengeClear(id)   {
	if (g_bConnected[id])
		ExecuteForward(g_eForwards[Fwd_UnLoaded], _, id);
	g_bConnected[id] = false;
	json_free(g_jObject[id]);
	g_jObject[id] = Invalid_JSON;
	TrieDestroy(g_tPlayerPreferences[id]);
}

	
save_values(const id)  {
	if (g_hTuple == Empty_Handle)   {
		ChallengeClear(id);
		return;
	}

	if (json_serial_size(g_jObject[id]) < 3)  {
		ChallengeClear(id);
		return;
	}
	
	if (id == 0)
	{
		json_serial_to_string(g_jObject[id], jsonDataBuffer, charsmax(jsonDataBuffer));
		formatex(queryBuffer, charsmax(queryBuffer), "REPLACE INTO %s (auth, data) VALUES ('global', '%s')", dbdata[table], jsonDataBuffer);
		new data[2];
		data[0] = 0;
		data[1] = -3;
		SQL_ThreadQuery(g_hTuple, "ThreadHandler", queryBuffer, data, sizeof data);
		return;
	}

	new auth[128];
	new name[128], hash[128];
	get_user_name(id,name,charsmax(name))
	hash_string(name,Hash_Crc32,hash,charsmax(hash));
	get_user_authid(id, auth, charsmax(auth));
	json_serial_to_string(g_jObject[id], jsonDataBuffer, charsmax(jsonDataBuffer));
	
	if (g_iSaveType == 1)
		formatex(queryBuffer, charsmax(queryBuffer), "REPLACE INTO %s (auth, data) VALUES ('%s-%s', '%s')", dbdata[table], auth, hash, jsonDataBuffer);
	else if (g_iSaveType == 2)
		formatex(queryBuffer, charsmax(queryBuffer), "REPLACE INTO %s (auth, data) VALUES ('%s', '%s')", dbdata[table], auth, jsonDataBuffer);
	else 
		formatex(queryBuffer, charsmax(queryBuffer), "REPLACE INTO %s (auth, data) VALUES ('%s', '%s')", dbdata[table], auth, jsonDataBuffer);
		
	DEBUG && log_to_file("PLAYER_PREF_DEBUG.log", "QUERY SAVE: %s", queryBuffer);

	new data[2];
	data[0] = 0;
	data[1] = -1;
	SQL_ThreadQuery(g_hTuple, "ThreadHandler", queryBuffer, data, sizeof data);
	ChallengeClear(id);
}

load_player(id)  {
	if (id == 0)
	{
		g_bConnected[0] = true;
		g_jObject[0] = json_init_object();
		g_tPlayerPreferences[0] = TrieCreate();
		formatex(queryBuffer, charsmax(queryBuffer), "SELECT auth, data FROM %s WHERE auth = 'global'", dbdata[table]);
		new data[2];
		data[0] = 0;
		data[1] = -2;
		SQL_ThreadQuery(g_hTuple, "ThreadHandler", queryBuffer, data, sizeof data);
		return;
	}
	
	if (is_user_hltv(id) || is_user_bot(id))    {
		return;
	}

	g_bConnected[id] = true;
	g_jObject[id] = json_init_object();
	g_tPlayerPreferences[id] = TrieCreate();

	if (g_hTuple == Empty_Handle)   {
		return;
	}

	new queryBuffer[128], szAuth[128];
	new name[128], hash[128];
	get_user_name(id,name,charsmax(name))
	hash_string(name,Hash_Crc32,hash,charsmax(hash));
	get_user_authid(id, szAuth, charsmax(szAuth));

	if (g_iSaveType == 1)
		formatex(queryBuffer, charsmax(queryBuffer), "SELECT auth, data FROM %s WHERE auth = '%s-%s'", dbdata[table], szAuth, hash);
	else if (g_iSaveType == 2)
		formatex(queryBuffer, charsmax(queryBuffer), "SELECT auth, data FROM %s WHERE auth = '%s'", dbdata[table], szAuth);
	else
		formatex(queryBuffer, charsmax(queryBuffer), "SELECT auth, data FROM %s WHERE auth = '%s'", dbdata[table], szAuth);
	DEBUG && log_to_file("PLAYER_PREF_DEBUG.log", "QUERY LOAD: %s", queryBuffer);
	new data[2];
	data[0] = id;
	data[1] = get_user_userid(id);
	SQL_ThreadQuery(g_hTuple, "ThreadHandler", queryBuffer, data, sizeof data);
}

public ThreadHandler(failstate, Handle: query, error[], errnum, data[], size, Float: queuetime)   {
	if (failstate)  {
		log_to_file("PLAYER_PREF_DEBUG.log", "[PP] [%d]: %s", errnum, error);
		return PLUGIN_HANDLED;
	}
	
	if (data[1] == -1 || data[1] == -3)
	{
		return PLUGIN_HANDLED;
	}

	new id = data[0];

	CHECK_NATIVE_PLAYER(id, PLUGIN_HANDLED)

	if (data[1] != -2 && get_user_userid(id) != data[1]) {
		log_to_file("PLAYER_PREF_DEBUG.log","[PP] Userid %d != Pushed userid %d", get_user_userid(id), data[1]);
		return PLUGIN_HANDLED;
	}

	if (SQL_NumResults(query))  {
		SQL_ReadResult(query, SQL_FieldNameToNum(query, "data"), jsonDataBuffer, charsmax(jsonDataBuffer));

		new JSON: jsonValue = json_parse(jsonDataBuffer);

		if (jsonValue == Invalid_JSON || jsonDataBuffer[0] != '{' || jsonDataBuffer[strlen(jsonDataBuffer) - 1] != '}')   {
			json_free(jsonValue);

			if (DEBUG)  {
				new auth[128];
				SQL_ReadResult(query, SQL_FieldNameToNum(query, "auth"), auth, charsmax(auth));

				DEBUG && log_to_file("PLAYER_PREF_DEBUG.log", "[PP] Skipped load from bad format json `auth` = %s", auth);
			}
			ExecuteForward(g_eForwards[Fwd_Loaded], _, id);
		}
		else 
		{
			DEBUG && log_to_file("PLAYER_PREF_DEBUG.log", "[PP] FULL RESPONSE:%s", jsonDataBuffer);
			new numsc = 0,strings = 0,booleans = 0;
			new values = json_object_get_count(jsonValue);
			new bool: bSomeBoolean, iSomeNumber;
			new value[MAX_VALUE_STRING_LENGTH],key[MAX_KEY_LENGTH];
			new JSON: element;
			new JSONType: jstype;
			for (new i = 0; i < values; i++)  
			{ 
				json_object_get_name(jsonValue, i, key, charsmax(key));
				element = json_object_get_value_at(jsonValue, i);
				
				jstype = json_get_type(element);
				switch  (jstype) {
					case JSONString:    {
						strings++;
						json_get_string(element, value, charsmax(value));
						iSomeNumber = str_to_num(value);
						DEBUG && log_to_file("PLAYER_PREF_DEBUG.log", "[PP] JSON NAME: %s. JSTYPE: %i. VALUE:%s",key, jstype,value);
						TrieSetString(g_tPlayerPreferences[id], key, value);
						json_object_set_string(g_jObject[id], key, value);
					}
					case JSONNumber:    {
						numsc++;
						iSomeNumber = json_get_number(element);
						TrieSetCell(g_tPlayerPreferences[id], key, iSomeNumber);
						json_object_set_number(g_jObject[id], key, iSomeNumber);
						DEBUG && log_to_file("PLAYER_PREF_DEBUG.log", "[PP] JSON NAME: %s. JSTYPE: %i. VALUE:%d",key, jstype,iSomeNumber);
					}
					case JSONBoolean:   {
						booleans++;
						bSomeBoolean = json_get_bool(element);
						TrieSetCell(g_tPlayerPreferences[id], key, bSomeBoolean ? 1 : 0);
						json_object_set_bool(g_jObject[id], key, bSomeBoolean);
						DEBUG && log_to_file("PLAYER_PREF_DEBUG.log", "[PP] JSON NAME: %s. JSTYPE: %i. VALUE:%d",key, jstype,bSomeBoolean);
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
	ExecuteForward(g_eForwards[Fwd_Loaded], _, id);
	return PLUGIN_HANDLED;
}

public plugin_end() {
	if (g_hTuple != Empty_Handle) {
		SQL_FreeHandle(g_hTuple);
	}
}