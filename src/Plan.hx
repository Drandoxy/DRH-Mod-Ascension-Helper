package mods.ascension_helper;

class Plan {
	public var slot:Int;
	public var level:Int;
	public var uid:String;

	public function new(slot:Int, level:Int, uid:String) {
		this.slot = slot;
		this.level = level;
		this.uid = uid;
	}

	public function copy():Plan
		return new Plan(slot, level, uid);

	public static function validId(id:String):Bool {
		if (id == null || !~/^[0-9]{1,10}$/.match(id))
			return false;
		var n = Std.parseFloat(id);
		return n > 0 && n <= 4294967295.0;
	}

	public static function copyAll(plans:Array<Plan>):Array<Plan>
		return [for (p in plans) p.copy()];

	public static function selected(plans:Array<Plan>, slot:Int, level:Int):Null<Plan> {
		for (p in plans)
			if (p.slot == slot && p.level == level)
				return p;
		return null;
	}

	public static function desired(plans:Array<Plan>, slot:Int, level:Int):Null<Plan> {
		var found:Plan = null;
		for (p in plans)
			if (p.slot == slot && p.level <= level && (found == null || p.level > found.level))
				found = p;
		return found;
	}

	public static function assign(plans:Array<Plan>, slot:Int, weapon:Weapon):Bool {
		for (p in plans)
			if (p.uid == weapon.uid && p.slot != slot)
				return false;
		var old = selected(plans, slot, weapon.level);
		if (old != null)
			plans.remove(old);
		plans.push(new Plan(slot, weapon.level, weapon.uid));
		return true;
	}

	public static function clearSlot(plans:Array<Plan>, slot:Int):Array<Plan>
		return [for (p in plans) if (p.slot != slot) p.copy()];

	public static function automatic(plans:Array<Plan>, slot:Int, visible:Array<Weapon>):Array<Plan> {
		var next = clearSlot(plans, slot);
		var sorted = visible.copy();
		sorted.sort(Weapon.compare);
		for (w in sorted)
			if (selected(next, slot, w.level) == null)
				assign(next, slot, w);
		return next;
	}

	public static function validate(plans:Array<Plan>):Bool {
		if (plans.length > 3000)
			return false;
		for (i in 0...plans.length) {
			var p = plans[i];
			if (p.slot < 0 || p.slot > 2 || p.level < 1 || p.level > 1000 || !validId(p.uid))
				return false;
			for (j in 0...i) {
				var q = plans[j];
				if (q.slot == p.slot && q.level == p.level || q.uid == p.uid && q.slot != p.slot)
					return false;
			}
		}
		return true;
	}
}
