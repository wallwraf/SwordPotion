var _ts = global.timeScale;
life -= _ts;
if (life <= 0) { instance_destroy(); exit; }

if (homing > 0 && instance_exists(target))
{
	var _cur  = point_direction(0, 0, hv, vv);
	var _want = point_direction(x, y, (target.bbox_left + target.bbox_right) / 2, (target.bbox_top + target.bbox_bottom) / 2);
	_cur += clamp(angle_difference(_want, _cur), -homing * _ts, homing * _ts);
	hv = lengthdir_x(spd, _cur);
	vv = lengthdir_y(spd, _cur);
}

vv += grav * _ts;
x += hv * _ts;
y += vv * _ts;

array_push(trail, [x, y]);
if (array_length(trail) > 8) array_delete(trail, 0, 1);

var _e = collision_circle(x, y, radius, obj_enemy, false, true);
if (_e != noone || collision_circle(x, y, radius, obj_col, true, true) != noone) impact(_e);