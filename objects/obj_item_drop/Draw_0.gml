// Draw
var _by = y - 14 + sin(age * 0.08 + bob) * 2;
var _pulse = 0.5 + 0.5 * sin(age * 0.1 + bob);
draw_set_colour(col);
draw_set_alpha(0.18 + 0.12 * _pulse);
draw_circle(x, _by, 13 + _pulse * 2, false);
draw_set_alpha(1);
item_draw_icon(item, x - 8, _by - 8, 16, 0.5);
draw_set_colour(c_white);
draw_set_halign(fa_left);
draw_set_valign(fa_top);