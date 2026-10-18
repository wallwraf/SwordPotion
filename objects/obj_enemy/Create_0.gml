event_inherited();

// Stats
stats = { hp: 10, hpMax: 10, atk: 1, def: 0, mag: 0, res: 0, spd: 0.5 };
mods = [];  // Times buffs/debuffs, see stat_mod()

// Damage Multiplier per type
affinity = array_create(array_length(global.damageTypes), 1);

status_init();
on_chip = function(_amount, _type) {};   // hook: damage numbers, particles, etc.

// Tunables
cfg = {
	flying: false, grav: 0.3, accel: 0.1, fric: 0.1,
	sightRange: 120, loseRange: 220, needLineOfSight: false,
	idleTime: 60, roamMin: 60, roamMax: 150, avoidLedges: true, chaseMult: 1.6,
	attackState: EnemyState.ATTACK, attackRange: 24, atkType: DamageType.BLUDGEONING,
	atkWindup: 20, atkActive: 8, atkRecover: 8, atkCooldown: 90,
	atkReach: 14, atkOffsetY: -8, atkRadius: 10,
	atkKnock: 3,
	hurtTime: 15, iframes: 8, knockResist: 0, superArmor: false, minDamage: 1,
	deathHold: SEC,
	deathFade: SEC * 0.5,
	dropChance: 0.35,        // chance of any drop at all
	dropPool: undefined,     // undefined = every droppable item, or an array of item ids
	dropLuck: 0              // pushes drops toward higher rarities (bosses)
}

dropped = false;

function drop_loot()
{
	if (dropped) return;
	dropped = true;
	if (random(1) >= cfg.dropChance) return;
	var _item = item_roll(cfg.dropPool, cfg.dropLuck);
	if (_item == undefined) return;
	instance_create_depth(x, (bbox_top + bbox_bottom) / 2, depth - 1, obj_item_drop, { item: _item });
}

spr = {};
target = obj_player;
startState = EnemyState.IDLE;

deadTimer = 0;
deadFrozen = false;

states = [];
state = -1;
prevState = -1;
stateTimer = 0;
started = false;

hSpd = 0; vSpd = 0; hSpdRem = 0; vSpdRem = 0;
facing = 1;
onGround = false;
attackCd = 0;
hitDone = false;
iframes = 0;
flashTimer = 0;
flashDur = 6;
roamDir = 1;
roamTime = 0;

function is_dead() { return (state == EnemyState.DEAD || stats.hp <= 0); }
function take_chip(_amount) { stats.hp = max(0, stats.hp - _amount); }

// -------------- State Machine --------------
function state_has(_id)
{
	return (_id >= 0 && _id < array_length(states) && is_struct(states[_id]));
}

// _def = { enter, step, exit, draw }, all optional.
function state_add(_id, _def)
{
	var _none = function() {};
	states[_id] = {
		enter: method(self, _def[$ "enter"] ?? _none),
		step: method(self, _def[$ "step"] ?? _none),
		deny: method(self, _def[$ "deny"] ?? _none),
		draw: method(self, _def[$ "draw"] ?? _none)
	};
}

// Use the built-in version of one state
function state_use(_ids)
{
	if (!is_array(_ids)) _ids = [_ids];
	for (var i = 0; i < array_length(_ids); i++)
		state_add(_ids[i], enemy_default_state(_ids[i]));
}

function state_use_all()
{
	state_use([EnemyState.IDLE,   EnemyState.ROAM, EnemyState.CHASE,
	           EnemyState.ATTACK, EnemyState.HURT, EnemyState.DEAD]);
}

function state_remove(_id) { states[_ids] = 0; }

// Returns false if the enemy doesn't have that state
function state_change(_id, _force = false)
{
	if (!state_has(_id)) return false;
	if (state == EnemyState.DEAD) return false;
	if (state == _id && !_force) return false;
	
	if (state_has(state)) states[state].deny();
	prevState = state;
	state = _id;
	stateTimer = 0;
	hitDone = false;
	states[state].enter();
	return true;
}

function state_home() { state_change(startState); }

function recover_from_hit()
{
	if (state_has(EnemyState.CHASE) && instance_exists(target)) state_change(EnemyState.CHASE);
	else state_home();
}

function attack_finished()
{
	if (state_has(EnemyState.CHASE) && sees_target()) state_change(EnemyState.CHASE);
	else state_home();
}

// ---------------- Helpers ----------------
function anim(_keys, _reset = true)   // a key, or an array tried in order
{
	if (is_string(_keys)) _keys = [_keys];
	for (var i = 0; i < array_length(_keys); i++)
	{
		var _s = spr[$ _keys[i]];
		if (_s == undefined) continue;
		if (sprite_index != _s) { sprite_index = _s; if (_reset) image_index = 0; }
		return;
	}
}

function anim_ended() { return image_index >= image_number - 1; }

function slow_down(_mult = 1)
{
	hSpd = approach(hSpd, 0, cfg.fric * _mult);
	if (cfg.flying) vSpd = approach(vSpd, 0, cfg.fric * _mult);
}

function sees_target()
{
	if (confused) return false;
	if (!instance_exists(target)) return false;
	if (point_distance(x, y, target.x, target.y) > cfg.sightRange) return false;
	if (cfg.needLineOfSight && collision_line(x, y, target.x, target.y, obj_col, false, true) != noone) return false;
	return true;
}

function attack_power() { return stat_get(global.damageTypes[cfg.atkType].atk) * outMult; }

// One melee hit per attack. Custom states (like a dash) can call this too.
function try_melee()
{
	if (hitDone) return false;
	var _t = collision_circle(x + facing * cfg.atkReach, y + cfg.atkOffsetY, cfg.atkRadius, target, false, true);
	if (_t == noone) return false;
	hitDone = true;
	_t.take_damage(attack_power(), cfg.atkType, id, cfg.atkKnock);
	return true;
}

// ---------------- Taking damage ----------------
// _atk is the attacker's final offensive number, _type is a DamageType
function receive_hit(_atk, _type = DamageType.BLUDGEONING, _src = noone, _knock = 2)
{
	if (state == EnemyState.DEAD || iframes > 0 || stats.hp <= 0) return 0;

	var _row  = global.damageTypes[_type];
	var _def  = stat_get(_row.def);
	var _dmg  = round(max(cfg.minDamage, _atk - _def) * affinity[_type] * vulnMult);
	if (_dmg <= 0) return 0;   // immune

	var _hit = _row[$ "hit"] ?? {};

	stats.hp = max(0, stats.hp - _dmg);
	show_number(_dmg, _row[$ "hitCol"] ?? c_white);
	flashTimer = flashDur;
	iframes = cfg.iframes;

	if (_src != noone && instance_exists(_src))
	{
		var _dir = sign(x - _src.x);
		if (_dir == 0) _dir = -facing;
		var _k = _knock * (_hit[$ "knock"] ?? 1) * (1 - cfg.knockResist);
		hSpd = _dir * _k;
		vSpd = cfg.flying ? 0 : -_k * 0.4;
	}

	on_hurt(_dmg, _type, _src);
	if (stats.hp > 0) effect_apply(_type, _dmg);   // chip % is based on this hit's damage

	if (stats.hp <= 0) kill();
	else if (!cfg.superArmor || _hit[$ "stagger"] != undefined)
	{
		hurtMult = _hit[$ "stagger"] ?? 1;
		state_change(EnemyState.HURT, true);
	}

	return _dmg;
}

function kill()
{
	stats.hp = 0;
	stunTimer = 0;
	if (state == EnemyState.DEAD) return;
	if (!state_change(EnemyState.DEAD)) { on_death(); drop_loot(); instance_destroy(); }
}

// Hooks: reassign in a child, e.g. on_death = function() { ...drops... };
on_hurt  = function(_dmg, _type, _src) {};
on_death = function() {};

// ---------------- Movement ----------------
function enemy_move()
{
	var _ts = global.timeScale;

	if (!cfg.flying)
	{
		if (onGround) { if (vSpd > 0) vSpd = 0; }
		else vSpd += cfg.grav * _ts;
	}

	var _vs = cfg.flying ? slowMult : 1;
	var _h = hSpd * _ts * slowMult + hSpdRem;
	var _v = vSpd * _ts * _vs + vSpdRem;
	var _mx = round(_h);
	var _my = round(_v);
	hSpdRem = _h - _mx;
	vSpdRem = _v - _my;

	repeat (abs(_mx))
	{
		if (!place_meeting(x + sign(_mx), y, obj_col)) x += sign(_mx);
		else { hSpd = 0; hSpdRem = 0; break; }
	}
	repeat (abs(_my))
	{
		if (!place_meeting(x, y + sign(_my), obj_col)) y += sign(_my);
		else { vSpd = 0; vSpdRem = 0; break; }
	}
}