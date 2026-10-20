if (!ready) exit;
if (!open) exit;

var _W  = display_get_gui_width();
var _H  = display_get_gui_height();
var _u  = _H / 270;
var _ts = _u * textScale;
var _lean = dtan(18);
var _pwFull = _W * panelCur;       // the panel's current, animated width
var _pwLay  = _W * panelTarget;    // the width buttons are laid out for
var _e = 1 - power(1 - openAnim, 3);          // the open/close ease
var _outS = clamp(openAnim * 2.5, 0, 1);      // buttons and title shrink away while closing

draw_set_font(fnt_notjammono);
if (ingame)
{
	var _pw = _pwFull * _e;

	draw_set_colour(c_black);
	draw_rectangle(0, 0, _W, _H, false);

	// Zoom the frozen game onto the player: they end up midway between the panel's edge and the screen's right edge
	if (sprite_exists(bg))
	{
		var _Z  = lerp(1, pauseZoom, _e);
		var _tx = lerp(zoomPx, (_pw + _W) / 2, _e);
		var _ty = lerp(zoomPy, _H * 0.5, _e);
		draw_sprite_ext(bg, 0, _tx - zoomPx * _Z, _ty - zoomPy * _Z,
			_Z * _W / sprite_get_width(bg), _Z * _H / sprite_get_height(bg), 0, c_white, 1);
	}
	draw_set_colour(c_black);
	draw_set_alpha(0.6 * openAnim);
	draw_rectangle(0, 0, _W, _H, false);
	draw_set_alpha(1);

	clipX0 = _pw - _lean * _H / 2;
	clipK = _lean;
}
else { clipX0 = 1000000; clipK = 0; }

// Screen kick
var _ks = 1 + 0.035 * kick;
matrix_set(matrix_world, matrix_build(_W / 2 * (1 - _ks), _H / 2 * (1 - _ks), 0, 0, 0, 0, _ks, _ks, 1));

draw_menu_bg(_W, _H, _u);

// Pause: bright slanted edge
if (ingame)
{
	var _e0 = clipX0, _e1 = clipX0 + clipK * _H;
	draw_poly([_e0, 0, _e0 + 5 * _u, 0, _e1 + 5 * _u, _H, _e1, _H], c_white, 1, false);
	draw_poly([_e0 + 5 * _u, 0, _e0 + 10 * _u, 0, _e1 + 10 * _u, _H, _e1 + 5 * _u, _H], c_black, 1, false);
}

var _items  = menu_items();
var _n      = array_length(_items);
var _level  = array_length(stack) - 1;
var _selI   = cursor[_level];
var _isRoot = (_level == 0);
var _wide   = page_wide();

// ---- Title (shrinks to fit the panel and stays clear of the top edge)
var _title = "";
if (_isRoot) _title = ingame ? "PAUSED" : global.gameTitle;
else for (var i = 1; i < array_length(stack); i++) _title += (i > 1 ? " > " : "") + string_upper(tr(stack[i].label));
var _tsc = (_isRoot && !ingame) ? 3.2 : 1.8;
var _x0 = ingame ? 26 * _u : _W * 0.09;

cOx = _x0 - 6 * _u;
cBw = 200 * _u;
cS = ease_out_back(clamp((pageAge + 10) / 16, 0, 1)) * _outS;

var _tw0 = string_width(_title) * _ts * _tsc;
var _maxTw = (ingame ? edge_at(_pwLay, _H * 0.18, _H) : _W) - cOx - 28 * _u;
if (_tw0 > _maxTw) _tsc *= _maxTw / _tw0;

var _tsz1 = _ts * _tsc;                       // title scale before the pop-in
var _th = string_height("A") * _tsz1;
var _tw = string_width(_title) * _tsz1;
cOy = max(_H * (ingame ? 0.14 : 0.17), 8 * _u + _tw * dsin(menuAngle) + _th / 2);   // tilted text rises to the right

if (cS > 0.01)
{
	var _tsz = _tsz1 * cS;
	draw_set_halign(fa_left);
	draw_set_valign(fa_middle);
	draw_set_colour(merge_colour(bgCol, c_black, 0.7));
	draw_set_font(fnt_boldpixels);
	draw_text_transformed(bpx(0, 0) + 3 * _u, bpy(0, 0) + 4 * _u, _title, _tsz, _tsz, menuAngle);
	draw_set_colour(c_white);
	draw_text_transformed(bpx(0, 0), bpy(0, 0), _title, _tsz, _tsz, menuAngle);
	var _uv = _th * 0.55;
	draw_title_bar(-4 * _u, _tw + 30 * _u, _uv, 4 * _u, _u);
	draw_set_font(fnt_notjammono);
}

// ---- Layout
var _dy = min(40 * _u, (_H * 0.62) / _n);
var _bh = min(27 * _u, _dy * 0.78);
var _y0 = min(_H * 0.40, _H * 0.92 - (_n - 1) * _dy - _bh);
var _want = (_wide ? 235 : 150) * _u;
var _bw = 0;
var _dx = 0;

if (ingame)
{
	// The top row is the tightest spot, since the edge leans outward going down
	var _room = edge_at(_pwLay, _y0 - _bh, _H) - _x0 - 22 * _u;
	_bw = max(80 * _u, min(_want, _room));
	_dx = min(24 * _u, _lean * _dy);   // the cascade follows the panel's edge
}
else
{
	_bw = min(_want, _W * 0.82);
	_dx = (_n > 1) ? clamp((_W - _bw - 60 * _u) / (_n - 1), 0, 24 * _u) : 0;
}

// ---- Buttons
for (var pass = 0; pass < 2; pass++)   // selected button last, so it overlaps its neighbours
{
	for (var i = 0; i < _n; i++)
	{
		if ((i == _selI) != (pass == 1)) continue;

		var _row = _items[i];
		var _p = clamp((pageAge - i * popStep) / popDur, 0, 1);
		if (_p <= 0) continue;

		var _s  = sel[i];
		var _on = node_enabled(_row);
		cS  = ease_out_back(_p) * lerp(1, 1.14, _s) * _outS;
		cOx = _x0 + i * _dx;
		cOy = _y0 + i * _dy;
		cBw = _bw;

		var _bgc = merge_colour(c_black, c_white, _s);
		var _fg  = _on ? merge_colour(c_white, c_black, _s) : c_gray;

		bquad(0, -_bh / 2, _bw, _bh / 2, merge_colour(bgCol, c_black, 0.7), 1, 4 * _u, 5 * _u);   // shadow
		bquad(0, -_bh / 2, _bw, _bh / 2, _bgc, 1);                                                // face

		draw_set_valign(fa_middle);
		draw_set_colour(_fg);
		draw_set_halign(fa_left);
		draw_text_transformed(bpx(18 * _u, 0), bpy(18 * _u, 0), tr(_row.label), _ts * cS, _ts * cS, menuAngle);

		draw_set_halign(fa_right);
		var _rx = _bw - 22 * _u;
		switch (_row.type)
		{
			case "menu":
				draw_text_transformed(bpx(_rx, 0), bpy(_rx, 0), ">", _ts * cS, _ts * cS, menuAngle);
				break;

			case "toggle":
				draw_text_transformed(bpx(_rx, 0), bpy(_rx, 0), tr(_row.get() ? "On" : "Off"), _ts * cS, _ts * cS, menuAngle);
				break;

			case "dropdown":
				draw_text_transformed(bpx(_rx, 0), bpy(_rx, 0), tr(_row.options[_row.get()]) + ((i == _selI && _on) ? "  v" : ""), _ts * cS, _ts * cS, menuAngle);
				break;

			case "slider":
				var _v = _row.get();
				var _bu0 = _bw * 0.40, _bu1 = _bw - 52 * _u;
				draw_text_transformed(bpx(_rx, 0), bpy(_rx, 0), string(round(_v * 100)) + "%", _ts * cS, _ts * cS, menuAngle);
				bquad(_bu0, -2 * _u, _bu1, 2 * _u, merge_colour(_fg, _bgc, 0.65), 1);
				bquad(_bu0, -2 * _u, lerp(_bu0, _bu1, _v), 2 * _u, _fg, 1);
				break;

			case "rebind":
				if (i != _selI)
				{
					// compact: plain text, no boxes
					var _k0 = key_name(global.binds[$ _row.action][0]);
					var _k1 = key_name(global.binds[$ _row.action][1]);
					draw_text_transformed(bpx(_rx, 0), bpy(_rx, 0), _k0 + "  /  " + _k1, _ts * cS * 0.85, _ts * cS * 0.85, menuAngle);
				}
				else
				{
					// selected row: boxes, active slot has a thick outline
					draw_set_halign(fa_center);
					for (var k = 0; k < 2; k++)
					{
						var _ku1 = _rx - (1 - k) * 44 * _u;
						var _ku0 = _ku1 - 38 * _u;
						var _cur = (_row.slot == k);

						if (_cur)
						{
							if (!rebinding || ((current_time div 220) mod 2 == 0))
								bframe_thick(_ku0, -8 * _u, _ku1, 8 * _u, _fg, 2 * _u);
						}
						else bframe(_ku0, -8 * _u, _ku1, 8 * _u, merge_colour(_fg, _bgc, 0.7));

						draw_set_colour(_fg);
						var _kt = (_cur && rebinding) ? "..." : key_name(global.binds[$ _row.action][k]);
						draw_text_transformed(bpx((_ku0 + _ku1) / 2, 0), bpy((_ku0 + _ku1) / 2, 0), _kt, _ts * cS * 0.85, _ts * cS * 0.85, menuAngle);
					}
				}
				break;
		}

		// Cursor: a triangular chip of the button itself, at its top-left corner
		if (i == _selI)
		{
			var _cw = _bh * 0.31;                          // chip width
			var _ch = _bh * 0.35;                          // chip height
			var _chipGap = 2.5 * _u;                       // gap between the chip and the button
			var _bob = sin(current_time * 0.012) * 0.8 * _u;
			var _cx1 = -_cw - _chipGap + _bob, _cx2 = -_chipGap + _bob;
			var _cy1 = -_bh / 2;
//			btri(_cx1, _cy1, _cx1, _cy1 + _ch, _cx2, _cy1 + _ch / 2, merge_colour(bgCol, c_black, 0.7), 4 * _u, 5 * _u);   // the button's shadow
			btri(_cx1, _cy1, _cx1, _cy1 + _ch, _cx2, _cy1 + _ch / 2, _bgc);                                                // the button's colour
		}
	}
}

// ---- Open dropdown: scrolls, and flips upward if there's more room above
if (dropOpen)
{
	var _di = _items[_selI];
	var _no = array_length(_di.options);
	var _rh = 20 * _u;

	cS  = lerp(1, 1.14, 1);
	cOx = _x0 + _selI * _dx;
	cOy = _y0 + _selI * _dy;
	cBw = _bw;

	var _below = _H * 0.96 - (cOy + (_bh / 2 + 6 * _u) * cS);
	var _above = (cOy - (_bh / 2 + 6 * _u) * cS) - _H * 0.04;
	var _flip  = (_below < _rh * min(_no, 3)) && (_above > _below);
	var _rows  = clamp(floor((_flip ? _above : _below) / _rh), 2, _no);

	ddScroll = clamp(ddScroll, dropIndex - _rows + 1, dropIndex);   // keep the highlighted row visible
	ddScroll = clamp(ddScroll, 0, _no - _rows);

	draw_set_valign(fa_middle);
	draw_set_halign(fa_left);
	for (var r = 0; r < _rows; r++)
	{
		var _o   = ddScroll + r;
		var _v0  = _flip ? -(_bh / 2 + 5 * _u + (_rows - r) * _rh) : (_bh / 2 + 5 * _u + r * _rh);
		var _hot = (_o == dropIndex);
		bquad(_bw * 0.45, _v0, _bw, _v0 + _rh - 2 * _u, _hot ? c_white : c_black, 1);
		draw_set_colour(_hot ? c_black : c_white);
		draw_text_transformed(bpx(_bw * 0.45 + 12 * _u, _v0 + _rh / 2 - _u), bpy(_bw * 0.45 + 12 * _u, _v0 + _rh / 2 - _u), tr(_di.options[_o]), _ts * cS, _ts * cS, menuAngle);
	}

	// Scroll arrows when there are more rows above or below
	var _arx = _bw - 16 * _u;
	var _firstTop = _flip ? -(_bh / 2 + 5 * _u + _rows * _rh) : (_bh / 2 + 5 * _u);
	if (ddScroll > 0)
	{
		var _acy = _firstTop + _rh / 2 - _u;
		btri(_arx - 5 * _u, _acy + 3 * _u, _arx + 5 * _u, _acy + 3 * _u, _arx, _acy - 4 * _u, (ddScroll == dropIndex) ? c_black : c_white);
	}
	if (ddScroll + _rows < _no)
	{
		var _bcy = _firstTop + (_rows - 1) * _rh + _rh / 2 - _u;
		btri(_arx - 5 * _u, _bcy - 3 * _u, _arx + 5 * _u, _bcy - 3 * _u, _arx, _bcy + 4 * _u, (ddScroll + _rows - 1 == dropIndex) ? c_black : c_white);
	}
}

matrix_set(matrix_world, matrix_build_identity());

// ---- Footer: the selected option's hint, or the key legend
var _hint = _items[_selI][$ "hint"];
var _foot = rebinding ? "Press a key (Esc to cancel, Del to clear)"
	: (((_hint != undefined) && (_hint != "")) ? _hint : "");
draw_set_halign(fa_left);
draw_set_valign(fa_middle);
draw_set_colour(c_white);
draw_text_transformed(18 * _u, _H - 12 * _u, _foot, _ts * 0.7, _ts * 0.7, 0);

draw_set_alpha(1);
draw_set_colour(c_white);
draw_set_halign(fa_left);
draw_set_valign(fa_top);
draw_set_font(fnt_default);