var _ts = global.timeScale;
life -= _ts;
if (life <= 0 || collision_point(x + dir * 5, y - 4, obj_col, true, true) != noone) { instance_destroy(); exit; }

x += dir * spd * _ts;

var _list = ds_list_create();
var _n = collision_rectangle_list(x - 6, y - h, x + 6, y, obj_enemy, false, true, _list, false);
for (var i = 0; i < _n; i++)
{
	var _e = _list[| i];
	if (array_contains(hits, _e)) continue;
	array_push(hits, _e);
	_e.receive_hit(dmg, type, src, knock);
}
ds_list_destroy(_list);