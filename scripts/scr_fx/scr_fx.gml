global.fxGold = [c_white, make_colour_rgb(255, 244, 150), make_colour_rgb(255, 200, 60), make_colour_rgb(210, 120, 30)];
global.fxDust = [make_colour_rgb(222, 212, 190), make_colour_rgb(170, 158, 138), make_colour_rgb(112, 102, 92)];
global.fxCool = [c_white, make_colour_rgb(170, 225, 255), make_colour_rgb(90, 160, 235)];
global.fxFire = [make_colour_rgb(255, 245, 190), make_colour_rgb(255, 170, 50), make_colour_rgb(200, 60, 20), make_colour_rgb(70, 30, 25)];

// count/speed/life/size are [min, max]. cols fade over a particle's life. shape: "pixel" (a square) or "streak" (a line along its motion).
// angle: [min, max] degrees (default all directions). Optional: jitter (spawn spread), shrink (0..1).
global.fxPresets = {
	spark_perfect: { count: [30, 36], speed: [2.5, 7.5], life: [14, 30], size: [1, 2], grav: 0.10, drag: 0.93, shrink: 0.5, shape: "streak", cols: global.fxGold },
	spark_parry:   { count: [14, 18], speed: [2.0, 5.5], life: [10, 22], size: [1, 2], grav: 0.08, drag: 0.93, shrink: 0.5, shape: "streak", cols: global.fxGold },
	spark_block:   { count: [5, 7],   speed: [1.2, 3.5], life: [8, 16],  size: [1, 1], grav: 0.08, drag: 0.92, shrink: 0.4, shape: "streak", cols: global.fxGold },
	spark_crit:    { count: [12, 16], speed: [2.0, 6.0], life: [10, 20], size: [1, 2], grav: 0.06, drag: 0.93, shrink: 0.5, shape: "streak", cols: global.fxGold },
	spark_dodge:   { count: [8, 10],  speed: [1.5, 4.0], life: [10, 18], size: [1, 2], grav: 0,    drag: 0.90, shrink: 0.6, shape: "pixel",  cols: global.fxCool },
	dust_land:     { count: [4, 6],   speed: [0.6, 1.9], life: [14, 28], size: [1, 2], grav: -0.02, drag: 0.90, shrink: 0.5, shape: "pixel", cols: global.fxDust, jitter: 3 },
	dodge_puff:    { count: [3, 4],   speed: [0.5, 1.4], life: [10, 18], size: [1, 2], grav: -0.02, drag: 0.90, shrink: 0.5, shape: "pixel", cols: global.fxDust },

	// examples for acts, rename or duplicate freely
	embers:        { count: [8, 12],  speed: [0.6, 2.5], life: [18, 34], size: [1, 2], grav: -0.05, drag: 0.95, shrink: 0.6, shape: "pixel", cols: global.fxFire },
	frost:         { count: [8, 12],  speed: [0.8, 3.0], life: [16, 30], size: [1, 2], grav: 0.03,  drag: 0.94, shrink: 0.5, shape: "pixel", cols: global.fxCool },
	puff:          { count: [6, 8],   speed: [0.5, 1.8], life: [14, 26], size: [2, 3], grav: -0.02, drag: 0.92, shrink: 0.6, shape: "pixel", cols: global.fxDust }
};

function fx_boot() { if (!instance_exists(obj_fx)) instance_create_depth(0, 0, -5000, obj_fx); }

// _scale multiplies the particle count (and nudges speed and size up past 1).
// _o: angle + spread (degrees) make it directional.
function fx_emit(_name, _x, _y, _scale = 1, _o = {})
{
	var _p = global.fxPresets[$ _name];
	if (_p == undefined) return;
	fx_boot();

	var _n = max(1, round(irandom_range(_p.count[0], _p.count[1]) * _scale));
	var _full = _p[$ "angle"] ?? [0, 360];
	var _ang = _o[$ "angle"];
	var _spread = _o[$ "spread"] ?? 360;
	var _spScale = 0.6 + 0.4 * _scale;
	var _jit = _p[$ "jitter"] ?? 2;

	with (obj_fx)
	{
		repeat (_n)
		{
			var _dir = (_ang != undefined) ? _ang + random_range(-_spread / 2, _spread / 2) : random_range(_full[0], _full[1]);
			var _spd = random_range(_p.speed[0], _p.speed[1]) * _spScale;
			array_push(parts, {
				x: _x + random_range(-_jit, _jit), y: _y + random_range(-_jit, _jit),
				hv: lengthdir_x(_spd, _dir), vv: lengthdir_y(_spd, _dir),
				grav: _p.grav, drag: _p.drag, age: 0,
				life: random_range(_p.life[0], _p.life[1]),
				size: round(random_range(_p.size[0], _p.size[1] + ((_scale > 1.3) ? 1 : 0))),
				shrink: _p[$ "shrink"] ?? 0.5, shape: _p.shape, cols: _p.cols
			});
		}
	}
}

function fx_flash(_x, _y, _r, _life = 8, _col = c_white)
{
	fx_boot();
	with (obj_fx) array_push(flashes, { x: _x, y: _y, r: _r, age: 0, life: _life, col: _col });
}

// Plays a sprite once. _o: scale, angle, flip, additive, speed (animation steps per frame), life (frames), follow (instance), ox, oy.
// The sprite's origin is used as-is, so centre-origin sprites are easiest.
function fx_sprite(_spr, _x, _y, _o = {})
{
	if (_spr == -1 || !sprite_exists(_spr)) return noone;
	return instance_create_depth(_x, _y, -5001, obj_fx_sprite, {
		spr: _spr, scl: _o[$ "scale"] ?? 1, ang: _o[$ "angle"] ?? 0, flip: _o[$ "flip"] ?? false,
		add: _o[$ "additive"] ?? false, spd: _o[$ "speed"] ?? 1, life: _o[$ "life"] ?? 0,
		follow: _o[$ "follow"] ?? noone, fox: _o[$ "ox"] ?? 0, foy: _o[$ "oy"] ?? 0
	});
}

// One art entry: any of { spr, scale, angle, flip, additive, speed, ox, oy, particles, pscale, flash, flashCol, shake }
function art_play(_e, _x, _y, _o = {})
{
	var _face = _o[$ "facing"] ?? 1;
	var _ang = _o[$ "angle"] ?? (_e[$ "angle"] ?? 0);

	if (_e[$ "spr"] != undefined)
		fx_sprite(_e.spr, _x + (_e[$ "ox"] ?? 0) * _face, _y + (_e[$ "oy"] ?? 0), {
			scale: _e[$ "scale"] ?? 1, angle: _ang, flip: (_e[$ "flip"] ?? true) && _face < 0,
			additive: _e[$ "additive"] ?? false, speed: _e[$ "speed"] ?? 1, life: _e[$ "life"] ?? 0 });

	if (_e[$ "particles"] != undefined) fx_emit(_e.particles, _x, _y, _e[$ "pscale"] ?? 1, (_o[$ "angle"] != undefined) ? { angle: _o.angle, spread: 80 } : {});
	if (_e[$ "flash"] != undefined) fx_flash(_x, _y, _e.flash, 10, _e[$ "flashCol"] ?? c_white);
	if (_e[$ "shake"] != undefined) screen_shake(_e.shake);
}