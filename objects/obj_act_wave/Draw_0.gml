draw_set_colour(col);
draw_set_alpha(clamp(life / 12, 0, 1));
draw_triangle(x - dir * 16, y, x + dir * 6, y, x + dir * 2, y - h, false);
draw_set_alpha(1);
draw_set_colour(c_white);