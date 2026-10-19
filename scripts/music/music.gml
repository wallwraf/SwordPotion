// ======================= DATA =======================
global.musicFade = 10;                 // default fade in frames (0 = snap)
global.musicCombatGrace = 2;           // seconds combat music lingers after the last enemy stops fighting
global.musicSilenceWhenNone = false;   // true: fade to silence when no rule applies
global.musicArea = "";

// Songs. loopStart defaults to 0, loopEnd defaults to 0 = the end of the track.
// Optional per song: volume, pitch, loop (false = plays once), bpm + beats + beatOffset (for at: "bar"), resume.
global.music = {
	// forest:  { snd: mus_forest, loopStart: 8.0, loopEnd: 72.0, volume: 0.9, bpm: 100, beats: 4 },
	// battle:  { snd: mus_battle, loopStart: 4.2 },
	// boss:    { snd: mus_boss },
	// fanfare: { snd: mus_fanfare, loop: false }
};

// Rules: when their circumstance is true, the highest priority wins (later rules win ties).
// opts = any music_play option for that song. Item rules are one-shots and default to stingers.
global.musicRules = [
	// { trigger: "room",   room: rm_forest,            song: "forest", opts: { resume: true } },
	// { trigger: "area",   area: "cave",               song: "cave",   priority: 10, opts: { resume: true } },
	// { trigger: "combat",                              song: "battle", priority: 50, opts: { fade: 20 } },
	// { trigger: "enemy",  enemy: obj_golem,           song: "boss",   priority: 100, opts: { fade: 0 } },
	// { trigger: "item",   item: "ember_ring",         song: "fanfare" },
	// { trigger: "item",   rarity: ["legendary", "unique"], song: "fanfare" }
];

// ======================= HELPERS =======================
function frames_to_ms(_f) { return _f / game_get_speed(gamespeed_fps) * 1000; }
function frames_to_s(_f)  { return _f / game_get_speed(gamespeed_fps); }

function struct_merge(_a, _b)
{
	var _out = {};
	var _n = variable_struct_get_names(_a);
	for (var i = 0; i < array_length(_n); i++) _out[$ _n[i]] = _a[$ _n[i]];
	_n = variable_struct_get_names(_b);
	for (var i = 0; i < array_length(_n); i++) _out[$ _n[i]] = _b[$ _n[i]];
	return _out;
}

function match_any(_v, _x) { return (_v == _x) || (is_array(_v) && array_contains(_v, _x)); }

// An object or its parent matches (so obj_boss matches anything that inherits from it)
function match_enemy(_t, _obj)
{
	if (is_array(_t))
	{
		for (var i = 0; i < array_length(_t); i++) if (match_enemy(_t[i], _obj)) return true;
		return false;
	}
	return (_obj == _t) || object_is_ancestor(_obj, _t);
}

function music_def(_id)
{
	var _d = is_string(_id) ? global.music[$ _id] : { snd: _id };   // a sound asset works too
	if (_d == undefined) { show_debug_message("music: unknown song " + string(_id)); return undefined; }
	return {
		snd: _d.snd,
		loopStart: _d[$ "loopStart"] ?? 0,
		loopEnd: _d[$ "loopEnd"] ?? 0,
		volume: _d[$ "volume"] ?? 1,
		pitch: _d[$ "pitch"] ?? 1,
		loop: _d[$ "loop"] ?? true,
		bpm: _d[$ "bpm"] ?? 0,
		beats: _d[$ "beats"] ?? 4,
		beatOffset: _d[$ "beatOffset"] ?? 0,
		resume: _d[$ "resume"] ?? false
	};
}

// ======================= API =======================
function music_boot() { if (!instance_exists(obj_music)) instance_create_depth(0, 0, -100000, obj_music); }

// The one function. _id = a song id from global.music, or a sound asset.
function music_play(_id, _o = {})
{
	music_boot();
	var _ok = false;
	with (obj_music) _ok = music_request(_id, _o);
	return _ok;
}

function music_stop(_frames = undefined)
{
	music_boot();
	with (obj_music) stop_all(_frames ?? global.musicFade);
}

function music_unlock() { if (instance_exists(obj_music) && obj_music.cur != undefined) obj_music.cur.lock = false; }
function music_set_area(_name) { global.musicArea = _name; }
function music_now() { return (instance_exists(obj_music) && obj_music.cur != undefined) ? obj_music.cur.song : ""; }
function music_apply() { if (instance_exists(obj_music)) with (obj_music) apply_volumes(); }   // call after the Music slider changes

function music_item(_item)   // an item was obtained: checks the item rules
{
	if (_item == undefined) return;
	music_boot();
	with (obj_music) item_event(_item);
}