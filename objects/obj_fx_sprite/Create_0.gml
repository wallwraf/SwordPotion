sprite_index = spr;
image_index = 0;
image_speed = 0;
image_xscale = scl * (flip ? -1 : 1);
image_yscale = scl;
image_angle = ang;
if (life <= 0) life = sprite_get_number(spr) / max(0.01, spd);
age = 0;