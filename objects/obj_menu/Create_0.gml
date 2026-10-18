if (!variable_instance_exists(id, "ingame"))    ingame = true;      // false in the main menu room
if (!variable_instance_exists(id, "startOpen")) startOpen = false;  // true in the main menu room

if (!variable_global_exists("settingsLoaded")) { global.settingsLoaded = true; settings_load(); }

ready = false;   // creation code runs after Create, so setup that depends on ingame/startOpen waits for the first Step
root = undefined;
stack = [];
cursor = [0];
open = false;
openAnim = 0;

menuPalette = [
	status_tint(DamageType.COLD),      status_tint(DamageType.FIRE),
	status_tint(DamageType.POISON),    status_tint(DamageType.PSYCHIC),
	status_tint(DamageType.LIGHTNING), status_tint(DamageType.NECROTIC),
	status_tint(DamageType.ACID),      status_tint(DamageType.RADIANT)
];

capture = false;
bg = -1;
textScale = 0.8;

menuAngle   = 8;      // tilt of buttons and text, degrees
skewK       = 0.45;   // how far button edges lean
stripeAngle = 14;     // background stripes
slabAngle   = 20;     // swipe edges
panelFrac   = 0.46;   // pause menu: share of the screen the menu panel covers
popStep = 6;          // frames between each button popping in
popDur  = 14;

dropOpen = false;
dropIndex = 0;
rebinding = false;

tintDefault = status_tint(DamageType.COLD);
bgCol = tintDefault;

pageAge = -14;        // frames since this page appeared (negative = waiting to pop)
sel = array_create(24, 0);   // per-button selection amount 0..1 (drives scale and invert)
kick = 0;
bgT = 0;

navKeys = [[vk_up, ord("W")], [vk_down, ord("S")], [vk_left, ord("A")], [vk_right, ord("D")]];
navT = [0, 0, 0, 0];

cOx = 0; cOy = 0; cS = 1; cBw = 100;   // drawing context for "button space"
clipX0 = 1000000; clipK = 0;           // pause panel edge (huge = no clipping)

stripes = [
	{ y: 0.88, t: 0.20,  shade: 0.72, ph: 0.0 },   // the big dark stripe along the bottom
	{ y: 0.68, t: 0.035, shade: 0.45, ph: 1.7 },
	{ y: 0.58, t: 0.022, shade: 0.35, ph: 3.1 },
	{ y: 0.47, t: 0.050, shade: 0.28, ph: 4.4 },
	{ y: 0.30, t: 0.018, shade: 0.30, ph: 5.2 },
	{ y: 0.18, t: 0.040, shade: 0.22, ph: 2.4 }
];

dust = [];
repeat (70) array_push(dust, { x: random(1), y: random(1), s: random_range(0.6, 2.2),
	vx: random_range(0.0001, 0.0005), vy: random_range(0.0002, 0.0008), ph: random(6.28) });

glints = [];
repeat (9) array_push(glints, { x: random(1), y: random(1), s: random_range(7, 15),
	life: random(1), spd: random_range(0.006, 0.014) });

ddScroll = 0;          // first visible row of an open dropdown
panelWide = 0.62;      // pause panel width for pages with values
panelCur = panelFrac;

function page_wide()
{
	var _its = menu_items();
	for (var i = 0; i < array_length(_its); i++)
		if (_its[i].type != "menu" && _its[i].type != "button") return true;
	return false;
}

// x of the pause panel's edge at height _y, for a panel _pw wide at mid-height
function edge_at(_pw, _y, _H) { return _pw + dtan(18) * (_y - _H / 2); }

function menu_setup()
{
	ready = true;
	global.menuIngame = ingame;
	global.paused = false;
	root = menu_build();
	stack = [root];
	cursor = [0];
	open = startOpen;
	openAnim = startOpen ? 1 : 0;
	reset_page();
}

// Held directions repeat after a short delay (for sliders)
function nav(_d)
{
	var _held = keyboard_check(navKeys[_d][0]) || keyboard_check(navKeys[_d][1]);
	if (!_held) { navT[_d] = 0; return false; }
	navT[_d]++;
	return (navT[_d] == 1) || (navT[_d] > 20 && navT[_d] mod 4 == 0);
}

function node_enabled(_n) { return (_n.enabled == undefined) || _n.enabled(); }

function menu_close()
{
	settings_save();
	open = false;
	global.paused = false;
	if (sprite_exists(bg)) { sprite_delete(bg); bg = -1; }
	instance_activate_all();
	stack = [root];
	cursor = [0];
	dropOpen = false;
	rebinding = false;
	io_clear();
}

function menu_continue()
{
	if (ingame) menu_close();
	else room_goto_next();   // Start: next room in the room order
}

function menu_quit_to_menu()
{
	settings_save();
	global.paused = false;
	global.timeScale = 1;
	global.timeScaleTarget = 1;
	if (sprite_exists(bg)) sprite_delete(bg);
	instance_activate_all();
	room_goto(global.mainMenuRoom);
}

function menu_items_at(_level)
{
	var _node = stack[_level];
	var _out = [];
	for (var i = 0; i < array_length(_node.items); i++)
	{
		var _n = _node.items[i];
		if (_n.visible == undefined || _n.visible()) array_push(_out, _n);
	}
	return _out;
}

function menu_items() { return menu_items_at(array_length(stack) - 1); }

// An option's own tint, or an automatic palette colour that varies by position and page
function item_tint(_item, _index, _level)
{
	var _t = _item[$ "tint"];            // safe read: undefined if the builder has no tint field
	if (_t != undefined) return _t;

	var _off = 0;
	for (var l = 0; l < _level; l++) _off += cursor[l] * 3 + 2;
	return menuPalette[(_index + _off) mod array_length(menuPalette)];
}

function tint_of(_level)
{
	var _its = menu_items_at(_level);
	var _i = clamp(cursor[_level], 0, array_length(_its) - 1);
	return item_tint(_its[_i], _i, _level);
}

function current_tint() { return tint_of(array_length(stack) - 1); }

function reset_page()
{
	for (var i = 0; i < array_length(sel); i++) sel[i] = 0;
	dropOpen = false;
	rebinding = false;
	pageAge = -14;
	panelCur = page_wide() ? panelWide : panelFrac;
}

// ---- Slab swipe: cover -> swap the page under cover -> reveal
function trans_start(_kind, _node, _tint)
{
	if (instance_exists(obj_slab)) return;
	instance_create_depth(0, 0, -10000, obj_slab, { job: { kind: _kind, node: _node }, tint: _tint });
}

function trans_swap(_job)
{
	switch (_job.kind)
	{
		case "push":
			array_push(stack, _job.node);
			array_push(cursor, 0);
			reset_page();
			break;
		case "pop":
			array_pop(stack);
			array_pop(cursor);
			settings_save();
			reset_page();
			break;
		case "action":
			_job.node.action();   // Start, Continue, Quit...
			break;
	}
	kick = 0.6;
}

// ---- Geometry in "button space": origin = left-centre of the button, tilted by menuAngle, edges leaning by skewK
function bpx(_u, _v)
{
	var _uu = _u - _v * skewK;
	var _su = cBw / 2 + (_uu - cBw / 2) * cS;
	var _sv = _v * cS;
	return cOx + lengthdir_x(_su, menuAngle) + lengthdir_x(_sv, menuAngle - 90);
}

function bpy(_u, _v)
{
	var _uu = _u - _v * skewK;
	var _su = cBw / 2 + (_uu - cBw / 2) * cS;
	var _sv = _v * cS;
	return cOy + lengthdir_y(_su, menuAngle) + lengthdir_y(_sv, menuAngle - 90);
}

function bquad(_u0, _v0, _u1, _v1, _col, _alpha, _ox = 0, _oy = 0)
{
	draw_primitive_begin(pr_trianglefan);
	draw_vertex_colour(bpx(_u0, _v0) + _ox, bpy(_u0, _v0) + _oy, _col, _alpha);
	draw_vertex_colour(bpx(_u1, _v0) + _ox, bpy(_u1, _v0) + _oy, _col, _alpha);
	draw_vertex_colour(bpx(_u1, _v1) + _ox, bpy(_u1, _v1) + _oy, _col, _alpha);
	draw_vertex_colour(bpx(_u0, _v1) + _ox, bpy(_u0, _v1) + _oy, _col, _alpha);
	draw_primitive_end();
}

function btri(_u0, _v0, _u1, _v1, _u2, _v2, _col)
{
	draw_primitive_begin(pr_trianglelist);
	draw_vertex_colour(bpx(_u0, _v0), bpy(_u0, _v0), _col, 1);
	draw_vertex_colour(bpx(_u1, _v1), bpy(_u1, _v1), _col, 1);
	draw_vertex_colour(bpx(_u2, _v2), bpy(_u2, _v2), _col, 1);
	draw_primitive_end();
}

function bframe(_u0, _v0, _u1, _v1, _col)
{
	draw_primitive_begin(pr_linestrip);
	draw_vertex_colour(bpx(_u0, _v0), bpy(_u0, _v0), _col, 1);
	draw_vertex_colour(bpx(_u1, _v0), bpy(_u1, _v0), _col, 1);
	draw_vertex_colour(bpx(_u1, _v1), bpy(_u1, _v1), _col, 1);
	draw_vertex_colour(bpx(_u0, _v1), bpy(_u0, _v1), _col, 1);
	draw_vertex_colour(bpx(_u0, _v0), bpy(_u0, _v0), _col, 1);
	draw_primitive_end();
}

// ---- Polygons clipped to the pause panel's slanted edge (no-op in the main menu)
function poly_clip(_pts)
{
	if (clipX0 >= 1000000) return _pts;
	var _out = [];
	var _n = array_length(_pts) div 2;
	for (var i = 0; i < _n; i++)
	{
		var _ax = _pts[i * 2], _ay = _pts[i * 2 + 1];
		var _j = (i + 1) mod _n;
		var _bx = _pts[_j * 2], _by = _pts[_j * 2 + 1];
		var _da = _ax - (clipX0 + clipK * _ay);
		var _db = _bx - (clipX0 + clipK * _by);
		if (_da <= 0) array_push(_out, _ax, _ay);
		if ((_da <= 0) != (_db <= 0))
		{
			var _t = _da / (_da - _db);
			array_push(_out, _ax + (_bx - _ax) * _t, _ay + (_by - _ay) * _t);
		}
	}
	return _out;
}

function draw_poly(_pts, _col, _alpha, _clip = true)
{
	if (_clip) _pts = poly_clip(_pts);
	var _n = array_length(_pts) div 2;
	if (_n < 3) return;
	draw_primitive_begin(pr_trianglefan);
	for (var i = 0; i < _n; i++) draw_vertex_colour(_pts[i * 2], _pts[i * 2 + 1], _col, _alpha);
	draw_primitive_end();
}

// ---- The living background
function draw_menu_bg(_W, _H, _u)
{
	var _breathe = sin(bgT * 0.025);
	var _base  = merge_colour(bgCol, c_white, 0.05 + 0.05 * _breathe);
	var _light = merge_colour(bgCol, c_white, 0.75);

	draw_poly([0, 0, _W, 0, _W, _H, 0, _H], _base, 1);

	// Dark angled stripes: they swell and sway slowly
	for (var i = 0; i < array_length(stripes); i++)
	{
		var _s  = stripes[i];
		var _th = _s.t * _H * (1 + 0.10 * sin(bgT * 0.025 + _s.ph));
		var _cx = _W / 2;
		var _cy = _s.y * _H + _H * 0.012 * sin(bgT * 0.017 + _s.ph);
		var _L  = _W * 1.3;
		var _dx = lengthdir_x(_L, stripeAngle), _dy = lengthdir_y(_L, stripeAngle);
		var _nx = lengthdir_x(_th / 2, stripeAngle - 90), _ny = lengthdir_y(_th / 2, stripeAngle - 90);
		draw_poly([_cx - _dx - _nx, _cy - _dy - _ny, _cx + _dx - _nx, _cy + _dy - _ny,
		           _cx + _dx + _nx, _cy + _dy + _ny, _cx - _dx + _nx, _cy - _dy + _ny],
		           merge_colour(bgCol, c_black, _s.shade), 1);
	}

	// Dust
	for (var i = 0; i < array_length(dust); i++)
	{
		var _d = dust[i];
		var _px = _d.x * _W, _py = _d.y * _H;
		if (_px > clipX0 + clipK * _py) continue;
		var _al = 0.2 + 0.4 * (0.5 + 0.5 * sin(_d.ph + bgT * 0.05));
		var _r = _d.s * _u;
		draw_poly([_px, _py - _r, _px + _r, _py, _px, _py + _r, _px - _r, _py], _light, _al, false);
	}

	// Glints: four-point twinkles
	for (var i = 0; i < array_length(glints); i++)
	{
		var _g = glints[i];
		var _px = _g.x * _W, _py = _g.y * _H;
		var _sz = sin(_g.life * pi) * _g.s * _u;
		if (_sz < 0.5 || _px > clipX0 + clipK * _py) continue;
		draw_poly([_px - _sz, _py, _px, _py - _sz * 0.16, _px + _sz, _py, _px, _py + _sz * 0.16], c_white, 0.9, false);
		draw_poly([_px, _py - _sz, _px + _sz * 0.16, _py, _px, _py + _sz, _px - _sz * 0.16, _py], c_white, 0.9, false);
	}
}

// Thick frame made of four slanted bars
function bframe_thick(_u0, _v0, _u1, _v1, _col, _t)
{
	bquad(_u0, _v0, _u1, _v0 + _t, _col, 1);
	bquad(_u0, _v1 - _t, _u1, _v1, _col, 1);
	bquad(_u0, _v0, _u0 + _t, _v1, _col, 1);
	bquad(_u1 - _t, _v0, _u1, _v1, _col, 1);
}