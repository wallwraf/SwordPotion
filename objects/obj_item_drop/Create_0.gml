// Create (item is passed in)
hv = random_range(-1.4, 1.4);
vv = random_range(-3.6, -2.6);
hRem = 0; vRem = 0;
age = 0;
pickDelay = 45;    // frames before it can be picked up
msgCd = 0;
bob = random(6.28);
col = item_col(item);

function solid_at(_x, _y) { return collision_rectangle(_x - 6, _y - 12, _x + 6, _y, obj_col, false, true) != noone; }