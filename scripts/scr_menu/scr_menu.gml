function mn_menu(_label, _items, _visible = undefined)
{ return { type: "menu", label: _label, items: _items, visible: _visible, enabled: undefined }; }

function mn_button(_label, _action, _visible = undefined)
{ return { type: "button", label: _label, action: _action, visible: _visible, enabled: undefined }; }

function mn_toggle(_label, _get, _set)
{ return { type: "toggle", label: _label, get: _get, set: _set, visible: undefined, enabled: undefined }; }

function mn_dropdown(_label, _options, _get, _set, _enabled = undefined)
{ return { type: "dropdown", label: _label, options: _options, get: _get, set: _set, visible: undefined, enabled: _enabled }; }

function mn_slider(_label, _get, _set, _step = 0.05)
{ return { type: "slider", label: _label, get: _get, set: _set, step: _step, visible: undefined, enabled: undefined }; }

function mn_rebind(_label, _action)
{ return { type: "rebind", label: _label, action: _action, slot: 0, visible: undefined, enabled: undefined }; }



function controls_items()
{
	var _acts = [
		["left", "Left"], ["right", "Right"], ["down", "Down"], ["up", "Up"],
		["jump", "Jump"], ["run", "Run / Previous"], ["attack", "Attack / Next"], ["action", "Action Menu"]
	];
	var _items = [];
	for (var i = 0; i < array_length(_acts); i++) array_push(_items, mn_rebind(_acts[i][1], _acts[i][0]));
	array_push(_items, mn_button("Reset to Defaults", function() {
		global.binds = json_parse(json_stringify(global.bindsDefault));
		settings_save();
	}));
	return _items;
}

// The whole menu structure. Edit this to add or move items.
function menu_build()
{
	return mn_menu("Main Menu", [
		mn_button("Continue", function() { with (obj_menu) menu_continue(); }),

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
			]),
			mn_menu("Audio", [
				mn_slider("Master",
					function() { return global.settings.master; },
					function(_v) { global.settings.master = _v; audio_apply(); }),
				mn_slider("Sound Effects",
					function() { return global.settings.sfx; },
					function(_v) { global.settings.sfx = _v; audio_apply(); }),
				mn_slider("Music",
					function() { return global.settings.music; },
					function(_v) { global.settings.music = _v; audio_apply(); })
			]),
			mn_menu("Controls", controls_items()),
			mn_dropdown("Language", global.languages,
				function() { return global.settings.language; },
				function(_v) { global.settings.language = _v; })
		]),

		mn_button("Quit to Menu",
			function() { with (obj_menu) menu_quit_to_menu(); },
			function() { return global.menuIngame; }),
		mn_button("Quit to Desktop", function() { game_end(); })
	]);
}