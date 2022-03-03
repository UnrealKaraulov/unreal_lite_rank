#if defined _unreal_rank_included
    #endinput
#endif

#define _unreal_rank_included

/**
 * Called when the client's level changes.
 *
 * @param id	 		Client index.
 * @param level 		Level.
 * @param levelstr[]	Level String.
 * @param rankstr[]		Rank String.
 * @noreturn
 */
forward unrealranks_user_level_updated(const id,const level,const levelstr[],const rankstr[])

/**
 * Called right before the client receives XP.
 *
 * @param id	 		Client index.
 * @param xp	 		Amount of XP ready to be received.
 * @noreturn
 */
forward unrealranks_user_receive_xp(const id,const xp)
