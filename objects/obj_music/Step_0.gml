// Rules read the world, so they freeze while a menu has it paused. The music itself keeps running.
if (!global.paused)
{
	in_combat_scan();
	eval_rules();
}

for (var i = array_length(dying) - 1; i >= 0; i--)
{
	if (current_time >= dying[i].t) { audio_stop_sound(dying[i].inst); array_delete(dying, i, 1); }
}

update_stingers();
update_cur();