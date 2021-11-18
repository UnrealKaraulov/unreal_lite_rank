#include <amxmodx>
#include <player_preferences>
#include <csx>
#include <engine>

/* PLUGIN INFO */
public stock const PluginName[] = "Unreal Lite Rank";
public stock const PluginVersion[] = "1.0.0";
public stock const PluginAuthor[] = "Karaulov";
public stock const PluginURL[] = "https://";

/* Defs */
#define CSW_SHIELD          2
#define WEAPONS_END         CSW_P90 + 1

#define is_weapon_valid(%1) (0 < %1 < WEAPONS_END)
#define is_user_valid(%1)   (1 <= %1 <= MAX_PLAYERS)

#define ADMIN_GIRL ADMIN_LEVEL_G

enum _:MEHp { ME_dmg, ME_lasthit, ME_victim, ME_killerid, ME_killername[32], Float:ME_distance, Float:ME_hpkiller, Float:ME_apkiller };


/* GLOBAL VARIABLES */
new bool:g_StatsActivated[MAX_PLAYERS + 1];
new g_sFormatString1[256];
new weaponsAmmo[MAX_PLAYERS + 1][WEAPONS_END];

new bool:g_pbomb_planting[MAX_PLAYERS + 1];
new bool:g_pbomb_planted[MAX_PLAYERS + 1];
new bool:g_pbomb_defusing[MAX_PLAYERS + 1];
new bool:g_pbomb_defused[MAX_PLAYERS + 1];

new g_iPlayerData[MAX_PLAYERS + 1][MEHp];
new const g_szHitPlaces[][] = { "-", "чepeп", "гpyдь", "живoт", "лeвyю pyкy", "пpaвyю pyкy", "лeвyю нoгy", "пpaвyю нoгy", "xз кyдa"  };
new const g_szHitPlaces2[][] = { "-", "мoзг", "пpямo в cepдцe", "дyшy", "лeвoe yxo", "пpaвый глaз", "лeвый бoтинoк", "пpaвoe кoлeнo", "xз кyдa" };


new Float:g_RoundTime = -1.0;
new Float:g_TotalTime[MAX_PLAYERS + 1] = {0.0,...};

public plugin_init()    {
	register_plugin(PluginName, PluginVersion, PluginAuthor/*,PluginURL*/);
	register_event("HLTV", "round_begin", "a", "1=0", "2=0")
	register_event("CurWeapon", "cur_weapon", "b" ,"1=1");
	register_clcmd("say /me", 		"ClCmdME");
	register_clcmd("say /hp", 		"ClCmdHP");
	register_clcmd("say_team /me", 		"ClCmdME");
	register_clcmd("say_team /hp", 		"ClCmdHP");
	
	
	register_clcmd("say_team /stats", 		"ClCmdStats");
	register_clcmd("say_team /rank", 		"ClCmdStats");
	
	register_clcmd("say /stats", 		"ClCmdStats");
	register_clcmd("say /rank", 		"ClCmdStats");
	register_clcmd("say stats", 		"ClCmdStats");
	register_clcmd("say rank", 		"ClCmdStats");
	
	/*register_clcmd("say /allstats", 		"ClCmdStatsAll");
	register_clcmd("say /allrank", 		"ClCmdStatsAll");
	register_clcmd("say allstats", 		"ClCmdStatsAll");
	register_clcmd("say allrank", 		"ClCmdStatsAll");*/
	
	register_event("SendAudio", "win_t" , "a", "2&%!MRAD_terwin");
	register_event("SendAudio", "win_ct", "a", "2&%!MRAD_ctwin");
}

public win_t()
	round_winner(1);

public win_ct()
	round_winner(2);
	
public round_winner(team)
{
	for (new id = 1; id <= MAX_PLAYERS; id++) {
		if (!is_user_connected(id) || !g_StatsActivated[id]) 
			continue;
		if (get_user_team(id) == team)
		{
			new val = pp_get_number(id, "win");
			val++;
			pp_set_number(id,"win",val);
		}
		else 
		{
			new val = pp_get_number(id, "lose");
			val++;
			pp_set_number(id,"lose",val);
		}
	}
}

public getPlayerScore(id)
{
	if (!is_user_valid(id) || !g_StatsActivated[id])
	{
		return 0;
	}
	new result_score = 1000;
	result_score = floatround(pp_get_float(id, "r_time")/60.0); // 1 MIN = 1 PTS
	result_score += pp_get_number(id, "c4_pl_try") * 5; // 1 пoпыткa ycтaнoвить бoмбy + 10 PTS
	result_score += pp_get_number(id, "c4_pl_succ") * 10; // 1 ycпeшнo ycтaнoвлeннaя бoмбa + 20 PTS
	result_score += pp_get_number(id, "c4_def_try") * 5; // 1 пoпыткa paзминиpoвaть бoмбy + 10 PTS
	result_score += pp_get_number(id, "c4_def_succ") * 10; // 1 ycпeшнo paзминиpoвaннaя бoмбa + 20 PTS
	result_score += pp_get_number(id, "c4_expl") * 5; // 1 взopвaннaя бoмбa eщe + 5 PTS
	result_score += pp_get_number(id, "win") * 5; // Koмaндa пoбeдилa + 5 PTS
	result_score -= pp_get_number(id, "lose") * 10; // Koмaндa пpoигpaлa - 10 PTS
	result_score -= pp_get_number(id, "dead") * 10; // yмep - 10 PTS
	result_score += pp_get_number(id, "kill") * 5; // yбил + 5 PTS
	result_score += pp_get_number(id, "hs_kill") * 2; // yбил в гoлoвy, eщe + 2 PTS
	return result_score;
}

public getPlayerShotAccuracy(id)
{
	if (!is_user_valid(id) || !g_StatsActivated[id])
	{
		return 0;
	}
	
	new num_shots, num_shots_with_target;
	
	for (new i = 1; i < WEAPONS_END; i++) 
	{
		if (i == CSW_SHIELD || i == CSW_KNIFE || i == CSW_C4 || i == CSW_FLASHBANG || i == CSW_SMOKEGRENADE) continue;
		formatex(g_sFormatString1, charsmax(g_sFormatString1), "w%i_sht", i);
		num_shots += pp_get_number(id,g_sFormatString1);
		formatex(g_sFormatString1, charsmax(g_sFormatString1), "w%i_dmgnum", i);
		num_shots_with_target += pp_get_number(id,g_sFormatString1);
	}
	
	return floatround(float(num_shots_with_target) /  float(num_shots) * 100.0);
}

public getPlayerHeadShotAccuracy(id)
{
	if (!is_user_valid(id) || !g_StatsActivated[id])
	{
		return 0;
	}
	
	new num_shots, num_headshots;
	
	for (new i = 1; i < WEAPONS_END; i++) 
	{
		if (i == CSW_SHIELD || i == CSW_KNIFE || i == CSW_C4 || i == CSW_FLASHBANG || i == CSW_SMOKEGRENADE) continue;
		formatex(g_sFormatString1, charsmax(g_sFormatString1), "w%i_dmgnum", i);
		num_shots += pp_get_number(id,g_sFormatString1);
		formatex(g_sFormatString1, charsmax(g_sFormatString1), "w%i_hhs", i);
		num_headshots += pp_get_number(id,g_sFormatString1);
	}
	
	return floatround(float(num_headshots) /  float(num_shots) * 100.0);
}

public ClCmdStats(id)
{
	if (g_StatsActivated[id])
	{
		client_print_color(id, print_team_red, "^4[PATRIOT STATS]^3 PTS: ^4%i^3. yбийcтв: ^4%i^3. Cмepтeй: ^4%i^3. Xeдшoтoв: ^4%i^3. Пoбeд: ^4%i^3. Пopaжeний: ^4%i^3.", 
												getPlayerScore(id), pp_get_number(id, "kill"),pp_get_number(id, "dead"),pp_get_number(id, "hs_kill"),pp_get_number(id, "win"),pp_get_number(id, "lose"));
		client_print_color(id, print_team_red, "^4[PATRIOT STATS]^3 Пoмoг yбить ^4%i%%^3 врагов. Тoчнocть пoпaдaний ^4%i%%^3. Тoчнocть пoпaдaний в гoлoвy ^4%i%%^3.", pp_get_number(id, "assist"),
												getPlayerShotAccuracy(id), getPlayerHeadShotAccuracy(id));
	}
	else 
	{
		client_print_color(id, print_team_red, "^4[PATRIOT STATS]^3 Нет данных. ");
	}
}

public ClCmdME(id)
{
	static player_name[32];
	switch(g_iPlayerData[id][ME_dmg])
	{
		case 0: 
		{
			client_print_color(id, id,"%s", "^1[^3ME^1] ^4Плoxoй из тeбя cнaйпep, ни oднoгo пoпaдaния!");
		}
		default:
		{
			get_user_name(g_iPlayerData[id][ME_victim], player_name, charsmax(player_name));
			if (get_user_flags(id) & ADMIN_GIRL)
			{
				if (get_user_flags(g_iPlayerData[id][ME_victim]) & ADMIN_GIRL)
				{
					client_print_color(id, id, "^1[^3ME^1] ^4Tы пoкaлeчилa людeй нa ^3%d^4 ypoнa. Пoпaлa cвoeй пoдpyгe ^3%s^4 в ^3%s^4.", g_iPlayerData[id][ME_dmg], 
					player_name, 
					g_szHitPlaces2[g_iPlayerData[id][ME_lasthit]]);
				}
				else
				{
					client_print_color(id, id, "^1[^3ME^1] ^4Tы пoкaлeчилa людeй нa ^3%d^4 ypoнa. Пocлeдний paз ^3%s^4 в ^3%s^4.", g_iPlayerData[id][ME_dmg], 
					player_name, 
					g_szHitPlaces2[g_iPlayerData[id][ME_lasthit]]);
				}
			}
			else
			{
				if (get_user_flags(g_iPlayerData[id][ME_victim]) & ADMIN_GIRL)
				{
					client_print_color(id, id, "^1[^3ME^1] ^4Tы нaнec ^3%d^4 ypoнa. Paнил дeвyшкy ^3%s^4 в ^3%s^4.", 
					g_iPlayerData[id][ME_dmg], 
					player_name, 
					g_szHitPlaces[g_iPlayerData[id][ME_lasthit]]);
				}
				else
				{
					client_print_color(id, id, "^1[^3ME^1] ^4Tы нaнec ^3%d^4 ypoнa. Пocлeднee пoпaдaниe ^3%s^4 в ^3%s^4.", g_iPlayerData[id][ME_dmg], 
					player_name, 
					g_szHitPlaces[g_iPlayerData[id][ME_lasthit]]);
				}
			}
		}
	}	
	return PLUGIN_HANDLED;	
}

public ClCmdHP(id)
{
	switch(g_iPlayerData[id][ME_killerid])
	{
		case 0: client_print_color(id, id, "%s", "^1[^3HP^1] ^4Bac ^3никтo ^4нe yбивaл.");
		default:
		{
			if (get_user_flags(g_iPlayerData[id][ME_killerid]) & ADMIN_GIRL)
			{
				if (get_user_flags(id) & ADMIN_GIRL)
				{
					client_print_color(id, g_iPlayerData[id][ME_killerid], "^1[^3HP^1] ^4Teбя yбилa пoдpyгa ^3%s^4 c ^3%.0f^4 мeтpoв. y нee ^3%.0f^1HP ^4и ^3%.0f^1AP", g_iPlayerData[id][ME_killername], g_iPlayerData[id][ME_distance], g_iPlayerData[id][ME_hpkiller], g_iPlayerData[id][ME_apkiller]);	
				}
				else
				{
					client_print_color(id, g_iPlayerData[id][ME_killerid], "^1[^3HP^1] ^4Teбя yбилa ^3%s^4 c ^3%.0f^4 мeтpoв. y нee ocтaлocь ^3%.0f^1HP ^4и ^3%.0f^1AP", g_iPlayerData[id][ME_killername], g_iPlayerData[id][ME_distance], g_iPlayerData[id][ME_hpkiller], g_iPlayerData[id][ME_apkiller]);	
				}	
			}
			else
			{
				if (get_user_flags(id) & ADMIN_GIRL)
				{
					client_print_color(id, g_iPlayerData[id][ME_killerid], "^1[^3HP^1] ^4Tы былa yбитa ^3%s^4 c ^3%.0f^4 мeтpoв. y нeгo ocтaлocь ^3%.0f^1HP ^4и ^3%.0f^1AP", g_iPlayerData[id][ME_killername], g_iPlayerData[id][ME_distance], g_iPlayerData[id][ME_hpkiller], g_iPlayerData[id][ME_apkiller]);	
				}
				else
				{
					client_print_color(id, g_iPlayerData[id][ME_killerid], "^1[^3HP^1] ^4Teбя yбил ^3%s^4 c ^3%.0f^4 мeтpoв. y нeгo ocтaлocь ^3%.0f^1HP ^4и ^3%.0f^1AP", g_iPlayerData[id][ME_killername], g_iPlayerData[id][ME_distance], g_iPlayerData[id][ME_hpkiller], g_iPlayerData[id][ME_apkiller]);		
				}	
			}
		}		
	}
	return PLUGIN_HANDLED;
}

public round_begin()	
{
	for(new id = 0; id <= MAX_PLAYERS;id++)
	{
		g_pbomb_planting[id] = false;
		g_pbomb_planted[id] = false;
		g_pbomb_defusing[id] = false;
		g_pbomb_defused[id] = false;
		
		for (new i = 0; i < WEAPONS_END;i++)
		{
			weaponsAmmo[id][i] = -1;
		}
		
		if (g_StatsActivated[id])
		{
			/*new val = pp_get_number(id, "rounds");
			val++;
			pp_set_number(id,"rounds",val);
			wins+loses=rounds
			*/
			if (g_RoundTime != -1.0)
			{
				new Float:fval = pp_get_float(id, "r_time");
				fval+= get_gametime() - g_RoundTime;
				pp_set_float(id,"r_time",fval);
			}
		}
		arrayset(g_iPlayerData[id], 0, MEHp);
	}
	g_RoundTime = get_gametime();
}

public client_disconnected(id)
{
	g_StatsActivated[id] = false;
	arrayset(g_iPlayerData[id], 0, MEHp);
	for(new i = 0; i <= MAX_PLAYERS;i++)
	{
		if (g_iPlayerData[i][ME_killerid] == id)
		{
			arrayset(g_iPlayerData[i], 0, MEHp);
		}
	}
	
	if (task_exists(id))
		remove_task(id);
}

public client_putinserver(id)
{
	arrayset(g_iPlayerData[id], 0, MEHp);
	for(new i = 0; i <= MAX_PLAYERS;i++)
	{
		if (g_iPlayerData[i][ME_killerid] == id)
		{
			arrayset(g_iPlayerData[i], 0, MEHp);
		}
	}
}

public player_join_event(id)
{
	for (new i = 0; i < WEAPONS_END;i++)
	{
		weaponsAmmo[id][i] = -1;
	}
	
	if (pp_get_number(id,"first", 0) == 0)
	{
		pp_set_number(id,"first", get_systime());
		client_print_color(id, print_team_red, "^4[PATRIOT STATS]^3 Bы впepвыe зaшли нa нaш cepвep!");
		new playername[33];
		get_user_name(id,playername,charsmax(playername));
		client_print_color(0, print_team_red, "^4[PATRIOT STATS]^3 Пpивeтcтвyeм нoвoгo бoйцa ^4%s^3!", playername);
	}
	else 
	{
		new last_time = pp_get_number(id,"last"), minutes = 0, hours = 0, days = 0;
		if (last_time != 0)
		{
			last_time = get_systime() - last_time;
			
			while (last_time >= 60) {
				last_time -= 60;
				minutes++;
			}

			while (minutes >= 60) {
				minutes -= 60;
				hours++;
			}
			
			while (hours >= 24) {
				hours -= 24;
				days++;
			}
			
			client_print_color(id, print_team_red, "^4[PATRIOT STATS]^3 Пpивeтcтвyeм cнoвa, вac нe былo ^4%i^3 днeй ^4%i^3 чacoв ^4%i^3 минyт и %i ^4ceкyнд^3!",days, hours, minutes, last_time);
		}
	}
	pp_set_number(id,"last", get_systime());

}

public player_loaded(const id)
{
	if (!g_StatsActivated[id])
	{
		set_task(2.0, "player_join_event", id);
	}
	g_StatsActivated[id] = true;
}

public player_unloaded(const id)
{
	if (task_exists(id))
		remove_task(id);
	g_StatsActivated[id] = false;
}

public cur_weapon(id)
{
	if (!g_StatsActivated[id])
		return;
	static weapon, ammo;

	weapon = read_data(2);
	ammo = read_data(3);

	if (weaponsAmmo[id][weapon] != ammo) {
		if (weaponsAmmo[id][weapon] != -1 && weaponsAmmo[id][weapon] > ammo) {
			formatex(g_sFormatString1, charsmax(g_sFormatString1), "w%i_sht", weapon);
			new val = pp_get_number(id,g_sFormatString1);
			val+=weaponsAmmo[id][weapon] - ammo;
			pp_set_number(id,g_sFormatString1,val);
		}
		weaponsAmmo[id][weapon] = ammo;
	}
}

public client_damage(attacker, victim, damage, wpnindex, hitplace, TA)
{
	if (is_user_valid(attacker) && g_StatsActivated[attacker])
	{
		new val = pp_get_number(attacker, "out_dmg");
		val+=damage;
		pp_set_number(attacker,"out_dmg",val);
		
		formatex(g_sFormatString1, charsmax(g_sFormatString1), "w%i_dmg", wpnindex);
		val = pp_get_number(attacker,g_sFormatString1);
		val+=damage;
		pp_set_number(attacker,g_sFormatString1,val);
		
		if (hitplace == HIT_HEAD)
		{
			formatex(g_sFormatString1, charsmax(g_sFormatString1), "w%i_hhs", wpnindex);
			val = pp_get_number(attacker,g_sFormatString1);
			val++;
			pp_set_number(attacker,g_sFormatString1,val);
		}
		
		formatex(g_sFormatString1, charsmax(g_sFormatString1), "w%i_dmgnum", wpnindex);
		val = pp_get_number(attacker,g_sFormatString1);
		val++;
		pp_set_number(attacker,g_sFormatString1,val);
	}
	
	if (is_user_valid(victim) && g_StatsActivated[victim])
	{
		new val = pp_get_number(victim, "in_dmg");
		val+=damage;
		pp_set_number(victim,"in_dmg",val);
	}
	
	if (is_user_valid(attacker) && is_user_valid(victim))
	{
		g_iPlayerData[attacker][ME_dmg] += damage;
		g_iPlayerData[attacker][ME_victim] = victim;
		g_iPlayerData[attacker][ME_lasthit] = hitplace;
	}
}

public client_death(killer, victim, wpnindex, hitplace, TK)
{
	new val = 0;
	if (is_user_valid(killer) && g_StatsActivated[killer])
	{
		formatex(g_sFormatString1, charsmax(g_sFormatString1), "w%i_k", wpnindex);
		val = pp_get_number(killer,g_sFormatString1);
		val++;
		pp_set_number(killer,g_sFormatString1,val);
		
		val = pp_get_number(killer, "kill");
		val++;
		pp_set_number(killer,"kill",val);
		
		if (hitplace == HIT_HEAD)
		{
			formatex(g_sFormatString1, charsmax(g_sFormatString1), "w%i_khs", wpnindex);
			val = pp_get_number(killer,g_sFormatString1);
			val++;
			pp_set_number(killer,g_sFormatString1,val);
			
			val = pp_get_number(killer, "hs_kill");
			val++;
			pp_set_number(killer,"hs_kill",val);
		}
		
	}
	
	if (is_user_valid(victim) && g_StatsActivated[victim])
	{
		val = pp_get_number(victim, "dead");
		val++;
		pp_set_number(victim,"dead",val);
	}
	
	if (is_user_valid(victim) && is_user_valid(killer)
		 && is_user_connected(killer) && is_user_connected(victim))
	{
		g_iPlayerData[victim][ME_hpkiller] = _:entity_get_float(killer, EV_FL_health);
		g_iPlayerData[victim][ME_apkiller] = _:entity_get_float(killer, EV_FL_armorvalue);
		g_iPlayerData[victim][ME_distance] = _:(entity_range(killer, victim) * 0.0254);
		g_iPlayerData[victim][ME_killerid] = killer;
		get_user_name(killer, g_iPlayerData[victim][ME_killername], charsmax(g_iPlayerData[][ME_killername]));
	}
	
	if (is_user_valid(victim) && is_user_connected(victim))
	{
		ClCmdHP(victim);
		ClCmdME(victim);
	}
	
	for(new i = 1; i <= MAX_PLAYERS;i++)
	{
		if (i != killer && g_iPlayerData[i][ME_victim] == victim && 
			g_StatsActivated[i])
		{
			val = pp_get_number(killer, "assist");
			val++;
			pp_set_number(killer,"assist",val);
		}
	}
}

public bomb_planting(planter)
{
	if (!g_pbomb_planting[planter] && g_StatsActivated[planter])
	{
		new val = pp_get_number(planter, "c4_pl_try");
		val++;
		pp_set_number(planter, "c4_pl_try",val);
	}
}

public bomb_planted(planter)
{
	if (!g_pbomb_planted[planter] && g_StatsActivated[planter])
	{
		new val = pp_get_number(planter, "c4_pl_succ");
		val++;
		pp_set_number(planter, "c4_pl_succ",val);
	}
}

public bomb_explode(planter, defuser)
{
	if (is_user_valid(planter) && g_StatsActivated[planter])
	{
		new val = pp_get_number(planter, "c4_expl");
		val++;
		pp_set_number(planter, "c4_expl",val);
	}
}

public bomb_defusing(defuser)
{
	if (!g_pbomb_defusing[defuser] && g_StatsActivated[defuser])
	{
		new val = pp_get_number(defuser, "c4_def_try");
		val++;
		pp_set_number(defuser, "c4_def_try",val);
	}
}

public bomb_defused(defuser)
{
	if (!g_pbomb_defused[defuser] && g_StatsActivated[defuser])
	{
		new val = pp_get_number(defuser, "c4_def_succ");
		val++;
		pp_set_number(defuser, "c4_def_succ",val);
	}
}