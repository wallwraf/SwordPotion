// Inherit the parent event
event_inherited();

// Sprites
spr = { idle: spr_huntressIdle, walk: spr_huntressWalk, dash: spr_huntressDash, dead: spr_huntressDeath };
mask_index = spr_huntressIdle;

// Stats
stats.hp = 50; stats.hpMax = 50; stats.atk = 6;
state_use_all();
cfg.attackState = ES_HUNTRESSDASH;
cfg.attackRange = 100;
dashDir = 1;

// Affinities

// States
state_add(ES_HUNTRESSDASH, {
	enter: function()
	{
		attackCd = cfg.atkCooldown;
		dashDir = facing;
		hSpd = 0;
		anim(["dash", "run", "walk"]);
	},
	step: function()
	{
		if (stateTimer < 1) { hSpd = 0; return; }
		hSpd = dashDir * 5;
		try_melee();
		if (stateTimer > 15 || place_meeting(x + dashDir * 2, y, obj_col)) { hSpd = 0; attack_finished(); }
	}
});