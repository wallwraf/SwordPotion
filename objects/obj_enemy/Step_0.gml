if (!started) { started = true; state_change(startState); }

var _ts = global.timeScale;
stateTimer += _ts;
attackCd = max(0, attackCd - _ts);
flashTimer = max(0, flashTimer - 1);
iframes = max(0, iframes - 1);

effects_update();
onGround = place_meeting(x, y + 1, obj_col);

if (stunTimer > 0)
{
	// Lightning: frozen, no state logic or movement
	stunTimer -= _ts;
	image_speed = 0;
}
else
{
	image_speed = _ts;

	// Confusion: drop any chase or attack in progress
	if (confused && (state == EnemyState.CHASE || state == EnemyState.ATTACK)) state_home();

	if (state_has(state)) states[state].step();

	image_xscale = facing;
	enemy_move();
}