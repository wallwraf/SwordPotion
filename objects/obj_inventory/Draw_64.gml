if (phase == 0) exit;

var _W = display_get_gui_width();
var _H = display_get_gui_height();

if (sprite_exists(bg)) draw_sprite_stretched(bg, 0, 0, 0, _W, _H);
draw_set_colour(c_black);
draw_set_alpha(0.6 * clamp(slideT * 1.5, 0, 1));
draw_rectangle(0, 0, _W, _H, false);
draw_set_alpha(1);

draw_book();

if (phase == 3 && array_length(tiles) > 0)
{
	draw_pages();
	draw_tooltip();
}

draw_set_alpha(1);
draw_set_colour(c_white);
draw_set_halign(fa_left);
draw_set_valign(fa_top);
draw_set_font(-1);