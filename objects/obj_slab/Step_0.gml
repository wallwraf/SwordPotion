t += 1 / dur;

// Midpoint: the screen is fully covered, so the page change or room change happens now
if (!swapped && t >= 0.5)
{
	swapped = true;
	if (instance_exists(obj_menu)) with (obj_menu) trans_swap(other.job);
}

show_debug_message(
    "Slab active: t = " + string(t)
);

if (t >= 1) instance_destroy();