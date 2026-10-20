for (var i = 0; i < array_length(parts); i++)
{
	var _p = parts[i];
	var _t = _p.age / _p.life;
	var _n = array_length(_p.cols) - 1;
	var _ci = _t * _n;
	var _c0 = floor(_ci);
	var _col = merge_colour(_p.cols[_c0], _p.cols[min(_c0 + 1, _n)], _ci - _c0);
	var _s = max(1, round(_p.size * (1 - _t * _p.shrink)));
	var _px = floor(_p.x), _py = floor(_p.y);

	draw_set_colour(_col);
	draw_set_alpha(clamp((1 - _t) * 3, 0, 1));
	if (_p.shape == "streak") draw_line_width(_px, _py, floor(_p.x - _p.hv * 1.8), floor(_p.y - _p.vv * 1.8), _s);
	else draw_rectangle(_px, _py, _px + _s - 1, _py + _s - 1, false);
}
for (var i = 0; i < array_length(flashes); i++)
{
	var _f = flashes[i];
	var _t = _f.age / _f.life;
	var _r = round(_f.r * (0.35 + 0.65 * sqrt(_t)));
	draw_set_colour(_f.col);
	draw_set_alpha((1 - _t) * 0.85);
	draw_circle(floor(_f.x), floor(_f.y), _r, false);
	draw_set_colour(c_white);
	draw_set_alpha(1 - _t);
	draw_circle(floor(_f.x), floor(_f.y), _r * 0.55, false);
}
draw_set_alpha(1);
draw_set_colour(c_white);