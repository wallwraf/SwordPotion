if (capture)
{
	capture = false;
	bg = sprite_create_from_surface(application_surface, 0, 0,
		surface_get_width(application_surface), surface_get_height(application_surface), false, false, 0, 0);
	instance_deactivate_all(true);   // keeps this object running
	global.paused = true;
	open = true;
	openAnim = 0;
	stack = [root];
	reset_page();
	cursor = [0];
	io_clear();
}