package mods.ascension_helper;

/** Snapshot of one physical owned item. IDs are strings to preserve UInt values. */
class Weapon {
	public var uid:String;
	public var owner:String;
	public var type:String;
	public var level:Int;
	public var rarity:Int;
	public var power:Float;
	public var aptitude = false;
	public var mana = 1.0;
	public var damage = 1.0;
	public var speed = 1.0;
	public var critChance = 0.0;
	public var critBonus = 0.0;
	public var utility = 0.0;
	public var charge = 1.0;
	public var cooldown = 1.0;
	public var extraProjectiles = 0;
	public var projectile = false;
	public var charged = false;
	public var usesMana = false;
	public var name:String;

	public function new(uid:String, type:String, level:Int, rarity:Int, power:Float, owner:String = "0") {
		this.uid = uid;
		this.type = type;
		this.level = level;
		this.rarity = rarity;
		this.power = power;
		this.owner = owner;
		name = type;
	}

	public function estimate():Float {
		var cadence = speed / Math.max(0.1, cooldown);
		if (charged)
			cadence /= Math.max(0.1, charge);
		return power * damage * cadence * (1 + critChance * critBonus) * (charged ? 1 + extraProjectiles * 0.15 : 1);
	}

	/** Rarity and mana preferences are intentional, ahead of estimated combat value. */
	public static function compare(a:Weapon, b:Weapon):Int {
		if (a.rarity != b.rarity)
			return a.rarity > b.rarity ? -1 : 1;
		if (a.aptitude != b.aptitude)
			return a.aptitude ? -1 : 1;
		var am = a.usesMana ? a.mana : 1.0;
		var bm = b.usesMana ? b.mana : 1.0;
		if (am != bm)
			return am < bm ? -1 : 1;
		var av = a.estimate();
		var bv = b.estimate();
		if (av != bv)
			return av > bv ? -1 : 1;
		if (a.utility != b.utility)
			return a.utility > b.utility ? -1 : 1;
		return Reflect.compare(a.uid, b.uid);
	}
}
