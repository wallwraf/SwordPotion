var _ts = global.timeScale;
timer += _ts;

if (phase == 0)
{
	vv += grav * _ts;
	x += hv * _ts;
	y += vv * _ts;

	// Stretch while moving fast, relax toward 1 otherwise
	ys = lerp(ys, 1 + clamp(abs(vv) * 0.1, 0, 0.5), min(1, 0.3 * _ts));

	// Land on the virtual floor
	if (y >= floorY && vv > 0)
	{
		y = floorY;
		var _impact = vv;
		ys = max(0.45, 1 - _impact * 0.12);   // squash on landing
		hv *= 0.6;
		vv = -_impact * bounce;

		if (_impact < 1.2) { vv = 0; hv = 0; phase = 1; timer = 0; }   // done bouncing
	}
}
else
{
	ys = lerp(ys, 1, min(1, 0.3 * _ts));      // let the last squash recover

	if (phase == 1 && timer >= holdTime) { phase = 2; timer = 0; }
	else if (phase == 2)
	{
		alpha = 1 - timer / fadeTime;
		if (timer >= fadeTime) instance_destroy();
	}
}