package mods.ascension_helper;

import account.AvatarInfo;

/**
 * Spends available training points by each hero's saved plan, in Town or in a dungeon, with the same
 * server request the Training screen uses. Never runs while the Training screen is open (it holds its
 * own unsaved stat values), and never repeats a request that was just sent.
 */
class StatSpender {
	var native:Native;
	var notify:(String, Bool) -> Void;
	var waitUntil = 0.0;
	var lastKey = "";
	var retryAt = 0.0;
	var lastLevel = -1;
	var lastHero = "";
	var refreshAt = 0.0;
	var log:String->Void;
	// The game never calls the success callback of this request, so success is confirmed by watching
	// the hero's stats reach the requested values (the server's reply updates the account data).
	var pendingHero = "";
	var pendingWanted = "";
	var pendingLines:Array<String> = [];
	var pendingSince = 0.0;

	public function new(native:Native, notify:(String, Bool) -> Void, ?log:String->Void) {
		this.native = native;
		this.notify = notify;
		this.log = log == null ? function(_) {} : log;
	}

	static function stats(a:AvatarInfo):Array<Int>
		return [Std.int(a.statUpgrade1), Std.int(a.statUpgrade2), Std.int(a.statUpgrade3), Std.int(a.statUpgrade4)];

	function confirm(now:Float):Void {
		if (pendingHero == "")
			return;
		var a = native.hero(pendingHero);
		if (a != null && stats(a).join(",") == pendingWanted) {
			log("training confirmed: " + pendingLines.join("; "));
			notify(pendingLines.join("\n"), true);
			pendingHero = "";
		} else if (now - pendingSince > 60) {
			log("training request not confirmed within 60 s");
			pendingHero = "";
		}
	}

	public function tick(now:Float, store:StatStore, trainingOpen:Bool):Void {
		confirm(now);
		if (store == null || trainingOpen || now < waitUntil || pendingHero != "")
			return;
		refreshAfterLevelUp(now);
		for (id in store.heroes()) {
			var plan = store.get(id);
			if (plan.length == 0)
				continue;
			var a = native.hero(id);
			if (a == null)
				continue;
			var current = stats(a);
			var wanted = StatPlan.target(plan, current, Std.int(a.skillPointsEarned));
			if (wanted.join(",") == current.join(","))
				continue;
			var key = id + ":" + wanted.join(",");
			if (key == lastKey && now < retryAt)
				continue;
			lastKey = key;
			retryAt = now + 30;
			waitUntil = now + 3;
			send(id, a, wanted, now);
			return;
		}
	}

	function send(id:String, a:AvatarInfo, wanted:Array<Int>, now:Float):Void {
		var before = [a.statUpgrade1, a.statUpgrade2, a.statUpgrade3, a.statUpgrade4];
		var lines:Array<String> = [];
		for (i in 0...4) {
			var added = wanted[i] - Std.int(before[i]);
			if (added > 0)
				lines.push(added + " skill point" + (added == 1 ? "" : "s") + " added to " + statName(a, i));
		}
		var name = a.gmHero == null ? "Hero" : Std.string(a.gmHero.Name);
		pendingHero = id;
		pendingWanted = wanted.join(",");
		pendingLines = lines;
		pendingSince = now;
		log("training request sent for " + name + ": " + before.join(",") + " -> " + wanted.join(","));
		a.RPC_updateAvatarSlots(cast wanted[0], cast wanted[1], cast wanted[2], cast wanted[3], null, function(_) {
			log("training request refused by the server");
			pendingHero = "";
			notify(name + ": the server refused the planned training points", false);
		});
	}

	/** The row name the Training screen shows, like "Melee Power" (each word capitalized). */
	public static function statName(a:AvatarInfo, index:Int):String {
		var text = "";
		try {
			var constant:String = cast Reflect.field(a.gmHero, "StatUpgrade" + (index + 1));
			text = facade.GameMasterLocale.getGameMasterSubString("STATS_NAME", constant);
		} catch (error:Dynamic) {
			ErrorLog.report("Could not read a stat name", error);
		}
		if (text == null || text == "")
			text = ["Stat 1", "Stat 2", "Stat 3", "Stat 4"][index];
		return titleCase(text);
	}

	public static function titleCase(text:String):String {
		var words:Array<String> = [];
		for (word in text.toLowerCase().split(" "))
			words.push(word.length == 0 ? word : word.charAt(0).toUpperCase() + word.substr(1));
		return words.join(" ");
	}

	/** A level-up in a dungeon earns points before the account data shows them; ask for fresh data once. */
	function refreshAfterLevelUp(now:Float):Void {
		var a = native.avatar();
		if (a == null)
			return;
		var hero = Std.string(a.id);
		var level = native.level(a);
		if (hero == lastHero && lastLevel >= 0 && level > lastLevel && level > Std.int(a.cloutLevel) && now >= refreshAt) {
			refreshAt = now + 10;
			try
				native.facade().dbAccountInfo.getUsersFullAccountInfo()
			catch (error:Dynamic) {
				ErrorLog.report("Could not refresh account info after a level-up", error);
			}
		}
		lastHero = hero;
		lastLevel = level;
	}
}
