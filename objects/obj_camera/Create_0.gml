cam = view_camera[0]
camW = camera_get_view_width(cam);
camH = camera_get_view_height(cam);

target = obj_player;

followSpeed = 0.12;
lookAhead = 40;
lookSpeed = 0.05;
lookOffset = 0;

global.shake = 0;
shakeDecay = 0.85;

display_set_gui_size(camera_get_view_width(view_camera[0]), camera_get_view_height(view_camera[0]));

if (instance_exists(target))
{
	camX = target.x - camW / 2;
	camY = target.y - camH / 2;
}
else
{
	camX = 0;
	camY = 0;
}