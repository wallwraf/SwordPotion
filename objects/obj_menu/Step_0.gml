if (!ready) menu_setup();

if (!open)
{
	if (ingame && !instance_exists(obj_slab) && !capture && keyboard_check_pressed(vk_escape)
		&& instance_exists(obj_player) && obj_player.state != PlayerState.DEAD) capture = true;
	exit;
}

// ---- Animation clocks (real time)
openAnim = closing ? max(0, openAnim - 0.1) : min(1, openAnim + 0.1);
panelCur = lerp(panelCur, panelTarget, 0.18);
bgT++;
pageAge++;
kick *= 0.82;
bgCol = merge_colour(bgCol, current_tint(), 0.12);

for (var i = 0; i < array_length(dust); i++)
{
	var _d = dust[i];
	_d.x += _d.vx;
	_d.y -= _d.vy;
	if (_d.y < -0.02) { _d.y = 1.02; _d.x = random(1); }
	if (_d.x > 1.02) _d.x = -0.02;
}
for (var i = 0; i < array_length(glints); i++)
{
	var _g = glints[i];
	_g.life += _g.spd;
	if (_g.life >= 1) { _g.life = 0; _g.x = random(1); _g.y = random(1); _g.s = random_range(10, 26); _g.rot = random_range(-8, 8); }
}

var _items = menu_items();
var _level = array_length(stack) - 1;
var _count = array_length(_items);
cursor[_level] = clamp(cursor[_level], 0, _count - 1);
for (var i = 0; i < _count; i++) sel[i] = lerp(sel[i], (i == cursor[_level]) ? 1 : 0, 0.3);
var _it = _items[cursor[_level]];
if (closing)
{
	if (openAnim <= 0) menu_close();
	exit;
}

// Input is locked while a swipe plays
if (instance_exists(obj_slab)) exit;

// ---- Waiting for a key to bind
if (rebinding)
{
	if (keyboard_check_pressed(vk_escape)) { rebinding = false; io_clear(); exit; }
	if (keyboard_check_pressed(vk_delete))
	{
		global.binds[$ _it.action][_it.slot] = -1;
		rebinding = false;
		settings_save();
		menu_sfx("select");
		io_clear();
		exit;
	}
	if (keyboard_check_pressed(vk_anykey))
	{
		global.binds[$ _it.action][_it.slot] = keyboard_lastkey;
		rebinding = false;
		settings_save();
		menu_sfx("select");
		io_clear();
	}
	exit;
}

var _up		 = nav(0), _down = nav(1), _left = nav(2), _right = nav(3);
var _confirm = keyboard_check_pressed(vk_enter) || keyboard_check_pressed(vk_space) || keyboard_check_pressed(ord("Z"));
var _back    = keyboard_check_pressed(vk_escape) || keyboard_check_pressed(vk_shift) || keyboard_check_pressed(ord("X"));

// ---- Dropdown list open
if (dropOpen)
{
	var _n = array_length(_it.options);
	if (_up)   { dropIndex = (dropIndex - 1 + _n) mod _n; menu_sfx("move"); }
	if (_down) { dropIndex = (dropIndex + 1) mod _n;      menu_sfx("move"); }
	if (_confirm) { _it.set(dropIndex); dropOpen = false; settings_save(); menu_sfx("select"); }
	if (_back)    { dropOpen = false; menu_sfx("back"); }
	exit;
}

// ---- Move the cursor (every change kicks the screen)
if (_up)   { cursor[_level] = (cursor[_level] - 1 + _count) mod _count; kick = 1; menu_sfx("move"); }
if (_down) { cursor[_level] = (cursor[_level] + 1) mod _count;          kick = 1; menu_sfx("move"); }
_it = _items[cursor[_level]];

// ---- Left/right adjusts values
var _h = (_right ? 1 : 0) - (_left ? 1 : 0);
if (_h != 0 && node_enabled(_it))
{
	switch (_it.type)
	{
		case "slider":
			_it.set(clamp(round((_it.get() + _h * _it.step) / _it.step) * _it.step, 0, 1));
			menu_sfx("move");
			break;
		case "toggle":
			_it.set(!_it.get());
			menu_sfx("move");
			break;
		case "dropdown":
			dropOpen = true;
			dropIndex = _it.get();
			ddScroll = 0;
			menu_sfx("select");
			break;
		case "rebind":
			_it.slot = clamp(_it.slot + _h, 0, 1);
			menu_sfx("move");
			break;
	}
}

// ---- Confirm
if (_confirm && node_enabled(_it))
{
	switch (_it.type)
	{
		case "menu":
			trans_start("push", _it, page_first_tint(_it), ingame);
			menu_sfx("select");
			break;
		case "button":
			menu_sfx("select");
			if (ingame && _it[$ "quick"] == true) { _it.action(); exit; }   // Continue: plays the opening in reverse
			trans_start("action", _it, item_tint(_it, cursor[_level], _level), false);
			exit;
		case "toggle":
			_it.set(!_it.get());
			menu_sfx("select");
			break;
		case "dropdown":
			dropOpen = true;
			dropIndex = _it.get();
			menu_sfx("select");
			break;
		case "rebind":
			rebinding = true;
			io_clear();
			break;
	}
}

// ---- Back
if (_back)
{
	if (array_length(stack) > 1)
	{
		trans_start("pop", undefined, tint_of(array_length(stack) - 2), ingame);
		menu_sfx("back");
	}
	else if (ingame) menu_begin_close();
}