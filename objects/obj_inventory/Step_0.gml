if (phase == 0)
{
	if (!capture && input_pressed("inventory") && instance_exists(obj_player) && obj_player.state != PlayerState.DEAD
		&& !global.paused && !instance_exists(obj_slab)) capture = true;
	exit;
}

var _g = inv_geometry();
var _H = display_get_gui_height();
cx = display_get_gui_width() / 2;
var _off = _H + _g.bookH * scale / 2 + 20;
cy = lerp(_off, _H / 2, 1 - power(1 - slideT, 3));
bookTop = cy - _g.bookH * scale / 2;

// While opening, the spine slides so the closed cover and the open book are both centred
var _oe = openT * openT * (3 - 2 * openT);
spineX = cx - (1 - _oe) * _g.halfW * scale / 2;

switch (phase)
{
	case 1:   // slide up from the bottom, cover closed
		slideT = min(1, slideT + slideSpeed);
		if (slideT >= 1) phase = 2;
		break;

	case 2:   // the cover swings open
		openT = min(1, openT + openSpeed);
		if (openT >= 1) { phase = 3; layout(); }
		break;

	case 3:   // open
		if (msgT > 0) msgT--;
		layout();

		if (input_pressed("inventory") || keyboard_check_pressed(vk_escape)) || input_pressed("run") { phase = 4; break; }

		var _dx = input_pressed("right") - input_pressed("left");
		var _dy = input_pressed("down")  - input_pressed("up");
		if (_dx != 0) nav(_dx, 0);
		else if (_dy != 0) nav(0, _dy);

		if (input_pressed("attack")) activate_focus();
		layout();
		break;

	case 4:   // closing: the same animation backwards
		openT = max(0, openT - openSpeed);
		if (openT <= 0) phase = 5;
		break;

	case 5:   // slide back down
		slideT = max(0, slideT - slideSpeed);
		if (slideT <= 0) close_finish();
		break;
}