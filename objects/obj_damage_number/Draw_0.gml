var _s = chip ? 0.75 : 1;
var _str = string(amount);
var _x = round(x);
var _y = round(y);

draw_set_halign(fa_center);
draw_set_halign(fa_bottom);
draw_set_font(fnt_boldpixels);
draw_set_alpha(alpha);

// Outline the Text
if (gfx().numberOutline)
{
	draw_set_colour(c_black);
	for (var _dx = -1; _dx <= 1; _dx++)
		for (var _dy = -1; _dy <= 1; _dy++)
			if (_dx != 0 || _dy != 0)
				draw_text_transformed(_x + _dx, _y + _dy, _str, _s, _s * ys, 0);
}

draw_set_colour(col);
draw_text_transformed(_x, _y, _str, _s, _s * ys, 0);

draw_set_alpha(1);
draw_set_font(fnt_default);
draw_set_colour(c_white);
draw_set_halign(fa_left);
draw_set_valign(fa_top);