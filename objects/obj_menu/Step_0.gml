if (!open)
{
	if (ingame && !capture && keyboard_check_pressed(vk_escape)
		&& instance_exists(obj_player) && obj_player.state != PlayerState.DEAD) capture = true;
	exit;
}

openAnim = min(1, openAnim + 0.12);

var _items = menu_items();
var _level = array_length(stack) - 1;
cursor[_level] = clamp(cursor[_level], 0, array_length(_items) - 1);
var _it = _items[cursor[_level]];

// ---- Waiting for a key to bind
if (rebinding)
{
	if (keyboard_check_pressed(vk_escape)) { rebinding = false; io_clear(); exit; }
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

var _up   = nav(0), _down = nav(1), _left = nav(2), _right = nav(3);
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

// ---- Move the cursor
var _count = array_length(_items);
if (_up)   { cursor[_level] = (cursor[_level] - 1 + _count) mod _count; menu_sfx("move"); }
if (_down) { cursor[_level] = (cursor[_level] + 1) mod _count;          menu_sfx("move"); }
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
			var _no = array_length(_it.options);
			_it.set((_it.get() + _h + _no) mod _no);
			menu_sfx("move");
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
			array_push(stack, _it);
			array_push(cursor, 0);
			menu_sfx("select");
			break;
		case "button":
			menu_sfx("select");
			_it.action();
			exit;   // the action may have closed the menu
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
		array_pop(stack);
		array_pop(cursor);
		settings_save();
		menu_sfx("back");
	}
	else if (ingame) menu_close();
}