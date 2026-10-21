draw_scarf();
draw_self();

if (global.hitbox)
{
	draw_set_colour(c_lime);
	draw_rectangle(bbox_left, bbox_top, bbox_right, bbox_bottom, true);
	draw_set_colour(c_red);
	draw_rectangle(x + facing * 4, y - 20, x + facing * 50, y + (sprite_height / 2) + 5, true);
	draw_set_colour(c_white);
}

// White Flash
if (flashTimer > 0)
{
	gpu_set_fog(true, c_white, 0, 1);
	draw_sprite_ext(sprite_index, image_index, x, y, image_xscale, image_yscale, image_angle, c_white, (flashTimer / flashDur) * 0.9);
	gpu_set_fog(false, c_white, 0, 1);
}

// Action Cursor
if (state == PlayerState.ACTION)
{
	draw_act_arrow();
	
	actDrawX = lerp(actDrawX, actCx, 0.3);
	actDrawY = lerp(actDrawY, actCy, 0.3);
	draw_circle(actDrawX, actDrawY, 10, true);
	
	if (actTarget != noone)
		draw_act_hud();
}