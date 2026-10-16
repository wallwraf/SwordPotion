// Runs Once at Game Start
global.sfxVolume = 1;

/// @param {Asset.GMSound} _snd sound asset
/// @param {Real} [_gain] volume multiplier (default 1)
/// @param {Real} [_pitchVar] random pitch range, e.g. 0.1 +/-10% (default 0)
/// @param {Bool} [_overlap] allow it to play on top of itself (default false)
function sfx_play(_snd, _gain = 1, _pitchVar = 0, _overlap = false)
{
	// Already Playing?
	if (!_overlap && audio_is_playing(_snd)) return noone;
	
	var _pitch = (1 + random_range(-_pitchVar, _pitchVar)) * lerp(1, global.timeScale, 0.5);
	
	return audio_play_sound(_snd, 10, false, _gain * global.sfxVolume, 0, _pitch);
}

function sfx_stop(_snd)
{
	audio_stop_sound(_snd);
}