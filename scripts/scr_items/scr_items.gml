// bonus = stat additions. resist = [type, amount] added to the damage multiplier
// (-0.5 takes 50% less, +0.25 takes 25% more). type = weapon damage type.
global.items = {
	rusty_sword: { name: "Rusty Sword", slot: "weapon", type: DamageType.SLASHING,    bonus: { atk: 4 } },
	iron_mace:   { name: "Iron Mace",   slot: "weapon", type: DamageType.BLUDGEONING, bonus: { atk: 6 } },
	ember_staff: { name: "Ember Staff", slot: "weapon", type: DamageType.FIRE,        bonus: { mag: 6 } },
	chain_mail:  { name: "Chain Mail",  slot: "armor",  bonus: { def: 4 }, resist: [[DamageType.SLASHING, -0.2]] },
	frost_cloak: { name: "Frost Cloak", slot: "armor",  bonus: { def: 1, res: 3 },
	               resist: [[DamageType.COLD, -0.5], [DamageType.FIRE, 0.25]] }
};