#include <amxmodx>
#include <amxmisc>
#include <player_preferences>
#include <unreal_lite_rank>
#include <csx>
#include <engine>
// Нужно перевести на reapi не забыть
#include <reapi>

/* PLUGIN INFO */
public stock const PluginName[] = "Unreal Lite Rank";
public stock const PluginVersion[] = "1.0.1";
public stock const PluginAuthor[] = "Karaulov";
public stock const PluginURL[] = "https://";

/* Defs */
#define CSW_SHIELD          2
#define WEAPONS_END         CSW_P90 + 1

#define is_weapon_valid(%1) (0 < %1 < WEAPONS_END)
#define is_user_valid(%1)   (1 <= %1 <= MAX_PLAYERS)

#define ADMIN_GIRL ADMIN_LEVEL_G

enum _:MEHp { ME_dmg, ME_lasthit, ME_victim, ME_killerid, ME_killername[33], Float:ME_distance, Float:ME_hpkiller, Float:ME_apkiller };

#define MAGIC_NUMBER -9999

/* GLOBAL VARIABLES */
new bool:g_StatsActivated[MAX_PLAYERS + 1];
new g_sFormatString1[256];
new weaponsAmmo[MAX_PLAYERS + 1][WEAPONS_END];

new bool:g_bBombPlant[MAX_PLAYERS + 1];
new bool:g_pbomb_planted[MAX_PLAYERS + 1];
new bool:g_pbomb_defusing[MAX_PLAYERS + 1];
new bool:g_pbomb_defused[MAX_PLAYERS + 1];

new g_iPlayerData[MAX_PLAYERS + 1][MEHp];
new const g_szHitPlaces[][] = { "тело", "чepeп", "гpyдь", "живoт", "лeвyю pyкy", "пpaвyю pyкy", "лeвyю нoгy", "пpaвyю нoгy", "xз кyдa"  };
new const g_szHitPlaces2[][] = { "тело", "мoзг", "пpямo в cepдцe", "дyшy", "лeвoe yxo", "пpaвый глaз", "лeвый бoтинoк", "пpaвoe кoлeнo", "xз кyдa" };

new g_iRoundId = 0;

new Float:g_fRoundTime = -1.0;
new bool:g_bDisableSAYHPME = false;

new g_iCacheSkills[MAX_PLAYERS + 1] = {0,...};
new Float:g_fCacheSkillsTime[MAX_PLAYERS + 1] = {0.0,...};

new g_iCacheScore[MAX_PLAYERS + 1] = {0,...};
new Float:g_fCacheScoreTime[MAX_PLAYERS + 1] = {0.0,...};


new g_iLevelId = 0;
new g_sRanks[64][64];
new g_iRanks[64] = {-1,...};


new g_iSkillId = 0;
new g_sSkills[64][64];
new g_iSkills[64] = {-1,...};

new g_iPlayerStartSkill[MAX_PLAYERS + 1];
new g_iPlayerStartRank[MAX_PLAYERS + 1];


new g_bPlayerUpdateHud[MAX_PLAYERS + 1] = {true,...};
new g_sPlayerHudMessage[MAX_PLAYERS + 1][256];

new g_sPrefix[64];

new Float:g_fHudPos[2];
new Float:g_fHudUpdateTimer = 1.0;
new Float:g_fStatsCacheClearTime = 5.0;

new Float:g_fCurrentTime = 0.0;

new g_iPTS_TRY_PLACE_BOMB = 5;
new g_iPTS_PLACE_BOMB = 10;
new g_iPTS_TRY_DEF_BOMB = 5;
new g_iPTS_DEF_BOMB = 10;
new g_iPTS_EXPL_BOMB = 5;
new g_iPTS_WIN = 5;
new g_iPTS_LOSE = 10;
new g_iPTS_KILL = 5;
new g_iPTS_DEATH = 10;
new g_iPTS_HS_KILL = 5;
new g_iPTS_KILL_ASSIST = 2;

new g_iSTART_RANK = 100;
new g_iSTART_SKILL = 100;

new Float:g_fPTS_TIME_EXP_MULTIPLIER = 1.0;

new g_hHudMessageRank;
new g_hHudMessageAnother;

new g_bPaused = false;

new g_fUserLevelUpdated,g_fUserReceiveXP;

public plugin_end()
{
	DestroyForward(g_fUserLevelUpdated);
	DestroyForward(g_fUserReceiveXP);
}

public plugin_init()    {
	register_plugin(PluginName, PluginVersion, PluginAuthor/*,PluginURL*/);
	
	register_event("HLTV", "round_begin", "a", "1=0", "2=0");
	register_event("TextMsg", "round_restart", "a", "2=#Game_will_restart_in","2=#Game_Commencing");
	
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
	
	register_clcmd("say clearstats", 		"ClCmdClearStats");
	register_clcmd("say /clearstats", 		"ClCmdClearStats");
	
	register_concmd("disable_sayhp", "disable_sayhp", ADMIN_RCON);
	register_concmd("reload_rank_cfg", "reload_rank_cfg", ADMIN_RCON);
	
	register_srvcmd("rank_pause", "rank_set_pause", ADMIN_RCON);
	register_srvcmd("rank_unpause", "rank_set_unpause", ADMIN_RCON);
	
	parseConfigFile();
	
	g_hHudMessageRank = CreateHudSyncObj();
	g_hHudMessageAnother = CreateHudSyncObj();
	
	g_fUserLevelUpdated = CreateMultiForward("unrealranks_user_level_updated", ET_IGNORE, FP_CELL, FP_CELL, FP_STRING, FP_STRING);
	g_fUserReceiveXP    = CreateMultiForward("unrealranks_user_receive_xp",    ET_IGNORE, FP_CELL, FP_CELL);
	
	set_task_ex(g_fHudUpdateTimer, "hud_update_task");
	
	set_task_ex(0.5,"timer_for_update_time", .flags = SetTask_Repeat);
}

public timer_for_update_time(id)
{
	g_fCurrentTime = get_gametime();
}

public reload_rank_cfg(id)
{
	parseConfigFile();
}

public rank_set_pause(id)
{
	g_bPaused = true;
}

public rank_set_unpause(id)
{
	g_bPaused = false;
}

public hud_update_task(id)
{
	new players[ 32 ], num, i = 0, pid = 0, username[MAX_NAME_LENGTH], level, score, skillid, skillscore;
	get_players( players, num, "ch" );
	
	for(;i < num;i++)
	{
		pid = players[i];
		
		if (is_user_alive(pid))
		{
			if (!g_bPlayerUpdateHud[pid])
			{
				set_hudmessage(0, 80, 220, g_fHudPos[0], g_fHudPos[1], 0, 0.0, g_fHudUpdateTimer + 0.10, 0.0, 0.0)
				ShowSyncHudMsg(pid, g_hHudMessageRank, "%s",g_sPlayerHudMessage[pid]);
				continue;
			}
			level = getPlayerLvl(pid);
			if (level > g_iLevelId - 1)
				level = g_iLevelId - 1;
			score = getPlayerScore(pid);
			skillid = getPlayerSkill(pid);
			if (skillid > g_iSkillId - 1)
				skillid = g_iSkillId - 1;
			skillscore = getPlayerScoreSkill(pid);
			
			if (score == MAGIC_NUMBER) score = 0;
			if (skillscore == MAGIC_NUMBER) skillscore = 0;
				
			get_user_name(pid,username,charsmax(username));
			set_hudmessage(0, 80, 220, g_fHudPos[0], g_fHudPos[1], 0, 0.0, g_fHudUpdateTimer + 0.10, 0.0, 0.0)
			formatex(g_sPlayerHudMessage[pid],charsmax(g_sPlayerHudMessage[]),"Ник: %s^nУровень: %i^nЗвание: %s^nОпыт: [%i/%i][%i за карту]^nСкил: %s [%i/%i][%i за карту]",
						username, level + 1, 
						g_sRanks[level], 
						score, 
						g_iRanks[level],
						score - g_iPlayerStartRank[pid], 
						g_sSkills[skillid], 
						skillscore,
						g_iSkills[skillid], 
						skillscore - g_iPlayerStartSkill[pid]);
			
			ShowSyncHudMsg(pid, g_hHudMessageRank, "%s",g_sPlayerHudMessage[pid]);
			g_bPlayerUpdateHud[pid] = false;
			
			ExecuteForward(g_fUserLevelUpdated, _, pid, level, g_sRanks[level], g_sSkills[skillid])
		}
		else 
		{
			new specTarget = entity_get_int(pid, EV_INT_iuser2);
			if (is_user_valid(specTarget) && strlen(g_sPlayerHudMessage[specTarget]) > 0)
			{
				set_hudmessage(0, 80, 220, g_fHudPos[0], g_fHudPos[1], 0, 0.0, g_fHudUpdateTimer + 0.10, 0.0, 0.0)
				ShowSyncHudMsg(pid, g_hHudMessageRank, "%s",g_sPlayerHudMessage[specTarget]);
			}
		}
	}
	

	set_task_ex(g_fHudUpdateTimer, "hud_update_task");
}


public disable_sayhp()
{
	g_bDisableSAYHPME = true;
}

public win_t()
	round_winner(1);

public win_ct()
	round_winner(2);
	
public round_winner(team)
{
	for (new id = 1; id < MAX_PLAYERS + 1; id++) {
		if (!is_user_connected(id) || !g_StatsActivated[id]) 
			continue;
		g_bPlayerUpdateHud[id] = true;
		if (get_user_team(id) == team)
		{
			ExecuteForward(g_fUserReceiveXP, _, id, g_iPTS_WIN);
			new val = pp_get_number(id, "win");
			val++;
			pp_set_number(id,"win",val);
		}
		else 
		{
			ExecuteForward(g_fUserReceiveXP, _, id, -g_iPTS_LOSE);
			new val = pp_get_number(id, "lose");
			val++;
			pp_set_number(id,"lose",val);
		}
	}
}

getPlayerScore(id)
{
	if (!is_user_valid(id) || !g_StatsActivated[id])
	{
		return MAGIC_NUMBER;
	}
	
	if (g_fCurrentTime - g_fCacheScoreTime[id] < g_fStatsCacheClearTime)
	{
		return g_iCacheScore[id];
	}
	
	new result_score = g_iSTART_RANK;
	
	result_score += floatround((pp_get_number(id, "r_time") / 60.0) * g_fPTS_TIME_EXP_MULTIPLIER); // 1 MIN = 1 PTS
	if (result_score > 2000)
		result_score = 2000;
	result_score += pp_get_number(id, "c4_pl_try") * g_iPTS_TRY_PLACE_BOMB; // 1 пoпыткa ycтaнoвить бoмбy + 5 PTS
	result_score += pp_get_number(id, "c4_pl_succ") * g_iPTS_PLACE_BOMB; // 1 ycпeшнo ycтaнoвлeннaя бoмбa + 10 PTS
	result_score += pp_get_number(id, "c4_def_try") * g_iPTS_TRY_DEF_BOMB; // 1 пoпыткa paзминиpoвaть бoмбy + 5 PTS
	result_score += pp_get_number(id, "c4_def_succ") * g_iPTS_DEF_BOMB; // 1 ycпeшнo paзминиpoвaннaя бoмбa + 10 PTS
	result_score += pp_get_number(id, "c4_expl") * g_iPTS_EXPL_BOMB; // 1 взopвaннaя бoмбa eщe + 5 PTS
	result_score += pp_get_number(id, "win") * g_iPTS_WIN; // Koмaндa пoбeдилa + 5 PTS
	result_score -= pp_get_number(id, "lose") * g_iPTS_LOSE; // Koмaндa пpoигpaлa - 10 PTS
	result_score += pp_get_number(id, "kill") * g_iPTS_KILL; // yбил + 5 PTS
	result_score -= pp_get_number(id, "dead") * g_iPTS_DEATH; // yмep - 10 PTS
	result_score += pp_get_number(id, "hs_kill") * g_iPTS_HS_KILL; // yбил в гoлoвy, eщe + 5 PTS
	result_score += pp_get_number(id, "assist") * g_iPTS_KILL_ASSIST; // Помог убить врага, + 2 PTS
	
	g_iCacheScore[id] = result_score;
	g_fCacheScoreTime[id] = g_fCurrentTime;
	
	return result_score;
}


getPlayerScoreSkill(id)
{
	if (!is_user_valid(id) || !g_StatsActivated[id])
	{
		return MAGIC_NUMBER;
	}
	
	if (g_fCurrentTime - g_fCacheSkillsTime[id] < g_fStatsCacheClearTime)
	{
		return g_iCacheSkills[id];
	}
	
	new result_score = g_iSTART_SKILL;
	new num_shots = 0;
	new Float:hs_rate = getPlayerHeadShotAccuracy(id,num_shots);
	
	result_score += pp_get_number(id, "c4_pl_try"); 
	result_score += pp_get_number(id, "c4_pl_succ");
	result_score += pp_get_number(id, "c4_def_try");
	result_score += pp_get_number(id, "c4_def_succ"); 
	result_score += pp_get_number(id, "c4_expl");
	result_score += pp_get_number(id, "win");
	result_score -= pp_get_number(id, "lose") * 3; 
	result_score += pp_get_number(id, "kill"); 
	result_score += pp_get_number(id, "assist");
	result_score -= pp_get_number(id, "dead") * 2; 
	result_score += pp_get_number(id, "hs_kill"); 
	
	if (num_shots > 10)
		result_score += floatround(hs_rate * 200.0);
	
	g_iCacheSkills[id] = result_score;
	g_fCacheSkillsTime[id] = g_fCurrentTime;
	
	return result_score;
}

getPlayerLvl(id)
{
	new last_success_lvl = g_iLevelId - 1;
	new pl_score = getPlayerScore(id);
	if (pl_score != MAGIC_NUMBER)
	{
		if (g_iPlayerStartRank[id] == -1)
			g_iPlayerStartRank[id] = pl_score;
		for(new i = 0; i < g_iLevelId; i++)
		{
			if (pl_score < g_iRanks[i] && g_iRanks[i] != -1)
			{
				last_success_lvl = i;
				break;
			}
		}
	}
	return last_success_lvl;
}

getPlayerSkill(id)
{
	new last_success_lvl = g_iSkillId - 1;
	new pl_score = getPlayerScoreSkill(id);
	if (pl_score != MAGIC_NUMBER)
	{
		if (g_iPlayerStartSkill[id] == -1)
			g_iPlayerStartSkill[id] = pl_score;
		for(new i = 0; i < g_iSkillId; i++)
		{
			if (pl_score < g_iSkills[i] && g_iSkills[i] != -1)
			{
				last_success_lvl = i;
				break;
			}
		}
	}
	return last_success_lvl;
}

Float:getPlayerShotAccuracy(id)
{
	if (!is_user_valid(id) || !g_StatsActivated[id])
	{
		return 1.0;
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
	
	return float(num_shots_with_target) /  float(num_shots);
}

Float:getPlayerHeadShotAccuracy(id, &numshotsout = -1)
{
	if (!is_user_valid(id) || !g_StatsActivated[id])
	{
		return 1.0;
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
	
	if (numshotsout != -1)
		numshotsout = num_shots;
	
	return float(num_headshots) /  float(num_shots);
}


public ClCmdStats(id)
{
	if (g_StatsActivated[id])
	{
		client_print_color(id, print_team_red, "^4[%s]^3 PTS: ^4%i^3. yбийcтв: ^4%i^3. Cмepтeй: ^4%i^3. Xeдшoтoв: ^4%i^3. Пoбeд: ^4%i^3. Пopaжeний: ^4%i^3.", g_sPrefix,
												getPlayerScore(id), pp_get_number(id, "kill"),pp_get_number(id, "dead"),pp_get_number(id, "hs_kill"),pp_get_number(id, "win"),pp_get_number(id, "lose"));
		client_print_color(id, print_team_red, "^4[%s]^3 Пoмoг yбить ^4%i^3 врагов. Тoчнocть пoпaдaний ^4%i%%^3. Тoчнocть в гoлoвy ^4%i%%^3",g_sPrefix, pp_get_number(id, "assist"),
												floatround(getPlayerShotAccuracy(id) * 100.0), floatround(getPlayerHeadShotAccuracy(id) * 100.0));
	}
	else 
	{
		client_print_color(id, print_team_red, "^4[%s]^3 Нет данных. ",g_sPrefix);
	}
}

public ClCmdClearStats(id)
{
	if (g_StatsActivated[id])
	{
		g_bPlayerUpdateHud[id] = true;
		g_iPlayerStartSkill[id] = -1;
		g_iPlayerStartRank[id] = -1;
		
		getPlayerSkill(id); getPlayerLvl(id);
		
		new plName[33];
		get_user_name(id,plName,charsmax(plName));
		pp_clear(id);
		client_print_color(id, print_team_red, "^4[%s]^3 Игрок ^4%s^3 покидает нас.",g_sPrefix,plName);
		set_task(2.0, "homecoming_back", 0)
	}
}

public homecoming_back(id)
{
	client_print_color(id, print_team_red, "^4[%s]^3 Но обещает вернуться.",g_sPrefix);
}

public round_restart()
{
	g_iRoundId = 0;
	g_fRoundTime = get_gametime();
}
public round_begin()	
{
	g_iRoundId++;
	if (g_fRoundTime < 0.0)
		g_fRoundTime = get_gametime();
	for(new id = 0; id < MAX_PLAYERS + 1;id++)
	{
		g_bBombPlant[id] = false;
		g_pbomb_planted[id] = false;
		g_pbomb_defusing[id] = false;
		g_pbomb_defused[id] = false;
		
		g_bPlayerUpdateHud[id] = true;
		
		arrayset(g_iPlayerData[id], 0, MEHp);
		
		for (new i = 0; i < WEAPONS_END;i++)
		{
			weaponsAmmo[id][i] = -1;
		}
		
		if (g_StatsActivated[id])
		{
			new fval = pp_get_number(id, "r_time");
			fval += floatround(get_gametime() - g_fRoundTime);
			pp_set_number(id,"r_time",fval);
		}
	}
	g_fRoundTime = get_gametime();
}

public client_disconnected(id)
{
	g_StatsActivated[id] = false;
	arrayset(g_iPlayerData[id], 0, MEHp);
	for(new i = 0; i < MAX_PLAYERS + 1;i++)
	{
		if (g_iPlayerData[i][ME_killerid] == id)
		{
			arrayset(g_iPlayerData[i], 0, MEHp);
		}
	}
	
	if (task_exists(id))
		remove_task(id);
		
		
	g_iCacheSkills[id] = 0;
	g_fCacheSkillsTime[id] = 0.0;
	g_iCacheScore[id] = 0;
	g_fCacheScoreTime[id] = 0.0;
	
	
	
	g_iPlayerStartSkill[id] = -1;
	g_iPlayerStartRank[id] = -1;
}

public client_putinserver(id)
{
	arrayset(g_iPlayerData[id], 0, MEHp);
	for(new i = 0; i < MAX_PLAYERS + 1;i++)
	{
		if (g_iPlayerData[i][ME_killerid] == id)
		{
			arrayset(g_iPlayerData[i], 0, MEHp);
		}
	}
	g_bPlayerUpdateHud[id] = true;
	g_iPlayerStartSkill[id] = -1;
	g_iPlayerStartRank[id] = -1;
	
	g_iCacheSkills[id] = 0;
	g_fCacheSkillsTime[id] = 0.0;
	g_iCacheScore[id] = 0;
	g_fCacheScoreTime[id] = 0.0;
}

public player_join_event(id)
{
	g_bPlayerUpdateHud[id] = true;
	for (new i = 0; i < WEAPONS_END;i++)
	{
		weaponsAmmo[id][i] = -1;
	}
	
	if (pp_get_number(id,"first", 0) == 0)
	{
		pp_set_number(id,"first", get_systime());
		client_print_color(id, print_team_red, "^4[%s]^3 Bы впepвыe зaшли нa нaш cepвep!",g_sPrefix);
		new playername[33];
		get_user_name(id,playername,charsmax(playername));
		client_print_color(0, print_team_red, "^4[%s]^3 Пpивeтcтвyeм нoвoгo бoйцa ^4%s^3!",g_sPrefix, playername);
		g_bPlayerUpdateHud[id] = true;
		g_iPlayerStartSkill[id] = -1;
		g_iPlayerStartRank[id] = -1;
		
		getPlayerSkill(id); getPlayerLvl(id);
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
			client_print_color(id, print_team_red, "^4[%s]^3 Пpивeтcтвyeм cнoвa, вac нe былo ^4%i^3 днeй ^4%i^3 чacoв ^4%i^3 минyт и %i ^4ceкyнд^3!",g_sPrefix,days, hours, minutes, last_time);
			
		}
	}
	pp_set_number(id,"last", get_systime());
}

public player_loaded(const id)
{
	if (!g_StatsActivated[id] && id != 0)
	{
		set_task(2.0, "player_join_event", id);
	}
	g_StatsActivated[id] = true;
	g_bPlayerUpdateHud[id] = true;
}

public player_unloaded(const id)
{
	if (task_exists(id))
		remove_task(id);
	g_StatsActivated[id] = false;
}

public player_save(const id)
{
	if (g_StatsActivated[id])
		pp_set_number(id,"last", get_systime());
}

public cur_weapon(id)
{
	if (!g_StatsActivated[id] || g_bPaused)
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
	if (is_user_valid(attacker) && g_StatsActivated[attacker] && !g_bPaused)
	{
		g_bPlayerUpdateHud[attacker] = true;
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
	
	if (is_user_valid(victim) && g_StatsActivated[victim] && !g_bPaused)
	{
		g_bPlayerUpdateHud[victim] = true;
		new val = pp_get_number(victim, "in_dmg");
		val+=damage;
		pp_set_number(victim,"in_dmg",val);
	}
	
	if (is_user_valid(attacker))
	{
		g_iPlayerData[attacker][ME_dmg] += damage;
		if (is_user_valid(victim))
		{
			g_iPlayerData[attacker][ME_victim] = victim;
		}
		g_iPlayerData[attacker][ME_lasthit] = hitplace;
	}
	
	
}

public client_death(killer, victim, wpnindex, hitplace, TK)
{
	new val = 0;
	if (is_user_valid(killer) && g_StatsActivated[killer] && !g_bPaused)
	{
		g_bPlayerUpdateHud[killer] = true;
		formatex(g_sFormatString1, charsmax(g_sFormatString1), "w%i_k", wpnindex);
		val = pp_get_number(killer,g_sFormatString1);
		val++;
		pp_set_number(killer,g_sFormatString1,val);
		
		ExecuteForward(g_fUserReceiveXP, _, killer, g_iPTS_KILL)
			
		val = pp_get_number(killer, "kill");
		val++;
		pp_set_number(killer,"kill",val);
		
		if (hitplace == HIT_HEAD)
		{
			formatex(g_sFormatString1, charsmax(g_sFormatString1), "w%i_khs", wpnindex);
			val = pp_get_number(killer,g_sFormatString1);
			val++;
			pp_set_number(killer,g_sFormatString1,val);
			
			ExecuteForward(g_fUserReceiveXP, _, killer, g_iPTS_HS_KILL)
		
			val = pp_get_number(killer, "hs_kill");
			val++;
			pp_set_number(killer,"hs_kill",val);
		}
		
	}
	
	if (is_user_valid(victim) && g_StatsActivated[victim] && !g_bPaused)
	{
		g_bPlayerUpdateHud[victim] = true;
		ExecuteForward(g_fUserReceiveXP, _, victim, -g_iPTS_DEATH)
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
	
	/*if (is_user_valid(victim) && is_user_connected(victim) && !g_bDisableSAYHPME)
	{
		ClCmdHP(victim);
		ClCmdME(victim);
	}*/
	if (!g_bPaused)
	{
		for(new i = 1; i < MAX_PLAYERS + 1;i++)
		{
			if (i != killer && g_iPlayerData[i][ME_victim] == victim && 
				g_StatsActivated[i])
			{
				ExecuteForward(g_fUserReceiveXP, _, killer, g_iPTS_KILL_ASSIST)
				val = pp_get_number(killer, "assist");
				val++;
				pp_set_number(killer,"assist",val);
			}
		}
	}
}

public bomb_planting(planter)
{
	if (is_user_valid(planter) && !g_bBombPlant[planter] && g_StatsActivated[planter] && !g_bPaused)
	{
		g_bBombPlant[planter] = true;
		g_bPlayerUpdateHud[planter] = true;
		ExecuteForward(g_fUserReceiveXP, _, planter, g_iPTS_TRY_PLACE_BOMB)
		
		new val = pp_get_number(planter, "c4_pl_try");
		val++;
		pp_set_number(planter, "c4_pl_try",val);
	}
}

public bomb_planted(planter)
{
	if (is_user_valid(planter) && !g_pbomb_planted[planter] && g_StatsActivated[planter] && !g_bPaused)
	{
		g_pbomb_planted[planter] = true;
		g_bPlayerUpdateHud[planter] = true;
		ExecuteForward(g_fUserReceiveXP, _, planter, g_iPTS_PLACE_BOMB)
		
		new val = pp_get_number(planter, "c4_pl_succ");
		val++;
		pp_set_number(planter, "c4_pl_succ",val);
	}
}

public bomb_explode(planter, defuser)
{
	if (is_user_valid(planter) && g_StatsActivated[planter] && !g_bPaused)
	{
		g_bPlayerUpdateHud[planter] = true;
		ExecuteForward(g_fUserReceiveXP, _, planter, g_iPTS_EXPL_BOMB)
		
		new val = pp_get_number(planter, "c4_expl");
		val++;
		pp_set_number(planter, "c4_expl",val);
	}
	if (is_user_valid(defuser) && !g_bPaused)
		g_bPlayerUpdateHud[defuser] = true;
}

public bomb_defusing(defuser)
{
	if (is_user_valid(defuser) && !g_bPaused)
	{
		g_bPlayerUpdateHud[defuser] = true;
		if (!g_pbomb_defusing[defuser] && g_StatsActivated[defuser])
		{
			g_pbomb_defusing[defuser] = true;
			ExecuteForward(g_fUserReceiveXP, _, defuser, g_iPTS_TRY_DEF_BOMB)
			
			new val = pp_get_number(defuser, "c4_def_try");
			val++;
			pp_set_number(defuser, "c4_def_try",val);
		}
	}
}

public bomb_defused(defuser)
{
	if (is_user_valid(defuser) && !g_bPaused)
	{
		g_bPlayerUpdateHud[defuser] = true;
		if (!g_pbomb_defused[defuser] && g_StatsActivated[defuser])
		{
			g_pbomb_defused[defuser] = true;
			ExecuteForward(g_fUserReceiveXP, _, defuser, g_iPTS_DEF_BOMB)

			new val = pp_get_number(defuser, "c4_def_succ");
			val++;
			pp_set_number(defuser, "c4_def_succ",val);
		}
	}
}

_ini_copyc(dest[], len, const src[], ch)
{
	new i, iRetVal;
	new bool:bCharFound;

	for (i = len; i >= 0; i--)
	{
		dest[i] = 0;

		if (!src[i])
			continue;

		if (!bCharFound && src[i] == ch)
		{
			bCharFound = true;
			continue;
		}

		dest[i] = src[i];
		iRetVal++;
	}

	return iRetVal;
}

public parseConfigFile()
{
	new configsDir[PLATFORM_MAX_PATH];
	new configPath[PLATFORM_MAX_PATH];
	new hFile;
	new szBuffer[256], szKey[64], szSection[64];

	get_configsdir(configsDir, charsmax(configsDir));
	formatex(configPath,charsmax(configPath),"%s/plugins/unreal_lite_rank/config.ini",configsDir);
	
	if (!(hFile = fopen(configPath, "rt")))
		return;

	g_iLevelId = 0;
	g_iSkillId = 0;
	
	for(new i = 0; i < MAX_PLAYERS + 1;i++)
	{
		g_iPlayerStartSkill[i] = -1;
		g_iPlayerStartRank[i] = -1;
	}
	
	while (!feof(hFile))
	{
		if (fgets(hFile, szBuffer, charsmax(szBuffer)) == 0)
			break;

		trim(szBuffer);

		if (szBuffer[0] == EOS || szBuffer[0] == ';' || szBuffer[0] == '/')
			continue;

		if (szBuffer[0] == '[')
		{
			_ini_copyc(szSection, charsmax(szSection), szBuffer[1], ']');
			continue;
		}

		split(szBuffer, szKey, charsmax(szKey), szBuffer, charsmax(szBuffer), "=");
		trim(szKey);
		trim(szBuffer);
		
		if (equali(szSection,"GENERAL"))
		{
			if (equali(szKey,"PREFIX"))
			{
				copy(g_sPrefix,charsmax(g_sPrefix),szBuffer);
			}
			else if (equali(szKey,"HUD_UPDATE_TIME"))
			{
				g_fHudUpdateTimer = str_to_float(szBuffer)
			}
			else if (equali(szKey,"HUD_POS_X"))
			{
				g_fHudPos[0] = str_to_float(szBuffer)
			}
			else if (equali(szKey,"HUD_POS_Y"))
			{
				g_fHudPos[1] = str_to_float(szBuffer)
			}
			else if (equali(szKey,"INTERNAL_HP_ME"))
			{
				g_bDisableSAYHPME = str_to_num(szBuffer) < 1;
			}
			else if (equali(szKey,"START_RANK"))
			{
				g_iSTART_RANK = str_to_num(szBuffer);
			}
			else if (equali(szKey,"START_SKILL"))
			{
				g_iSTART_SKILL = str_to_num(szBuffer);
			}
			else if (equali(szKey,"CACHE_CLEAR_TIME"))
			{
				g_fStatsCacheClearTime = str_to_float(szBuffer);
			}
		}
		else if (equali(szSection,"EXP"))
		{
			if (equali(szKey,"TRY_PLACE_BOMB"))
			{
				g_iPTS_TRY_PLACE_BOMB = str_to_num(szBuffer);
			}
			else if (equali(szKey,"PLACE_BOMB"))
			{
				g_iPTS_PLACE_BOMB = str_to_num(szBuffer);
			}
			else if (equali(szKey,"TRY_DEF_BOMB"))
			{
				g_iPTS_TRY_DEF_BOMB = str_to_num(szBuffer);
			}
			else if (equali(szKey,"DEF_BOMB"))
			{
				g_iPTS_DEF_BOMB = str_to_num(szBuffer);
			}
			else if (equali(szKey,"EXPL_BOMB"))
			{
				g_iPTS_EXPL_BOMB = str_to_num(szBuffer);
			}
			else if (equali(szKey,"WIN"))
			{
				g_iPTS_WIN = str_to_num(szBuffer);
			}
			else if (equali(szKey,"LOSE"))
			{
				g_iPTS_LOSE = str_to_num(szBuffer);
			}
			else if (equali(szKey,"DEATH"))
			{
				g_iPTS_DEATH = str_to_num(szBuffer);
			}
			else if (equali(szKey,"KILL"))
			{
				g_iPTS_KILL = str_to_num(szBuffer);
			}
			else if (equali(szKey,"HS_KILL"))
			{
				g_iPTS_HS_KILL = str_to_num(szBuffer);
			}
			else if (equali(szKey,"KILL_ASSIST"))
			{
				g_iPTS_KILL_ASSIST = str_to_num(szBuffer);
			}
			else if (equali(szKey,"TIME_EXP_MULTIPLIER"))
			{
				g_fPTS_TIME_EXP_MULTIPLIER = str_to_float(szBuffer);
			}
		}
		else if (equali(szSection,"RANKS"))
		{
			if (g_iLevelId < 64)
			{
				copy(g_sRanks[g_iLevelId],charsmax(g_sRanks[]),szBuffer);
				g_iRanks[g_iLevelId] = str_to_num(szKey);
				g_iLevelId++;
			}
		}
		else if (equali(szSection,"SKILLS"))
		{
			if (g_iSkillId < 64)
			{
				copy(g_sSkills[g_iSkillId],charsmax(g_sSkills[]),szBuffer);
				g_iSkills[g_iSkillId] = str_to_num(szKey);
				g_iSkillId++;
			}
		}
	}

	fclose(hFile);
}

public ClCmdME(id)
{
	if (g_bDisableSAYHPME)
		return PLUGIN_HANDLED;
	static player_name[33];
	switch(g_iPlayerData[id][ME_dmg])
	{
		case 0: 
		{
			client_print_color(id, id,"%s", "^1[^3ME^1] ^4Плoxoй из тeбя cнaйпep, ни oднoгo пoпaдaния!");
		}
		default:
		{
			if (is_user_connected(g_iPlayerData[id][ME_victim]))
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
	}	
	return PLUGIN_HANDLED;	
}

public ClCmdHP(id)
{
	if (g_bDisableSAYHPME)
		return PLUGIN_HANDLED;
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