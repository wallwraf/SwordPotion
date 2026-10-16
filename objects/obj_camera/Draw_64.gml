if (instance_exists(obj_player))
{
	var _cam = view_camera[0];
	
	// How many GUI pixels per world pixel
	var _s = display_get_gui_width() / camera_get_view_width(_cam);
	
	// World Pos -> GUI Pos
	var _gx = (obj_player.x - camera_get_view_x(_cam)) * _s;
	var _gy = (obj_player.y - camera_get_view_y(_cam)) * _s;
	
	with (obj_player) draw_hp_bar(_gx, _gy, _s);
}