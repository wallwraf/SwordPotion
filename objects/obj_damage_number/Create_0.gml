depth = -10000;
phase = 0;
timer = 0;
alpha = 1;

grav = 0.22;
bounce = 0.45;
hv = random_range(0.5, 1.2) * choose (-1, 1) * (chip ? 0.7 : 1);
vv = chip ? random_range(-2.6, -1.8) : random_range(-3.6, -2.8);

ys = 0.5;
holdTime = SEC * 0.8;
fadeTime = SEC * 0.4;