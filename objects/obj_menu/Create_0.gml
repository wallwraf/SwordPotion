if (!variable_instance_exists(id, "ingame"))    ingame = true;      // false in the main menu room
if (!variable_instance_exists(id, "startOpen")) startOpen = false;  // true in the main menu room

if (!variable_global_exists("settingsLoaded")) { global.settingsLoaded = true; settings_load(); }
global.menuIngame = ingame;
global.paused = false;

root = menu_build();
stack = [root];
cursor = [0];
open = startOpen;
capture = false;
bg = -1;
openAnim = startOpen ? 1 : 0;
textScale = 0.8;

dropOpen = false;
dropIndex = 0;
rebinding = false;

navKeys = [[vk_up, ord("W")], [vk_down, ord("S")], [vk_left, ord("A")], [vk_right, ord("D")]];
navT = [0, 0, 0, 0];

// Held directions repeat after a short delay (for sliders)
function nav(_d)
{
	var _held = keyboard_check(navKeys[_d][0]) || keyboard_check(navKeys[_d][1]);
	if (!_held) { navT[_d] = 0; return false; }
	navT[_d]++;
	return (navT[_d] == 1) || (navT[_d] > 20 && navT[_d] mod 4 == 0);
}

function node_enabled(_n) { return (_n.enabled == undefined) || _n.enabled(); }

function menu_items()
{
	var _node = stack[array_length(stack) - 1];
	var _out = [];
	for (var i = 0; i < array_length(_node.items); i++)
	{
		var _n = _node.items[i];
		if (_n.visible == undefined || _n.visible()) array_push(_out, _n);
	}
	return _out;
}

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
	else show_debug_message("Continue: load the save here");   // main menu hook
}

function menu_quit_to_menu()
{
	settings_save();
	global.paused = false;
	global.timeScale = 1;
	global.timeScaleTarget = 1;
	if (sprite_exists(bg)) sprite_delete(bg);
	instance_activate_all();
	if (global.mainMenuRoom != -1) room_goto(global.mainMenuRoom);
	else game_restart();    // works while your main menu is the first room
}