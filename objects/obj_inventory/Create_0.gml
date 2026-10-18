// ---- Config
bookSpr = INV_SPRITE;
scale = 2.25;
animSpeed = 0.25;    // book frames per step while opening/closing
slideSpeed = 0.06;
txtScale = 0.5;      // text size relative to scale
tipW = 150;          // tooltip width (book units)

// ---- State
phase = 0;           // 0 closed, 1 slide in, 2 opening, 3 open, 4 closing, 5 slide out
capture = false;
bg = -1;
slideT = 0;
frame = 0;           // 0-2 opening, 3 open, 4-6 page turn (reserved for when there are multiple pages)
focus = 0;
msg = "";
msgT = 0;
slots = [];
cx = 0; cy = 0;
bookX = 0; bookY = 0;
lay = {};

function focus_item()
{
	var _f = slots[focus];
	var _p = obj_player;
	switch (_f.kind)
	{
		case "inv":   return _p.invItems[_f.idx];
		case "act":   return _p.actItems[_f.idx];
		case "equip": return _p.equipment[$ _f.idx];
	}
	return undefined;
}

function layout()
{
	var _s  = scale;
	var _sw = sprite_get_width(bookSpr);
	var _sh = sprite_get_height(bookSpr);
	bookX = cx - _sw * _s / 2;
	bookY = cy - _sh * _s / 2;
	slots = [];

	// left page: inventory grid
	var _g  = inv_grid();
	var _pl = global.invPageL;
	var _lw = (_pl[2] - _pl[0]) * _sw, _lh = (_pl[3] - _pl[1]) * _sh;
	var _gw = _g.cols * INV_TILE + (_g.cols - 1) * INV_GAP;
	var _gh = _g.rows * INV_TILE + (_g.rows - 1) * INV_GAP;
	var _gx = _pl[0] * _sw + (_lw - _gw) / 2;
	var _gy = _pl[1] * _sh + (_lh - _gh) / 2;
	for (var r = 0; r < _g.rows; r++)
		for (var c = 0; c < _g.cols; c++)
			array_push(slots, { kind: "inv", idx: r * _g.cols + c,
				x: bookX + (_gx + c * (INV_TILE + INV_GAP)) * _s, y: bookY + (_gy + r * (INV_TILE + INV_GAP)) * _s,
				w: INV_TILE * _s, h: INV_TILE * _s });

	// right page: actions on the left, equipment on the right, stats below
	var _pr = global.invPageR;
	var _rx = _pr[0] * _sw, _ry = _pr[1] * _sh;
	var _rw = (_pr[2] - _pr[0]) * _sw, _rh = (_pr[3] - _pr[1]) * _sh;

	var _lineH = string_height("A") * txtScale + 2;
	var _need  = 6 * INV_TILE + 5 * INV_GAP + 14 + (1 + array_length(global.statDisplay) + 4) * _lineH;
	var _fit   = min(1, _rh / _need);   // shrinks only if the page is too short
	var _t  = INV_TILE * _fit;
	var _gp = INV_GAP * _fit;
	var _x0 = _rx + (_rw - (2 * _t + 2 * _gp)) / 2;
	var _keys = ["helmet", "body", "legs", "acc1", "acc2", "weapon"];

	for (var i = 0; i < 6; i++)
		array_push(slots, { kind: "act", idx: i, x: bookX + _x0 * _s, y: bookY + (_ry + i * (_t + _gp)) * _s, w: _t * _s, h: _t * _s });
	for (var i = 0; i < 6; i++)
		array_push(slots, { kind: "equip", idx: _keys[i], x: bookX + (_x0 + _t + 2 * _gp) * _s, y: bookY + (_ry + i * (_t + _gp)) * _s, w: _t * _s, h: _t * _s });

	var _below = _ry + 6 * _t + 5 * _gp;
	lay = {
		lineH: _lineH,
		divY: bookY + (_below + 7 * _fit) * _s,
		statX: bookX + (_rx + 4) * _s,
		statY: bookY + (_below + 14 * _fit) * _s,
		left: bookX + _rx * _s, right: bookX + (_rx + _rw) * _s,
		bottom: bookY + (_ry + _rh) * _s
	};
	focus = clamp(focus, 0, array_length(slots) - 1);
}

// Move the focus to the nearest slot in a direction
function nav(_dx, _dy)
{
	var _f = slots[focus];
	var _fx = _f.x + _f.w / 2, _fy = _f.y + _f.h / 2;
	var _best = -1, _bs = infinity;
	for (var i = 0; i < array_length(slots); i++)
	{
		if (i == focus) continue;
		var _o = slots[i];
		var _rx = _o.x + _o.w / 2 - _fx;
		var _ry = _o.y + _o.h / 2 - _fy;
		var _fwd = _rx * _dx + _ry * _dy;
		if (_fwd <= 1) continue;
		var _lat = abs(_rx * _dy - _ry * _dx);
		if (_lat > _fwd * 1.5 + 8 * scale) continue;
		var _score = _fwd + _lat * 2.5;
		if (_score < _bs) { _bs = _score; _best = i; }
	}
	if (_best >= 0) focus = _best;
}

function activate_focus()
{
	var _f = slots[focus];
	var _p = obj_player;
	msg = (_f.kind == "inv") ? _p.inv_activate(_f.idx) : _p.inv_unequip(_f.kind, _f.idx);
	msgT = 120;
}

// Equipment after pressing select on the focused slot (for the stat preview), or undefined
function preview_equipment()
{
	var _f = slots[focus];
	var _p = obj_player;
	var _eq = {};
	var _n = variable_struct_get_names(_p.equipment);
	for (var i = 0; i < array_length(_n); i++) _eq[$ _n[i]] = _p.equipment[$ _n[i]];

	if (_f.kind == "inv")
	{
		var _it = _p.invItems[_f.idx];
		if (_it == undefined) return undefined;
		var _key = _p.equip_key_for(item_def(_it));
		if (_key == "") return undefined;
		_eq[$ _key] = _it;
		return _eq;
	}
	if (_f.kind == "equip" && _p.equipment[$ _f.idx] != undefined)
	{
		_eq[$ _f.idx] = undefined;
		return _eq;
	}
	return undefined;
}

function close_finish()
{
	phase = 0;
	global.paused = false;
	if (sprite_exists(bg)) { sprite_delete(bg); bg = -1; }
	instance_activate_all();
	io_clear();
}

// ---- Drawing
function draw_slot_tile(_sl, _it, _label)
{
	var _ts = scale * txtScale;
	draw_set_colour(make_colour_rgb(110, 70, 40));
	draw_set_alpha(0.22);
	draw_rectangle(_sl.x, _sl.y, _sl.x + _sl.w - 1, _sl.y + _sl.h - 1, false);
	draw_set_alpha(0.55);
	draw_rectangle(_sl.x, _sl.y, _sl.x + _sl.w - 1, _sl.y + _sl.h - 1, true);

	if (_it != undefined)
	{
		draw_set_alpha(1);
		item_draw_icon(_it, _sl.x, _sl.y, _sl.w, _ts * 1.6);
	}
	else if (_label != "")
	{
		draw_set_halign(fa_center);
		draw_set_valign(fa_middle);
		draw_set_alpha(0.5);
		draw_set_font(fnt_3x6);
		draw_text_transformed(_sl.x + _sl.w / 2, _sl.y + _sl.h / 2, _label, _ts * 0.8, _ts * 0.8, 0);
		draw_set_font(fnt_default);
	}
	draw_set_alpha(1);
}

function draw_focus_frame(_sl)
{
	var _pulse = 0.75 + 0.25 * sin(current_time * 0.012);
	draw_set_colour(make_colour_rgb(45, 22, 15));
	draw_set_alpha(_pulse);
	for (var k = 0; k < max(2, scale * 1.5); k++)
		draw_rectangle(_sl.x - k - 2, _sl.y - k - 2, _sl.x + _sl.w + k + 1, _sl.y + _sl.h + k + 1, true);
	draw_set_alpha(1);
}

function draw_stats()
{
	var _p  = obj_player;
	var _ts = scale * txtScale;
	var _lh = lay.lineH * scale;
	var _good = make_colour_rgb(30, 150, 50);
	var _bad  = make_colour_rgb(200, 40, 40);

	var _now = stats_for(_p.equipment, _p.baseStats);
	var _eq  = preview_equipment();
	var _aft = (_eq != undefined) ? stats_for(_eq, _p.baseStats) : undefined;

	draw_set_halign(fa_left);
	draw_set_valign(fa_top);

	// divider
	draw_set_colour(make_colour_rgb(90, 55, 35));
	draw_line_width(lay.left, lay.divY, lay.right, lay.divY, max(1, scale));

	var _y = lay.statY;
	draw_set_colour(c_black);
	draw_set_font(fnt_damage);
	draw_text_transformed(lay.statX, _y, "HP: " + string(_p.hp) + "/" + string(_p.hpMax), _ts, _ts, 0);
	draw_set_font(fnt_default);
	_y += _lh;

	for (var i = 0; i < array_length(global.statDisplay); i++)
	{
		var _k   = global.statDisplay[i][0];
		var _cur = _now.stats[$ _k] ?? 0;
		var _txt = global.statDisplay[i][1] + ": " + string(_cur);
		draw_set_colour(c_black);
		draw_set_font(fnt_damage);
		draw_text_transformed(lay.statX, _y, _txt, _ts, _ts, 0);
		if (_aft != undefined)
		{
			var _d = (_aft.stats[$ _k] ?? 0) - _cur;
			if (_d != 0)
			{
				draw_set_colour(_d > 0 ? _good : _bad);
				draw_set_font(fnt_damage);
				draw_text_transformed(lay.statX + string_width(_txt + " ") * _ts, _y, ((_d > 0) ? "+" : "") + string(_d), _ts, _ts, 0);
				draw_set_font(fnt_default);
			}
		}
		_y += _lh;
		draw_set_font(fnt_default);
	}

	// damage-type bonuses, only the ones that are non-zero or about to change
	for (var t = 0; t < array_length(global.damageTypes); t++)
	{
		if (_y + _lh > lay.bottom) break;
		var _c = _now.typeBonus[t];
		var _a = (_aft != undefined) ? _aft.typeBonus[t] : _c;
		if (_c == 0 && _a == _c) continue;
		var _txt2 = global.damageNames[t] + ": " + ((_c >= 0) ? "+" : "") + string(_c);
		draw_set_colour(c_black);
		draw_set_font(fnt_damage);
		draw_text_transformed(lay.statX, _y, _txt2, _ts, _ts, 0);
		if (_a != _c)
		{
			draw_set_colour((_a - _c) > 0 ? _good : _bad);
			draw_set_font(fnt_damage);
			draw_text_transformed(lay.statX + string_width(_txt2 + " ") * _ts, _y, (((_a - _c) > 0) ? "+" : "") + string(_a - _c), _ts, _ts, 0);
			draw_set_font(fnt_default);
		}
		_y += _lh;
		draw_set_font(fnt_default);
	}
}

function draw_tooltip()
{
	var _f  = slots[focus];
	var _it = focus_item();
	var _L = [];
	var _foot = "";

	if (_it != undefined)
	{
		_L = item_tooltip(_it);
		_foot = (_f.kind == "inv") ? ((item_def(_it).slot == "consumable") ? "Z: use" : "Z: equip") : "Z: unequip";
	}
	else if (_f.kind != "inv")
	{
		var _name = (_f.kind == "act") ? "Act Slot " + string(_f.idx + 1) : global.equipLabels[$ _f.idx][1];
		array_push(_L, { text: _name, col: c_white, size: 1.1 });
		array_push(_L, { text: "Empty", col: c_gray, size: 0.85 });
	}
	else return;   // empty inventory tile: no tooltip

	if (msgT > 0 && msg != "") array_push(_L, { text: msg, col: make_colour_rgb(235, 70, 70), size: 0.9, gap: 4 });
	if (_foot != "") array_push(_L, { text: _foot, col: c_gray, size: 0.8, gap: 4 });

	var _ts = scale * txtScale;
	var _w = tipW * scale;
	var _pad = 6 * scale;
	var _inner = _w - _pad * 2;

	var _h = _pad;
	for (var i = 0; i < array_length(_L); i++)
	{
		var _sz = _ts * _L[i].size;
		_h += (_L[i][$ "gap"] ?? 0) * scale + string_height_ext(_L[i].text, -1, _inner / _sz) * _sz + 2 * scale;
	}
	_h += _pad;

	// left of the book, else right, else overlapping the edge
	var _tx = bookX - _w - 14 * scale;
	if (_tx < 8) _tx = bookX + sprite_get_width(bookSpr) * scale + 14 * scale;
	if (_tx + _w > display_get_gui_width() - 8) _tx = 8;
	var _ty = clamp(bookY + 12 * scale, 8, display_get_gui_height() - _h - 8);

	draw_set_colour(c_black);
	draw_set_alpha(0.88);
	draw_rectangle(_tx, _ty, _tx + _w, _ty + _h, false);
	draw_set_alpha(1);
	draw_set_colour((_it != undefined) ? item_col(_it) : c_gray);
	draw_rectangle(_tx, _ty, _tx + _w, _ty + _h, true);

	draw_set_halign(fa_left);
	draw_set_valign(fa_top);
	var _y = _ty + _pad;
	for (var i = 0; i < array_length(_L); i++)
	{
		var _l = _L[i];
		var _sz = _ts * _l.size;
		_y += (_l[$ "gap"] ?? 0) * scale;
		draw_set_colour(_l.col);
		draw_set_font(fnt_damage);
		draw_text_ext_transformed(_tx + _pad, _y, _l.text, -1, _inner / _sz, _sz, _sz, 0);
		draw_set_font(fnt_default);
		_y += string_height_ext(_l.text, -1, _inner / _sz) * _sz + 2 * scale;
	}
}

function draw_pages()
{
	if (!variable_struct_exists(lay, "lineH") || array_length(slots) == 0)
	{
		layout();
	}
	
	var _p = obj_player;
	for (var i = 0; i < array_length(slots); i++)
	{
		var _sl = slots[i];
		var _it = undefined;
		var _lab = "";
		switch (_sl.kind)
		{
			case "inv":   _it = _p.invItems[_sl.idx]; break;
			case "act":   _it = _p.actItems[_sl.idx]; _lab = "ACT " + string(_sl.idx + 1); break;
			case "equip": _it = _p.equipment[$ _sl.idx]; _lab = global.equipLabels[$ _sl.idx][0]; break;
		}
		draw_slot_tile(_sl, _it, _lab);
	}
	
	var _slot_count = array_length(slots);
	if (_slot_count > 0)
    {
        // Keep focus within the array's valid bounds.
        focus = clamp(focus, 0, _slot_count - 1);

        draw_focus_frame(slots[focus]);
    }
	
	if (variable_struct_exists(lay, "lineH"))
	{
		draw_stats();
	}
}