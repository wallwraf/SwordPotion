draw_self();

if (flashTimer > 0)
{
	gpu_set_fog(true, c_white, 0, 1);
	draw_sprite_ext(sprite_index, image_index, x, y, image_xscale, image_yscale, image_angle, c_white, (flashTimer / flashDur) * 0.9);
	gpu_set_fog(false, c_white, 0, 1);
}

if (state_has(state)) states[state].draw();