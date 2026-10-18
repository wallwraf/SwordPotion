var _W = display_get_gui_width();
var _H = display_get_gui_height();
var _u = _H / 270;
var _tl = _H * dtan(slabAngle) / 2;
var _slack = _tl + 20 * _u;
var _mv = 0.45, _gp = 0.11;

var _edge = [];
for (var j = 0; j <= 5; j++)
{
	var _pr = clamp((t - (5 - j) * _gp) / _mv, 0, 1);
	var _eq = (_pr < 0.5) ? 2 * _pr * _pr : 1 - power(-2 * _pr + 2, 2) / 2;
	_edge[j] = lerp(-_slack, _W + _slack, _eq);
}

// left to right: TINT BLACK GRAY BLACK TINT
var _cols = [tint, c_black, make_colour_rgb(205, 205, 210), c_black, tint];
for (var k = 0; k < 5; k++)
{
	if (_edge[k + 1] - _edge[k] < 0.5) continue;
	draw_primitive_begin(pr_trianglefan);
	draw_vertex_colour(_edge[k] + _tl, 0, _cols[k], 1);
	draw_vertex_colour(_edge[k + 1] + _tl, 0, _cols[k], 1);
	draw_vertex_colour(_edge[k + 1] - _tl, _H, _cols[k], 1);
	draw_vertex_colour(_edge[k] - _tl, _H, _cols[k], 1);
	draw_primitive_end();
}