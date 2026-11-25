package mods.ascension_helper;

import account.AvatarInfo;
import account.ItemInfo;
import facade.DBFacade;
import gameMasterDictionary.GMAttack;
import mods.api.Context;
import mods.api.dungeon.Hero;

/** Version-specific reads and the game's ordinary server equip request. */
class Native {
	public var ctx:Context;
	public var live:Hero;

	public function new(ctx:Context)
		this.ctx = ctx;

	public function facade():DBFacade
		return ctx.core.facade;

	public function account():String
		return ctx.state.account == null ? "0" : Std.string(ctx.state.account.id);

	public function avatar():AvatarInfo {
		var f = facade();
		return f == null || f.dbAccountInfo == null ? null : f.dbAccountInfo.activeAvatarInfo;
	}

	public function hero(id:String):AvatarInfo {
		var f = facade();
		return f == null
			|| f.dbAccountInfo == null ? null : f.dbAccountInfo.inventoryInfo.getAvatarInfoForAvatarInstanceId(cast Std.parseInt(id));
	}

	/**
	 * Whether the account inventory is loaded enough to tell that a weapon is gone: it must hold at
	 * least one weapon. Before that (or during loading) nothing is treated as missing.
	 */
	public function inventoryReady():Bool {
		var f = facade();
		if (f == null || f.dbAccountInfo == null || f.dbAccountInfo.inventoryInfo == null || f.dbAccountInfo.inventoryInfo.items == null)
			return false;
		var iter = f.dbAccountInfo.inventoryInfo.items.iterator();
		while (iter.hasNext()) {
			var it:ItemInfo = cast iter.next();
			if (it != null && it.gmWeaponItem != null)
				return true;
		}
		return false;
	}

	/** Whether this weapon is still owned. Only meaningful while inventoryReady() is true. */
	public function owned(uid:String):Bool {
		return item(uid) != null;
	}

	public function item(uid:String):ItemInfo {
		var f = facade();
		return f == null || f.dbAccountInfo == null ? null : cast f.dbAccountInfo.inventoryInfo.items.itemFor(Std.parseInt(uid));
	}

	public function level(a:AvatarInfo):Int {
		var result:Int = cast a.cloutLevel;
		if (live != null && live.local && live.classId == a.avatarType)
			if (live.level > 0)
				result = cast live.level;
		return result;
	}

	public function list(a:AvatarInfo):Array<Weapon> {
		var result:Array<Weapon> = [];
		var f = facade();
		if (a == null || f == null || f.dbAccountInfo == null)
			return result;
		var iter = f.dbAccountInfo.inventoryInfo.items.iterator();
		while (iter.hasNext()) {
			var it:ItemInfo = cast iter.next();
			if (it == null || it.gmWeaponItem == null || it.rarity == null || it.rarity.Id < 1 || it.rarity.Id > 4)
				continue;
			if (it.avatarId != 0 && it.avatarId != a.id)
				continue;
			if (!f.dbAccountInfo.inventoryInfo.canAvatarEquipThisMasterType(a, it.gmWeaponItem.MasterType))
				continue;
			var w = new Weapon(Std.string(it.databaseId), it.gmWeaponItem.MasterType, cast it.requiredLevel, cast it.rarity.Id, it.power,
				Std.string(it.avatarId));
			w.name = it.Name;
			w.aptitude = it.legendaryModifier == 2;
			var gm = it.gmWeaponItem;
			w.speed = valid(gm.Speed, 1);
			w.projectile = gameMasterDictionary.GMWeaponItem.SHOOTING_WEAPON_SORT.indexOf(gm.MasterType) >= 0
				|| gameMasterDictionary.GMWeaponItem.MAGIC_WEAPON_SORT.indexOf(gm.MasterType) >= 0;
			w.charged = gm.ChargeAttack != null && gm.ChargeAttack != "";
			for (name in gm.AttackArray) {
				if (name == null || name == "")
					continue;
				var attack:GMAttack = cast f.gameMaster.attackByConstant.itemFor(name);
				if (attack != null && attack.ManaCost > 0)
					w.usesMana = true;
			}
			if (gm.ChargeAttack != null && gm.ChargeAttack != "") {
				var charge:GMAttack = cast f.gameMaster.attackByConstant.itemFor(gm.ChargeAttack);
				if (charge != null && charge.ManaCost > 0)
					w.usesMana = true;
			}
			for (m in it.modifiers) {
				if (m == null)
					continue;
				var n = Std.int(Math.max(1, Math.min(5, m.Level)));
				var type = m.Type;
				switch (type) {
					case "MANA_COST":
						w.mana *= valid(m.MP_COST, 1);
					case "ATKSPD":
						w.speed *= valid(m.MELEE_SPD, 1);
					case "DAMAGE":
						w.damage *= 1 + 0.1 * n;
					case "CRIT_CHANCE":
						w.critChance += [0.1, 0.125, 0.15, 0.2, 0.25][n - 1];
						w.critBonus += 1;
					case "CRIT_DAMAGE":
						w.critChance += 0.05;
						w.critBonus += 1.5 + 0.5 * n;
					case "COOLDOWN_REDUC":
						w.cooldown *= valid(m.COOLDOWN_REDUC, 1);
					case "CHARGE_REDUC":
						w.charge *= valid(m.CHARGE_REDUC, 1);
					case "SCALING":
						if (w.charged)
							w.extraProjectiles += cast m.MAX_PROJECTILES;
					case "CHAIN", "PIERCE":
						if (w.projectile)
							w.utility += 5 * n;
					case "BURNING", "POISON":
						w.utility += 4 * n;
					case "INCREASE_COLLISION":
						w.utility += 3 * n;
					case "BUFF_GRANT_DURATION_MULTIPLIER":
						w.utility += 2 * n;
					case "SHOCKING", "STUN", "CHILLING", "ROOT", "SLOW", "CRIPPLE":
						w.utility += n;
					case "PULL", "KNOCKBACK":
						w.utility += n * 0.5;
					case "SPAWN_FOOD_ON_HIT", "DEATH_FOOD":
						w.utility += n * 0.25;
					default:
				}
			}
			if (it.legendaryModifier == 7 || it.legendaryModifier == 8)
				w.utility += 1;
			result.push(w);
		}
		result.sort(function(a, b) return a.level != b.level ? a.level - b.level : Weapon.compare(a, b));
		return result;
	}

	static function valid(n:Float, fallback:Float):Float
		return Math.isNaN(n) || !Math.isFinite(n) || n <= 0 ? fallback : n;

	public function equipped(uid:String, hero:String, slot:Int):Bool {
		var value = item(uid);
		return value != null && Std.string(value.avatarId) == hero && value.avatarSlot == slot;
	}

	/** Read every owned item, including equipment absent from the saved plan. */
	public function equippedLevel(hero:String, slot:Int):Int {
		var f = facade();
		if (f == null || f.dbAccountInfo == null)
			return 0;
		var result = 0;
		var items = f.dbAccountInfo.inventoryInfo.items.iterator();
		while (items.hasNext()) {
			var item:ItemInfo = cast items.next();
			if (item != null && Std.string(item.avatarId) == hero && item.avatarSlot == slot)
				result = Std.int(Math.max(result, item.requiredLevel));
		}
		return result;
	}

	public function eligible(a:AvatarInfo, uid:String):Bool {
		var value = item(uid);
		if (value == null || value.gmWeaponItem == null || a == null)
			return false;
		if (value.avatarId != 0 && value.avatarId != a.id)
			return false;
		return value.requiredLevel <= level(a)
			&& facade().dbAccountInfo.inventoryInfo.canAvatarEquipThisMasterType(a, value.gmWeaponItem.MasterType);
	}

	public function equip(hero:String, uid:String, slot:Int, success:Void->Void, failure:Void->Void):Void {
		facade().dbAccountInfo.inventoryInfo.equipItemOnAvatar(cast Std.parseInt(hero), cast Std.parseInt(uid), cast slot, success, failure);
	}
}
