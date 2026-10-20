var _ts = global.timeScale;    // slows with the world, so bullet time slows the sparks too
for (var i = array_length(parts) - 1; i >= 0; i--)
{
	var _p = parts[i];
	_p.age += _ts;
	if (_p.age >= _p.life) { array_delete(parts, i, 1); continue; }
	var _d = power(_p.drag, _ts);
	_p.hv *= _d;
	_p.vv = _p.vv * _d + _p.grav * _ts;
	_p.x += _p.hv * _ts;
	_p.y += _p.vv * _ts;
}
for (var i = array_length(flashes) - 1; i >= 0; i--)
{
	flashes[i].age += _ts;
	if (flashes[i].age >= flashes[i].life) array_delete(flashes, i, 1);
}