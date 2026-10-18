enum PLAYER_ACT
{
	NONE,
	
	SLAM,
	PUNCTURE,
	X_SLASH, ONSLAUGHT,
	
	ACID_LOB,
	ICE_SHARD,
	FIREBOLT, FIREBALL,
	FORCE_PUSH,
	LIGHTNING_FLASH,
	VAMPIRISM,
	POISON_DART,
	MIND_SPIKE,
	SMITE,
	THUNDERCLAP,
	
	COUNT
}

function is_enemy(_o)
{
	return instance_exists(_o) && (_o.object_index == obj_enemy || object_is_ancestor(_o.object_index, obj_enemy));
}

// kind: "line" (x1,y1 -> x2,y2) "beam", "ring" (center x1,y1 r0 -> r1), "arc" (center x1,y1, a0, sweep, r0 -> r1)
function act_fx(_kind, _a)
{
	var _s = { kind: _kind, x1: 0, y1: 0, x2: 0, y2: 0, r0: 0, r1: 0, a0: 0, sweep: 360, thick: 3, col: c_white, life: 12 };
	var _n = variable_struct_get_names(_a);
	for (var i = 0; i < array_length(_n); i++) _s[$ _n[i]] = _a[$ _n[i]];
	instance_create_depth(0, 0, -9000, obj_act_fx, _s);
}

// power = multiplier on your atk (physical) or mag (elemental) stat, before the target's defense.
// Acts with `cast` use the built-in cast routine. Acts with `step` run their own.
global.acts = array_create(PLAYER_ACT.COUNT, undefined);

// ---------------- Bludgeoning ----------------
global.acts[PLAYER_ACT.SLAM] = {
	name: "Slam", desc: "Leap, hang in the air, then crash down. A shockwave rolls out left and right.",
	type: DamageType.BLUDGEONING, power: 2.0, needsTarget: false, col: make_colour_rgb(255, 170, 60),
	enter: function()
	{
		hSpd = 0;
		vSpd = -sqrt(2 * grav * 36);
		sprite_index = spr.jump; image_index = 0;
	},
	step: function()
	{
		hSpd = 0;
		switch (actPhase)
		{
			case 0:   // rise
				vSpd += grav;
				sprite_index = spr.jump; image_index = 0;
				if (vSpd >= -0.4) { vSpd = 0; actPhase = 1; actTimer = 0; }
				break;

			case 1:   // hang (the windup)
				vSpd = 0;
				if (actTimer >= 18) { actPhase = 2; actTimer = 0; sprite_index = spr.fall; image_index = 0; }
				break;

			case 2:   // slam down
				if (!onGround) { vSpd = 11; break; }
				act_hit_circle(x, bbox_bottom - 6, 24, 1.2, 3);
				act_wave(-1);
				act_wave(1);
				screen_shake(7);
				flashTimer = flashDur;
				actPhase = 3; actTimer = 0;
				break;

			case 3:   // recover
				vSpd = 0;
				if (actTimer >= 14) act_end();
				break;
		}
	}
};

// ---------------- Piercing ----------------
global.acts[PLAYER_ACT.PUNCTURE] = {
	name: "Puncture", desc: "Thrust through enemies in the direction you're holding.",
	type: DamageType.PIERCING, power: 1.7, needsTarget: false, col: make_colour_rgb(220, 225, 235),
	enter: function()
	{
		var _dx = kRight - kLeft;
		var _dy = input_check("down") - input_check("up");
		if (_dx == 0 && _dy == 0) _dx = facing;
		if (_dx != 0) facing = _dx;
		actData.dir = point_direction(0, 0, _dx, _dy);
		actData.px = x; actData.py = y;
		hSpd = 0; vSpd = 0;
		sprite_index = spr.attack; image_index = 0;
	},
	step: function()
	{
		switch (actPhase)
		{
			case 0:   // windup
				hSpd = 0; vSpd = 0;
				if (actTimer >= 7) { actPhase = 1; actTimer = 0; flashTimer = 3; }
				break;

			case 1:   // thrust
				hSpd = lengthdir_x(10, actData.dir);
				vSpd = lengthdir_y(10, actData.dir);
				act_afterimage();
				act_hit_circle(x + lengthdir_x(14, actData.dir), (bbox_top + bbox_bottom) / 2 + lengthdir_y(14, actData.dir), 12, 1, 3);
				var _blocked = (x == actData.px && y == actData.py && actTimer > 2);
				actData.px = x; actData.py = y;
				if (actTimer >= 12 || _blocked) { hSpd = 0; vSpd = 0; actPhase = 2; actTimer = 0; }
				break;

			case 2:   // recover
				hSpd = 0; vSpd = 0;
				if (actTimer >= 8) act_end();
				break;
		}
	}
};

// ---------------- Slashing ----------------
global.acts[PLAYER_ACT.X_SLASH] = {
	name: "X Slash", desc: "Two heavy downward slashes in an X, stepping forward with each.",
	type: DamageType.SLASHING, power: 1.5, needsTarget: false, col: make_colour_rgb(235, 235, 245),
	enter: function() { hSpd = 0; sprite_index = spr.attack; image_index = 0; actData.n = 0; },
	step: function()
	{
		act_gravity(0.4);
		var _top = bbox_top - 4;
		var _bot = bbox_bottom - 4;

		switch (actPhase)
		{
			case 0:   // windup
				act_brake();
				if (actTimer >= 12)
				{
					actPhase = 1; actTimer = 0;
					hitList = [];
					hSpd = facing * 2.6;
					// slash 1 cuts down-forward, slash 2 cuts down-back, forming the X
					var _ax = (actData.n == 0) ? x - facing * 8  : x + facing * 42;
					var _bx = (actData.n == 0) ? x + facing * 42 : x - facing * 8;
					act_fx("line", { x1: _ax, y1: _top, x2: _bx, y2: _bot, thick: 6, col: actCur.col, life: 12 });
					screen_shake(2);
				}
				break;

			case 1:   // strike, lunging forward
				act_hit_rect(x + facing * 2, _top, x + facing * 40, _bot, 1, 2);
				if (actTimer >= 8)
				{
					hSpd = 0;
					actData.n++;
					actPhase = (actData.n >= 2) ? 2 : 0;
					actTimer = 0;
				}
				break;

			case 2:   // recover
				act_brake();
				if (actTimer >= 14) act_end();
				break;
		}
	}
};

global.acts[PLAYER_ACT.ONSLAUGHT] = {
	name: "Onslaught", desc: "Dash forward, then carve a curved slash all the way around you.",
	type: DamageType.SLASHING, power: 1.8, needsTarget: false, col: make_colour_rgb(235, 235, 245),
	enter: function()
	{
		var _dx = kRight - kLeft;
		if (_dx != 0) facing = _dx;
		hSpd = 0; vSpd = 0;
		sprite_index = spr.attack; image_index = 0;
	},
	step: function()
	{
		switch (actPhase)
		{
			case 0:   // windup
				act_brake();
				act_gravity();
				if (actTimer >= 9) { actPhase = 1; actTimer = 0; }
				break;

			case 1:   // dash forward
				hSpd = facing * 8;
				vSpd = 0;
				act_afterimage();
				if (actTimer >= 12 || place_meeting(x + facing * 2, y, obj_col))
				{
					hSpd = 0;
					actPhase = 2; actTimer = 0;
					hitList = [];
					act_fx("arc", { x1: x, y1: (bbox_top + bbox_bottom) / 2, r0: 30, r1: 40, a0: 90,
						sweep: (facing > 0) ? -300 : 300, thick: 7, col: actCur.col, life: 14 });
					screen_shake(3);
				}
				break;

			case 2:   // slash
				act_brake();
				act_gravity();
				if (actTimer < 6) act_hit_circle(x, (bbox_top + bbox_bottom) / 2, 40, 1, 3);
				if (actTimer >= 16) act_end();
				break;
		}
	}
};

// ---------------- Acid ----------------
global.acts[PLAYER_ACT.ACID_LOB] = {
	name: "Acid Lob", desc: "Lob a glob of acid that bursts on impact.",
	type: DamageType.ACID, power: 0.9, needsTarget: true, col: make_colour_rgb(190, 230, 60),
	cast: { kind: "proj", windup: 12, recover: 12, spd: 4, radius: 6, grav: 0.12, homing: 0, splash: 22, knock: 1 }
};

// ---------------- Cold ----------------
global.acts[PLAYER_ACT.ICE_SHARD] = {
	name: "Ice Shard", desc: "Launch a sharp icicle that chills what it hits.",
	type: DamageType.COLD, power: 1.2, needsTarget: true, col: make_colour_rgb(120, 190, 255),
	cast: { kind: "proj", windup: 10, recover: 10, spd: 7, radius: 5, grav: 0, homing: 0, splash: 0, knock: 1 }
};

// ---------------- Fire ----------------
global.acts[PLAYER_ACT.FIREBOLT] = {
	name: "Firebolt", desc: "A fast bolt of fire. Minor damage.", icon: spr_actFirebolt,
	type: DamageType.FIRE, power: 0.8, needsTarget: true, col: make_colour_rgb(255, 140, 40),
	cast: { kind: "proj", windup: 6, recover: 8, spd: 9, radius: 4, grav: 0, homing: 0, splash: 0, knock: 1 }
};

global.acts[PLAYER_ACT.FIREBALL] = {
	name: "Fireball", desc: "A slow, heavy fireball that bends toward its target and explodes.",
	type: DamageType.FIRE, power: 2.6, needsTarget: true, col: make_colour_rgb(255, 110, 30),
	cast: { kind: "proj", windup: 22, recover: 16, spd: 3.5, radius: 9, grav: 0, homing: 1.5, splash: 28, knock: 2 }
};

// ---------------- Force ----------------
global.acts[PLAYER_ACT.FORCE_PUSH] = {
	name: "Force Push", desc: "A short-range blast that hurls enemies away.",
	type: DamageType.FORCE, power: 0.8, needsTarget: false, col: make_colour_rgb(200, 215, 255),
	cast: { kind: "burst", windup: 10, recover: 12, shape: "rect", w: 56, r: 0, knock: 2, shake: 3 }
};

// ---------------- Lightning ----------------
global.acts[PLAYER_ACT.LIGHTNING_FLASH] = {
	name: "Lightning Flash", desc: "Blink to the target at lightning speed, zapping anything in the way.",
	type: DamageType.LIGHTNING, power: 1.2, needsTarget: true, col: make_colour_rgb(255, 240, 90),
	enter: function()
	{
		hSpd = 0; vSpd = 0; hSpdRem = 0; vSpdRem = 0;
		sprite_index = spr.jump; image_index = 0;
		actData.px = x; actData.py = y;
		var _dx = actTargetRun.x - x;
		if (_dx != 0) facing = sign(_dx);
	},
	step: function()
	{
		if (!instance_exists(actTargetRun)) { hSpd = 0; vSpd = 0; act_end(); return; }

		sprite_index = spr.jump;   // hold the first jump frame
		image_index = 0;

		if (actPhase == 0)   // windup, gravity off
		{
			hSpd = 0; vSpd = 0;
			if (actTimer >= SEC * 0.25)
			{
				actPhase = 1; actTimer = 0;
				actData.px = x; actData.py = y;
				flashTimer = flashDur;
				screen_shake(6);
			}
			return;
		}

		var _tx = actTargetRun.x;
		var _ty = actTargetRun.y;
		var _dist = point_distance(x, y, _tx, _ty);

		// Arrived: snap and stop dead
		if (_dist <= 20 * global.timeScale)
		{
			if (!place_meeting(_tx, _ty, obj_col)) { x = _tx; y = _ty; }
			hSpd = 0; vSpd = 0;
			act_end();
			return;
		}

		// Blocked by a solid
		if (x == actData.px && y == actData.py && actTimer > 1) { hSpd = 0; vSpd = 0; act_end(); return; }
		actData.px = x; actData.py = y;

		var _dir = point_direction(x, y, _tx, _ty);
		hSpd = lengthdir_x(20, _dir);
		vSpd = lengthdir_y(20, _dir);
		act_afterimage();
		if (actCur.power > 0) act_hit_circle(x, (bbox_top + bbox_bottom) / 2, 14, 1, 2);   // set power to 0 for pure movement
	}
};

// ---------------- Necrotic ----------------
global.acts[PLAYER_ACT.VAMPIRISM] = {
	name: "Vampirism", desc: "Drain a target with necrotic energy and heal for 25% of the damage dealt.",
	type: DamageType.NECROTIC, power: 1.5, needsTarget: true, col: make_colour_rgb(150, 60, 190),
	cast: { kind: "instant", windup: 16, recover: 14, knock: 0, sky: false },
	onHit: function(_dealt)
	{
		if (_dealt <= 0) return;
		var _h = max(1, round(_dealt * 0.25));
		heal(_h);
		show_number(_h, c_lime);
	}
};

// ---------------- Poison ----------------
global.acts[PLAYER_ACT.POISON_DART] = {
	name: "Poison Dart", desc: "A very fast, light dart that leaves poison behind.",
	type: DamageType.POISON, power: 0.5, needsTarget: true, col: make_colour_rgb(80, 190, 110),
	cast: { kind: "proj", windup: 6, recover: 6, spd: 11, radius: 3, grav: 0, homing: 0, splash: 0, knock: 0 }
};

// ---------------- Psychic ----------------
global.acts[PLAYER_ACT.MIND_SPIKE] = {
	name: "Mind Spike", desc: "A spike of thought that always hits and leaves the target confused.",
	type: DamageType.PSYCHIC, power: 1.1, needsTarget: true, col: make_colour_rgb(240, 110, 200),
	cast: { kind: "instant", windup: 14, recover: 12, knock: 0, sky: false }
};

// ---------------- Radiant ----------------
global.acts[PLAYER_ACT.SMITE] = {
	name: "Smite", desc: "A pillar of light falls on the target and brands it, so it takes extra damage.",
	type: DamageType.RADIANT, power: 1.6, needsTarget: true, col: make_colour_rgb(255, 225, 110),
	cast: { kind: "instant", windup: 24, recover: 14, knock: 0, sky: true }
};

// ---------------- Thunder ----------------
global.acts[PLAYER_ACT.THUNDERCLAP] = {
	name: "Thunderclap", desc: "A concussive burst around you that staggers everything nearby.",
	type: DamageType.THUNDER, power: 1.0, needsTarget: false, col: make_colour_rgb(190, 180, 255),
	cast: { kind: "burst", windup: 16, recover: 14, shape: "circle", w: 0, r: 56, knock: 2, shake: 6 }
};