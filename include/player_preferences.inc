#if defined _player_preferences_included
	#endinput
#endif

#define _player_preferences_included

/**
 * Called when a player is loaded.
 *
 * @param id                Client index
 *
 * @noreturn
 */
forward player_loaded(const id);

/**
 * Called when a value of a key is changed.
 *
 * @param id                Client index
 * @param key               Unique key
 *
 * @note		If you want to block this event, use the return PLUGIN_HANDLED
 * @noreturn
 */
forward player_key_changed(const id, const key[]);

/**
 * Checks if the specified key for player exists.
 *
 * @param id                Client index
 * @param key               Unique key to which the value will be set
 *
 * @return                  true on success, false otherwise
 * @error                   If the index is not within the range of 1 to MaxClients,
 *                          an error will be thrown.
 */
native bool: pp_has_key(const id, const key[]);



/**
 * Clear all data for player.
 *
 * @param id                Client index
 *
 * @return                  nothing
 * @error                   If the index is not within the range of 1 to MaxClients,
 *                          an error will be thrown.
 */
native pp_clear(const id);


/**
 * Gets the value of the specified key set to the player as string.
 *
 * @param id                Client index
 * @param key               Unique key to search for
 * @param dest              Buffer to copy value to
 * @param length            Maximum buffer size
 * @param defaultValue      Default value to set if key wasn't found
 *
 * @return                  Key's value set to the player or defaultValue if key wasn't found
 * @error                   If the index is not within the range of 1 to MaxClients
 *                          or an invalid number of arguments is set, an error will be thrown.
 */
native pp_get_string(const id, const key[], dest[], const length, const defaultValue[] = "");

/**
 * Sets a string value for a player for the specified key.
 *
 * @param id                Client index
 * @param key               Unique key to set the value to
 * @param value             Value to set
 *
 * @return                  1 on success, 0 otherwise
 * @error                   If the index is not within the range of 1 to MaxClients
 *                          or an invalid number of arguments is set, an error will be thrown.
 */
native pp_set_string(const id, const key[], const value[]);

/**
 * Gets the value of the specified key set to the player as integer.
 *
 * @param id                Client index
 * @param key               Unique key to search for
 * @param defaultValue      Default value to set if key wasn't found
 *
 * @return                  Key's value set to the player or defaultValue if key wasn't found
 * @error                   If the index is not within the range of 1 to MaxClients
 *                          or an invalid number of arguments is set, an error will be thrown.
 */
native pp_get_number(const id, const key[], const defaultValue = 0);

/**
 * Sets an integer value for a player for the specified key.
 *
 * @param id                Client index
 * @param key               Unique key to set the value to
 * @param value             Value to set
 *
 * @return                  1 on success, 0 otherwise
 * @error                   If the index is not within the range of 1 to MaxClients
 *                          or an invalid number of arguments is set, an error will be thrown.
 */
native pp_set_number(const id, const key[], const value);

/**
 * Gets the value of the specified key set to the player as boolean.
 *
 * @param id                Client index
 * @param key               Unique key to search for
 * @param defaultValue      Default value to set if key wasn't found
 *
 * @return                  Key's value set to the player or defaultValue if key wasn't found
 * @error                   If the index is not within the range of 1 to MaxClients
 *                          or an invalid number of arguments is set, an error will be thrown.
 */
native bool: pp_get_bool(const id, const key[], const bool:defaultValue = false);

/**
 * Sets a boolean value for a player for the specified key.
 *
 * @param id                Client index
 * @param key               Unique key to set the value to
 * @param value             Value to set
 *
 * @return                  1 on success, 0 otherwise
 * @error                   If the index is not within the range of 1 to MaxClients
 *                          or an invalid number of arguments is set, an error will be thrown.
 */
native pp_set_bool(const id, const key[], const bool:value);

/**
 * Gets the value of the specified key set to the player as float.
 *
 * @param id                Client index
 * @param key               Unique key to search for
 * @param defaultValue      Default value to set if key wasn't found
 *
 * @return                  Key's value set to the player or defaultValue if key wasn't found
 * @error                   If the index is not within the range of 1 to MaxClients
 *                          or an invalid number of arguments is set, an error will be thrown.
 */
native Float: pp_get_float(const id, const key[], const Float:defaultValue = 0.0);

/**
 * Sets a float value for a player for the specified key.
 *
 * @param id                Client index
 * @param key               Unique key to set the value to
 * @param value             Value to set
 *
 * @return                  1 on success, 0 otherwise
 * @error                   If the index is not within the range of 1 to MaxClients
 *                          or an invalid number of arguments is set, an error will be thrown.
 */
native pp_set_float(const id, const key[], const Float:value);

/**
 * Checks if the specified key exists.
 *
 * @param key               Unique key to which the value will be set
 *
 * @return                  true on success, false otherwise
 */
native bool: pp_has_key_global(const key[]);

/**
 * Gets the value of the specified key as string.
 *
 * @param key               Unique key to search for
 * @param dest              Buffer to copy value to
 * @param length            Maximum buffer size
 * @param defaultValue      Default value to set if key wasn't found
 *
 * @return                  Key's value set to the player or defaultValue if key wasn't found
 */
native pp_get_string_global(const key[], dest[], const length, const defaultValue[] = "");

/**
 * Sets a string value for specified key.
 *
 * @param key               Unique key to set the value to
 * @param value             Value to set
 *
 * @return                  1 on success, 0 otherwise
 */
native pp_set_string_global(const key[], const value[]);

/**
 * Gets the value of the specified key as integer.
 *
 * @param key               Unique key to search for
 * @param defaultValue      Default value to set if key wasn't found
 *
 * @return                  Key's value set to the player or defaultValue if key wasn't found
 */
native pp_get_number_global(const key[], const defaultValue = 0);

/**
 * Sets an integer value for specified key.
 *
 * @param key               Unique key to set the value to
 * @param value             Value to set
 *
 * @return                  1 on success, 0 otherwise
 */
native pp_set_number_global(const key[], const value);

/**
 * Gets the value of the specified key as boolean.
 *
 * @param key               Unique key to search for
 * @param defaultValue      Default value to set if key wasn't found
 *
 * @return                  Key's value set to the player or defaultValue if key wasn't found
 */
native bool: pp_get_bool_global(const key[], const bool:defaultValue = false);

/**
 * Sets a boolean value for specified key.
 *
 * @param key               Unique key to set the value to
 * @param value             Value to set
 *
 * @return                  1 on success, 0 otherwise
 */
native pp_set_bool_global(const key[], const bool:value);

/**
 * Gets the value of the specified key as float.
 *
 * @param key               Unique key to search for
 * @param defaultValue      Default value to set if key wasn't found
 *
 * @return                  Key's value set to the player or defaultValue if key wasn't found
 */
native Float: pp_get_float_global(const key[], const Float:defaultValue = 0.0);

/**
 * Sets a float value for specified key.
 *
 * @param key               Unique key to set the value to
 * @param value             Value to set
 *
 * @return                  1 on success, 0 otherwise
 */
native pp_set_float_global(const key[], const Float:value);
