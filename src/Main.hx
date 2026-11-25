package mods.ascension_helper;

import brain.event.EventComponent;
import brain.stateMachine.State;
import brain.stateMachine.StateMachine;
import mods.api.Context;
import mods.api.Subscription;
import mods.api.settings.Flag;
import openfl.events.Event;
import town.InventoryTownSubState;
import town.TrainTownSubState;

class Main extends mods.api.Mod {
	var ctx:Context;
	var native:Native;
	var store:Store;
	var editor:Editor;
	var inventoryState:State;
	var trainingState:State;
	var statStore:StatStore;
	var statPlanner:StatPlanner;
	var statSpender:StatSpender;
	var autoTrain:Flag;
	var accountId = "0";
	var enabled:Flag;
	var subs:Array<Subscription> = [];
	var coreSubs:Array<modding.ModSubscription> = [];
	var events:EventComponent;
	var gate = new Gate();
	var levelTrigger = new LevelTrigger();
	var next = 0.0;
	var quietUntil = 0.0;
	var revision = "";
	var alive = false;
	var uncertain = false;
	var epoch = 0;
	var needsReconcile = true;
	var faultShown = false;
	var blockedNotice = "";
	var auditAt = 0.0;
	var nextHygiene = 0.0;
	var toast:Toast;

	override public function init(context:Context):Void {
		ctx = context;
		ErrorLog.reset(function(message) context.log(message));
		native = new Native(ctx);
		enabled = ctx.settings.flag("autoEquip", "Automatic equipment", "Equip saved weapons when their level is reached.", true);
		autoTrain = ctx.settings.flag("autoTrain", "Automatic training", "Spend training points by each hero's saved plan.", true);
		coreSubs.push(ctx.core.onStateEnter(function(machine:StateMachine, state:State) {
			wake(true);
			quietUntil = clock() + 0.25;
			if (Std.isOfType(state, InventoryTownSubState))
				inventoryState = state;
			if (Std.isOfType(state, TrainTownSubState))
				trainingState = state;
		}));
		coreSubs.push(ctx.core.onStateExit(function(machine:StateMachine, state:State) {
			wake(true);
			if (state == trainingState) {
				if (statPlanner != null)
					statPlanner.tick(null);
				trainingState = null;
			}
			if (state == inventoryState) {
				if (editor != null)
					editor.close(true);
				inventoryState = null;
				quietUntil = clock() + 1;
			}
		}));
		subs.push(ctx.onHeroSpawned(function(hero) {
			if (hero.local) {
				native.live = hero;
				wake(true);
				revision = "";
			}
		}));
		subs.push(ctx.onHeroDespawned(function(hero) {
			if (native.live == hero) {
				native.live = null;
				wake(true);
				quietUntil = clock() + 1;
			}
		}));
		subs.push(ctx.onTownEnter(function() {
			native.live = null;
			wake(true);
			revision = "";
		}));
		subs.push(ctx.onFloorEnter(function(_) {
			wake(true);
			revision = "";
		}));
	}

	override public function ready(context:Context):Void {
		alive = true;
		toast = new Toast(ctx.overlay);
		statPlanner = new StatPlanner(native, function() {
			return statStore;
		}, notify);
		statSpender = new StatSpender(native, notify, function(text) ctx.log(text));
		editor = new Editor(ctx, native, function() {
			return store;
		}, notify, function() {
			wake(true);
			revision = "";
			quietUntil = clock() + 1;
		});
		events = new EventComponent(ctx.core.facade);
		events.addListener("DB_ACCOUNT_INFO_RESPONSE", function(_) {
			if (!alive)
				return;
			if (editor != null)
				editor.invalidate();
			quietUntil = clock() + 0.5;
			needsReconcile = true;
		});
		ctx.overlay.addEventListener(Event.ENTER_FRAME, frame);
	}

	function wake(resetFailures:Bool = false):Void {
		needsReconcile = true;
		auditAt = 0;
		if (resetFailures)
			gate.reset();
	}

	static function clock():Float
		return haxe.Timer.stamp();

	function notify(message:String, good:Bool = true):Void {
		if (ctx != null)
			ctx.log("message: " + message.split("\n").join(" / "));
		if (toast != null)
			toast.show(message, good);
	}

	/** Loading screens hide messages; one cut short there is shown again once loading has finished. */
	function loading():Bool {
		var f = native.facade();
		var machine:Dynamic = f == null ? null : Reflect.getProperty(f, "mainStateMachine");
		var state:String = machine == null ? null : Std.string(Reflect.getProperty(machine, "currentStateName"));
		return state != null && (state.indexOf("Loading") >= 0 || state.indexOf("Reload") >= 0);
	}

	function frame(_:Event):Void {
		var now = clock();
		if (now < next)
			return;
		next = now + 0.25;
		if (toast != null)
			toast.tick(now, loading());
		try {
			var id = native.account();
			if (id != accountId) {
				if (editor != null)
					editor.close(true);
				epoch++;
				gate = new Gate();
				levelTrigger = new LevelTrigger();
				faultShown = false;
				needsReconcile = true;
				accountId = id;
				store = Plan.validId(id) ? new Store(ctx.data, id) : null;
				if (statPlanner != null)
					statPlanner.tick(null);
				statStore = Plan.validId(id) ? new StatStore(ctx.data, id) : null;
				revision = "";
				if (store != null && store.recovered)
					notify("Recovered saved selections. Open Ascension Helper to review them.");
			}
			// Plans follow the account: on login, after a sale and every 2 s, whatever else is switched on.
			if (store != null && (editor == null || !editor.editing) && now >= nextHygiene) {
				nextHygiene = now + 2;
				var removed = PlanHygiene.run(store, native);
				if (removed > 0) {
					needsReconcile = true;
					notify(PlanHygiene.message(removed), true);
				}
			}
			if (editor != null)
				editor.tick(inventoryState);
			// Left by joining a dungeon, the Training screen may never report closing, and it reports
			// opening before it is drawn: keep the state and check each tick whether it is on screen.
			var trainingOpen = StatPlanner.screenOpen(trainingState);
			if (statPlanner != null)
				statPlanner.tick(trainingOpen ? trainingState : null);
			// The Training screen holds its own unsaved stat values, so auto-training waits while it is open.
			if (autoTrain.value && statSpender != null)
				statSpender.tick(now, statStore, trainingOpen);
			if (!enabled.value || store == null || now < quietUntil || editor.editing)
				return;
			reconcile(now);
		} catch (error:Dynamic) {
			if (!faultShown) {
				faultShown = true;
				notify("Ascension Helper paused: " + Std.string(error), false);
				ctx.log("Paused after an adapter or save error: " + Std.string(error));
			}
		}
	}

	function reconcile(now:Float):Void {
		if (faultShown)
			return;
		if (gate.pending != null) {
			if (gate.timeout(now) && !uncertain) {
				uncertain = true;
				notify("Equipment request is still pending. No further requests will be sent.", false);
			}
			return;
		}
		var a = native.avatar();
		if (a == null)
			return;
		var hero = Std.string(a.id);
		var levelPlans = levelTrigger.needsPlans(hero, cast a.mAscensionLevel, cast a.cloutLevel) ? store.committed(hero) : [];
		levelTrigger.observe(hero, cast a.mAscensionLevel, cast a.cloutLevel, levelPlans);
		if (levelTrigger.jobs.length == 0)
			return;
		var level = native.level(a);
		var current = hero + ":" + level + ":" + a.mAscensionLevel + ":" + a.cloutLevel;
		if (revision != current) {
			revision = current;
			gate.reset();
			needsReconcile = true;
		}
		if (!needsReconcile && now < auditAt)
			return;
		auditAt = now + 2;
		needsReconcile = false;
		var plans = store.committed(hero);
		for (slot in 0...3) {
			var p = Plan.desired(levelTrigger.jobs, slot, level);
			if (p == null)
				continue;
			var saved = Plan.desired(plans, slot, cast a.cloutLevel);
			if (saved == null || saved.uid != p.uid || native.equipped(p.uid, hero, slot)) {
				levelTrigger.done(p);
				continue;
			}
			var equippedLevel = native.equippedLevel(hero, slot);
			// Old equipment may remain briefly while the server publishes an ascension reset.
			// Only equipment valid at the confirmed new level can suppress a lower planned weapon.
			if (equippedLevel > p.level && equippedLevel <= a.cloutLevel) {
				levelTrigger.done(p);
				continue;
			}
			var key = current + ":" + slot + ":" + p.uid;
			if (!native.eligible(a, p.uid)) {
				levelTrigger.done(p);
				if (blockedNotice != key) {
					blockedNotice = key;
					notify("Planned weapon unavailable for slot " + (slot + 1) + ". Review your saved selections.", false);
				}
				continue;
			}
			if (!gate.begin(key, now))
				continue;
			uncertain = false;
			var requestedEpoch = epoch;
			var requestedAccount = accountId;
			var requestedHero = hero;
			var requestedUid = p.uid;
			var requestedSlot = slot;
			try
				native.equip(hero, p.uid, slot, function() {
					if (!alive || requestedEpoch != epoch || requestedAccount != accountId)
						return;
					var confirmed = native.equipped(requestedUid, requestedHero, requestedSlot);
					gate.finish(key, confirmed);
					levelTrigger.done(p);
					needsReconcile = true;
					quietUntil = clock() + 0.5;
					if (confirmed)
						notify("Weapon equipped in slot "
							+ (requestedSlot + 1)
							+ (ctx.state.inTown ? "." : " on the account. Current dungeon update depends on the server."));
					else
						notify("Server response did not confirm the planned slot. Automatic retry stopped.", false);
				}, function() {
					if (!alive || requestedEpoch != epoch || requestedAccount != accountId)
						return;
					gate.finish(key, false);
					levelTrigger.done(p);
					needsReconcile = true;
					notify("Server rejected the weapon change. It will be reconsidered at the next level-up.", false);
				})
			catch (e:Dynamic) {
				gate.finish(key, false);
				needsReconcile = true;
				throw e;
			}
			return;
		}
	}

	override public function dispose():Void {
		alive = false;
		if (editor != null)
			editor.dispose();
		if (statPlanner != null)
			statPlanner.detach();
		if (events != null)
			events.destroy();
		for (s in subs)
			s.cancel();
		for (s in coreSubs)
			s.cancel();
		if (ctx != null)
			ctx.overlay.removeEventListener(Event.ENTER_FRAME, frame);
		if (toast != null)
			toast.dispose();
		ErrorLog.reset();
	}
}
