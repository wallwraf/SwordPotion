// Inherit the parent event
event_inherited();

// Sprites
spr = { idle: spr_dummy, hurt: spr_dummy_hit, dead: spr_dummy_break };
mask_index = spr_dummy;

// Stats
stats.hp = 50; stats.hpMax = 50;
cfg.knockResist = 1;
cfg.deathTime = 30;

// Affinities
affinity[DamageType.BLUDGEONING] = 1.1;
affinity[DamageType.PIERCING] = 1.1;
affinity[DamageType.SLASHING] = 1.1;

// States
state_use([EnemyState.IDLE, EnemyState.HURT, EnemyState.DEAD]);