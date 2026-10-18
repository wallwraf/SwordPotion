var _t = age / life;
draw_set_colour(col);
draw_set_alpha(1 - _t);

switch (kind)
{
	case "line":   // slash: sweeps out, then thins
		var _p = min(1, _t * 3);
		draw_line_width(x1, y1, lerp(x1, x2, _p), lerp(y1, y2, _p), max(1, thick * (1 - _t)));
		break;

	case "beam":
		draw_line_width(x1, y1, x2, y2, max(1, thick * (1 - _t)));
		break;

	case "ring":
		draw_circle(x1, y1, lerp(r0, r1, _t), true);
		draw_circle(x1, y1, lerp(r0, r1, _t) - 1, true);
		break;

	case "arc":
		var _r = lerp(r0, r1, _t);
		var _end = a0 + sweep * min(1, _t * 2.5);
		var _steps = max(2, ceil(abs(_end - a0) / 6));
		draw_primitive_begin(pr_trianglestrip);
		for (var i = 0; i <= _steps; i++)
		{
			var _a = lerp(a0, _end, i / _steps);
			draw_vertex_colour(x1 + lengthdir_x(_r - thick / 2, _a), y1 + lengthdir_y(_r - thick / 2, _a), col, 1 - _t);
			draw_vertex_colour(x1 + lengthdir_x(_r + thick / 2, _a), y1 + lengthdir_y(_r + thick / 2, _a), col, 1 - _t);
		}
		draw_primitive_end();
		break;
}

draw_set_alpha(1);
draw_set_colour(c_white);