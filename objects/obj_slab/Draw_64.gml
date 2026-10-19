var _W = display_get_gui_width();
var _H = display_get_gui_height();
var _u = _H / 270;
var _tl = _H * dtan(slabAngle) / 2;
var _slack = _tl + 20 * _u;

// Pause-menu swipes are clipped to the panel and travel only across it
var _c0 = 1000000, _ck = 0, _range = _W;
if (panel && instance_exists(obj_menu))
{
	_c0 = obj_menu.clipX0;
	_ck = obj_menu.clipK;
	_range = max(_c0, _c0 + _ck * _H);
}

var _mv = 0.45, _gp = 0.11;
var _edge = [];
for (var j = 0; j <= 5; j++)
{
	var _pr = clamp((t - (5 - j) * _gp) / _mv, 0, 1);
	var _eq = (_pr < 0.5) ? 2 * _pr * _pr : 1 - power(-2 * _pr + 2, 2) / 2;
	_edge[j] = lerp(-_slack, _range + _slack, _eq);
}

var _cols = [tint, c_black, make_colour_rgb(205, 205, 210), c_black, tintCur];
for (var k = 0; k < 5; k++)
{
	if (_edge[k + 1] - _edge[k] < 0.5) continue;
	var _pts = clip_poly([_edge[k] + _tl, 0, _edge[k + 1] + _tl, 0, _edge[k + 1] - _tl, _H, _edge[k] - _tl, _H], _c0, _ck);
	var _n = array_length(_pts) div 2;
	if (_n < 3) continue;
	draw_primitive_begin(pr_trianglefan);
	for (var i = 0; i < _n; i++) draw_vertex_colour(_pts[i * 2], _pts[i * 2 + 1], _cols[k], 1);
	draw_primitive_end();
}