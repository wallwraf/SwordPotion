if (phase == 0)
{
	if (!capture && input_pressed("inventory") && instance_exists(obj_player) && obj_player.state != PlayerState.DEAD
		&& !global.paused && !instance_exists(obj_slab)) capture = true;
	exit;
}

var _H = display_get_gui_height();
cx = display_get_gui_width() / 2;
var _off = _H + sprite_get_height(bookSpr) * scale / 2 + 20;
cy = lerp(_off, _H / 2, 1 - power(1 - slideT, 3));

switch (phase)
{
	case 1:
		slideT = min(1, slideT + slideSpeed);
		if (slideT >= 1) phase = 2;
		break;

	case 2:
		frame += animSpeed;
		if (frame >= 3) { frame = 3; phase = 3; layout(); }
		break;

	case 3:
		if (msgT > 0) msgT--;
		layout();

		if (input_pressed("inventory") || keyboard_check_pressed(vk_escape)) { phase = 4; break; }

		var _dx = input_pressed("right") - input_pressed("left");
		var _dy = input_pressed("down")  - input_pressed("up");
		if (_dx != 0) nav(_dx, 0);
		else if (_dy != 0) nav(0, _dy);

		if (input_pressed("attack")) activate_focus();
		layout();   // pick up scroll and selection changes from this frame
		break;

	case 4:
		frame -= animSpeed;
		if (frame <= 0) { frame = 0; phase = 5; }
		break;

	case 5:
		slideT = max(0, slideT - slideSpeed);
		if (slideT <= 0) close_finish();
		break;
}