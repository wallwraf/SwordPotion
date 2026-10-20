life = SEC * 3;
age = 0;
trailT = 0;
trail = [];

function impact(_e)
{
	if (_e != noone) _e.receive_hit(dmg, type, src, knock);

	if (splash > 0)
	{
		var _list = ds_list_create();
		var _n = collision_circle_list(x, y, splash, obj_enemy, false, true, _list, false);
		for (var i = 0; i < _n; i++)
		{
			var _o = _list[| i];
			if (_o != _e) _o.receive_hit(dmg * 0.6, type, src, knock);   // splash does 60%
		}
		ds_list_destroy(_list);
		act_fx("ring", { x1: x, y1: y, r0: 4, r1: splash, col: col, life: 14 });
		screen_shake(2);
	}
	if (art[$ "hit"] != undefined) art_play(art.hit, x, y);
	instance_destroy();
}