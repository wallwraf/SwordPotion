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
enum PlayerState { FREE, IN_AIR, LAND, ATTACK, ACTION, ACT_RUN, PARRY, HURT, DEAD }

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

// ---- Combat: dodge, parry, crits
dodgeT = 0; dodgeAge = 0; dodgeCd = 0; dodgeHit = false;
boostT = 0; speedMult = 1;
fastAtkT = 0; atkSpeed = 1;
parryAge = 0; parryHit = false; parryCd = 0;
bulletT = 0; critT = 0; swingCrit = false;

if (!instance_exists(obj_inventory)) instance_create_depth(0, 0, -100, obj_inventory);

// ---- Inventory and equipment
invItems = [];
actItems  = array_create(6, undefined);                // act tomes in the six act slots (actSlots holds the acts they teach)
equipment = { helmet: undefined, body: undefined, legs: undefined, acc1: undefined, acc2: undefined, weapon: undefined };
typeBonus = array_create(array_length(global.damageTypes), 0);

function stats_recalc()
{
	var _r = stats_for(equipment, baseStats);
	stats = _r.stats;
	for (var t = 0; t < array_length(affinity); t++) { affinity[t] = _r.affinity[t]; typeBonus[t] = _r.typeBonus[t]; }
}

function equip_key_for(_def)
{
	switch (_def.slot)
	{
		case "weapon": case "helmet": case "body": case "legs": return _def.slot;
		case "accessory": return (equipment.acc1 == undefined) ? "acc1" : ((equipment.acc2 == undefined) ? "acc2" : "acc1");
	}
	return "";
}

function inv_add(_item)
{
	if (_item == undefined || array_length(invItems) >= inv_capacity()) return false;
	array_push(invItems, _item);
	return true;
}

function inv_activate(_i)
{
	if (_i < 0 || _i >= array_length(invItems)) return "";
	var _it = invItems[_i];
	var _def = item_def(_it);

	if (_def.slot == "act")
	{
		if (array_contains(actSlots, _def.act)) return "Already equipped.";
		for (var s = 0; s < array_length(actItems); s++)
			if (actItems[s] == undefined) { act_slot_set(s, _it); array_delete(invItems, _i, 1); return ""; }
		return "All act slots are full.";
	}

	var _key = equip_key_for(_def);
	if (_key != "")
	{
		var _old = equipment[$ _key];
		equipment[$ _key] = _it;
		if (_old != undefined) invItems[_i] = _old;      // the swapped-out piece takes its place
		else array_delete(invItems, _i, 1);
		stats_recalc();
		return "";
	}

	if (_def[$ "use"] != undefined)
	{
		if (method(self, _def.use)(_it)) array_delete(invItems, _i, 1);
		return "";
	}
	return "Can't use that.";
}

function inv_unequip(_kind, _idx)
{
	var _held = (_kind == "act") ? actItems[_idx] : equipment[$ _idx];
	if (_held == undefined) return "";
	if (array_length(invItems) >= inv_capacity()) return "Inventory full.";

	array_push(invItems, _held);
	if (_kind == "act") act_slot_set(_idx, undefined);
	else { equipment[$ _idx] = undefined; stats_recalc(); }
	return "";
}

function act_slot_set(_slot, _item)
{
	actItems[_slot] = _item;
	actSlots[_slot] = (_item == undefined) ? PLAYER_ACT.NONE : item_def(_item).act;
}

// Swings use the weapon's first damage type (fists = bludgeoning). Extend here for multi-type weapons.
function attack_types()
{
	var _w = equipment.weapon;
	if (_w == undefined) return [DamageType.BLUDGEONING];
	var _t = item_types(item_def(_w));
	return (array_length(_t) > 0) ? _t : [DamageType.BLUDGEONING];
}

function attack_type() { return attack_types()[0]; }

function attack_power()
{
	var _t = attack_type();
	return (stat_get(global.damageTypes[_t].atk) + typeBonus[_t]) * outMult;
}

function act_power(_mult = 1)
{
	return stat_get(global.damageTypes[actCur.type].atk) * actCur.power * _mult * outMult;
}

// ---- Starting gear (fixed rolls) and a few random items so the book isn't empty. Remove the repeat when done testing.
equipment.weapon = item_make("rusty_sword", "common", "normal", []);
equipment.body   = item_make("chain_mail", "common", "normal", []);
act_slot_set(0, item_make(act_item_id(PLAYER_ACT.LIGHTNING_FLASH), "common"));
act_slot_set(1, item_make(act_item_id(PLAYER_ACT.FIREBOLT), "common"));
act_slot_set(2, item_make(act_item_id(PLAYER_ACT.FIREBALL), "common"));
act_slot_set(3, item_make(act_item_id(PLAYER_ACT.X_SLASH), "common"));
act_slot_set(4, item_make(act_item_id(PLAYER_ACT.SLAM), "common"));
act_slot_set(5, item_make(act_item_id(PLAYER_ACT.VAMPIRISM), "common"));
stats_recalc();
repeat (8) inv_add(item_roll());

function act_unequip(_slot) { return act_equip(_slot, PLAYER_ACT.NONE); }
function act_learn(_act) { actsKnown[_act] = true; }

function act_equipped()   // compact list in slot order
{
	var _out = [];
	for (var i = 0; i < array_length(actSlots); i++)
		if (actSlots[i] != PLAYER_ACT.NONE) array_push(_out, actSlots[i]);
	return _out;
}

// ---- Scarf:
scarfCols = [make_colour_rgb(255, 128, 112), make_colour_rgb(222, 58, 72), make_colour_rgb(142, 30, 58)];   // highlight, base, shade (2 or 3 colours)
scarfOutline = make_colour_rgb(52, 14, 40);                  // the one outline colour

scarfRadii = [3, 2.6, 2.2, 1.8, 1.4];   // one radius per node. Node 0 is the anchor. The length of this array is the node count.
scarfStep  = [3.4, 0.9];                // rest offset from each node to the next: backwards, then down
scarfK    = 18;                         // stiffness
scarfDamp = 0.94;                       // damping per step at normal speed
scarfGrav = 15;                         // gravity, pixels per second squared
scarfSlack = 2;                         // how far past the rest length a segment may stretch
scarfFlutter = 120;                     // ripple while moving. 0 = pure Celeste
scarfSub = 3;                           // discs drawn per segment

scarfAnchorX = 2;      // pixels toward the back from the sprite's centre (flips with facing)
scarfAnchorY = 0.32;   // how far down the mask the neck is, 0..1

scarf = [];
scarfReady = false;
scarfT = 0;

function scarf_anchor()
{
	return {
		x: (bbox_left + bbox_right) / 2 - facing * scarfAnchorX,
		y: bbox_top + (bbox_bottom - bbox_top) * scarfAnchorY
	};
}

// Lay the whole scarf out in its rest shape at the anchor
function scarf_reset(_a)
{
	scarf = [];
	for (var i = 0; i < array_length(scarfRadii); i++)
		array_push(scarf, { x: _a.x - facing * scarfStep[0] * i, y: _a.y + scarfStep[1] * i, vx: 0, vy: 0 });
	scarfReady = true;
}

function scarf_update()
{
	var _fps = game_get_speed(gamespeed_fps);
	var _dt = global.timeScale / _fps;
	var _a = scarf_anchor();

	// first frame, or the player teleported (a dash snap, a room change): don't drag the scarf across the level
	if (!scarfReady || point_distance(_a.x, _a.y, scarf[0].x, scarf[0].y) > 80) { scarf_reset(_a); return; }

	scarfT += _dt;
	var _damp = power(scarfDamp, _dt * _fps);    // 0.94 per step at normal speed, correct at any time scale
	var _speed = min(1, abs(hSpd));

	// node 0 is glued to the player
	scarf[0].x = _a.x;
	scarf[0].y = _a.y;

	for (var i = 1; i < array_length(scarf); i++)
	{
		var _p = scarf[i - 1];
		var _n = scarf[i];

		// each node is pulled toward "the previous node plus the rest offset"
		var _ox = -facing * scarfStep[0];
		var _oy = scarfStep[1];
		var _tx = _p.x + _ox;
		var _ty = _p.y + _oy;

		// F = -k * x - c * v: a spring with damping, plus gravity so it settles
		_n.vx += (_tx - _n.x) * scarfK * _dt;
		_n.vy += (_ty - _n.y) * scarfK * _dt;
		_n.vy += scarfGrav * _dt;
		_n.vy += sin(scarfT * 14 + i * 1.1) * scarfFlutter * _speed * _dt;   // the scarf ripples while you move
		_n.vx *= _damp;
		_n.vy *= _damp;
		_n.x += _n.vx * _dt;
		_n.y += _n.vy * _dt;

		// never stretch farther than the rest length + slack from the node before it
		var _maxD = point_distance(0, 0, _ox, _oy) + scarfSlack;
		var _d = point_distance(_n.x, _n.y, _p.x, _p.y);
		if (_d > _maxD)
		{
			var _dir = point_direction(_p.x, _p.y, _n.x, _n.y);
			_n.x = _p.x + lengthdir_x(_maxD, _dir);
			_n.y = _p.y + lengthdir_y(_maxD, _dir);
		}
	}
}

// A pixel-perfect filled disc: every pixel where i*i + j*j <= r*r, drawn as one run per row.
// _cols is one colour or an array of bands from top to bottom.
function draw_px_disc(_cx, _cy, _r, _cols)
{
	_cx = round(_cx);
	_cy = round(_cy);
	var _R = ceil(_r);
	var _bands = is_array(_cols);
	var _n = _bands ? array_length(_cols) : 1;

	for (var j = -_R; j <= _R; j++)
	{
		var _h2 = _r * _r - j * j;
		if (_h2 < 0) continue;
		var _w = floor(sqrt(_h2));
		draw_set_colour(_bands ? _cols[clamp(floor((j + _R) / (2 * _R + 1) * _n), 0, _n - 1)] : _cols);
		draw_rectangle(_cx - _w, _cy + j, _cx + _w, _cy + j, false);
	}
}

function draw_scarf()
{
	if (!scarfReady) return;

	// a list of discs [x, y, radius]: every node, plus a few between each pair so it reads as one ribbon
	var _list = [];
	for (var i = 0; i < array_length(scarf) - 1; i++)
	{
		var _a = scarf[i], _b = scarf[i + 1];
		for (var k = 0; k < scarfSub; k++)
		{
			var _t = k / scarfSub;
			array_push(_list, [lerp(_a.x, _b.x, _t), lerp(_a.y, _b.y, _t), lerp(scarfRadii[i], scarfRadii[i + 1], _t)]);
		}
	}
	var _end = array_length(scarf) - 1;
	array_push(_list, [scarf[_end].x, scarf[_end].y, scarfRadii[_end]]);

	draw_set_alpha(image_alpha);
	// pass 1: every outline (radius + 1). pass 2: every fill. Tip first, so the base sits on top.
	for (var i = array_length(_list) - 1; i >= 0; i--) draw_px_disc(_list[i][0], _list[i][1], _list[i][2] + 1, scarfOutline);
	for (var i = array_length(_list) - 1; i >= 0; i--) draw_px_disc(_list[i][0], _list[i][1], _list[i][2], scarfCols);
	draw_set_alpha(1);
	draw_set_colour(c_white);
}

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
    var _act = actCur;
    var _art = undefined;
    var _wave = undefined;
    var _spr = -1;

    if (is_struct(_act))
    {
        if (variable_struct_exists(_act, "art"))
        {
            _art = _act.art;

            if (is_struct(_art) && variable_struct_exists(_art, "wave"))
            {
                _wave = _art.wave;

                if (is_struct(_wave) && variable_struct_exists(_wave, "spr"))
                {
                    _spr = _wave.spr;
                }
            }
        }
    }

    instance_create_depth(
        x + _dir * 8,
        bbox_bottom,
        depth - 1,
        obj_act_wave,
        {
            dir: _dir,
            spd: 4,
            life: 22,
			h: 16,
            dmg: act_power(1),
            type: actCur.type,
            src: id,
            col: actCur.col,
            knock: 3,
            spr: _spr
        }
    );
}

function act_projectile(_x, _y, _tx, _ty)
{
    var _c = actCur.cast;

    var _art = {};
    var _proj = {};
    var _spr = -1;

    if (is_struct(actCur) && variable_struct_exists(actCur, "art"))
    {
        if (is_struct(actCur.art))
        {
            _art = actCur.art;
        }
    }

    if (variable_struct_exists(_art, "proj"))
    {
        if (is_struct(_art.proj))
        {
            _proj = _art.proj;
        }
    }

    if (variable_struct_exists(_proj, "spr"))
    {
        _spr = _proj.spr;
    }

    var _hv, _vv;

    if (_c.grav > 0)
    {
        var _T = max(
            10,
            point_distance(_x, _y, _tx, _ty) / _c.spd
        );

        _hv = (_tx - _x) / _T;
        _vv = (_ty - _y) / _T - 0.5 * _c.grav * _T;
    }
    else
    {
        var _dir = point_direction(_x, _y, _tx, _ty);

        _hv = lengthdir_x(_c.spd, _dir);
        _vv = lengthdir_y(_c.spd, _dir);
    }

    instance_create_depth(
        _x,
        _y,
        depth - 1,
        obj_act_projectile,
        {
            hv: _hv,
            vv: _vv,
            spd: _c.spd,
            grav: _c.grav,
            homing: _c.homing,
            radius: _c.radius,
            splash: _c.splash,
            knock: _c.knock,
            col: actCur.col,
            type: actCur.type,
            dmg: act_power(),
            src: id,
            target: actTargetRun,
            spr: _spr,
            art: _art
        }
    );
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
			act_art("cast", x + facing * 10, _cy);
			break;

		case "instant":
			if (actTargetRun == noone || !instance_exists(actTargetRun)) break;
			act_art("cast", x, _cy);
			if (!act_art("hit", _tx, _ty))
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
				if (!act_art("burst", x + facing * _c.w * 0.5, _cy)) act_fx("ring", { x1: x + facing * _c.w * 0.5, y1: _cy, r0: 6, r1: 24, col: actCur.col, life: 12 });
			}
			else
			{
				act_hit_circle(x, _cy, _c.r, 1, _c.knock);
				if (!act_art("burst", x, _cy)) act_fx("ring", { x1: x, y1: _cy, r0: 8, r1: _c.r, col: actCur.col, life: 16 });
			}
			screen_shake(_c.shake);
			break;
	}
}



function move_and_collide_pixels()
{
	var _h = hSpd * global.timeScale * slowMult + hSpdRem;
	var _v = vSpd * global.timeScale + vSpdRem;

	var _mx = round(_h);
	var _my = round(_v);
	hSpdRem = _h - _mx;
	vSpdRem = _v - _my;

	var _grounded = onGround && vSpd >= 0;   // never climb while jumping or rising

	// Horizontal: climbs slopes when grounded
	if (!move_x_slope(_mx, _grounded))
	{
		hSpd = 0;
		hSpdRem = 0;
	}

	// Stay glued to the ground going downhill
	if (_grounded) snap_down(SLOPE_DOWN);

	// Vertical (unchanged)
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

	var _w = 2;   // line width
	var _o = 1;   // outline thickness all the way around

	draw_set_alpha(_alpha);

	// outline: black lines with round caps, wider by the outline thickness
	var _ow = _w + _o * 2;
	draw_set_colour(c_black);
	draw_line_width(_x1, _y1, _x, _y, _ow);
	draw_line_width(_x2, _y2, _x, _y, _ow);
	draw_circle(_x1, _y1, _ow / 2, false);
	draw_circle(_x2, _y2, _ow / 2, false);
	draw_circle(_x, _y, _ow / 2, false);

	// the chevron itself, with matching round caps
	draw_set_colour(_col);
	draw_line_width(_x1, _y1, _x, _y, _w);
	draw_line_width(_x2, _y2, _x, _y, _w);
	draw_circle(_x1, _y1, _w / 2, false);
	draw_circle(_x2, _y2, _w / 2, false);
	draw_circle(_x, _y, _w / 2, false);

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
		var _list = act_equipped();
		var _act = global.acts[_list[clamp(actIndex, 0, array_length(_list) - 1)]];
		
		draw_chevron(_px, _py, _dir, arrowSize, _act.col, _fade);
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

function take_damage(_atk, _type = DamageType.BLUDGEONING, _src = noone, _knock = 3, _info = undefined)
{
	if (state == PlayerState.DEAD || iframes > 0 || hp <= 0) return 0;
	var _a = atk_info(_info);

	// 1. A dodge avoids it completely
	if (dodge_check(_a, _src)) return 0;

	// 2. Perfect parry and parry stop it completely. Blocking only reduces it.
	var _pr = parry_check(_a);
	if (_pr == "perfect" || _pr == "parry") { parry_success(_pr, _src); return 0; }
	var _blocked = (_pr == "block");

	var _row  = global.damageTypes[_type];
	var _def  = stat_get(_row.def);
	var _base = round(max(minDamage, _atk - _def) * affinity[_type] * vulnMult);
	if (_base <= 0) return 0;

	var _hit = _row[$ "hit"] ?? {};
	var _dealt = _blocked ? block_damage(_base) : _base;

	hp = max(0, hp - _dealt);
	hpChipTimer = hpChipDelay;
	barShowTimer = barShowTime;
	flashTimer = flashDur;
	show_number(_dealt, _row[$ "hitCol"] ?? c_white);

	var _dir = -facing;
	if (_src != noone && instance_exists(_src) && x != _src.x) _dir = sign(x - _src.x);
	var _k = _knock * (_hit[$ "knock"] ?? 1) * (1 - knockResist);

	if (_blocked)
	{
		var _c = global.combatCfg;
		parryHit = true;
		iframes = _c.blockIframes;
		hSpd = _dir * _k * _c.blockKnock;       // a small slide, and no hurt state: you keep blocking
		show_number("Blocked", c_gray);
		var _pt = parry_point(_src);
		fx_emit("spark_block", _pt.x, _pt.y, 1);
		if (hp <= 0) kill();
		return _dealt;
	}

	iframes = iframeTime;
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
	return _dealt;
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
	
	if (dodgeT > 0 && _new_state != PlayerState.FREE && _new_state != PlayerState.IN_AIR && _new_state != PlayerState.LAND) dodge_end();
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
			swingCrit = (critT > 0) || (random(1) < global.combatCfg.critChance);   // a guaranteed crit if armed, otherwise 0.5%
			critT = 0;
			atkSpeed = (fastAtkT > 0) ? global.combatCfg.fastAtkMult : 1;            // perfect dodge: this swing is faster
			fastAtkT = 0;
			break;
			
		case PlayerState.PARRY:
			parryAge = 0;
			parryHit = false;
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
	var _target = _move * (_run ? runSpd : walkSpd) * speedMult;
	
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
	if (kParryPressed && parryCd <= 0) { state_change(PlayerState.PARRY); return; }
	if (kRunPressed && dodgeT <= 0 && dodgeCd <= 0) dodge_start();   // no state change: movement keeps following your keys
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
	var _ws = walkSpd * speedMult;
	if (_move != 0) facing = _move;
	
	if (_move != 0)
	{
		facing = _move;
		
		if (sign(hSpd) != 0 && sign(hSpd) != _move)
			hSpd = approach(hSpd, _move * _ws, airTurn);
		else if (abs(hSpd) > _ws)
			hSpd = approach(hSpd, _move * _ws, airDrag);
		else
			hSpd = approach(hSpd, _move * _ws, airAccel);
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
	if (kParryPressed && parryCd <= 0) { state_change(PlayerState.PARRY); return; }
	if (kRunPressed && dodgeT <= 0 && dodgeCd <= 0) dodge_start();   // no state change: movement keeps following your keys
	if (onGround && vSpd >= 0)
	{
		vSpd = 0;
		var _long = (peakFall >= landMinFall);
		if (_long)
		{
			// pixel dust either side of your feet, bigger with a longer fall
			var _s = clamp((peakFall - landMinFall) / 8, 0, 1);
			fx_emit("dust_land", x - 3, bbox_bottom, 0.6 + _s * 1.6, { angle: 165, spread: 60 });
			fx_emit("dust_land", x + 3, bbox_bottom, 0.6 + _s * 1.6, { angle: 15, spread: 60 });
		}
		state_change(_long ? PlayerState.LAND : PlayerState.FREE);
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
	if (kParryPressed && parryCd <= 0) { state_change(PlayerState.PARRY); return; }
	if (kRunPressed && dodgeT <= 0 && dodgeCd <= 0) dodge_start();   // no state change: movement keeps following your keys
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
	image_speed = global.timeScale * atkSpeed;
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
			_e.receive_hit(attack_power(), attack_type(), id, 2, swingCrit);
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
	draw_set_font(fnt_8bitoperator);
	draw_set_halign(fa_center);

	if (array_length(_list) == 0)
	{
		draw_set_colour(c_black);
			for (var _dx = -1; _dx <= 1; _dx++)
				for (var _dy = -1; _dy <= 1; _dy++)
					if (_dx != 0 || _dy != 0)
						draw_text_transformed(x + _dx, bbox_top - 18 + _dy, "No acts equipped", 1, 1, 0);
		draw_set_colour(#989898);
		draw_text(x, bbox_top - 18, "No acts equipped");
	}
	else
	{
		var _d = global.acts[_list[clamp(actIndex, 0, array_length(_list) - 1)]];
		var _warn = (_d.needsTarget && actTarget == noone);
		draw_set_colour(c_black);
			for (var _dx = -1; _dx <= 1; _dx++)
				for (var _dy = -1; _dy <= 1; _dy++)
					if (_dx != 0 || _dy != 0)
						draw_text_transformed(x + _dx, bbox_top - 18 + _dy, "< [X]  " + _d.name + "  (" + string(actIndex + 1) + "/" + string(array_length(_list)) + ")" + "  [Z] >", 1, 1, 0);
		draw_set_colour(_warn ? c_gray : _d.col);
		draw_text(x, bbox_top - 18, "< [X]  " + _d.name + "  (" + string(actIndex + 1) + "/" + string(array_length(_list)) + ")" + "  [Z] >");
		if (_warn) draw_text(x, bbox_top - 8, "select a target");
	}

	draw_set_colour(c_white);
	draw_set_halign(fa_left);
	draw_set_font(fnt_default);
}

function popup(_text, _col) { if (global.combatCfg.popups) show_number(_text, _col); }

function atk_info(_i)
{
	if (_i == undefined) _i = {};
	return { dodge: _i[$ "dodge"] ?? DodgeType.NORMAL, parryable: _i[$ "parryable"] ?? true, blockable: _i[$ "blockable"] ?? true };
}

// ---- Dodge
function dodge_start()
{
	dodgeT = global.combatCfg.dodgeFrames;
	dodgeAge = 0;
	dodgeHit = false;
	if (onGround) fx_emit("dodge_puff", x, bbox_bottom, 1, { angle: (facing > 0) ? 180 : 0, spread: 50 });
}

function dodge_end()
{
	dodgeT = 0;
	dodgeCd = dodgeHit ? global.combatCfg.dodgeCdHit : global.combatCfg.dodgeCdMiss;   // a whiff costs more
}

function dodge_check(_a, _src)
{
	if (dodgeT <= 0 || _a.dodge == DodgeType.NONE) return false;
	var _c = global.combatCfg;
	var _perfect = (dodgeAge <= _c.dodgePerfect);
	if (_a.dodge == DodgeType.PERFECT && !_perfect) return false;   // only a perfect dodge avoids this one

	dodgeHit = true;
	if (_perfect)
	{
		boostT = _c.boostFrames;
		fastAtkT = _c.fastAtkFrames;
		fx_emit("spark_dodge", x, (bbox_top + bbox_bottom) / 2, 1);
		flashTimer = flashDur;
		popup("Perfect Dodge", make_colour_rgb(120, 210, 255));
	}
	else popup("Dodge", c_white);
	return true;
}

// ---- Parry
function parry_stage()
{
	var _c = global.combatCfg;
	if (parryAge < _c.parryPerfect) return "perfect";
	if (parryAge < _c.parryPerfect + _c.parryWindow) return "parry";
	return "block";
}

function parry_check(_a)   // "none", "perfect", "parry" or "block"
{
	if (state != PlayerState.PARRY) return "none";
	var _st = parry_stage();
	if (_st != "block" && _a.parryable) return _st;   // perfect or parry: stops it completely
	return _a.blockable ? "block" : "none";           // after the window, or an unparryable attack: block it
}

function parry_point(_src)
{
	var _cy = (bbox_top + bbox_bottom) / 2;
	if (_src != noone && instance_exists(_src))
		return { x: lerp(x, _src.x, 0.35), y: lerp(_cy, (_src.bbox_top + _src.bbox_bottom) / 2, 0.35) };
	return { x: x + facing * 10, y: _cy };
}

function bullet_time(_frames, _scale)
{
	global.timeScale = min(global.timeScale, _scale);   // drops at once for a hit-stop feel, then eases back
	global.timeScaleTarget = _scale;
	bulletT = _frames;
}

function stagger_src(_src, _frames)
{
	if (_src != noone && instance_exists(_src) && is_enemy(_src)) _src.stagger(_frames);
}

function parry_success(_st, _src)
{
	var _c = global.combatCfg;
	var _pt = parry_point(_src);
	parryHit = true;
	iframes = max(iframes, 8);
	if (_src != noone && instance_exists(_src) && _src.x != x) facing = sign(_src.x - x);

	if (_st == "perfect")
	{
		fx_emit("spark_perfect", _pt.x, _pt.y, 1);
		fx_flash(_pt.x, _pt.y, _c.flashPerfect, 12, make_colour_rgb(255, 225, 120));
		screen_shake(5);
		bullet_time(_c.bulletPerfect, _c.bulletPerfectScale);
		critT = _c.critWindow;                                // the next melee is a guaranteed crit
		stagger_src(_src, _c.staggerPerfect);
		popup("Perfect Parry", make_colour_rgb(255, 215, 60));
	}
	else
	{
		fx_emit("spark_parry", _pt.x, _pt.y, 1);
		fx_flash(_pt.x, _pt.y, _c.flashParry, 8, make_colour_rgb(255, 225, 120));
		screen_shake(3);
		bullet_time(_c.bulletParry, _c.bulletParryScale);
		stagger_src(_src, _c.staggerParry);
		popup("Parry", make_colour_rgb(255, 215, 60));
	}
}

// Blocking: reduction grows with DEF
function block_damage(_dmg)
{
	var _c = global.combatCfg;
	var _def = stat_get("def");
	var _pct = min(_c.blockMax, _c.blockBase + _c.blockDefScale * _def / (_def + _c.blockDefHalf));
	return max(1, round(_dmg * (1 - _pct)));
}

function state_parry()
{
	var _c = global.combatCfg;
	parryAge += global.timeScale;

	hSpd = approach(hSpd, 0, onGround ? groundFric * 3 : airFric * 3);   // left/right movement is halted
	if (onGround) { if (vSpd > 0) vSpd = 0; }
	else vSpd += grav;

	sprite_index = spr[$ "parry"] ?? spr.idle;   // add spr.parry to your sprite struct when you have one
	image_index = 0;

	if (parryAge >= _c.parryPerfect + _c.parryWindow + _c.parryBlockFrames)
	{
		parryCd = parryHit ? _c.parryCdHit : _c.parryCdMiss;
		state_change(onGround ? PlayerState.FREE : PlayerState.IN_AIR);
	}
}

// Plays the current act's art for a key. Returns false if it has none, so the old primitive effect can take over.
function act_art(_key, _x, _y, _o = {})
{
	var _a = actCur[$ "art"];
	if (_a == undefined || _a[$ _key] == undefined) return false;
	art_play(_a[$ _key], _x, _y, struct_merge({ facing: facing }, _o));
	return true;
}