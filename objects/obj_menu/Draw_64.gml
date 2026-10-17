if (!open) exit;

var _gw = display_get_gui_width();
var _gh = display_get_gui_height();
var _u  = _gh / 270;            // 1 unit = 1 pixel on a 270p layout
var _ts = _u * textScale;
var _a  = openAnim;

// Backdrop: the frozen game, dimmed
if (sprite_exists(bg)) draw_sprite_stretched(bg, 0, 0, 0, _gw, _gh);
draw_set_colour(c_black);
draw_set_alpha(0.7 * _a);
draw_rectangle(0, 0, _gw, _gh, false);
draw_set_alpha(_a);

var _items = menu_items();
var _level = array_length(stack) - 1;
var _sel   = cursor[_level];

// Title (breadcrumb)
var _title = "";
for (var i = 1; i < array_length(stack); i++) _title += (i > 1 ? " > " : "") + tr(stack[i].label);
if (_title == "") _title = ingame ? tr("Paused") : tr(stack[0].label);

var _pw  = 260 * _u;
var _rh  = 24 * _u;
var _px  = _gw / 2 - _pw / 2;
var _top = _gh / 2 - (array_length(_items) * _rh) / 2 + 8 * _u;
var _vx  = _px + _pw - 12 * _u;   // right edge for values

draw_set_valign(fa_middle);
draw_set_halign(fa_center);
draw_set_colour(c_white);
draw_set_font(fnt_damage);
draw_text_transformed(_gw / 2, _top - 28 * _u, _title, _ts * 1.3, _ts * 1.3, 0);

for (var i = 0; i < array_length(_items); i++)
{
	var _row = _items[i];
	var _y   = _top + i * _rh + _rh / 2;
	var _on  = node_enabled(_row);
	var _hot = (i == _sel);
	var _col = !_on ? c_gray : (_hot ? c_yellow : c_white);

	if (_hot)
	{
		draw_set_colour(c_white);
		draw_set_alpha(0.12 * _a);
		draw_rectangle(_px, _y - _rh / 2, _px + _pw, _y + _rh / 2 - 2, false);
		draw_set_alpha(_a);
	}

	draw_set_colour(_col);
	draw_set_halign(fa_left);
	draw_set_font(fnt_damage);
	draw_text_transformed(_px + 12 * _u, _y, (_hot ? "> " : "  ") + tr(_row.label), _ts, _ts, 0);

	draw_set_halign(fa_right);
	switch (_row.type)
	{
		case "menu":
			draw_set_font(fnt_damage);
			draw_text_transformed(_vx, _y, ">", _ts, _ts, 0);
			break;

		case "toggle":
			draw_set_font(fnt_damage);
			draw_text_transformed(_vx, _y, tr(_row.get() ? "On" : "Off"), _ts, _ts, 0);
			break;

		case "dropdown":
			draw_set_font(fnt_damage);
			draw_text_transformed(_vx, _y, tr(_row.options[_row.get()]) + ((_hot && _on) ? "  v" : ""), _ts, _ts, 0);
			break;

		case "slider":
			var _v  = _row.get();
			var _bw = 70 * _u;
			var _bx = _vx - 40 * _u - _bw;
			draw_set_font(fnt_damage);
			draw_text_transformed(_vx, _y, string(round(_v * 100)) + "%", _ts, _ts, 0);
			draw_set_colour(c_dkgray);
			draw_rectangle(_bx, _y - 2 * _u, _bx + _bw, _y + 2 * _u, false);
			draw_set_colour(_col);
			draw_rectangle(_bx, _y - 2 * _u, _bx + _bw * _v, _y + 2 * _u, false);
			break;

		case "rebind":
			var _kw = 54 * _u;
			for (var s = 0; s < 2; s++)
			{
				var _kx  = _vx - _kw - (s == 0 ? _kw + 4 * _u : 0);
				var _cur = (_hot && _row.slot == s);
				draw_set_colour(_cur ? c_yellow : c_gray);
				draw_rectangle(_kx, _y - 8 * _u, _kx + _kw, _y + 8 * _u, true);
				draw_set_halign(fa_center);
				draw_set_font(fnt_damage);
				draw_text_transformed(_kx + _kw / 2, _y, (_cur && rebinding) ? "..." : key_name(global.binds[$ _row.action][s]), _ts * 0.85, _ts * 0.85, 0);
			}
			draw_set_halign(fa_right);
			break;
	}
}

// Open dropdown list, drawn on top
if (dropOpen)
{
	var _di = _items[_sel];
	var _dn = array_length(_di.options);
	var _dw = 90 * _u;
	var _dx = _vx - _dw;
	var _dy = _top + _sel * _rh + _rh;

	draw_set_colour(c_black);
	draw_set_alpha(0.92 * _a);
	draw_rectangle(_dx, _dy, _dx + _dw, _dy + _dn * _rh, false);
	draw_set_alpha(_a);
	draw_set_colour(c_white);
	draw_rectangle(_dx, _dy, _dx + _dw, _dy + _dn * _rh, true);

	draw_set_halign(fa_left);
	for (var o = 0; o < _dn; o++)
	{
		draw_set_colour(o == dropIndex ? c_yellow : c_white);
		draw_set_font(fnt_damage);
		draw_text_transformed(_dx + 10 * _u, _dy + o * _rh + _rh / 2, (o == dropIndex ? "> " : "  ") + tr(_di.options[o]), _ts, _ts, 0);
	}
}

// Footer
draw_set_halign(fa_center);
draw_set_colour(c_gray);
draw_set_font(fnt_damage);
draw_text_transformed(_gw / 2, _gh - 14 * _u,
	rebinding ? "Press a key (Esc to cancel)" : "Up/Down: select    Left/Right: adjust    Enter: confirm    Shift: back",
	_ts * 0.8, _ts * 0.8, 0);

draw_set_alpha(1);
draw_set_colour(c_white);
draw_set_halign(fa_left);
draw_set_valign(fa_top);
draw_set_font(fnt_default);