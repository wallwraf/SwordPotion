// Stats
hpMax = 100;
hp = hpMax;
hpChip = hp;
hpChipTimer = 0;
hpChipDelay = 60;
hpChipSpeed = 0.06;

barRadius = 18;
barSpan = 110;
barThick = 3;
barGap = 22;
barAlpha = 0;
barShowTimer = 0;
barShowTime = 150;
barFadeIn = 0.3;
barFadeOut = 0.06;
barChipCol = make_colour_rgb(210, 210, 210);

// Animation Settings
hSpdRem = 0;
vSpdRem = 0;
mask_index = spr_player;
spr =
{
	idle: spr_player_idle,
	walk: spr_player_walk,
	run: spr_player_run,
	jump: spr_player_jump,
	fall: spr_player_fall,
	land: spr_player_land,
	fallLoop: spr_player_fall_loop,
	attack: spr_player_attack,
	attackEnd: spr_player_attack_end
}

// State Machine
enum PlayerState
{
	FREE,
	IN_AIR,
	LAND,
	ATTACK,
	ACTION,
	DASH_TO,
	HURT,
	DEAD
}

state = PlayerState.FREE;
stateTimer = 0;

// Default Values
hSpd = 0;
vSpd = 0;
facing = 1;

walkSpd = 1;
runSpd = 3;
grav = 0.3;

// Jump Height
jumpMaxHeight = (bbox_bottom - bbox_top) * 2.5;
jumpMinHeight = 4;

jumpSpd = -sqrt(2 * grav * jumpMaxHeight);
jumpCutSpd = -sqrt(2 * grav * jumpMinHeight);

isJumping = false;
onGround = false;

landMinFall = 3;
landCancelFrames = 4;
peakFall = 0;

groundAccel = 0.25;
groundFric = 0.20;
groundTurn = 0.75;
airAccel = 0.15;
airDrag = 0.015;
airFric = 0.03;
airTurn = 0.35;

actSlow = 0.8;
actTarget = noone;
actIndex = 0;
actRange = 400;
actCx = 0;
actCy = 0;
actDrawX = 0;
actDrawY = 0;

arrowCol = make_colour_rgb(255, 255, 255);
arrowSpacing = 14;
arrowSpeed = 0.06;
arrowSize = 7;
arrowOy = -12;

flashTimer = 0;
flashDur = 6;

// DASH_TO action
dashTarget = noone;
dashSpd = 20;
dashWindup = game_get_speed(gamespeed_fps) * 0.25;
dashTimer = 0;
dashPhase = 0;
dashPx = x; dashPy = y;

function move_and_collide_pixels()
{
	var _h = hSpd * global.timeScale + hSpdRem;
	var _v = vSpd * global.timeScale + vSpdRem;
	
	var _mx = round(_h);
	var _my = round(_v);
	hSpdRem = _h - _mx;
	vSpdRem = _v - _my;
	
	// Horizontal Pixel Collision
	repeat (abs(_mx))
	{
		if (!place_meeting(x + sign(_mx), y, obj_col))
			x += sign(_mx);
		else
		{
			hSpd = 0;
			hSpdRem = 0;
			break;
		}
	}
	// Vertical Pixel Collision
	repeat (abs(_my))
	{
		if (!place_meeting(x, y + sign(_my), obj_col))
			y += sign(_my);
		else
		{
			vSpd = 0;
			vSpdRem = 0;
			break;
		}
	}
}

function enter_act_menu()
{
	actTarget = noone;
	actIndex = 0;
	actCx = x; actCy = y;
	actDrawX = x; actDrawY = y;
	global.timeScaleTarget = 1 - actSlow;
	state_change(PlayerState.ACTION);
}

function find_act_target(_dx, _dy)
{
	var _best = noone;
	var _best_score = infinity;
	
	with (obj_actionable)
	{
		if (id == other.actTarget) continue;
		
		var _rx = x - other.actCx;
		var _ry = y - other.actCy;
		var _dist = point_distance(0, 0, _rx, _ry);
		if (_dist == 0 || _dist > other.actRange) continue;
		
		var _forward = _rx * _dx + _ry * _dy;
		if (_forward <= 0) continue;
		
		var _cos = _forward / _dist;
		if (_cos < 0.5) continue;
		
		var _score = _dist / _cos;
		if (_score < _best_score)
		{
			_best_score = _score;
			_best = id;
		}
	}
	return _best;
}

function draw_chevron(_x, _y, _dir, _size, _col, _alpha)
{
	var _back = _dir + 180;
	var _x1 = _x + lengthdir_x(_size, _back + 45);
	var _y1 = _y + lengthdir_y(_size, _back + 45);
	var _x2 = _x + lengthdir_x(_size, _back - 45);
	var _y2 = _y + lengthdir_y(_size, _back - 45);
	
	draw_set_alpha(_alpha);
	draw_set_colour(_col);
	draw_line_width(_x1, _y1, _x, _y, 3);
	draw_line_width(_x2, _y2, _x, _y, 3);
	draw_circle(_x, _y, 1.5, false);
	draw_set_alpha(1);
	draw_set_colour(c_white);
}

function draw_act_arrow()
{
	if (actTarget == noone || !instance_exists(actTarget)) return;
	
	var _x1 = (bbox_left + bbox_right) / 2;
	var _y1 = (bbox_top + bbox_bottom) / 2;
	var _x2 = actTarget.x;
	var _y2 = actTarget.y;
	
	var _dir = point_direction(_x1, _y1, _x2, _y2);
	var _dist = point_distance(_x1, _y1, _x2, _y2);
	
	var _padStart = 10;
	var _padEnd = 20;
	var _len = _dist - _padStart - _padEnd;
	if (_len <= 0) return;
	
	// Scroll toward
	var _scroll = (current_time * arrowSpeed) mod arrowSpacing;
	
	for (var _d = _scroll; _d < _len; _d += arrowSpacing)
	{
		// Fade in
		var _fade = min(1, _d / (arrowSpacing * 2)) * min(1, (_len - _d) / (arrowSpacing * 2));
		var _px = _x1 + lengthdir_x(_padStart + _d, _dir);
		var _py = _y1 + lengthdir_y(_padStart + _d, _dir);
		draw_chevron(_px, _py, _dir, arrowSize, arrowCol, _fade);
	}
}

function perform_action(_act, _target)
{
	switch (_act)
	{
		case PLAYER_ACT.NONE:
			break;
			
		case PLAYER_ACT.SLAM:
			hSpd = 0;
			vSpd = 10;
			state_change(PlayerState.IN_AIR);
			break;
		
		case PLAYER_ACT.DASH_TO:
			dashTarget = _target;
			state_change(PlayerState.DASH_TO);
			break;
		
		case PLAYER_ACT.ACTIVATE:
			
			break;
		
		default:
			_target.on_act(_act, id);
			break;
	}
}

// Approach Function
function approach(_val, _target, _amount)
{
	if (_val < _target) return min(_val + _amount, _target);
	return max(_val - _amount, _target);
}

// Health
function take_damage(_amount)
{
	if (state == PlayerState.DEAD) return;
	
	hp = max(0, hp - _amount);
	hpChipTimer = hpChipDelay;
	barShowTimer = barShowTime;
	
	if (hp <= 0) state_change(PlayerState.DEAD);
	else state_change(PlayerState.HURT);
}

function heal(_amount)
{
	hp = min(hpMax, hp + _amount);
	hpChip = max(hpChip, hp)
	barShowTimer = barShowTime;
}

function hp_colour(_t)
{
	var _green = make_colour_rgb(70, 220, 80);
	var _yellow = make_colour_rgb(240, 210, 60);
	var _red = make_colour_rgb(230, 50, 50);
	
	if (_t > 0.5) return merge_colour(_yellow, _green, (_t - 0.5) * 2);
	return merge_colour(_red, _yellow, _t * 2)
}

function draw_arc_band(_px, _py, _s, _a0, _a1, _col, _thick, _alpha)
{
	if (_a1 <= _a0) return;
	
	var _half = barSpan / 2
	var _r = barRadius * _s;
	var _cx = round(_px);
	// Place the Center so that arc's top ends sit barGap below origin
	var _cy = round(_py + (barGap - barRadius * dcos(_half)) * _s);
	var _r0 = _r - _thick * _s / 2;
	var _r1 = _r + _thick * _s / 2;
	var _steps = max(2, ceil((_a1 - _a0) / 4));
	
	draw_primitive_begin(pr_trianglestrip);
	for (var i = 0; i <= _steps; i++)
	{
		var _a = lerp(_a0, _a1, i / _steps);
		draw_vertex_colour(_cx + lengthdir_x(_r0, _a), _cy + lengthdir_y(_r0, _a), _col, _alpha);
		draw_vertex_colour(_cx + lengthdir_x(_r1, _a), _cy + lengthdir_y(_r1, _a), _col, _alpha);
	}
	draw_primitive_end();
}

function draw_hp_bar(_px, _py, _s)
{
	if (barAlpha <= 0) return;
	
	var _a0 = 270 - barSpan / 2;
	var _fHp = hp / hpMax;
	var _fChip = hpChip / hpMax;
	
	// Outline
	draw_arc_band(_px, _py, _s, _a0 - 2, _a0 + barSpan + 2, c_black, barThick + 2, barAlpha);
	
	// Chip
	draw_arc_band(_px, _py, _s, _a0 + barSpan * _fHp, _a0 + barSpan * _fChip, barChipCol, barThick, barAlpha);
	
	// Current Health
	draw_arc_band(_px, _py, _s, _a0, _a0 + barSpan * _fHp, hp_colour(_fHp), barThick, barAlpha);
}

// On New State
function state_change(_new_state)
{
	if (state == _new_state) return;
	state = _new_state;
	stateTimer = 0;
	
	if (_new_state != PlayerState.IN_AIR) isJumping = false;
	
	switch (_new_state)
	{
		case PlayerState.FREE:
			peakFall = 0;
			break;
		
		case PlayerState.ATTACK:
			sprite_index = spr.attack;
			image_index = 0;
			break;
			
		case PlayerState.IN_AIR:
			// Start in the Jump sprite if rising, otherwise fall.
			sprite_index = (vSpd < 0) ? spr.jump : spr.fall;
			image_index = 0;
			break;
			
		case PlayerState.LAND:
			peakFall = 0;
			sprite_index = spr.land;
			image_index = 0;
			break;
		
		case PlayerState.HURT:
			hSpd = -facing * 1.5;
			vSpd = -2;
			break;
			
		case PlayerState.DASH_TO:
			hSpd = 0; vSpd = 0;
			hSpdRem = 0; vSpdRem = 0;
			sprite_index = spr.jump;
			image_index = 0;
			dashTimer = 0;
			dashPhase = 0;
			dashPx = x; dashPy = y;
			var _dx = dashTarget.x - x;
			if (_dx != 0) facing = sign(_dx);
			break;
	}
}

function anim_ended()
{
	return image_index >= image_number - 1;
}

// State Functions
function state_free()
{
	var _move = kRight - kLeft;
	var _run = kRun;
	var _target = _move * (_run ? runSpd : walkSpd);
	
	if (_move != 0)
	{
		facing = _move;
		
		var _rate = (abs(_target) < abs(hSpd) ? groundFric : groundAccel);
		if (sign(hSpd) != 0 && sign(hSpd) != _move) _rate = groundTurn;
		else if (abs(_target) < abs(hSpd))			_rate = groundFric;
		else										_rate = groundAccel;
		
		hSpd = approach(hSpd, _target, _rate);
	}
	else
	{
		hSpd = approach(hSpd, 0, groundFric);
	}
	
	// Pick Sprite from Player Action
	if (_move == 0 && abs(hSpd) < 0.1)	sprite_index = spr.idle;
	else if (abs(hSpd) > walkSpd + 0.1)	sprite_index = spr.run;
	else								sprite_index = spr.walk;
	
	// Transitions
	if (kJump)
	{
		sfx_play(snd_jump);
		vSpd = jumpSpd;
		isJumping = true;
		state_change(PlayerState.IN_AIR);
	}
	else if (!onGround)
	{
		state_change(PlayerState.IN_AIR);
	}
	else if (kSelect)
	{
		state_change(PlayerState.ATTACK);
	}
	else if (keyboard_check(ord("C")))
	{
		enter_act_menu();
		return;
	}
}

function state_inair()
{
	var _move = kRight - kLeft;
	if (_move != 0) facing = _move;
	
	if (_move != 0)
	{
		facing = _move;
		
		if (sign(hSpd) != 0 && sign(hSpd) != _move)
			hSpd = approach(hSpd, _move * walkSpd, airTurn);
		else if (abs(hSpd) > walkSpd)
			hSpd = approach(hSpd, _move * walkSpd, airDrag);
		else
			hSpd = approach(hSpd, _move * walkSpd, airAccel);
	}
	else
	{
		hSpd = approach(hSpd, 0, airFric);
	}
	
	vSpd += grav;
	peakFall = max(peakFall, vSpd);
	
	// Jump Cut
	if (isJumping && !kJumpHeld && vSpd < jumpCutSpd) vSpd = jumpCutSpd;
	if (vSpd >= 0) isJumping = false;
	
	// Jump -> Fall -> Fall Loop
	if (vSpd < 0) sprite_index = spr.jump;
	else if (sprite_index == spr.jump) { sprite_index = spr.fall; image_index = 0; }
	else if (sprite_index == spr.fall && anim_ended()) sprite_index = spr.fallLoop;
	
	// Transitions
	if (onGround && vSpd >= 0)
	{
		vSpd = 0;
		state_change(peakFall >= landMinFall ? PlayerState.LAND : PlayerState.FREE);
	}
	else if (kSelect)
	{
		state_change(PlayerState.ATTACK);
	}
	else if (keyboard_check(ord("C")))
	{
		enter_act_menu();
		return;
	}
}

function state_land()
{
	var _move = kRight - kLeft;
	
	// Keep Sliding
	sfx_play(snd_land);
	hSpd = approach(hSpd, 0, groundFric);
	if (vSpd > 0) vSpd = 0;
	
	// Walked off Ledge
	if (!onGround) { state_change(PlayerState.IN_AIR); return; }
	
	// Instant Cancels
	if (kJump)
	{
		sfx_play(snd_jump);
		vSpd = jumpSpd;
		isJumping = true;
		state_change(PlayerState.IN_AIR);
		return;
	}
	if (kSelect) { state_change(PlayerState.ATTACK); return; }
	if (kAction) { state_change(PlayerState.ACTION); return; }
	
	// Movement Cancels
	if (stateTimer >= landCancelFrames && _move != 0)
	{
		state_change(PlayerState.FREE);
		return;
	}
	
	// Otherwise Finish
	if (anim_ended()) state_change(PlayerState.FREE);
}

function state_attack()
{
	if (onGround)
	{
		hSpd = approach(hSpd, 0, groundFric);
		if (vSpd > 0) vSpd = 0;
	}
	else
	{
		hSpd = approach(hSpd, 0, airFric);
		vSpd += grav;
	}
	
	// Swap to End sprite
	if (sprite_index == spr.attack && anim_ended())
	{
		sprite_index = spr.attackEnd;
		image_index = 0;
	}
	else if (sprite_index == spr.attackEnd && anim_ended())
	{
		state_change(onGround ? PlayerState.FREE : PlayerState.IN_AIR);
	}
}

function state_action()
{
	var _ts = global.timeScale;
	
	// Physics
	if (onGround)
	{
		hSpd = approach(hSpd, 0, groundFric * _ts);
		if (vSpd > 0) vSpd = 0;
	}
	else
	{
		hSpd = approach(hSpd, 0, airFric * _ts);
		vSpd += grav * _ts;
	}
	
	// If the target was destroyed, drop
	if (actTarget != noone && !instance_exists(actTarget)) actTarget = noone;
	
	// Movement Keys
	var _dx = keyboard_check_pressed(vk_right) - keyboard_check_pressed(vk_left);
	var _dy = keyboard_check_pressed(vk_down) - keyboard_check_pressed(vk_up);
	
	if (_dx != 0 || _dy != 0)
	{
		var _found = find_act_target(_dx, _dy);
		if (_found != noone)
		{
			actTarget = _found;
			actCx = _found.x;
			actCy = _found.y;
			actIndex = 0;
		}
	}
	
	// Act Cycle Forward or Back
	if (actTarget != noone)
	{
		var _count = array_length(actTarget.actions);
		if (_count > 1)
		{
			if (keyboard_check_pressed(ord("Z"))) actIndex = (actIndex + 1) mod _count;
			if (keyboard_check_pressed(ord("X"))) actIndex = (actIndex - 1 + _count) mod _count;
		}
	}
	
	// Release
	if (!keyboard_check(ord("C")))
	{
		global.timeScaleTarget = 1;
		
		var _t = actTarget;
		var _a = (_t != noone) ? _t.actions[actIndex] : PLAYER_ACT.NONE;
		
		state_change(onGround ? PlayerState.FREE : PlayerState.IN_AIR);
		if (_a != PLAYER_ACT.NONE) perform_action(_a, _t);
	}
}

function state_hurt()
{
	vSpd += grav;
	if (stateTimer >= 20 && onGround)
	{
		state_change(PlayerState.FREE);
	}
}

function state_dead()
{
	hSpd = 0;
	game_restart();
}

// ACTIONS

	// DASH_TO
function end_dash()
{
	hSpd = 0; vSpd = 0;
	hSpdRem = 0; vSpdRem = 0;
	dashTarget = noone;
	state_change(onGround ? PlayerState.FREE : PlayerState.IN_AIR);
}
function state_dash_to()
{
	// Target Vanished, Exit
	if (!instance_exists(dashTarget)) { end_dash(); return; }
	
	// Hold the First Jump Frame (windup)
	sprite_index = spr.jump;
	image_index = 0;
	
	dashTimer++;
	
	if (dashPhase == 0)
	{
		hSpd = 0; vSpd = 0;
		if (dashTimer >= dashWindup)
		{
			sfx_play(snd_dash);
			dashPhase = 1;
			flashTimer = flashDur;
			screen_shake(6);
		}
		return;
	}
	
	// Dash
	var _dist = point_distance(x, y, dashTarget.x, dashTarget.y);
	var _step = dashSpd * global.timeScale;
	
	// Arrived
	if (_dist <= _step)
	{
		if (!place_meeting(dashTarget.x, dashTarget.y, obj_col))
		{
			x = dashTarget.x;
			y = dashTarget.y;
		}
		end_dash();
		return;
	}
	
	// Blocked by Solid
	if (x == dashPx && y == dashPy && dashTimer > dashWindup + 1)
	{
		end_dash();
		return;
	}
	dashPx = x; dashPy = y;
	
	var _dir = point_direction(x, y, dashTarget.x, dashTarget.y);
	hSpd = lengthdir_x(dashSpd, _dir);
	vSpd = lengthdir_y(dashSpd, _dir);
	
	// Afterimage
	if (dashTimer mod 1 == 0)
	{
		instance_create_depth(x, y, depth + 1, obj_afterimage, 
		{
			spr: sprite_index,
			img: image_index,
			xs: image_xscale,
			ys: image_yscale
		});
	}
}