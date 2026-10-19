if (capture)
{
	capture = false;
	bg = sprite_create_from_surface(application_surface, 0, 0,
		surface_get_width(application_surface), surface_get_height(application_surface), false, false, 0, 0);
	var _cam = view_camera[0];
	var _gw = display_get_gui_width(), _gh = display_get_gui_height();
	zoomPx = ((obj_player.bbox_left + obj_player.bbox_right) / 2 - camera_get_view_x(_cam)) / camera_get_view_width(_cam) * _gw;
	zoomPy = ((obj_player.bbox_top + obj_player.bbox_bottom) / 2 - camera_get_view_y(_cam)) / camera_get_view_height(_cam) * _gh;
	closing = false;
	instance_deactivate_all(true);   // keeps this object running
	instance_activate_object(obj_music);   // the music keeps running while the game is paused
	global.paused = true;
	open = true;
	openAnim = 0;
	stack = [root];
	reset_page();
	cursor = [0];
	io_clear();
}