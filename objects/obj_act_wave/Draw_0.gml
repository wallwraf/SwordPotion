if (spr != -1) draw_sprite_ext(spr, floor((45 - life) * 0.3) mod sprite_get_number(spr), x, y, dir, 1, 0, c_white, clamp(life / 12, 0, 1));
else
{
	draw_set_colour(col);
	draw_set_alpha(clamp(life / 12, 0, 1));
	draw_triangle(x - dir * 16, y, x + dir * 6, y, x + dir * 2, y - h, false);
	draw_set_alpha(1);
	draw_set_colour(c_white);
}