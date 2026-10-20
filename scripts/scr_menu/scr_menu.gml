function mn_menu(_label, _items, _visible = undefined, _tint = undefined)
{ return { type: "menu", label: _label, items: _items, visible: _visible, enabled: undefined, tint: _tint }; }

function mn_button(_label, _action, _visible = undefined, _tint = undefined, _quick = false)
{ return { type: "button", label: _label, action: _action, visible: _visible, enabled: undefined, tint: _tint, quick: _quick }; }

function mn_toggle(_label, _get, _set)
{ return { type: "toggle", label: _label, get: _get, set: _set, visible: undefined, enabled: undefined }; }

function mn_dropdown(_label, _options, _get, _set, _enabled = undefined, _tint = undefined)
{ return { type: "dropdown", label: _label, options: _options, get: _get, set: _set, visible: undefined, enabled: _enabled, tint: _tint }; }

function mn_slider(_label, _get, _set, _step = 0.05)
{ return { type: "slider", label: _label, get: _get, set: _set, step: _step, visible: undefined, enabled: undefined }; }

function mn_rebind(_label, _action, _hint = "", _tint = undefined)
{ return { type: "rebind", label: _label, action: _action, slot: 0, hint: _hint, visible: undefined, enabled: undefined, tint: _tint }; }

function controls_items()
{
	var _acts = [
		["left",      "Left",        "Move left. Also moves the Action cursor."],
		["right",     "Right",       "Move right. Also moves the Action cursor."],
		["up",        "Up",          "Aim up. Also moves the Action cursor."],
		["down",      "Down",        "Aim down. Also moves the Action cursor."],
		["jump",      "Jump",        "Hold for a higher jump."],
		["run",       "Run / Dodge", "Hold to run. Tap to dodge. In the Action menu, cycles acts backward."],
		["parry",     "Parry",       "Hold to brace. Time it right to parry, otherwise you block."],
		["attack",    "Attack",      "Swing your weapon. In the Action menu, cycles acts forward."],
		["action",    "Act Menu",    "Hold to open the Action menu, release to perform the act."],
		["inventory", "Inventory",   "Open and close the inventory."]
	];
	var _items = [];
	for (var i = 0; i < array_length(_acts); i++) array_push(_items, mn_rebind(_acts[i][1], _acts[i][0], _acts[i][2]));
	array_push(_items, mn_button("Reset to Defaults", function() {
		global.binds = json_parse(json_stringify(global.bindsDefault));
		settings_save();
	}));
	return _items;
}

function status_tint(_type) { return global.damageTypes[_type].fx.col; }

function ease_out_back(_t)
{
	var _c1 = 1.70158;
	var _c3 = _c1 + 1;
	return 1 + _c3 * power(_t - 1, 3) + _c1 * power(_t - 1, 2);
}

// The whole menu structure. Edit this to add or move items.
function menu_build()
{
	return mn_menu("Main Menu", [
		mn_button(global.menuIngame ? "Continue" : "Start", function() { with (obj_menu) menu_continue(); }, undefined, status_tint(DamageType.COLD), true),
		
		mn_menu("Settings", [
			mn_menu("Video", [
				mn_toggle("Fullscreen",
					function() { return global.settings.fullscreen; },
					function(_v) { global.settings.fullscreen = _v; video_apply(); }),
				mn_dropdown("Resolution", ["25%", "50%", "75%", "100%"],
					function() { return global.settings.resolution; },
					function(_v) { global.settings.resolution = _v; video_apply(); },
					function() { return !global.settings.fullscreen; }),
				mn_dropdown("Graphics", ["Potato", "Low", "Medium", "High"],
					function() { return global.settings.graphics; },
					function(_v) { global.settings.graphics = _v; })
			], undefined, status_tint(DamageType.LIGHTNING)),
			mn_menu("Audio", [
				mn_slider("VOL",
					function() { return global.settings.master; },
					function(_v) { global.settings.master = _v; audio_apply(); }),
				mn_slider("SFX",
					function() { return global.settings.sfx; },
					function(_v) { global.settings.sfx = _v; audio_apply(); }),
				mn_slider("MUS",
					function() { return global.settings.music; },
					function(_v) { global.settings.music = _v; audio_apply(); })
			], undefined, status_tint(DamageType.PSYCHIC)),
			mn_menu("Controls", controls_items(), undefined, status_tint(DamageType.ACID)),
			mn_dropdown("Language", global.languages,
				function() { return global.settings.language; },
				function(_v) { global.settings.language = _v; },
				undefined, status_tint(DamageType.RADIANT))
		]),

		mn_button("Quit to Menu",
			function() { with (obj_menu) menu_quit_to_menu(); },
			function() { return global.menuIngame; },
			status_tint(DamageType.NECROTIC)),
		mn_button("Quit to Desktop", function() { game_end(); }, undefined, status_tint(DamageType.ACID))
	]);
}

// Keeps the part of a polygon left of the line x = _c0 + _k * y (_c0 >= 1000000 = no clipping)
function clip_poly(_pts, _c0, _k)
{
	if (_c0 >= 1000000) return _pts;
	var _out = [];
	var _n = array_length(_pts) div 2;
	for (var i = 0; i < _n; i++)
	{
		var _ax = _pts[i * 2], _ay = _pts[i * 2 + 1];
		var _j = (i + 1) mod _n;
		var _bx = _pts[_j * 2], _by = _pts[_j * 2 + 1];
		var _da = _ax - (_c0 + _k * _ay);
		var _db = _bx - (_c0 + _k * _by);
		if (_da <= 0) array_push(_out, _ax, _ay);
		if ((_da <= 0) != (_db <= 0))
		{
			var _t = _da / (_da - _db);
			array_push(_out, _ax + (_bx - _ax) * _t, _ay + (_by - _ay) * _t);
		}
	}
	return _out;
}