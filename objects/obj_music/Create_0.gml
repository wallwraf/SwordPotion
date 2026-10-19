persistent = true;

cur = undefined;       // the song playing now
pending = undefined;   // a request waiting for its moment (at: "loop" or "bar")
queue = [];            // requests waiting behind the current song
dying = [];            // instances fading out, stopped when done
stingers = [];         // one-shots playing over the music
duckFactor = 1;        // how far the current song is ducked under stingers
memory = {};           // song -> position where it was last interrupted (for resume)

ruleIdx = -1;
seen = {};             // enemy object -> how long it counts as "in combat"
scanT = 0;
combat = false;
combatList = [];

// ---------- building and starting songs ----------
function build_request(_id, _o)
{
	var _d = music_def(_id);
	if (_d == undefined) return undefined;

	var _song = is_string(_id) ? _id : "snd" + string(_id);
	var _fade = _o[$ "fade"] ?? global.musicFade;
	var _stinger = _o[$ "stinger"] ?? false;
	var _resume = _o[$ "resume"] ?? _d.resume;

	return {
		song: _song, def: _d,
		fadeOut: _o[$ "fadeOut"] ?? _fade,
		fadeIn:  _o[$ "fadeIn"]  ?? _fade,
		at: _o[$ "at"] ?? "now",
		queue: _o[$ "queue"] ?? false,
		loops: max(1, _o[$ "loops"] ?? 1),
		loop: _stinger ? false : (_o[$ "loop"] ?? _d.loop),
		loopStart: _o[$ "loopStart"] ?? _d.loopStart,
		loopEnd: _o[$ "loopEnd"] ?? _d.loopEnd,
		gain: _d.volume * (_o[$ "volume"] ?? 1),
		pitch: _d.pitch * (_o[$ "pitch"] ?? 1),
		startAt: _o[$ "startAt"] ?? (_resume ? (memory[$ _song] ?? 0) : 0),
		priority: _o[$ "priority"] ?? 0,
		force: _o[$ "force"] ?? false,
		lock: _o[$ "lock"] ?? false,
		stinger: _stinger,
		duck: _o[$ "duck"] ?? 0.25,
		clear: _o[$ "clear"] ?? true,
		restart: _o[$ "restart"] ?? false,
		target: 0
	};
}

function start_song(_r)
{
	var _len = audio_sound_length(_r.def.snd);
	var _gain = _r.gain * global.settings.music * duckFactor;
	var _inst = audio_play_sound(_r.def.snd, 100, _r.loop, (_r.fadeIn > 0) ? 0 : _gain, _r.startAt, _r.pitch);

	var _hasEnd = (_r.loopEnd > 0 && _r.loopEnd < _len);
	if (_r.loop)
	{
		audio_sound_loop_start(_inst, _r.loopStart);
		if (_hasEnd) audio_sound_loop_end(_inst, _r.loopEnd);
	}
	if (_r.fadeIn > 0) audio_sound_gain(_inst, _gain, frames_to_ms(_r.fadeIn));

	return {
		song: _r.song, def: _r.def, inst: _inst, gain: _r.gain,
		loop: _r.loop, loops: _r.loops, loopsDone: 0,
		endT: (_r.loop && _hasEnd) ? _r.loopEnd : _len,
		priority: _r.priority, lock: _r.lock, lastPos: _r.startAt
	};
}

function retire(_inst, _frames)
{
	if (_frames <= 0) { audio_stop_sound(_inst); return; }
	var _ms = frames_to_ms(_frames);
	audio_sound_gain(_inst, 0, _ms);
	array_push(dying, { inst: _inst, t: current_time + _ms + 40 });
}

function transition_to(_r)
{
	if (cur != undefined)
	{
		memory[$ cur.song] = audio_sound_get_track_position(cur.inst);   // for resume
		retire(cur.inst, _r.fadeOut);
	}
	cur = start_song(_r);
}

function stop_all(_frames)
{
	if (cur != undefined)
	{
		memory[$ cur.song] = audio_sound_get_track_position(cur.inst);
		retire(cur.inst, _frames);
		cur = undefined;
	}
	pending = undefined;
	queue = [];
}

function apply_duck(_ms)
{
	if (cur != undefined) audio_sound_gain(cur.inst, cur.gain * global.settings.music * duckFactor, _ms);
}

function apply_volumes()
{
	apply_duck(0);
	for (var i = 0; i < array_length(stingers); i++) audio_sound_gain(stingers[i].inst, stingers[i].gain * global.settings.music, 0);
}

// ---------- the request entry point ----------
function music_request(_id, _o)
{
	var _req = build_request(_id, _o);
	if (_req == undefined) return false;

	if (_req.stinger) return play_stinger(_req);

	// asking for what's already playing leaves it alone (and cancels anything waiting)
	if (cur != undefined && cur.song == _req.song && !_req.restart && !_req.queue)
	{
		pending = undefined;
		if (_req.clear) queue = [];
		return false;
	}

	if (cur != undefined && !_req.queue)
	{
		if (cur.lock) return false;
		if (!_req.force && _req.priority < cur.priority) return false;
	}

	if (_req.queue)
	{
		if (cur == undefined) transition_to(_req);
		else array_push(queue, _req);
		return true;
	}

	if (_req.clear) queue = [];

	if (_req.at == "now" || cur == undefined)
	{
		pending = undefined;
		transition_to(_req);
	}
	else
	{
		pending = _req;
		if (_req.at == "bar" && cur.def.bpm > 0)
		{
			// the next bar line, measured from the song's beat offset
			var _bar = 60 / cur.def.bpm * cur.def.beats;
			var _off = cur.def.beatOffset;
			var _pos = audio_sound_get_track_position(cur.inst);
			pending.target = _off + ceil((_pos - _off) / _bar + 0.001) * _bar;
		}
	}
	return true;
}

// ---------- stingers: one-shots over the music ----------
function play_stinger(_req)
{
	var _gain = _req.gain * global.settings.music;
	var _inst = audio_play_sound(_req.def.snd, 100, false, _gain, _req.startAt, _req.pitch);
	array_push(stingers, { inst: _inst, gain: _req.gain, duck: _req.duck, fadeIn: _req.fadeIn });
	duckFactor = min(duckFactor, _req.duck);
	apply_duck(frames_to_ms(_req.fadeOut));
	return true;
}

function update_stingers()
{
	var _restore = -1;
	for (var i = array_length(stingers) - 1; i >= 0; i--)
	{
		if (!audio_is_playing(stingers[i].inst))
		{
			_restore = stingers[i].fadeIn;
			array_delete(stingers, i, 1);
		}
	}
	if (_restore < 0) return;

	duckFactor = 1;
	for (var i = 0; i < array_length(stingers); i++) duckFactor = min(duckFactor, stingers[i].duck);
	apply_duck(frames_to_ms(_restore));
}

// ---------- the current song: loops, queue, pending ----------
function cur_ended()
{
	cur = undefined;
	if (array_length(queue) > 0)
	{
		var _n = queue[0];
		array_delete(queue, 0, 1);
		transition_to(_n);
	}
	else if (pending != undefined)
	{
		var _p = pending;
		pending = undefined;
		transition_to(_p);
	}
}

function update_cur()
{
	if (cur == undefined) return;

	if (!audio_is_playing(cur.inst)) { cur_ended(); return; }   // a one-shot finished

	var _fps = game_get_speed(gamespeed_fps);
	var _pos = audio_sound_get_track_position(cur.inst);
	var _wrapped = cur.loop && (_pos < cur.lastPos - 0.05);
	if (_wrapped) cur.loopsDone++;
	cur.lastPos = _pos;
	var _rem = cur.endT - _pos;

	// a request waiting for the loop point or the next bar
	if (pending != undefined)
	{
		var _lead = frames_to_s(pending.fadeOut) + 1 / _fps;   // start early so the crossfade ends on the boundary
		var _fire;
		if (pending.at == "bar" && cur.def.bpm > 0) _fire = (_pos >= pending.target - _lead) || _wrapped || (_rem <= _lead);
		else _fire = (_rem <= _lead) || _wrapped;
		if (_fire)
		{
			var _r = pending;
			pending = undefined;
			transition_to(_r);
			return;
		}
	}

	// the queue waits for the final loop pass to reach its end
	if (array_length(queue) > 0)
	{
		var _next = queue[0];
		var _last = (!cur.loop) || (cur.loopsDone + 1 >= cur.loops);
		if (_last && _rem <= frames_to_s(_next.fadeOut) + 1 / _fps)
		{
			array_delete(queue, 0, 1);
			transition_to(_next);
		}
	}
}

// ---------- rules ----------
function in_combat_scan()
{
	scanT--;
	if (scanT > 0) return;
	scanT = 6;

	var _grace = global.musicCombatGrace * game_get_speed(gamespeed_fps);
	var _keys = variable_struct_get_names(seen);
	for (var i = 0; i < array_length(_keys); i++) seen[$ _keys[i]].t -= 6;

	with (obj_enemy)
		if (in_combat()) other.seen[$ string(object_index)] = { obj: object_index, t: _grace };

	combat = false;
	combatList = [];
	_keys = variable_struct_get_names(seen);
	for (var i = 0; i < array_length(_keys); i++)
	{
		var _e = seen[$ _keys[i]];
		if (_e.t > 0) { combat = true; array_push(combatList, _e.obj); }
	}
}

function rule_active(_r)
{
	switch (_r.trigger)
	{
		case "room":   return match_any(_r.room, room);
		case "area":   return match_any(_r.area, global.musicArea);
		case "combat": return combat;
		case "enemy":
			for (var i = 0; i < array_length(combatList); i++)
				if (match_enemy(_r.enemy, combatList[i])) return true;
			return false;
	}
	return false;   // item rules are events, see item_event
}

function eval_rules()
{
	var _best = -1;
	var _bp = -1000000;
	for (var i = 0; i < array_length(global.musicRules); i++)
	{
		var _r = global.musicRules[i];
		if (!rule_active(_r)) continue;
		var _p = _r[$ "priority"] ?? 0;
		if (_p >= _bp) { _bp = _p; _best = i; }
	}

	if (_best == ruleIdx) return;       // only react when the circumstances change
	ruleIdx = _best;

	if (_best < 0)
	{
		if (global.musicSilenceWhenNone) stop_all(global.musicFade);
		return;
	}
	var _rule = global.musicRules[_best];
	music_request(_rule.song, struct_merge(_rule[$ "opts"] ?? {}, { force: true }));
}

function item_event(_item)
{
	var _best = -1;
	var _bp = -1000000;
	for (var i = 0; i < array_length(global.musicRules); i++)
	{
		var _r = global.musicRules[i];
		if (_r.trigger != "item") continue;

		var _ok = false;
		if (_r[$ "item"]   != undefined) _ok = _ok || match_any(_r.item, _item.id);
		if (_r[$ "rarity"] != undefined) _ok = _ok || match_any(_r.rarity, _item.rarity);
		if (_r[$ "match"]  != undefined) _ok = _ok || _r.match(_item);   // a function(item) returning true or false
		if (!_ok) continue;

		var _p = _r[$ "priority"] ?? 0;
		if (_p >= _bp) { _bp = _p; _best = i; }
	}
	if (_best < 0) return;
	var _rule = global.musicRules[_best];
	music_request(_rule.song, struct_merge({ stinger: true }, _rule[$ "opts"] ?? {}));
}