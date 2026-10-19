if (capture)
{
	capture = false;
	bg = sprite_create_from_surface(application_surface, 0, 0,
		surface_get_width(application_surface), surface_get_height(application_surface), false, false, 0, 0);
	instance_deactivate_all(true);
	instance_activate_object(obj_player);   // the book reads and edits the player (its Step is frozen by global.paused)
	instance_activate_object(obj_music);   // the music keeps running while the game is paused
	global.paused = true;
	phase = 1;
	slideT = 0;
	openT = 0;
	focus = 0;
	onList = true;
	onFilter = false;
	listSel = 0;
	listScroll = 0;
	tileFocus = 0;
	msg = "";
	msgT = 0;
	io_clear();
}