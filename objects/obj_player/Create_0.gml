// Stats
hpMax = 100;
hp = hpMax;
hpChip = hp;
hpChipTimer = 0;
hpChipDelay = 60;
hpChipSpeed = 0.06;

status_init();
buildScale = 0.5;
baseStats = { atk: 5, def: 0, mag: 5, res: 0 };   // your base/level stats
stats = {};                                       // computed: base + equipment
affinity = array_create(array_length(global.damageTypes), 1);
equipment = { weapon: undefined, armor: undefined, accessory: undefined };

minDamage = 1;
knockResist = 0;
iframes = 0;
iframeTime = SEC * 0.5;
on_chip = function(_amount, _type) {};

hitList = [];

barRadius = 18;
barSpan = 110;
barThick = 3;
barGap = 22;
barAlpha = 0;
barShowTimer = 0;
barShowTime = 150;
barFadeIn = 0.3;
barFadeOut = 0.06;
barChipCol = make_colour_rgb(210, 210, 210);

// Animation Settings
hSpdRem = 0;
vSpdRem = 0;
mask_index = spr_player;
spr =
{
	idle: spr_player_idle,
	walk: spr_player_walk,
	run: spr_player_run,
	jump: spr_player_jump,
	fall: spr_player_fall,
	land: spr_player_land,
	fallLoop: spr_player_fall_loop,
	attack: spr_player_attack,
	attackEnd: spr_player_attack_end
}

// State Machine
enum PlayerState
{
	FREE,
	IN_AIR,
	LAND,
	ATTACK,
	ACTION,
	ACT_RUN,
	HURT,
	DEAD
}

state = PlayerState.FREE;
stateTimer = 0;

// Default Values
hSpd = 0;
vSpd = 0;
facing = 1;

walkSpd = 1;
runSpd = 3;
grav = 0.3;

// Jump Height
jumpMaxHeight = (bbox_bottom - bbox_top) * 2.5;
jumpMinHeight = 4;

jumpSpd = -sqrt(2 * grav * jumpMaxHeight);
jumpCutSpd = -sqrt(2 * grav * jumpMinHeight);

isJumping = false;
onGround = false;

landMinFall = 3;
landCancelFrames = 4;
peakFall = 0;

groundAccel = 0.25;
groundFric = 0.20;
groundTurn = 0.75;
airAccel = 0.15;
airDrag = 0.015;
airFric = 0.03;
airTurn = 0.35;

actSlow = 0.8;
actTarget = noone;
actIndex = 0;
actRange = 400;
actCx = 0;
actCy = 0;
actDrawX = 0;
actDrawY = 0;

arrowCol = make_colour_rgb(255, 255, 255);
arrowSpacing = 14;
arrowSpeed = 0.06;
arrowSize = 7;
arrowOy = -12;

flashTimer = 0;
flashDur = 6;

// ---- Player Act Slot: up to 6 equipped acts
actSlots = array_create(6, PLAYER_ACT.NONE);
actsKnown = array_create(PLAYER_ACT.COUNT, true);   // set false and unlock with act_learn() once drops exist

actCur = undefined;
actFn = undefined;
actTargetRun = noone;
actPhase = 0;
actTimer = 0;
actData = {};
actAi = 0;
actHeld = 0;
actPicked = false;
actHoldMin = 20;   // frames you must hold the menu before a no-target act can fire

function act_equip(_slot, _act)   // _act = PLAYER_ACT.NONE clears the slot
{
	if (_slot < 0 || _slot >= array_length(actSlots)) return false;
	if (_act != PLAYER_ACT.NONE)
	{
		if (!actsKnown[_act]) return false;
		for (var i = 0; i < array_length(actSlots); i++)
			if (actSlots[i] == _act) actSlots[i] = PLAYER_ACT.NONE;   // an act can only sit in one slot
	}
	actSlots[_slot] = _act;
	return true;
}

function act_unequip(_slot) { return act_equip(_slot, PLAYER_ACT.NONE); }
function act_learn(_act) { actsKnown[_act] = true; }

function act_equipped()   // compact list in slot order
{
	var _out = [];
	for (var i = 0; i < array_length(actSlots); i++)
		if (actSlots[i] != PLAYER_ACT.NONE) array_push(_out, actSlots[i]);
	return _out;
}

// ---- Running an act
function act_start(_act, _target)
{
	actCur = global.acts[_act];
	actTargetRun = _target;
	actPhase = 0;
	actTimer = 0;
	actData = {};
	actAi = 0;
	hitList = [];

	var _none = function() {};
	actFn = {
		enter: method(self, actCur[$ "enter"] ?? ((actCur[$ "cast"] != undefined) ? act_cast_enter : _none)),
		step:  method(self, actCur[$ "step"]  ?? act_cast_step),
		exit:  method(self, actCur[$ "exit"]  ?? _none)
	};
	state_change(PlayerState.ACT_RUN);
}

function act_end() { state_change(onGround ? PlayerState.FREE : PlayerState.IN_AIR); }

function state_act_run()
{
	actTimer += global.timeScale;
	actFn.step();
}

// ---- Helpers acts use
function act_power(_mult = 1)
{
	return stat_get(global.damageTypes[actCur.type].atk) * actCur.power * _mult * outMult;
}

function act_gravity(_scale = 1)
{
	if (onGround) { if (vSpd > 0) vSpd = 0; }
	else vSpd += grav * _scale;
}

function act_brake() { hSpd = approach(hSpd, 0, onGround ? groundFric : airFric); }

function act_afterimage()
{
	actAi++;
	if (actAi mod gfx().afterimage == 0)
		instance_create_depth(x, y, depth + 1, obj_afterimage, { spr: sprite_index, img: image_index, xs: image_xscale, ys: image_yscale });
}

function act_hit_list(_list, _n, _mult, _knock)
{
	var _dealt = 0;
	for (var i = 0; i < _n; i++)
	{
		var _e = _list[| i];
		if (array_contains(hitList, _e)) continue;
		array_push(hitList, _e);
		_dealt += _e.receive_hit(act_power(_mult), actCur.type, id, _knock);
	}
	return _dealt;
}

function act_hit_rect(_x1, _y1, _x2, _y2, _mult = 1, _knock = 2)
{
	var _list = ds_list_create();
	var _n = collision_rectangle_list(_x1, _y1, _x2, _y2, obj_enemy, false, true, _list, false);
	var _d = act_hit_list(_list, _n, _mult, _knock);
	ds_list_destroy(_list);
	return _d;
}

function act_hit_circle(_cx, _cy, _r, _mult = 1, _knock = 2)
{
	var _list = ds_list_create();
	var _n = collision_circle_list(_cx, _cy, _r, obj_enemy, false, true, _list, false);
	var _d = act_hit_list(_list, _n, _mult, _knock);
	ds_list_destroy(_list);
	return _d;
}

function act_wave(_dir)
{
	instance_create_depth(x + _dir * 8, bbox_bottom, depth - 1, obj_act_wave, {
		dir: _dir, spd: 4, life: 45, h: 16, dmg: act_power(1), type: actCur.type, src: id, col: actCur.col, knock: 3
	});
}

function act_projectile(_x, _y, _tx, _ty)
{
	var _c = actCur.cast;
	var _hv, _vv;
	if (_c.grav > 0)
	{
		// ballistic arc that lands on the aim point
		var _T = max(10, point_distance(_x, _y, _tx, _ty) / _c.spd);
		_hv = (_tx - _x) / _T;
		_vv = (_ty - _y) / _T - 0.5 * _c.grav * _T;
	}
	else
	{
		var _dir = point_direction(_x, _y, _tx, _ty);
		_hv = lengthdir_x(_c.spd, _dir);
		_vv = lengthdir_y(_c.spd, _dir);
	}
	instance_create_depth(_x, _y, depth - 1, obj_act_projectile, {
		hv: _hv, vv: _vv, spd: _c.spd, grav: _c.grav, homing: _c.homing, radius: _c.radius, splash: _c.splash,
		knock: _c.knock, col: actCur.col, type: actCur.type, dmg: act_power(), src: id, target: actTargetRun
	});
}

// ---- Built-in cast routine: windup -> fire -> recover (kinds: proj, instant, burst)
function act_cast_enter()
{
	sprite_index = spr.attack;
	image_index = 0;
	act_cast_aim();
}

function act_cast_aim()
{
	if (actTargetRun != noone && instance_exists(actTargetRun))
	{
		actData.tx = (actTargetRun.bbox_left + actTargetRun.bbox_right) / 2;
		actData.ty = (actTargetRun.bbox_top + actTargetRun.bbox_bottom) / 2;
		facing = (actData.tx >= x) ? 1 : -1;
	}
}

function act_cast_step()
{
	var _c = actCur.cast;
	act_gravity();
	act_brake();
	act_cast_aim();   // keeps tracking while the target lives

	if (actPhase == 0)
	{
		if (actTimer >= _c.windup) { actPhase = 1; actTimer = 0; act_cast_fire(); }
		return;
	}
	if (actTimer >= _c.recover) act_end();
}

function act_cast_fire()
{
	var _c  = actCur.cast;
	var _cy = (bbox_top + bbox_bottom) / 2;
	var _tx = actData[$ "tx"] ?? (x + facing * 100);
	var _ty = actData[$ "ty"] ?? _cy;

	switch (_c.kind)
	{
		case "proj":
			act_projectile(x + facing * 10, _cy, _tx, _ty);
			break;

		case "instant":
			if (actTargetRun == noone || !instance_exists(actTargetRun)) break;
			act_fx("beam", { x1: _c.sky ? _tx : x, y1: _c.sky ? _ty - 160 : _cy, x2: _tx, y2: _ty, thick: 5, col: actCur.col, life: 14 });
			if (is_enemy(actTargetRun))
			{
				var _dealt = actTargetRun.receive_hit(act_power(), actCur.type, id, _c.knock);
				if (actCur[$ "onHit"] != undefined) method(self, actCur.onHit)(_dealt);
			}
			screen_shake(2);
			break;

		case "burst":
			if (_c.shape == "rect")
			{
				act_hit_rect(x + facing * 4, bbox_top - 6, x + facing * _c.w, bbox_bottom, 1, _c.knock);
				act_fx("ring", { x1: x + facing * _c.w * 0.5, y1: _cy, r0: 6, r1: 24, col: actCur.col, life: 12 });
			}
			else
			{
				act_hit_circle(x, _cy, _c.r, 1, _c.knock);
				act_fx("ring", { x1: x, y1: _cy, r0: 8, r1: _c.r, col: actCur.col, life: 16 });
			}
			screen_shake(_c.shake);
			break;
	}
}

// ---- Test loadout (swap freely; the ACT menu cycles whatever is equipped)
act_equip(0, PLAYER_ACT.LIGHTNING_FLASH);
act_equip(1, PLAYER_ACT.FIREBOLT);
act_equip(2, PLAYER_ACT.FIREBALL);
act_equip(3, PLAYER_ACT.X_SLASH);
act_equip(4, PLAYER_ACT.SLAM);
act_equip(5, PLAYER_ACT.VAMPIRISM);

function move_and_collide_pixels()
{
	var _h = hSpd * global.timeScale * slowMult + hSpdRem;
	var _v = vSpd * global.timeScale + vSpdRem;
	
	var _mx = round(_h);
	var _my = round(_v);
	hSpdRem = _h - _mx;
	vSpdRem = _v - _my;
	
	// Horizontal Pixel Collision
	repeat (abs(_mx))
	{
		if (!place_meeting(x + sign(_mx), y, obj_col))
			x += sign(_mx);
		else
		{
			hSpd = 0;
			hSpdRem = 0;
			break;
		}
	}
	// Vertical Pixel Collision
	repeat (abs(_my))
	{
		if (!place_meeting(x, y + sign(_my), obj_col))
			y += sign(_my);
		else
		{
			vSpd = 0;
			vSpdRem = 0;
			break;
		}
	}
}

function enter_act_menu()
{
	actTarget = noone;
	actCx = x; actCy = y;
	actDrawX = x; actDrawY = y;
	actHeld = 0;
	actPicked = false;
	global.timeScaleTarget = 1 - actSlow;
	state_change(PlayerState.ACTION);
}

function find_act_target(_dx, _dy)
{
	var _best = noone;
	var _best_score = infinity;
	
	with (obj_actionable)
	{
		if (is_enemy(id) && state == EnemyState.DEAD) continue;
		if (id == other.actTarget) continue;
		
		var _rx = x - other.actCx;
		var _ry = y - other.actCy;
		var _dist = point_distance(0, 0, _rx, _ry);
		if (_dist == 0 || _dist > other.actRange) continue;
		
		var _forward = _rx * _dx + _ry * _dy;
		if (_forward <= 0) continue;
		
		var _cos = _forward / _dist;
		if (_cos < 0.5) continue;
		
		var _score = _dist / _cos;
		if (_score < _best_score)
		{
			_best_score = _score;
			_best = id;
		}
	}
	return _best;
}

function draw_chevron(_x, _y, _dir, _size, _col, _alpha)
{
	var _back = _dir + 180;
	var _x1 = _x + lengthdir_x(_size, _back + 45);
	var _y1 = _y + lengthdir_y(_size, _back + 45);
	var _x2 = _x + lengthdir_x(_size, _back - 45);
	var _y2 = _y + lengthdir_y(_size, _back - 45);
	
	draw_set_alpha(_alpha);
	draw_set_colour(_col);
	draw_line_width(_x1, _y1, _x, _y, 3);
	draw_line_width(_x2, _y2, _x, _y, 3);
	draw_circle(_x, _y, 1.5, false);
	draw_set_alpha(1);
	draw_set_colour(c_white);
}

function draw_act_arrow()
{
	if (actTarget == noone || !instance_exists(actTarget)) return;
	
	var _x1 = (bbox_left + bbox_right) / 2;
	var _y1 = (bbox_top + bbox_bottom) / 2;
	var _x2 = actTarget.x;
	var _y2 = actTarget.y;
	
	var _dir = point_direction(_x1, _y1, _x2, _y2);
	var _dist = point_distance(_x1, _y1, _x2, _y2);
	
	var _padStart = 10;
	var _padEnd = 20;
	var _len = _dist - _padStart - _padEnd;
	if (_len <= 0) return;
	
	// Scroll toward
	var _scroll = (current_time * arrowSpeed) mod arrowSpacing;
	
	for (var _d = _scroll; _d < _len; _d += arrowSpacing)
	{
		// Fade in
		var _fade = min(1, _d / (arrowSpacing * 2)) * min(1, (_len - _d) / (arrowSpacing * 2));
		var _px = _x1 + lengthdir_x(_padStart + _d, _dir);
		var _py = _y1 + lengthdir_y(_padStart + _d, _dir);
		draw_chevron(_px, _py, _dir, arrowSize, arrowCol, _fade);
	}
}

// Approach Function
function approach(_val, _target, _amount)
{
	if (_val < _target) return min(_val + _amount, _target);
	return max(_val - _amount, _target);
}

function is_dead() { return (state == PlayerState.DEAD || hp <= 0); }

function take_chip(_amount)
{
	hp = max(0, hp - _amount);
	hpChipTimer = hpChipDelay;
	barShowTimer = barShowTime;
}

function kill()
{
	hp = 0;
	if (state == PlayerState.DEAD) return;
	global.timeScaleTarget = 1;   // don't leave the world slowed if killed in the ACT menu
	state_change(PlayerState.DEAD);
}

function stats_recalc()
{
	stats = {};
	var _names = variable_struct_get_names(baseStats);
	for (var i = 0; i < array_length(_names); i++) stats[$ _names[i]] = baseStats[$ _names[i]];

	for (var t = 0; t < array_length(affinity); t++) affinity[t] = 1;

	var _slots = variable_struct_get_names(equipment);
	for (var s = 0; s < array_length(_slots); s++)
	{
		var _it = equipment[$ _slots[s]];
		if (_it == undefined) continue;

		var _bonus = _it[$ "bonus"] ?? {};
		var _bn = variable_struct_get_names(_bonus);
		for (var b = 0; b < array_length(_bn); b++)
			stats[$ _bn[b]] = (stats[$ _bn[b]] ?? 0) + _bonus[$ _bn[b]];

		var _res = _it[$ "resist"] ?? [];
		for (var r = 0; r < array_length(_res); r++)
			affinity[_res[r][0]] = max(0, affinity[_res[r][0]] + _res[r][1]);
	}
}

// Call any time during gameplay. Pass undefined to unequip.
function equip(_slot, _item)
{
	equipment[$ _slot] = _item;
	stats_recalc();
}

function attack_type()
{
	var _w = equipment.weapon;
	return (_w != undefined) ? _w.type : DamageType.BLUDGEONING;   // fists
}

function attack_power()
{
	return stat_get(global.damageTypes[attack_type()].atk) * outMult;
}

// Same pipeline as the enemy's receive_hit
function take_damage(_atk, _type = DamageType.BLUDGEONING, _src = noone, _knock = 3)
{
	if (state == PlayerState.DEAD || iframes > 0 || hp <= 0) return 0;

	var _row  = global.damageTypes[_type];
	var _def  = stat_get(_row.def);
	var _base = round(max(minDamage, _atk - _def) * affinity[_type] * vulnMult);
	if (_base <= 0) return 0;   // immune

	var _hit = _row[$ "hit"] ?? {};

	hp = max(0, hp - _base);
	hpChipTimer = hpChipDelay;
	barShowTimer = barShowTime;
	flashTimer = flashDur;
	iframes = iframeTime;
	show_number(_base, _row[$ "hitCol"] ?? c_white);

	var _dir = -facing;
	if (_src != noone && instance_exists(_src) && x != _src.x) _dir = sign(x - _src.x);
	var _k = _knock * (_hit[$ "knock"] ?? 1) * (1 - knockResist);
	hSpd = _dir * _k;
	vSpd = -_k;

	if (hp > 0) effect_apply(_type, _base);

	if (hp <= 0) kill();
	else
	{
		hurtMult = _hit[$ "stagger"] ?? 1;
		if (state == PlayerState.ACTION) global.timeScaleTarget = 1;
		state_change(PlayerState.HURT);
	}
	return _base;
}

function heal(_amount)
{
	hp = min(hpMax, hp + _amount);
	hpChip = max(hpChip, hp)
	barShowTimer = barShowTime;
}

function hp_colour(_t)
{
	var _green = make_colour_rgb(70, 220, 80);
	var _yellow = make_colour_rgb(240, 210, 60);
	var _red = make_colour_rgb(230, 50, 50);
	
	if (_t > 0.5) return merge_colour(_yellow, _green, (_t - 0.5) * 2);
	return merge_colour(_red, _yellow, _t * 2)
}

function draw_arc_band(_px, _py, _s, _a0, _a1, _col, _thick, _alpha)
{
	if (_a1 <= _a0) return;
	
	var _half = barSpan / 2
	var _r = barRadius * _s;
	var _cx = round(_px);
	// Place the Center so that arc's top ends sit barGap below origin
	var _cy = round(_py + (barGap - barRadius * dcos(_half)) * _s);
	var _r0 = _r - _thick * _s / 2;
	var _r1 = _r + _thick * _s / 2;
	var _steps = max(2, ceil((_a1 - _a0) / 4));
	
	draw_primitive_begin(pr_trianglestrip);
	for (var i = 0; i <= _steps; i++)
	{
		var _a = lerp(_a0, _a1, i / _steps);
		draw_vertex_colour(_cx + lengthdir_x(_r0, _a), _cy + lengthdir_y(_r0, _a), _col, _alpha);
		draw_vertex_colour(_cx + lengthdir_x(_r1, _a), _cy + lengthdir_y(_r1, _a), _col, _alpha);
	}
	draw_primitive_end();
}

function draw_hp_bar(_px, _py, _s)
{
	if (barAlpha <= 0) return;
	
	var _a0 = 270 - barSpan / 2;
	var _fHp = hp / hpMax;
	var _fChip = hpChip / hpMax;
	
	// Outline
	draw_arc_band(_px, _py, _s, _a0 - 2, _a0 + barSpan + 2, c_black, barThick + 2, barAlpha);
	
	// Chip
	draw_arc_band(_px, _py, _s, _a0 + barSpan * _fHp, _a0 + barSpan * _fChip, barChipCol, barThick, barAlpha);
	
	// Current Health
	draw_arc_band(_px, _py, _s, _a0, _a0 + barSpan * _fHp, hp_colour(_fHp), barThick, barAlpha);
	draw_status_pips(_px, _py, _s);
}

// On New State
function state_change(_new_state)
{
	if (state == _new_state) return;
	state = _new_state;
	stateTimer = 0;
	
	if (_new_state != PlayerState.IN_AIR) isJumping = false;
	
	switch (_new_state)
	{
		case PlayerState.FREE:
			peakFall = 0;
			break;
		
		case PlayerState.ATTACK:
			sprite_index = spr.attack;
			image_index = 0;
			hitList = [];
			break;
			
		case PlayerState.IN_AIR:
			// Start in the Jump sprite if rising, otherwise fall.
			sprite_index = (vSpd < 0) ? spr.jump : spr.fall;
			image_index = 0;
			break;
			
		case PlayerState.LAND:
			peakFall = 0;
			sprite_index = spr.land;
			image_index = 0;
			break;
		
		case PlayerState.HURT:
			break;
			
		case PlayerState.ACT_RUN:
			actFn.enter();
			break;
	}
}

function anim_ended()
{
	return image_index >= image_number - 1;
}

// State Functions
function state_free()
{
	var _move = kRight - kLeft;
	var _run = kRun;
	var _target = _move * (_run ? runSpd : walkSpd);
	
	if (_move != 0)
	{
		facing = _move;
		
		var _rate = (abs(_target) < abs(hSpd) ? groundFric : groundAccel);
		if (sign(hSpd) != 0 && sign(hSpd) != _move) _rate = groundTurn;
		else if (abs(_target) < abs(hSpd))			_rate = groundFric;
		else										_rate = groundAccel;
		
		hSpd = approach(hSpd, _target, _rate);
	}
	else
	{
		hSpd = approach(hSpd, 0, groundFric);
	}
	
	// Pick Sprite from Player Action
	if (_move == 0 && abs(hSpd) < 0.1)	sprite_index = spr.idle;
	else if (abs(hSpd) > walkSpd + 0.1)	sprite_index = spr.run;
	else								sprite_index = spr.walk;
	
	// Transitions
	if (kJump)
	{
		sfx_play(snd_jump);
		vSpd = jumpSpd;
		isJumping = true;
		state_change(PlayerState.IN_AIR);
	}
	else if (!onGround)
	{
		state_change(PlayerState.IN_AIR);
	}
	else if (kSelect)
	{
		state_change(PlayerState.ATTACK);
	}
	else if (kAction)
	{
		enter_act_menu();
		return;
	}
}

function state_inair()
{
	var _move = kRight - kLeft;
	if (_move != 0) facing = _move;
	
	if (_move != 0)
	{
		facing = _move;
		
		if (sign(hSpd) != 0 && sign(hSpd) != _move)
			hSpd = approach(hSpd, _move * walkSpd, airTurn);
		else if (abs(hSpd) > walkSpd)
			hSpd = approach(hSpd, _move * walkSpd, airDrag);
		else
			hSpd = approach(hSpd, _move * walkSpd, airAccel);
	}
	else
	{
		hSpd = approach(hSpd, 0, airFric);
	}
	
	vSpd += grav;
	peakFall = max(peakFall, vSpd);
	
	// Jump Cut
	if (isJumping && !kJumpHeld && vSpd < jumpCutSpd) vSpd = jumpCutSpd;
	if (vSpd >= 0) isJumping = false;
	
	// Jump -> Fall -> Fall Loop
	if (vSpd < 0) sprite_index = spr.jump;
	else if (sprite_index == spr.jump) { sprite_index = spr.fall; image_index = 0; }
	else if (sprite_index == spr.fall && anim_ended()) sprite_index = spr.fallLoop;
	
	// Transitions
	if (onGround && vSpd >= 0)
	{
		vSpd = 0;
		state_change(peakFall >= landMinFall ? PlayerState.LAND : PlayerState.FREE);
	}
	else if (kSelect)
	{
		state_change(PlayerState.ATTACK);
	}
	else if (kAction)
	{
		enter_act_menu();
		return;
	}
}

function state_land()
{
	var _move = kRight - kLeft;
	
	// Keep Sliding
	sfx_play(snd_land);
	hSpd = approach(hSpd, 0, groundFric);
	if (vSpd > 0) vSpd = 0;
	
	// Walked off Ledge
	if (!onGround) { state_change(PlayerState.IN_AIR); return; }
	
	// Instant Cancels
	if (kJump)
	{
		sfx_play(snd_jump);
		vSpd = jumpSpd;
		isJumping = true;
		state_change(PlayerState.IN_AIR);
		return;
	}
	if (kSelect) { state_change(PlayerState.ATTACK); return; }
	if (kAction) { state_change(PlayerState.ACTION); return; }
	
	// Movement Cancels
	if (stateTimer >= landCancelFrames && _move != 0)
	{
		state_change(PlayerState.FREE);
		return;
	}
	
	// Otherwise Finish
	if (anim_ended()) state_change(PlayerState.FREE);
}

function state_attack()
{
	var _hitStart = 1;
	var _hitEnd = 2;
	
	if (sprite_index == spr.attack && image_index >= _hitStart && image_index <= _hitEnd)
	{
		var _list = ds_list_create();
		var _n = collision_rectangle_list(x + facing * 4, y - 20, x + facing * 30, y, obj_enemy, false, true, _list, false);
		for (var i = 0; i < _n; i++)
		{
			var _e = _list[| i];
			if (array_contains(hitList, _e)) continue;
			array_push(hitList, _e);
			_e.receive_hit(attack_power(), attack_type(), id, 2);
		}
		ds_list_destroy(_list);
	}
	
	if (onGround)
	{
		hSpd = approach(hSpd, 0, groundFric);
		if (vSpd > 0) vSpd = 0;
	}
	else
	{
		hSpd = approach(hSpd, 0, airFric);
		vSpd += grav;
	}
	
	// Swap to End sprite
	if (sprite_index == spr.attack && anim_ended())
	{
		sprite_index = spr.attackEnd;
		image_index = 0;
	}
	else if (sprite_index == spr.attackEnd && anim_ended())
	{
		state_change(onGround ? PlayerState.FREE : PlayerState.IN_AIR);
	}
}

function state_action()
{
	var _ts = global.timeScale;
	actHeld++;   // real frames

	if (onGround) { hSpd = approach(hSpd, 0, groundFric * _ts); if (vSpd > 0) vSpd = 0; }
	else { hSpd = approach(hSpd, 0, airFric * _ts); vSpd += grav * _ts; }

	if (actTarget != noone && !instance_exists(actTarget)) actTarget = noone;

	// Movement keys hop the cursor between targets
	var _dx = input_pressed("right") - input_pressed("left");
	var _dy = input_pressed("down")  - input_pressed("up");
	if (_dx != 0 || _dy != 0)
	{
		actPicked = true;
		var _found = find_act_target(_dx, _dy);
		if (_found != noone) { actTarget = _found; actCx = _found.x; actCy = _found.y; }
	}

	// Attack cycles forward, run cycles backward through your equipped acts
	var _list = act_equipped();
	var _count = array_length(_list);
	if (_count > 0)
	{
		actIndex = clamp(actIndex, 0, _count - 1);
		if (input_pressed("attack")) { actIndex = (actIndex + 1) mod _count; actPicked = true; }
		if (input_pressed("run"))    { actIndex = (actIndex - 1 + _count) mod _count; actPicked = true; }
	}

	// Release: perform
	if (!kAction)
	{
		global.timeScaleTarget = 1;

		var _act = (_count > 0) ? _list[actIndex] : PLAYER_ACT.NONE;
		var _ok = false;
		if (_act != PLAYER_ACT.NONE)
		{
			// targeted acts need a target; the rest need any input, or a short hold, so a quick tap does nothing
			_ok = global.acts[_act].needsTarget ? (actTarget != noone) : (actPicked || actHeld >= actHoldMin);
		}

		if (_ok) act_start(_act, actTarget);
		else state_change(onGround ? PlayerState.FREE : PlayerState.IN_AIR);
	}
}

function state_hurt()
{
	hSpd = approach(hSpd, 0, onGround ? groundFric : airFric);
	vSpd += grav;
	if (stateTimer >= 20 * hurtMult && onGround) state_change(PlayerState.FREE);
}

function state_dead()
{
	hSpd = 0;
	game_restart();
}

function draw_status_pips(_px, _py, _s)
{
	var _pips = [];
	for (var i = 0; i < array_length(effects); i++)
	{
		var _fx = global.damageTypes[effects[i].type].fx;
		array_push(_pips, { col: _fx.col, frac: clamp((effects[i].duration - effects[i].clock) / _fx.dur, 0, 1) });
	}
	for (var t = 0; t < array_length(buildup); t++)
		if (buildup[t] > 0) array_push(_pips, { col: global.damageTypes[t].fx.col, frac: buildup[t] });

	if (array_length(_pips) == 0) return;

	var _w = 8 * _s, _h = 3 * _s, _gap = 3 * _s;
	var _total = array_length(_pips) * (_w + _gap) - _gap;
	var _x0 = _px - _total / 2;
	var _y0 = _py + (barGap + barRadius * (1 - dcos(barSpan / 2)) + barThick + 3) * _s;

	draw_set_alpha(barAlpha);
	for (var i = 0; i < array_length(_pips); i++)
	{
		var _x = _x0 + i * (_w + _gap);
		draw_set_colour(c_black);
		draw_rectangle(_x - 1, _y0 - 1, _x + _w, _y0 + _h, false);
		draw_set_colour(_pips[i].col);
		draw_rectangle(_x, _y0, _x + max(0, _w * _pips[i].frac - 1), _y0 + _h - 1, false);
	}
	draw_set_alpha(1);
	draw_set_colour(c_white);
}

function draw_act_hud()
{
	var _list = act_equipped();
	draw_set_font(fnt_arrow);
	draw_set_halign(fa_center);

	if (array_length(_list) == 0)
	{
		draw_set_colour(c_gray);
		draw_text(x, bbox_top - 18, "No acts equipped");
	}
	else
	{
		var _d = global.acts[_list[clamp(actIndex, 0, array_length(_list) - 1)]];
		var _warn = (_d.needsTarget && actTarget == noone);
		draw_set_colour(_warn ? c_gray : _d.col);
		draw_text(x, bbox_top - 18, "< [X]  " + _d.name + "  (" + string(actIndex + 1) + "/" + string(array_length(_list)) + ")" + "  [Z] >");
		if (_warn) draw_text(x, bbox_top - 8, "select a target");
	}

	draw_set_colour(c_white);
	draw_set_halign(fa_left);
	draw_set_font(fnt_default);
}

equip("weapon", global.items.rusty_sword);
equip("armor", global.items.chain_mail);