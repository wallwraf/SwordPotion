if (phase == 0) exit;

var _W = display_get_gui_width();
var _H = display_get_gui_height();

if (sprite_exists(bg)) draw_sprite_stretched(bg, 0, 0, 0, _W, _H);
draw_set_colour(c_black);
draw_set_alpha(0.6 * clamp(slideT * 1.5, 0, 1));
draw_rectangle(0, 0, _W, _H, false);
draw_set_alpha(1);

var _sw = sprite_get_width(bookSpr);
var _sh = sprite_get_height(bookSpr);
draw_sprite_ext(bookSpr, floor(frame),
	cx + (sprite_get_xoffset(bookSpr) - _sw / 2) * scale, cy + (sprite_get_yoffset(bookSpr) - _sh / 2) * scale,
	scale, scale, 0, c_white, 1);

if (phase == 3)
{
	draw_pages();
	draw_tooltip();
}

draw_set_alpha(1);
draw_set_colour(c_white);
draw_set_halign(fa_left);
draw_set_valign(fa_top);