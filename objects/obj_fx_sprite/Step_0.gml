age += global.timeScale;
image_index = min(sprite_get_number(spr) - 1, age * spd);
if (follow != noone && instance_exists(follow)) { x = follow.x + fox; y = follow.y + foy; }
if (age >= life) instance_destroy();