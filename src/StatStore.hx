package mods.ascension_helper;

/** Saved training plans per hero, in alternating verified snapshots like the weapon plans. */
class StatStore {
	var folder:String;
	var account:String;
	var sequence = 0;
	var ids:Array<String> = [];
	var plans:Array<String> = [];

	public function new(folder:String, account:String) {
		this.folder = folder;
		this.account = account;
		if (!sys.FileSystem.exists(folder))
			sys.FileSystem.createDirectory(folder);
		for (i in 0...2)
			try {
				var d:Dynamic = haxe.Json.parse(sys.io.File.getContent(path(i)));
				if (d.schema != 1 || d.account != account || !Std.isOfType(d.sequence, Int) || d.sequence <= sequence || !Std.isOfType(d.heroes, Array))
					continue;
				var nextIds:Array<String> = [];
				var nextPlans:Array<String> = [];
				for (row in (cast d.heroes : Array<Dynamic>)) {
					var id = Std.string(row.id);
					if (!Plan.validId(id) || nextIds.indexOf(id) >= 0)
						throw "Invalid hero";
					var text = Std.string(row.plan);
					StatPlan.decode(text);
					nextIds.push(id);
					nextPlans.push(text);
				}
				sequence = d.sequence;
				ids = nextIds;
				plans = nextPlans;
			} catch (_:Dynamic) {}
	}

	function path(slot:Int):String
		return folder + "/stats-" + account + "-" + slot + ".json";

	public function heroes():Array<String>
		return ids.copy();

	public function get(id:String):Array<Int> {
		var i = ids.indexOf(id);
		return i < 0 ? [] : StatPlan.decode(plans[i]);
	}

	public function set(id:String, list:Array<Int>):Void {
		var text = StatPlan.encode(list);
		StatPlan.decode(text);
		var i = ids.indexOf(id);
		var oldIds = ids.copy();
		var oldPlans = plans.copy();
		if (i < 0) {
			ids.push(id);
			plans.push(text);
		} else
			plans[i] = text;
		try
			save()
		catch (e:Dynamic) {
			ids = oldIds;
			plans = oldPlans;
			throw e;
		}
	}

	function save():Void {
		var next = sequence + 1;
		var heroes:Array<Dynamic> = [];
		for (i in 0...ids.length)
			heroes.push({id: ids[i], plan: plans[i]});
		var d:Dynamic = {
			schema: 1,
			account: account,
			sequence: next,
			heroes: heroes
		};
		var file = path(next % 2);
		sys.io.File.saveContent(file, haxe.Json.stringify(d));
		var check:Dynamic = haxe.Json.parse(sys.io.File.getContent(file));
		if (check.sequence != next || check.account != account)
			throw "Saved training plan verification failed";
		sequence = next;
	}
}
