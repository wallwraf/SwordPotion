function status_init()
{
	mods = [];
	effects = [];
	buildup = array_create(array_length(global.damageTypes), 0);
	buildIdle = array_create(array_length(global.damageTypes), 0);
	slowMult = 1; vulnMult = 1; outMult = 1;
	confused = false;
	stunTimer = 0;
	hurtMult = 1;
	buildScale = 1;       // scales how fast build-up meters (necrotic) fill
	statusActive = false;
}

function status_clear()   // cleanse items, checkpoints, etc.
{
	effects = [];
	for (var t = 0; t < array_length(buildup); t++) { buildup[t] = 0; buildIdle[t] = 0; }
	stunTimer = 0;
}

function stat_get(_name)
{
	var _v = stats[$ _name] ?? 0;
	for (var i = 0; i < array_length(mods); i++)
		if (mods[i].stat == _name) _v += mods[i].amount;
	return _v;
}

function stat_mod(_name, _amount, _frames)
{
	array_push(mods, { stat: _name, amount: _amount, time: _frames });
}

function show_number(_amount, _col, _chip = false)
{
	instance_create_depth((bbox_left + bbox_right) / 2, (bbox_top + bbox_bottom) / 2, -10000, obj_damage_number, {
		amount: _amount, col: _col, chip: _chip,
		floorY: bbox_bottom + random_range(-2, 2)
	});
}

// Needs on the calling object: is_dead(), take_chip(amount), kill(), on_chip(amount, type)
function effect_chip(_amount, _type)
{
	if (is_dead()) return;
	take_chip(_amount);
	flashTimer = max(flashTimer, 3);
	show_number(_amount, global.damageTypes[_type].fx.col, true);
	on_chip(_amount, _type);
	if (is_dead()) kill();
}

function effect_apply(_type, _base)
{
	var _fx = global.damageTypes[_type][$ "fx"];
	if (_fx == undefined) return;

	if (_fx[$ "build"] != undefined)
	{
		buildup[_type] = min(1, buildup[_type] + _fx.build * affinity[_type] * buildScale);
		buildIdle[_type] = 0;
		if (buildup[_type] >= 1) kill();
		return;
	}

	for (var i = 0; i < array_length(effects); i++)
	{
		if (effects[i].type == _type)
		{
			effects[i].duration = effects[i].clock + _fx.dur;
			effects[i].base = max(effects[i].base, _base);
			return;
		}
	}
	array_push(effects, { type: _type, clock: 0, duration: _fx.dur, base: _base });
}

function effects_update()
{
	var _ts = global.timeScale;

	for (var m = array_length(mods) - 1; m >= 0; m--)
	{
		mods[m].time -= _ts;
		if (mods[m].time <= 0) array_delete(mods, m, 1);
	}

	if (is_dead())
	{
		effects = [];
		statusActive = false;
		image_blend = c_white;
		return;
	}

	slowMult = 1; vulnMult = 1; outMult = 1; confused = false;
	var _tint = c_white;

	for (var i = array_length(effects) - 1; i >= 0; i--)
	{
		var _e  = effects[i];
		var _fx = global.damageTypes[_e.type].fx;
		_e.clock += _ts;

		var _ticks = _fx[$ "ticks"];
		if (_ticks != undefined)
		{
			for (var j = 0; j < array_length(_ticks); j++)
			{
				var _k1 = floor((_e.clock - _ticks[j]) / _fx.every);
				var _k0 = floor((_e.clock - _ts - _ticks[j]) / _fx.every);
				if (_k1 > _k0 && _k1 >= 1)
				{
					effect_chip(max(1, round(_e.base * _fx.pct)), _e.type);
					if (_fx[$ "stun"] != undefined) stunTimer = max(stunTimer, _fx.stun);
				}
			}
		}

		if (_e.clock >= _e.duration) { array_delete(effects, i, 1); continue; }

		if (_fx[$ "slow"]    != undefined) slowMult = min(slowMult, _fx.slow);
		if (_fx[$ "vuln"]    != undefined) vulnMult += _fx.vuln;
		if (_fx[$ "weaken"]  != undefined) outMult = min(outMult, 1 - _fx.weaken);
		if (_fx[$ "confuse"] != undefined) confused = true;
		_tint = merge_colour(_tint, _fx.col, 0.5);
	}

	var _anyBuild = false;
	for (var t = 0; t < array_length(buildup); t++)
	{
		if (buildup[t] <= 0) continue;
		_anyBuild = true;
		var _fxb = global.damageTypes[t].fx;
		buildIdle[t] += _ts;
		if (buildIdle[t] >= _fxb.decayDelay) buildup[t] = max(0, buildup[t] - _fxb.decay * _ts / SEC);
		_tint = merge_colour(_tint, _fxb.col, buildup[t] * 0.7);
	}

	statusActive = (array_length(effects) > 0) || _anyBuild;
	image_blend = gfx().tint ? _tint : c_white;
}