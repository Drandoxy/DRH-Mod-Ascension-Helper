package mods.ascension_helper;

import account.AvatarInfo;
import brain.uI.UIButton;
import gameMasterDictionary.GMInventoryBase;
import mods.api.Context;
import openfl.display.DisplayObject;
import openfl.display.DisplayObjectContainer;
import openfl.display.MovieClip;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.events.MouseEvent;
import openfl.geom.Rectangle;
import openfl.text.TextField;
import town.InventoryTownSubState;
import brain.stateMachine.State;
import uI.equipPicker.HeroWithEquipPicker;
import uI.inventory.UIInventory;
import uI.inventory.UIInventoryItem;

/** Owns only added controls; borrowed native visibility and labels are restored on exit. */
class Editor {
	var ctx:Context;
	var native:Native;
	var getStore:Void->Store;
	var notify:(String, Bool) -> Void;
	var changed:Void->Void;
	var inv:UIInventory;
	var root:MovieClip;
	var grid:MovieClip;
	var stableCardBounds:Rectangle;
	var storageOverlays:StorageOverlays;
	var picker:HeroWithEquipPicker;
	var ui:NativeUI;
	var entry:UIButton;
	var storageButton:UIButton;
	var oldStorageRight:brain.uI.UIObject;
	var layer:Sprite;
	var slotLayer:Sprite;
	var gridBackdrop:Sprite;
	var controls:Array<UIButton> = [];
	var slotHits:Array<Sprite> = [];
	// Ascension slots copy the equipped card look: the same frame, sized and placed like the cards.
	var slotCards:Array<Sprite> = [];
	var slotCardBounds:Array<Rectangle> = [];
	var slotCardState:Array<Int> = [];
	var slotHover:Array<Bool> = [];
	// Controller targets for the J/K/L slots; mouse input stays on the slot hit areas.
	var slotButtons:Array<UIButton> = [];
	var slotTransforms:Array<{node:DisplayObject, x:Float, y:Float, sx:Float, sy:Float}> = [];
	var cells:Array<UIInventoryItem> = [];
	var stars:Array<Sprite> = [];
	var tileModifiers:Array<TileModifiers> = [];
	var cardViews:Array<CardVisual> = [];
	var cellBounds:Array<Rectangle> = [];
	var slotFilters:Array<Array<openfl.filters.BitmapFilter>> = [];
	var hidden:Array<{node:DisplayObject, visible:Bool}> = [];
	var pickerLabel:TextField;
	var oldLabel = "";
	var planDirty = true;
	var heroId = "0";
	var heroName = "";
	var draft:Array<Plan> = [];
	var all:Array<Weapon> = [];
	var visible:Array<Weapon> = [];
	var types:Array<String> = [];
	var typeIndex = 0;
	var rarity = 0;
	var levelDropdown:Dropdown;
	var levelIndex = 0;
	var levelOptions:Array<String> = ["LEVEL: ALL"];
	var typeDropdown:Dropdown;
	var rarityDropdown:Dropdown;
	var planList:PlanList;

	var promptFormats:Array<{label:TextField, format:openfl.text.TextFormat}> = [];
	var heroTooltips:Array<{object:brain.uI.UIObject, tooltip:MovieClip}> = [];
	var autoButton:UIButton;
	var noneButton:UIButton;

	var pageLabel:TextField;
	var pageCenter:Float = 0;
	var pageMiddle:Float = 0;
	var concealStage:openfl.display.Stage;
	var selectorNodes:Array<DisplayObject> = [];
	var slot = -1;
	var page = 0;
	var dirty = true;
	var busy = false;
	var pendingAction:Void->Void;
	var frameBounds:Array<Rectangle> = [];
	var slotBounds:Array<Rectangle> = [];

	public var editing(default, null) = false;

	public function new(ctx:Context, native:Native, getStore:Void->Store, notify:(String, Bool) -> Void, changed:Void->Void) {
		this.ctx = ctx;
		this.native = native;
		this.getStore = getStore;
		this.notify = notify;
		this.changed = changed;
	}

	public function invalidate():Void
		dirty = true;

	public function tick(state:State):Void {
		if (pendingAction != null) {
			var action = pendingAction;
			pendingAction = null;
			try
				action()
			catch (e:Dynamic)
				notify("Could not update selections: " + Std.string(e), false);
		}
		if (state == null) {
			detach();
			return;
		}
		var next:UIInventory = cast Reflect.field(state, "mUIInventory");
		if (next == null || next.root == null || next.root.stage == null)
			return;
		if (inv != next) {
			detach();
			mount(next);
		}
		if (entry == null)
			return;
		var loot = Reflect.field(inv, "mCurrentTab") == GMInventoryBase.WEAPON_CATEGORY;
		entry.visible = !editing && loot;
		if (!editing) {
			storageOverlays.update(loot);
			return;
		}
		if (!loot) {
			close(true);
			return;
		}
		var a = picker.currentlySelectedAvatarInfo;
		if (a == null) {
			close(true);
			notify("Choose an owned hero before configuring weapons.", false);
			return;
		}
		if (heroId != Std.string(a.id)) {
			commit();
			beginHero(a);
			selectSlot(initialSlot());
			dirty = true;
		}
		maintain();
		if (dirty) {
			dirty = false;
			rebuild();
		}
		linkController();
	}

	/** Links all visible editor controls for controller navigation; an open filter list keeps focus. */
	function linkController():Void {
		var targets:Array<Dynamic> = [];
		var lists = [typeDropdown, rarityDropdown, levelDropdown];
		try {
			for (d in lists)
				if (d != null && d.isOpen) {
					for (b in d.buttons)
						targets.push(b);
					Navigator.link(targets);
					return;
				}
			for (b in slotButtons)
				targets.push(b);
			for (b in controls)
				targets.push(b);
			for (d in lists)
				if (d != null)
					targets.push(d.trigger);
			if (planList != null)
				for (b in planList.deleteButtons)
					targets.push(b);
			for (i in 0...cells.length) {
				var cell = cells[i];
				if (cell == null || cell.info == null)
					continue;
				var view = i < cardViews.length ? cardViews[i] : null;
				if (view != null && view.style != null) {
					var style = view.style;
					cell.navigationSelectedInteraction = function() style.setHover(true);
					cell.navigationSetToUnselectedInteraction = function() style.setHover(false);
				}
				targets.push(cell);
			}
			Navigator.link(targets);
		} catch (error:Dynamic) {
			// Controller navigation is optional; mouse use is unaffected.
			ErrorLog.report("Could not link the planner for the controller", error);
		}
	}

	function mount(value:UIInventory):Void {
		inv = value;
		root = cast Reflect.field(inv, "mInventoryRoot");
		var asset:brain.assetRepository.SwfAsset = cast Reflect.field(inv, "mSwfAsset");
		picker = cast Reflect.field(inv, "mHeroWithEquipPicker");
		if (root == null || asset == null || picker == null) {
			inv = null;
			return;
		}
		grid = NativeUI.clipChild(root, "grid_widget");
		if (grid == null) {
			inv = null;
			return;
		}
		ui = new NativeUI(asset, native.facade());
		storageOverlays = new StorageOverlays(ui, native, grid, inv, function() return showCardDetails());
		var card = NativeUI.clipChild(root, "item_card");
		var background = NativeUI.child(card, "bg");
		stableCardBounds = background == null ? (card == null ? null : card.getBounds(root)) : background.getBounds(root);
		var storage = NativeUI.child(grid, "add_storage_button");
		if (storage == null) {
			inv = null;
			return;
		}
		var face = NativeUI.child(cast storage, "up");
		var bounds = face == null ? storage.getBounds(grid) : face.getBounds(grid);
		bounds.y += 1.5;
		bounds.height = Math.max(10, bounds.height - 3);
		var right = NativeUI.child(grid, "slot_4").getBounds(grid);
		var available = Math.max(80, right.x + right.width - bounds.x - bounds.width - 12);
		entry = ui.button(grid, "ASCENSION", new Rectangle(bounds.x + bounds.width + 12, bounds.y, available, bounds.height), open);
		storageButton = cast Reflect.field(inv, "mAddStorageButton");
		if (storageButton != null) {
			oldStorageRight = storageButton.rightNavigation;
			storageButton.clearRightNavigation();
			storageButton.rightNavigation = entry;
			entry.leftNavigation = storageButton;
		}
	}

	function open():Void {
		if (editing || inv == null || getStore() == null)
			return;
		var a = picker.currentlySelectedAvatarInfo;
		if (a == null) {
			notify("Select an owned hero first.", false);
			return;
		}
		var step = "plan cleanup";
		try {
			// First, before touching any native card: a sold weapon leaves the plan.
			dropMissingWeapons(Std.string(a.id));
			editing = true;
			step = "storage overlays";
			storageOverlays.update(false);
			entry.visible = false;
			step = "hero";
			beginHero(a);
			step = "layout";
			build();
			maintain();
			step = "weapon list";
			rebuild();
			step = "slot";
			selectSlot(initialSlot());
			dirty = false;
			step = "controller";
			linkController();
			if (slot < slotButtons.length)
				ui.focus(slotButtons[slot]);
		} catch (error:Dynamic) {
			editing = false;
			cleanup();
			// Shown instead of silently doing nothing when the planner cannot open; the step helps a report.
			ErrorLog.report("Could not open the weapon planner (" + step + ")", error);
			notify("Could not open the weapon planner (" + step + "): " + Std.string(error), false);
		}
	}

	/** Sold or otherwise gone weapons leave the plan, so the planner and auto-equip never use them. */
	function dropMissingWeapons(hero:String):Void {
		if (!native.inventoryReady())
			return;
		var removed = getStore().prune(hero, function(uid) return native.owned(uid));
		if (removed > 0)
			notify(removed == 1 ? "Removed 1 weapon you no longer own from the plan." : "Removed " + removed
				+ " weapons you no longer own from the plan.", true);
	}

	function initialSlot():Int {
		var chosen:account.InventoryBaseInfo = cast Reflect.field(inv, "mSelectedItemInfo");
		var equipped:openfl.Vector<uI.equipPicker.AvatarEquipElement> = cast Reflect.field(picker, "mEquipElements");
		if (chosen != null && equipped != null)
			for (i in 0...equipped.length)
				if (equipped[i].itemInfo == chosen)
					return i;
		for (i in 0...3)
			for (p in draft)
				if (p.slot == i)
					return i;
		return 0;
	}

	function beginHero(a:AvatarInfo):Void {
		heroId = Std.string(a.id);
		heroName = a.gmHero.Name;
		draft = getStore().edit(heroId);
		planDirty = true;
		slot = -1;
		page = 0;
		typeIndex = 0;
		rarity = 0;
		all = native.list(a);
		types = [""];
		for (w in all)
			if (types.indexOf(w.type) < 0)
				types.push(w.type);
		levelIndex = 0;
	}

	function hide(node:DisplayObject):Void {
		if (node == null)
			return;
		for (v in hidden)
			if (v.node == node) {
				node.visible = false;
				return;
			}
		hidden.push({node: node, visible: node.visible});
		node.visible = false;
	}

	function build():Void {
		layer = new Sprite();
		root.addChild(layer);
		slotLayer = new Sprite();
		picker.root.addChild(slotLayer);
		frameBounds = [];
		slotBounds = [];
		cellBounds = [];
		slotFilters = [];
		var tabs:Array<DisplayObject> = [];
		for (name in ["tab_weapons", "tab_potions", "tab_pets", "tab_stuff"]) {
			var node = NativeUI.child(grid, name);
			if (node != null)
				tabs.push(node);
		}
		if (tabs.length == 0)
			throw "Native inventory tabs are unavailable";
		var top = tabs[0].getBounds(root);
		for (node in tabs)
			top = top.union(node.getBounds(root));
		for (node in tabs)
			hide(node);
		// The grey category background and its dividers are separate unnamed native children.
		for (i in 0...grid.numChildren) {
			var node = grid.getChildAt(i);
			if (node == null || tabs.indexOf(node) >= 0)
				continue;
			var named = false;
			for (name in ["add_storage_button", "pagination"])
				if (node == NativeUI.child(grid, name))
					named = true;
			for (index in 0...15)
				if (node == NativeUI.child(grid, "slot_" + index))
					named = true;
			if (!named) {
				var b = node.getBounds(root);
				if (b.y < top.y + top.height && b.y + b.height > top.y)
					hide(node);
			}
		}
		var body:Rectangle = null;
		for (i in 0...15) {
			var frame = NativeUI.child(grid, "slot_" + i);
			if (frame != null)
				body = body == null ? frame.getBounds(root) : body.union(frame.getBounds(root));
		}
		if (body != null) {
			var storage = NativeUI.child(grid, "add_storage_button");
			if (storage != null)
				body = body.union(storage.getBounds(root));
			body.x = top.x - 18;
			body.width = top.width + 36;
			var bottomEdge = body.y + body.height + 14;
			body.y = top.y + top.height * 0.20;
			body.height = bottomEdge - body.y;
			gridBackdrop = new Sprite();
			root.addChild(gridBackdrop);
			root.setChildIndex(gridBackdrop, root.getChildIndex(grid));
			ui.wood(gridBackdrop, body);
		}
		var pad = top.width * 0.025;
		var gap = top.width * 0.026;
		var width = top.width - pad * 2;
		var barH = top.height * 0.30;
		var rowH = top.height * 0.22;
		var ribbonWidth = Math.min(width * 0.52, 340.);
		ui.ribbon(layer, new Rectangle(top.x + (top.width - ribbonWidth) / 2, top.y, ribbonWidth, barH), "SELECT WEAPONS");
		var half = (width - gap) / 2;
		autoButton = add("AUTO SELECT", new Rectangle(top.x + pad, top.y + barH + 8, half, rowH), auto);
		noneButton = add("NONE", new Rectangle(top.x + pad + half + gap, top.y + barH + 8, half, rowH), clear, false);
		var third = (width - gap * 2) / 3;
		var filterY = top.y + barH + rowH + 25;
		typeDropdown = new Dropdown(ui, layer, new Rectangle(top.x + pad, filterY, third, rowH), ["TYPE: ALL"], function(value) {
			typeIndex = value;
			page = 0;
			filter();
		});
		rarityDropdown = new Dropdown(ui, layer, new Rectangle(top.x + pad + third + gap, filterY, third, rowH),
			["RARITY: ALL", "COMMON+", "UNCOMMON+", "RARE+", "LEGENDARY"], function(value) {
				rarity = value;
				page = 0;
				filter();
		});
		levelDropdown = new Dropdown(ui, layer, new Rectangle(top.x + pad + 2 * (third + gap), filterY, third, rowH), ["LEVEL: ALL"], function(value) {
			levelIndex = value;
			page = 0;
			filter();
		});

		// Disable only the hero tooltips while editing; hero selection remains usable.
		var heroes:openfl.Vector<uI.equipPicker.HeroElement> = cast Reflect.field(picker, "mHeroSlots");
		if (heroes != null)
			for (hero in heroes)
				if (hero != null) {
					var original = hero.tooltip;
					heroTooltips.push({object: hero, tooltip: original});

					hero.tooltip = null;
					var tip:uI.inventory.UIHeroTooltip = cast Reflect.field(hero, "mHeroTooltip");
					if (tip != null)
						tip.visible = false;
				}
		var card = NativeUI.child(root, "item_card");
		if (card != null) {
			var source = stableCardBounds;
			var area = new Rectangle(source.x, source.y, source.width, source.height);
			if (body != null) {
				area.y = body.y;
				area.height = body.height;
			}
			// Same top edge; the bottom sits about 5% higher.
			area.height *= 0.95;
			planList = new PlanList(ui, native, layer, area, function(uid, selectedSlot, level) {
				pendingAction = function() {
					var next = [
						for (p in draft)
							if (!(p.uid == uid && p.slot == selectedSlot && p.level == level)) p.copy()
					];
					persist(next);
				};
			});
		}

		var addStorage = NativeUI.child(grid, "add_storage_button");
		var bottom = addStorage.getBounds(root);
		bottom.height *= 0.78;
		bottom.width = width * 0.48;
		bottom.x = top.x + (top.width - bottom.width) / 2;
		hide(addStorage);
		add("CANCEL", new Rectangle(bottom.x, bottom.y, (bottom.width - gap) / 2, bottom.height), function() {
			close(false);
		}, true);
		add("SAVE", new Rectangle(bottom.x + (bottom.width + gap) / 2, bottom.y, (bottom.width - gap) / 2, bottom.height), function() {
			close(true);
		});
		var pagination = NativeUI.child(grid, "pagination");
		var pb = pagination.getBounds(root);
		pb.x = top.x + pad;
		pb.width = width;
		pb.height *= 0.72;
		hide(pagination);
		add("PREVIOUS", new Rectangle(pb.x, pb.y, pb.width * 0.22, pb.height), function() {
			if (page > 0) {
				page--;
				render();
			}
		}, false);
		add("NEXT", new Rectangle(pb.x + pb.width * 0.78, pb.y, pb.width * 0.22, pb.height), function() {
			if ((page + 1) * 15 < visible.length) {
				page++;
				render();
			}
		}, false);
		pageLabel = ui.text(layer, "PAGE 1 / 1", new Rectangle(pb.x + pb.width * 0.24, pb.y, pb.width * 0.52, pb.height), 0xFFE68C);
		var pageFormat = pageLabel.defaultTextFormat;
		pageFormat.size = Math.round(cast(pageFormat.size, Float) * 1.3);
		pageLabel.defaultTextFormat = pageFormat;
		pageLabel.setTextFormat(pageFormat);
		pageCenter = pb.x + pb.width / 2;
		pageMiddle = pb.y + pb.height / 2;
		pickerLabel = cast NativeUI.child(picker.root, "label");
		if (pickerLabel != null) {
			oldLabel = pickerLabel.text;
			pickerLabel.text = "SELECT A SLOT";
		}
		var names = ["empty_z", "empty_x", "empty_c"];
		var weaponsPanel = NativeUI.clipChild(picker.root, "UI_weapons");
		for (i in 0...3) {
			var nativeSlot = NativeUI.child(picker.root, names[i]);
			if (nativeSlot == null)
				throw "Native weapon slot unavailable";
			hide(nativeSlot);
			selectorNodes.push(nativeSlot);
			slotFilters.push(nativeSlot.filters.copy());
			var b = nativeSlot.getBounds(picker.root);
			var equipCell = weaponsPanel == null ? null : NativeUI.clipChild(weaponsPanel, "equip_slot_" + i);
			var cardFrame = equipCell == null ? null : NativeUI.child(equipCell, "frame");
			var card = new Sprite();
			card.name = "ascensionSlotFrame";
			card.mouseEnabled = false;
			if (cardFrame != null) {
				// Same bounds as the equipped card; the stone slot art is fitted inside its frame.
				b = cardFrame.getBounds(picker.root);
				fitInto(nativeSlot, b);
				equipCell.addChild(card);
				var letter = NativeUI.child(equipCell, "label");
				if (letter != null)
					equipCell.setChildIndex(card, equipCell.getChildIndex(letter));
				slotCardBounds.push(cardFrame.getBounds(equipCell));
			} else {
				slotLayer.addChild(card);
				slotCardBounds.push(b);
			}
			slotCards.push(card);
			slotCardState.push(-1);
			slotBounds.push(b);
			var hit = new Sprite();
			slotLayer.addChild(hit);
			hit.graphics.beginFill(0xFFFFFF, 0.01);
			hit.graphics.drawRect(b.x, b.y, b.width, b.height);
			hit.graphics.endFill();
			hit.buttonMode = true;
			var chosen = i;
			hit.addEventListener(MouseEvent.CLICK, function(e:MouseEvent) {
				e.stopImmediatePropagation();
				selectSlot(chosen);
			});
			// Hover looks like the equipped cards: the frame turns cyan, no glow.
			slotHover.push(false);
			var pad = new MovieClip();
			pad.mouseEnabled = false;
			pad.mouseChildren = false;
			pad.graphics.beginFill(0xFFFFFF, 0);
			pad.graphics.drawRect(b.x, b.y, b.width, b.height);
			pad.graphics.endFill();
			hit.addChild(pad);
			var slotButton = new UIButton(native.facade(), pad);
			slotButton.rolloverFilter = null;
			slotButton.releaseCallback = function() selectSlot(chosen);
			slotButton.navigationSelectedInteraction = function() {
				slotHover[chosen] = true;
				paintSlot(chosen);
			};
			slotButton.navigationSetToUnselectedInteraction = function() {
				slotHover[chosen] = false;
				paintSlot(chosen);
			};
			slotButtons.push(slotButton);
			hit.addEventListener(MouseEvent.MOUSE_OVER, function(_) {
				slotHover[chosen] = true;
				paintSlot(chosen);
				ui.focus(slotButton);
			});
			hit.addEventListener(MouseEvent.MOUSE_OUT, function(_) {
				slotHover[chosen] = false;
				paintSlot(chosen);
			});
			var count = ui.text(hit, "0", new Rectangle(b.x, b.y + b.height * 0.25, b.width, b.height * 0.5), 0xE0AB16);
			var countFormat = count.defaultTextFormat;
			countFormat.size = cast(countFormat.size, Float) + 6;
			count.defaultTextFormat = countFormat;
			count.setTextFormat(countFormat);
			count.name = "count";
			count.filters = [
				new openfl.filters.GlowFilter(0x454545, 1, 2, 2, 8, 1),
				new openfl.filters.GlowFilter(0xFFD534, 0.8, 4, 4, 2, 1)
			];
			slotHits.push(hit);
		}
		var cellsNative:openfl.Vector<UIInventoryItem> = cast Reflect.field(inv, "mItems");
		for (i in 0...15) {
			var parent = NativeUI.clipChild(grid, "slot_" + i);
			if (parent == null)
				throw "Native storage cell unavailable";
			if (cellsNative != null && i < cellsNative.length) {
				var original = cellsNative[i];
				original.root.dispatchEvent(new MouseEvent("rollOut"));
				original.root.filters = [];
				original.deSelect();
				hide(original.root);
			}
			var firstSlot = NativeUI.child(grid, "slot_0");
			var base = firstSlot.getBounds(root);
			var origin = root.globalToLocal(parent.localToGlobal(new openfl.geom.Point()));
			var firstOrigin = root.globalToLocal(firstSlot.localToGlobal(new openfl.geom.Point()));
			var step = Math.abs(NativeUI.child(grid, "slot_1").x - firstSlot.x);
			var side = step > 0 ? step * 0.94 : Math.min(base.width, base.height);
			frameBounds.push(new Rectangle(base.x + origin.x - firstOrigin.x, base.y + origin.y - firstOrigin.y, side, side));
			// The native press callback runs only for a controller press; mouse clicks use the CLICK handler below.
			var cell:UIInventoryItem = null;
			cell = new UIInventoryItem(native.facade(), parent, ui.asset.getClass("inv_slot"), ui.asset.getClass("DR_weapon_tooltip"),
				function(_:account.InventoryBaseInfo) {
					if (cell != null && cell.info != null)
						try
							toggle(Std.string(cell.info.databaseId))
						catch (error:Dynamic)
							notify("Selection could not be saved", false);
				});
			cell.draggable = false;
			cell.root.addEventListener(MouseEvent.MOUSE_DOWN, function(e:MouseEvent) {
				e.stopImmediatePropagation();
			}, true, 1000);
			cell.root.addEventListener(MouseEvent.MOUSE_DOWN, function(e:MouseEvent) {
				e.stopImmediatePropagation();
			}, false, 1000);
			var selectedCell = cell;
			cell.root.addEventListener(MouseEvent.CLICK, function(e:MouseEvent) {
				e.stopImmediatePropagation();
				if (selectedCell.info != null)
					try
						toggle(Std.string(selectedCell.info.databaseId))
					catch (error:Dynamic)
						notify("Selection could not be saved", false);
			}, false, 1000);
			cells.push(cell);
			cellBounds.push(cell.root.getBounds(cell.root));
			stars.push(null);
			cardViews.push(null);
			tileModifiers.push(null);
		}

		hide(NativeUI.child(root, "item_card"));
		hide(NativeUI.child(root, "inv_chests"));
		hide(NativeUI.child(root, "inv_consumable"));
		hide(NativeUI.child(root, "booster_card"));
		concealStage = root.stage;
		if (concealStage != null) {
			concealStage.addEventListener(Event.EXIT_FRAME, conceal, false, -1000);
			concealStage.addEventListener(Event.RENDER, conceal, false, -1000);
		}
	}

	/** Native hero switches re-show inventory parts after our frame tick; hide them again before drawing. */
	function conceal(_:Event):Void {
		if (!editing || inv == null)
			return;
		// The three slot holders stay visible: they are the editor's slot selectors.
		for (v in hidden)
			if (v.node != null && v.node.visible && selectorNodes.indexOf(v.node) < 0)
				v.node.visible = false;
		var originals:openfl.Vector<UIInventoryItem> = cast Reflect.field(inv, "mItems");
		if (originals != null)
			for (value in originals)
				if (value != null && value.root != null && value.root.visible)
					hide(value.root);
		if (concealStage != null)
			concealStage.invalidate();
	}

	function add(label:String, bounds:Rectangle, callback:Void->Void, grey:Bool = false):UIButton {
		var b = ui.button(layer, label, bounds, function() {
			if (!busy)
				pendingAction = callback;
		}, grey);
		controls.push(b);
		return b;
	}

	function maintain():Void {
		if (layer != null && layer.parent == root)
			root.setChildIndex(layer, root.numChildren - 1);
		if (slotLayer != null && slotLayer.parent == picker.root)
			picker.root.setChildIndex(slotLayer, picker.root.numChildren - 1);
		for (cell in cells)
			if (cell.root != null && cell.root.parent != null)
				cell.root.parent.setChildIndex(cell.root, cell.root.parent.numChildren - 1);
		for (i in 0...15) {
			var holder = NativeUI.child(grid, "slot_" + i);
			if (holder != null)
				holder.visible = true;
		}
		for (v in hidden)
			if (v.node != null)
				v.node.visible = false;
		var equipment = NativeUI.clipChild(picker.root, "UI_weapons");
		if (equipment != null) {
			for (i in 0...3) {
				var cell = NativeUI.clipChild(equipment, "equip_slot_" + i);
				if (cell == null)
					continue;
				var prompt:TextField = cast NativeUI.child(cell, "label");
				if (prompt != null) {
					var seen = false;
					for (saved in promptFormats)
						if (saved.label == prompt)
							seen = true;
					// Letters keep their original size, position and color; only selection recolors them.
					if (!seen)
						promptFormats.push({label: prompt, format: prompt.defaultTextFormat});
				}
				for (j in 0...cell.numChildren) {
					var child = cell.getChildAt(j);
					// Native labels and controller glyphs stay in their original hierarchy.
					if (["frame", "selected", "icon", "graphic"].indexOf(child.name) >= 0)
						hide(child);
				}
			}
			var equipped:openfl.Vector<uI.equipPicker.AvatarEquipElement> = cast Reflect.field(picker, "mEquipElements");
			if (equipped != null)
				for (item in equipped) {
					var icon:DisplayObject = cast Reflect.field(item, "mIcon");
					hide(icon);
				}
		}
		for (name in ["empty_z", "empty_x", "empty_c"]) {
			var node = NativeUI.child(picker.root, name);
			if (node != null)
				node.visible = true;
		}
		if (pickerLabel != null)
			pickerLabel.text = "SELECT A SLOT";
		var originals:openfl.Vector<UIInventoryItem> = cast Reflect.field(inv, "mItems");
		if (originals != null)
			for (value in originals)
				if (value != null)
					hide(value.root);
	}

	/** Frame (gold, hover cyan thin, selected cyan thick), letter and count color of one Ascension slot. */
	function paintSlot(i:Int):Void {
		if (i >= slotCards.length)
			return;
		var state = i == slot ? 2 : i < slotHover.length && slotHover[i] ? 1 : 0;
		if (slotCardState[i] != state) {
			slotCardState[i] = state;
			CardVisual.drawSlotFrame(slotCards[i], slotCardBounds[i], state);
		}
		var letter:TextField = cast slotLetter(i);
		if (letter != null) {
			var original:Dynamic = null;
			for (saved in promptFormats)
				if (saved.label == letter)
					original = saved.format.color;
			if (original == null) {
				promptFormats.push({label: letter, format: letter.defaultTextFormat});
				original = letter.defaultTextFormat.color;
			}
			recolor(letter, state == 2 ? CardVisual.SELECTED_COLOR : original);
		}
		var count:TextField = i < slotHits.length ? cast slotHits[i].getChildByName("count") : null;
		if (count != null) {
			recolor(count, state == 2 ? CardVisual.SELECTED_COLOR : CardVisual.FRAME_COLOR);
			// The count's outer glow follows the same color: gold normally, cyan when selected.
			var glow = state == 2 ? CardVisual.SELECTED_COLOR : 0xFFD534;
			var current:Array<openfl.filters.BitmapFilter> = count.filters;
			var outer:openfl.filters.GlowFilter = current.length > 1 ? cast current[1] : null;
			if (outer == null || outer.color != glow)
				count.filters = [
					new openfl.filters.GlowFilter(0x454545, 1, 2, 2, 8, 1),
					new openfl.filters.GlowFilter(glow, 0.8, 4, 4, 2, 1)
				];
		}
	}

	static function recolor(field:TextField, color:Dynamic):Void {
		var format = field.defaultTextFormat;
		if (format.color == color)
			return;
		format.color = color;
		field.defaultTextFormat = format;
		field.setTextFormat(format);
	}

	function slotLetter(i:Int):DisplayObject {
		var weaponsPanel = picker == null ? null : NativeUI.clipChild(picker.root, "UI_weapons");
		var equipCell = weaponsPanel == null ? null : NativeUI.clipChild(weaponsPanel, "equip_slot_" + i);
		return equipCell == null ? null : NativeUI.child(equipCell, "label");
	}

	/** Scales and moves a node so its bounds match the target; the original transform is restored on close. */
	function fitInto(node:DisplayObject, target:Rectangle):Void {
		slotTransforms.push({node: node, x: node.x, y: node.y, sx: node.scaleX, sy: node.scaleY});
		var before = node.getBounds(picker.root);
		if (before.width <= 0 || before.height <= 0)
			return;
		node.scaleX *= target.width / before.width;
		node.scaleY *= target.height / before.height;
		var after = node.getBounds(picker.root);
		node.x += target.x - after.x;
		node.y += target.y - after.y;
	}

	function selectSlot(index:Int):Void {
		slot = index;
		planDirty = true;
		page = 0;
		for (i in 0...slotHits.length) {
			var hit = slotHits[i];
			var b = slotBounds[i];
			hit.graphics.clear();
			hit.graphics.beginFill(0xFFFFFF, 0.01);
			hit.graphics.drawRect(b.x, b.y, b.width, b.height);
			hit.graphics.endFill();
		}
		filter();
		maintain();
	}

	function rebuild():Void {
		var a = native.hero(heroId);
		all = native.list(a);
		planDirty = true;
		var previous = types.length > typeIndex ? types[typeIndex] : "";
		types = [""];
		for (w in all)
			if (types.indexOf(w.type) < 0)
				types.push(w.type);
		typeIndex = Std.int(Math.max(0, types.indexOf(previous)));
		filter();
	}

	function reservedElsewhere(uid:String):Bool {
		for (p in draft)
			if (p.uid == uid && p.slot != slot)
				return true;
		return false;
	}

	function filter():Void {
		var type = types.length > typeIndex ? types[typeIndex] : "";
		var maxLevel = 0;
		for (w in all)
			maxLevel = Std.int(Math.max(maxLevel, w.level));
		levelOptions = ["LEVEL: ALL"];
		for (i in 0...Std.int(Math.ceil(maxLevel / 10)))
			levelOptions.push((i == 0 ? 1 : i * 10) + "-" + ((i + 1) * 10));
		if (levelIndex >= levelOptions.length)
			levelIndex = 0;
		if (levelDropdown != null)
			levelDropdown.setOptions(levelOptions, levelIndex);
		var low = levelIndex <= 1 ? 1 : (levelIndex - 1) * 10;
		var high = levelIndex * 10;
		visible = [
			for (w in all)
				if (!reservedElsewhere(w.uid)
					&& (type == "" || w.type == type)
					&& w.rarity >= rarity
					&& (levelIndex == 0 || w.level >= low && w.level <= high)) w
		];
		if (typeDropdown != null)
			typeDropdown.setOptions([
				for (t in types)
					t == "" ? "TYPE: ALL" : StringTools.replace(StringTools.replace(t, "_TYPE", ""), "_", " ")
			], typeIndex);
		if (rarityDropdown != null)
			rarityDropdown.setOptions(["RARITY: ALL", "COMMON+", "UNCOMMON+", "RARE+", "LEGENDARY"], rarity);
		page = Std.int(Math.max(0, Math.min(page, Math.ceil(visible.length / 15) - 1)));
		render();
	}

	function render():Void {
		if (!editing || cells.length != 15)
			return;
		if (planList != null && planDirty) {
			planList.update(draft, slot);
			planDirty = false;
		}
		for (i in 0...slotHits.length) {
			var total = 0;
			for (p in draft)
				if (p.slot == i)
					total++;
			var count:TextField = cast slotHits[i].getChildByName("count");
			count.text = Std.string(total);
			count.width = count.textWidth + 8;
			count.height = count.textHeight + 4;
			count.y = slotBounds[i].y + (slotBounds[i].height - count.height) / 2;
			count.x = slotBounds[i].x + (slotBounds[i].width - count.width) / 2;
			var art = NativeUI.child(picker.root, ["empty_z", "empty_x", "empty_c"][i]);
			if (art != null)
				art.filters = [];
			paintSlot(i);
		}
		autoButton.enabled = true;
		noneButton.enabled = true;
		for (i in 0...15) {
			var index = page * 15 + i;
			var cell = cells[i];
			if (index >= visible.length) {
				cell.root.visible = false;
				if (cardViews[i] != null)
					cardViews[i].dispose();
				cardViews[i] = null;
				stars[i] = null;
				tileModifiers[i] = null;
				continue;
			}
			var w = visible[index];
			var info = native.item(w.uid);
			if (cell.info != info)
				cell.info = info;
			cell.root.visible = info != null;
			cell.draggable = false;
			cell.equippable = 1;
			var view = cardViews[i];
			var details = showCardDetails();
			if (view != null && view.key != CardVisual.keyFor(info, details)) {
				view.dispose();
				view = null;
			}
			if (view == null && info != null) {
				var boundCell = cell;
				view = new CardVisual(ui, native, cell, null, inv, function(uid:String) {
					try
						toggle(uid)
					catch (error:Dynamic)
						notify("Selection could not be saved", false);
				}, function() {
					if (boundCell.info == null || slot < 0)
						return false;
					var item:account.ItemInfo = cast boundCell.info;
					var planned = Plan.selected(draft, slot, cast item.requiredLevel);
					return planned != null && planned.uid == Std.string(item.databaseId);
				}, details);
			}
			cardViews[i] = view;
			if (view != null) {
				view.refresh();
				stars[i] = view.badge;
				tileModifiers[i] = view.strip;
			}
		}
		if (pageLabel != null) {
			pageLabel.text = "PAGE " + (page + 1) + " / " + Std.int(Math.max(1, Math.ceil(visible.length / 15)));
			pageLabel.width = pageLabel.textWidth + 8;
			pageLabel.height = pageLabel.textHeight + 4;
			pageLabel.x = pageCenter - pageLabel.width / 2;
			pageLabel.y = pageMiddle - pageLabel.height / 2;
		}
	}

	/** Levels and modifier icons on cards, unless Weapon Modifiers in Inventory Preview already draws them. */
	function showCardDetails():Bool {
		return !ctx.isActive(CardVisual.WEAPON_MODIFIERS_MOD);
	}

	function persist(next:Array<Plan>):Void {
		getStore().draft(heroId, next);
		draft = next;
		planDirty = true;
		filter();
	}

	function toggle(uid:String):Void {
		if (slot < 0)
			return;
		for (w in visible)
			if (w.uid == uid) {
				var next = Plan.copyAll(draft);
				var old = Plan.selected(next, slot, w.level);
				if (old != null && old.uid == uid)
					next.remove(old);
				else if (!Plan.assign(next, slot, w)) {
					notify("That physical weapon is already planned for another slot.", false);
					return;
				}
				persist(next);
				return;
			}
	}

	function auto():Void {
		if (slot < 0)
			selectSlot(0);
		if (slot >= 0)
			persist(Plan.automatic(draft, slot, visible));
	}

	function clear():Void {
		if (slot >= 0)
			persist(Plan.clearSlot(draft, slot));
	}

	function commit():Void {
		var before = getStore().committed(heroId);
		var different = !samePlan(before, draft);
		getStore().commit(heroId, draft);
		if (different) {
			changed();
			notify(heroName + " Ascension Helper config saved", true);
		}
	}

	static function samePlan(a:Array<Plan>, b:Array<Plan>):Bool {
		if (a.length != b.length)
			return false;
		for (p in a) {
			var q = Plan.selected(b, p.slot, p.level);
			if (q == null || q.uid != p.uid)
				return false;
		}
		return true;
	}

	public function close(save:Bool):Void {
		if (!editing)
			return;
		if (save)
			commit();
		else
			getStore().cancel(heroId);
		editing = false;
		cleanup();
		if (entry != null)
			ui.focus(entry);
	}

	function cleanup():Void {
		if (concealStage != null) {
			concealStage.removeEventListener(Event.EXIT_FRAME, conceal);
			concealStage.removeEventListener(Event.RENDER, conceal);
		}
		concealStage = null;
		selectorNodes = [];
		for (saved in promptFormats) {
			saved.label.defaultTextFormat = saved.format;
			saved.label.setTextFormat(saved.format);
		}
		promptFormats = [];
		for (view in cardViews)
			if (view != null)
				view.dispose();
		cardViews = [];
		tileModifiers = [];
		if (gridBackdrop != null && gridBackdrop.parent != null)
			gridBackdrop.parent.removeChild(gridBackdrop);
		gridBackdrop = null;
		pendingAction = null;
		if (typeDropdown != null)
			typeDropdown.dispose();
		if (rarityDropdown != null)
			rarityDropdown.dispose();
		if (levelDropdown != null)
			levelDropdown.dispose();
		levelDropdown = null;
		typeDropdown = null;
		rarityDropdown = null;
		if (planList != null)
			planList.dispose();
		planList = null;
		for (value in heroTooltips)
			if (value.object != null)
				value.object.tooltip = value.tooltip;
		heroTooltips = [];
		for (cell in cells) {
			if (cell.root != null && cell.root.parent != null)
				cell.root.parent.removeChild(cell.root);
			cell.destroy();
		}
		cells = [];
		stars = [];
		for (button in controls)
			button.destroy();
		controls = [];
		for (v in hidden)
			if (v.node != null)
				v.node.visible = v.visible;
		hidden = [];
		if (pickerLabel != null)
			pickerLabel.text = oldLabel;
		var names = ["empty_z", "empty_x", "empty_c"];
		for (i in 0...names.length) {
			var node = NativeUI.child(picker.root, names[i]);
			if (node != null && i < slotFilters.length)
				node.filters = slotFilters[i];
		}
		for (card in slotCards)
			if (card.parent != null)
				card.parent.removeChild(card);
		slotCards = [];
		slotCardBounds = [];
		slotCardState = [];
		slotHover = [];
		for (b in slotButtons) {
			b.clearLeftNavigation();
			b.clearRightNavigation();
			b.clearUpNavigation();
			b.clearDownNavigation();
		}
		slotButtons = [];
		for (saved in slotTransforms) {
			saved.node.x = saved.x;
			saved.node.y = saved.y;
			saved.node.scaleX = saved.sx;
			saved.node.scaleY = saved.sy;
		}
		slotTransforms = [];
		if (slotLayer != null && slotLayer.parent != null)
			slotLayer.parent.removeChild(slotLayer);
		slotLayer = null;
		slotHits = [];
		if (layer != null && layer.parent != null)
			layer.parent.removeChild(layer);
		layer = null;

		pageLabel = null;
		pickerLabel = null;

		if (entry != null)
			entry.visible = true;
		if (inv != null && inv.root != null && inv.root.stage != null)
			inv.refresh(false);
	}

	function detach():Void {
		if (storageOverlays != null)
			storageOverlays.dispose();
		storageOverlays = null;
		if (editing)
			close(true);
		if (entry != null) {
			if (storageButton != null && storageButton.rightNavigation == entry) {
				storageButton.clearRightNavigation();
				if (oldStorageRight != null)
					storageButton.rightNavigation = oldStorageRight;
			}
			storageButton = null;
			oldStorageRight = null;
			if (entry.root != null && entry.root.parent != null)
				entry.root.parent.removeChild(entry.root);
			entry.destroy();
			entry = null;
		}
		inv = null;
		root = null;
		grid = null;
		picker = null;
		if (ui != null)
			ui.dispose();
		ui = null;
	}

	public function dispose():Void
		detach();
}
