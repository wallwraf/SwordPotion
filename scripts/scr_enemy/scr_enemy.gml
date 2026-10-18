enum EnemyState { IDLE, ROAM, CHASE, ATTACK, HURT, DEAD, CUSTOM }
// Per-enemy custom states, numbered from CUSTOM:
// #macro ES_DASH (EnemyState.CUSTOM + 0)

enum DamageType
{
	BLUDGEONING,
	PIERCING,
	SLASHING,
	
	ACID,
	COLD,
	FIRE,
	FORCE,
	LIGHTNING,
	NECROTIC,
	POISON,
	PSYCHIC,
	RADIANT,
	THUNDER
}

#macro SEC 60

// atk/def = stats the type uses. hit = on-hit modifiers. fx = status effect applied by the hit.
// Chip: % of the hit's damage, once per `every` frames at each offset in `ticks`, until `dur` ends.
global.damageTypes = [
	/* BLUDGEONING */ { atk: "atk", def: "def" },
	/* PIERCING    */ { atk: "atk", def: "def" },
	/* SLASHING    */ { atk: "atk", def: "def" },

	/* ACID */ { atk: "mag", def: "res", fx: {
		col: make_colour_rgb(190, 230, 60), dur: 4 * SEC, every: SEC, ticks: [0, 5], pct: 0.04 } },

	/* COLD */ { atk: "mag", def: "res", fx: {
		col: make_colour_rgb(120, 190, 255), dur: 6 * SEC, every: 2 * SEC, ticks: [0], pct: 0.04, slow: 0.5 } },

	/* FIRE */ { atk: "mag", def: "res", fx: {
		col: make_colour_rgb(255, 140, 40), dur: 3 * SEC, every: SEC, ticks: [0], pct: 0.12 } },

	/* FORCE */ { atk: "mag", def: "res", hit: { knock: 3 } },

	/* LIGHTNING */ { atk: "mag", def: "res", fx: {
		col: make_colour_rgb(255, 240, 90), dur: 6 * SEC, every: 2 * SEC, ticks: [0], pct: 0.02, stun: 0.5 * SEC } },

	/* NECROTIC */ { atk: "mag", def: "res", fx: {
		col: make_colour_rgb(140, 70, 170), build: 0.20, decayDelay: 3 * SEC, decay: 0.05 } },

	/* POISON */ { atk: "mag", def: "res", fx: {
		col: make_colour_rgb(80, 190, 110), dur: 5 * SEC, every: SEC, ticks: [0], pct: 0.05 } },

	/* PSYCHIC */ { atk: "mag", def: "res", fx: {
		col: make_colour_rgb(240, 110, 200), dur: 5 * SEC, confuse: true, weaken: 0.5 } },

	/* RADIANT */ { atk: "mag", def: "res", fx: {
		col: make_colour_rgb(255, 225, 110), dur: 6 * SEC, vuln: 0.25 } },

	/* THUNDER */ { atk: "mag", def: "res", hit: { stagger: 2.5 } }
];

function approach(_val, _target, _amount)
{
	if (_val < _target) return min (_val + _amount, _target);
	return max(_val - _amount, _target);
}

// Built in behavior for each core state
function enemy_default_state(_id)
{
	switch (_id)
	{
		case EnemyState.IDLE:
			return {
				enter: function() { anim("idle"); },
				step: function()
				{
					slow_down();
					if (state_has(EnemyState.CHASE) && sees_target()) { state_change(EnemyState.CHASE); return; }
					if (state_has(EnemyState.ROAM) && stateTimer >= cfg.idleTime) state_change(EnemyState.ROAM);
				}
			};
		
		case EnemyState.ROAM:
			return {
				enter: function()
				{
					anim(["walk", "idle"]);
					roamDir = choose(-1, 1);
					roamTime = irandom_range(cfg.roamMin, cfg.roamMax);
				},
				step: function()
				{
					facing = roamDir;
					hSpd = approach(hSpd, roamDir * stat_get("spd"), cfg.accel);
					
					var _wall = place_meeting(x + roamDir * 2, y, obj_col);
					var _ledge = cfg.avoidLedges && onGround && !place_meeting(x + roamDir * 8, y + 4, obj_col);
					if (_wall || _ledge) { roamDir *= -1; return; }
					
					if (state_has(EnemyState.CHASE) && sees_target()) { state_change(EnemyState.CHASE); return; }
					if (stateTimer >= roamTime)
					{
						// No IDLE State? Keep Roaming in a new Dir
						if (!state_change(EnemyState.IDLE)) state_change(EnemyState.ROAM, true);
					}
				}
			};
		
		case EnemyState.CHASE:
			return {
				enter: function() { anim(["chase", "run", "walk"]); },
				step: function()
				{
					if (!instance_exists(target)) { state_home(); return; }
					if (_dist > cfg.loseRange) { state_home(); return; }
					
					var _dx = target.x - x;
					if (abs(_dx) > 1) facing = sign(_dx);
					var _spd = stat_get("spd") * cfg.chaseMult;
					
					if (cfg.flying)
					{
						var _dir = point_direction(x, y, target.x, target.y);
						hSpd = approach(hSpd, lengthdir_x(_spd, _dir), cfg.accel);
						vSpd = approach(hSpd, lengthdir_y(_spd, _dir), cfg.accel);
					}
					else hSpd = approach(hSpd, facing * _spd, cfg.accel);
					
					if (state_has(cfg.attackState) && attackCd <= 0 && _dist <= cfg.attackRange)
						state_change(cfg.attackState);
				}
			};
		
		case EnemyState.ATTACK:
			return {
				enter: function()
				{
					attackCd = cfg.atkCooldown;
					if (instance_exists(target) && abs(target.x - x) > 1) facing = sign(target.x - x);
					anim("attack");
				},
				step: function()
				{
					slow_down();
					var _on = cfg.atkWindup;
					var _off = _on + cfg.atkActivel
					if (stateTimer >= _on && stateTimer < _off) try_melee();
					if (stateTimer >= _off + cfg.atkRecover) attack_finished();
				}
			};
			
		case EnemyState.HURT:
			return {
				enter: function() { anim("hurt"); },
				step: function()
				{
					slow_down(0.5);
					if (stateTimer >= cfg.hurtTime * hurtMult) recover_from_hit();
				}
			};
		
		case EnemyState.DEAD:
			return {
				enter: function() { anim("dead"); on_death(); drop_loot(); },
				step: function()
				{
					slow_down();

					// Play the death animation until it reaches its final frame
					if (!deadFrozen)
					{
						var _hasAnim = (spr[$ "dead"] != undefined);
						if (_hasAnim && image_index < image_number - 1) return;
						deadFrozen = true;
						if (_hasAnim) image_index = image_number - 1;
					}

					// Hold the last frame, then fade out
					image_speed = 0;
					deadTimer += global.timeScale;

					var _fade = deadTimer - cfg.deathHold;
					if (_fade > 0) image_alpha = 1 - _fade / cfg.deathFade;
					if (_fade >= cfg.deathFade) instance_destroy();
				}
			};
	}
	return {};
}
















