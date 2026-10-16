if (instance_exists(target))
{
	// Look Ahead
	lookOffset = lerp(lookOffset, target.facing * lookAhead, lookSpeed);
	
	var _goalX = target.x + lookOffset - camW / 2;
	var _goalY = target.y - camH / 2;
	
	// Smooth Follow
	camX = lerp(camX, _goalX, followSpeed);
	camY = lerp(camY, _goalY, followSpeed);
}

// Keep Inside Bounds
camX = clamp(camX, 0, room_width - camW);
camY = clamp(camY, 0, room_height - camH);

// camX / camY
var _ox = 0, _oy = 0;
if (global.shake > 0.1)
{
	_ox = random_range(-global.shake, global.shake);
	_oy = random_range(-global.shake, global.shake);
	global.shake *= shakeDecay;
}
else global.shake = 0;

camera_set_view_pos(cam, round(camX + _ox), round(camY + _oy));