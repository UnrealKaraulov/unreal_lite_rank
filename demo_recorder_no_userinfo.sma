#include <amxmodx>
#include <engine>
#include <player_preferences>

new g_sDemoPrefix[] = "patriots_";

const TASK_DEMO1 = 1000;
const TASK_DEMO2 = 10000;


const MAX_DEMO_ID = 3;

new g_iCurrentDemoID[MAX_PLAYERS + 1];

public plugin_init()
{
	register_plugin("PP DEMO RECODER", "0.1", "Karaulov");
}

public client_disconnected(id)
{
	g_iCurrentDemoID[id] = 1;
	
	if (task_exists(id + TASK_DEMO1))
	{
		remove_task(id + TASK_DEMO1);
	}
	
	if (task_exists(id + TASK_DEMO2))
	{
		remove_task(id + TASK_DEMO2);
	}
}

public client_putinserver(id)
{
	set_task(5.0, "record_demo", TASK_DEMO1 + id);
}

public server_changelevel(map[])
{
	for(new i = 1; i < 33; i++)
	{
		if (is_user_connected(i))
		{
			client_cmd(i, "stop");
		}
	}
}

public record_demo(idtask)
{
	new id = idtask - TASK_DEMO1;
	
	g_iCurrentDemoID[id] = pp_get_number(id, "did");
	g_iCurrentDemoID[id]++;
	if (g_iCurrentDemoID[id] > MAX_DEMO_ID)
		g_iCurrentDemoID[id] = 1;
	pp_set_number(id, "did", g_iCurrentDemoID[id]);
	
	client_cmd(id, "stop");
	set_task(5.0, "record_demo2", TASK_DEMO2 + id,_,_,"b");
	new Name[33], Time[9];
	get_user_name(id, Name, 32);
	get_time("%H:%M:%S", Time, 8);
	client_print_color(id, print_team_red,"^4[NEWPATRIOTS.RU]^1 Идёт запись демо ^4^"%s_%i.dem^"^1 - ^4%s.", g_sDemoPrefix,g_iCurrentDemoID[id], Time);
}


public record_demo2(idtask)
{
	new id = idtask - TASK_DEMO2;
	if (!is_user_connected(id))
		return;
		
	client_cmd(id, "record ^"%s_%i^"",g_sDemoPrefix,g_iCurrentDemoID[id]);
}