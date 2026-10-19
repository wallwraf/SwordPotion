#macro SLOPE_UP 3     // tallest rise (pixels) you can climb in one pixel of movement
#macro SLOPE_DOWN 4   // how far you stay glued to the ground when going downhill

// Moves _mx pixels horizontally with collision. If _canClimb, rises over slopes and small steps.
// Returns false if something stopped the move.
function move_x_slope(_mx, _canClimb)
{
	var _s = sign(_mx);
	repeat (abs(_mx))
	{
		if (!place_meeting(x + _s, y, obj_col)) { x += _s; continue; }

		var _climbed = false;
		if (_canClimb)
		{
			for (var k = 1; k <= SLOPE_UP; k++)
			{
				if (!place_meeting(x + _s, y - k, obj_col)) { x += _s; y -= k; _climbed = true; break; }
			}
		}
		if (!_climbed) return false;
	}
	return true;
}

// If there's ground within _maxDrop pixels below and none directly underneath, drop onto it
function snap_down(_maxDrop)
{
	if (place_meeting(x, y + 1, obj_col)) return false;
	for (var k = 1; k <= _maxDrop; k++)
		if (place_meeting(x, y + k + 1, obj_col)) { y += k; return true; }
	return false;
}

// True only for a real wall: blocked ahead even after stepping up as far as you can climb
function wall_ahead(_dir, _dist = 2)
{
	return place_meeting(x + _dir * _dist, y, obj_col) && place_meeting(x + _dir * _dist, y - SLOPE_UP, obj_col);
}