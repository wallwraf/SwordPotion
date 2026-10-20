global.gameTitle = "SwordPotion";

global.settingsDefault = { fullscreen: false, resolution: 3, graphics: 3, master: 1, sfx: 1, music: 1, language: 0 };

global.bindsDefault = {
	left:   [vk_left,  ord("A")],
	right:  [vk_right, ord("D")],
	up:     [vk_up,    ord("W")],
	down:   [vk_down,  ord("S")],
	jump:   [vk_up,    ord("W")],
	run:    [vk_shift, ord("X")],      // tap = dodge, hold = sprint
	attack: [vk_enter, ord("Z")],
	action: [vk_control, ord("C")],
	inventory: [vk_tab, -1],
	parry:  [vk_space, -1]
};

global.settings = json_parse(json_stringify(global.settingsDefault));
global.binds = json_parse(json_stringify(global.bindsDefault));

global.hitbox = false;
global.paused = false;

global.resPercents = [0.25, 0.5, 0.75, 1];
global.languages = ["English"];
global.strings = {};
global.mainMenuRoom = rm_menu;
global.menuSnd = { move: snd_menuMove, select: snd_menuSelect, back: snd_menuBack };

global.gfxPresets = [
	{ afterimage: 4, shake: 0.0, numberOutline: false, tint: false },
	{ afterimage: 3, shake: 0.5, numberOutline: false, tint: false },
	{ afterimage: 2, shake: 1.0, numberOutline: true, tint: true },
	{ afterimage: 1, shake: 1.0, numberOutline: true, tint: true }
];

function gfx() { return global.gfxPresets[global.settings.graphics]; }
function tr(_s) { return global.strings[$ _s] ?? _s; }

function video_apply()
{
	var _s = global.settings;
	window_set_fullscreen(_s.fullscreen);
	if (!_s.fullscreen)
	{
		var _p = global.resPercents[_s.resolution];
		window_set_size(max(320, display_get_width() * _p), max(180, display_get_height() * _p));
		window_center();
	}
}

function audio_apply()
{
	audio_master_gain(global.settings.master);
	global.sfxVolume = global.settings.sfx;
	music_apply();
}

function settings_apply() { audio_apply(); video_apply(); }

function settings_save()
{
	var _f = file_text_open_write("settings.json");
	file_text_write_string(_f, json_stringify({ settings: global.settings, binds: global.binds }));
	file_text_close(_f);
}

function settings_load()
{
	global.settings = json_parse(json_stringify(global.settingsDefault));
	global.binds = json_parse(json_stringify(global.bindsDefault));
	
	if (file_exists("settings.json"))
	{
		var _f = file_text_open_read("settings.json")
		var _txt = file_text_read_string(_f);
		file_text_close(_f);
		try
		{
			var _d = json_parse(_txt);
			var _n = variable_struct_get_names(global.settings);
			for (var i = 0; i < array_length(_n); i++)
				if (_d.settings[$ _n[i]] != undefined) global.settings[$ _n[i]] = _d.settings[$ _n[i]];
			_n = variable_struct_get_names(global.binds);
			for (var i = 0; i < array_length(_n); i++)
				if (_d.binds[$ _n[i]] != undefined) global.binds[$ _n[i]] = _d.binds[$ _n[i]];
		}
		catch (_e) { show_debug_message("settings.json unreadable, using defaults"); }
	}
	settings_apply();
}

function menu_sfx(_name)
{
	var _s = global.menuSnd[$ _name];
	if (_s != -1 && audio_exists(_s)) sfx_play(_s, 1, 0, true);
}

// Rebindable input
function input_check(_action)
{
	var _k = global.binds[$ _action];
	for (var i = 0; i < array_length(_k); i++)
		if (_k[i] > 0 && keyboard_check(_k[i])) return true;
	return false;
}

function input_pressed(_action)
{
	var _k = global.binds[$ _action];
	for (var i = 0; i < array_length(_k); i++)
		if (_k[i] > 0 && keyboard_check_pressed(_k[i])) return true;
	return false;
}

function key_name(_k)
{
	switch (_k)
	{
		case vk_space:     return "Space";
		case vk_enter:     return "Enter";
		case vk_shift:     return "Shift";
		case vk_control:   return "Ctrl";
		case vk_alt:       return "Alt";
		case vk_tab:       return "Tab";
		case vk_left:      return "Left";
		case vk_right:     return "Right";
		case vk_up:        return "Up";
		case vk_down:      return "Down";
		case vk_backspace: return "Bksp";
	}
	if (_k <= 0) return "-";
	if (_k >= 33 && _k <= 126) return chr(_k);
	return "Key " + string(_k);
}