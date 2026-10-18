// Step
var _ts = global.timeScale;
age += _ts;
msgCd = max(0, msgCd - _ts);

if (!solid_at(x, y + 1)) vv += 0.25 * _ts;
else { hv = approach(hv, 0, 0.06 * _ts); if (vv > 0) vv = 0; }

hRem += hv * _ts;
vRem += vv * _ts;
var _mx = round(hRem), _my = round(vRem);
hRem -= _mx; vRem -= _my;

repeat (abs(_mx))
{
	if (!solid_at(x + sign(_mx), y)) x += sign(_mx);
	else { hv *= -0.4; hRem = 0; break; }
}
repeat (abs(_my))
{
	if (!solid_at(x, y + sign(_my))) y += sign(_my);
	else
	{
		vv = (abs(vv) > 1.5) ? -vv * 0.35 : 0;   // small bounce on landing
		hv *= 0.7;
		vRem = 0;
		break;
	}
}

// Pickup: walk over it
if (age >= pickDelay)
{
	var _pl = collision_rectangle(x - 10, y - 18, x + 10, y, obj_player, false, true);
	if (_pl != noone)
	{
		if (_pl.inv_add(item))
		{
			with (_pl) show_number(item_name(other.item), item_col(other.item));   // floating name in the rarity colour
			instance_destroy();
		}
		else if (msgCd <= 0)
		{
			with (_pl) show_number("Inventory full", c_ltgray);
			msgCd = SEC * 2;
		}
	}
}