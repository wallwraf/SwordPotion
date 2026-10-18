for (var i = 0; i < array_length(trail); i++)
{
	var _f = (i + 1) / array_length(trail);
	draw_set_colour(col);
	draw_set_alpha(_f * 0.5);
	draw_circle(trail[i][0], trail[i][1], radius * _f, false);
}
draw_set_alpha(1);
draw_set_colour(col);
draw_circle(x, y, radius, false);
draw_set_colour(c_white);
draw_circle(x, y, radius * 0.5, false);