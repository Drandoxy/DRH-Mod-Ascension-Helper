package mods.ascension_helper;

import openfl.display.Sprite;
import openfl.display.MovieClip;
import openfl.geom.Rectangle;
import openfl.events.MouseEvent;
import openfl.text.TextField;
import uI.modifiers.UIModifier;

/** A bounded, scrollable native-art list with actual native modifier hover tooltips. */
class PlanList {
	var ui:NativeUI;
	var native:Native;
	var parent:Sprite;
	var root:Sprite;
	var rows:Sprite;
	var bounds:Rectangle;
	var plans:Array<Plan> = [];

	var slot = -1;
	var offset = 0.;
	var viewport:Sprite;
	var track:Sprite;
	var thumb:Sprite;
	public var deleteButtons(default, null):Array<brain.uI.UIButton> = [];
	var remove:(String, Int, Int) -> Void;
	var dragging = false;
	var grabOffset = 0.;
	var dragStage:openfl.display.Stage;
	var rowHeight = 62.;
	var cache:Array<PlanRow> = [];

	public var rowsCreated(default, null) = 0;
	public var rowsDisposed(default, null) = 0;

	var header:Sprite;
	var headerLabel:TextField;

	public function new(ui:NativeUI, native:Native, parent:Sprite, bounds:Rectangle, remove:(String, Int, Int) -> Void) {
		this.ui = ui;
		this.native = native;
		this.parent = parent;
		this.bounds = bounds;
		this.remove = remove;
		root = new Sprite();
		parent.addChild(root);
		ui.wood(root, bounds);
		header = ui.ribbon(root, new Rectangle(bounds.x + bounds.width * 0.10, bounds.y - 6, bounds.width * 0.80, 38), "WEAPON PLAN");
		headerLabel = cast header.getChildAt(header.numChildren - 1);
		viewport = new Sprite();
		root.addChild(viewport);
		viewport.x = bounds.x + 12;
		viewport.y = bounds.y + 52;
		viewport.graphics.beginFill(0, 0.01);
		viewport.graphics.drawRect(0, 0, bounds.width - 40, bounds.height - 66);
		viewport.graphics.endFill();
		viewport.scrollRect = new Rectangle(0, 0, bounds.width - 40, bounds.height - 66);
		root.addEventListener(MouseEvent.MOUSE_WHEEL, function(e:MouseEvent) {
			e.stopImmediatePropagation();
			scroll(offset - e.delta * rowHeight * 0.55);
		});
		track = new Sprite();
		root.addChild(track);
		track.x = bounds.x + bounds.width - 22;
		track.y = bounds.y + 52;
		track.graphics.lineStyle(1, 0x130A02);
		track.graphics.beginFill(0x241003, 1);
		track.graphics.drawRoundRect(0, 0, 5, bounds.height - 66, 3, 3);
		track.graphics.endFill();
		// Slender Settings-style arrows are decoration; only the gold handle scrolls.
		for (bottom in [false, true]) {
			var y = bottom ? bounds.height - 12 : 46.;
			var arrow = new Sprite();
			root.addChild(arrow);
			arrow.x = track.x + 2.5;
			arrow.y = bounds.y + y;
			arrow.graphics.lineStyle(1.5, 0x130A02);
			arrow.graphics.beginFill(0xFFC600);
			arrow.graphics.moveTo(-5, bottom ? 0 : 6);
			arrow.graphics.lineTo(5, bottom ? 0 : 6);
			arrow.graphics.lineTo(0, bottom ? 6 : 0);
			arrow.graphics.lineTo(-5, bottom ? 0 : 6);
			arrow.graphics.endFill();
			arrow.mouseEnabled = false;
		}
		thumb = new Sprite();
		track.addChild(thumb);
		thumb.buttonMode = true;
		thumb.addEventListener(MouseEvent.MOUSE_DOWN, function(e:MouseEvent) {
			e.stopImmediatePropagation();
			dragging = true;
			var grab = track.globalToLocal(new openfl.geom.Point(e.stageX, e.stageY));
			grabOffset = grab.y - thumb.y;
			dragStage = root.stage;
			if (dragStage != null) {
				dragStage.addEventListener(MouseEvent.MOUSE_MOVE, move);
				dragStage.addEventListener(MouseEvent.MOUSE_UP, end);
				dragStage.addEventListener(openfl.events.Event.DEACTIVATE, end);
			}
		});
		thumb.addEventListener(MouseEvent.CLICK, function(e:MouseEvent) {
			e.stopImmediatePropagation();
		});
		track.addEventListener(MouseEvent.CLICK, function(e:MouseEvent) {
			e.stopImmediatePropagation();
		});
	}

	function maximum():Float
		return Math.max(0, plans.length * rowHeight - (bounds.height - 66));

	function move(e:MouseEvent):Void {
		if (!dragging)
			return;
		var point = track.globalToLocal(new openfl.geom.Point(e.stageX, e.stageY));
		scroll((point.y - grabOffset) / Math.max(1, bounds.height - 66 - 26) * maximum());
	}

	function end(_:openfl.events.Event):Void {
		dragging = false;
		if (dragStage != null) {
			dragStage.removeEventListener(MouseEvent.MOUSE_MOVE, move);
			dragStage.removeEventListener(MouseEvent.MOUSE_UP, end);
			dragStage.removeEventListener(openfl.events.Event.DEACTIVATE, end);
		}
		dragStage = null;
	}

	function scroll(value:Float):Void {
		offset = Math.max(0, Math.min(value, maximum()));
		render();
	}

	public function update(values:Array<Plan>, selectedSlot:Int):Void {
		if (slot != selectedSlot)
			offset = 0;
		slot = selectedSlot;
		plans = [for (p in values) if (slot < 0 || p.slot == slot) p.copy()];
		plans.sort(function(a, b) return a.level == b.level ? a.slot - b.slot : a.level - b.level);
		offset = Math.max(0, Math.min(offset, maximum()));
		render();
	}

	/** One saved plan row; null when it cannot be drawn, so the rest of the list still shows. */
	function makeRow(p:Plan, width:Float):PlanRow {
		var row:PlanRow = null;
		try {
			row = new PlanRow(ui, native, rows, p, width, rowHeight, remove);
		} catch (error:Dynamic) {
			ErrorLog.report("Could not draw saved plan row for weapon " + p.uid, error);
			row = null;
		}
		return row;
	}

	function clear():Void {
		for (row in cache) {
			row.dispose();
			rowsDisposed++;
		}
		cache = [];
		deleteButtons = [];
		if (rows != null && rows.parent != null)
			rows.parent.removeChild(rows);
		rows = null;
	}

	function render():Void {
		if (rows == null) {
			rows = new Sprite();
			viewport.addChild(rows);
		}
		var width = bounds.width - 40;
		var height = bounds.height - 66;
		headerLabel.text = slot < 0 ? "SAVED WEAPON PLAN" : "SLOT " + (slot + 1) + " WEAPON PLAN";
		headerLabel.width = headerLabel.textWidth + 8;
		headerLabel.x = bounds.x + (bounds.width - headerLabel.width) / 2;
		for (row in cache)
			row.used = false;
		var first = Std.int(Math.max(0, Std.int(offset / rowHeight) - 1));
		var count = Std.int(Math.ceil(height / rowHeight)) + 3;
		deleteButtons = [];
		for (i in first...Std.int(Math.min(plans.length, first + count))) {
			var p = plans[i];
			var key = PlanRow.signature(p, native.item(p.uid));
			var found:PlanRow = null;
			for (row in cache)
				if (row.key == key) {
					found = row;
					break;
				}
			if (found == null) {
				found = makeRow(p, width);
				if (found == null)
					continue;
				cache.push(found);
				rowsCreated++;
			}
			found.used = true;
			found.root.y = i * rowHeight;
			deleteButtons.push(found.deletion);
		}
		for (row in cache.copy())
			if (!row.used) {
				row.dispose();
				cache.remove(row);
				rowsDisposed++;
			}
		rows.y = -offset;
		var max = maximum();
		thumb.visible = max > 0;
		thumb.graphics.clear();
		var thumbHeight = 26.;
		thumb.graphics.lineStyle(1.5, 0x130A02);
		thumb.graphics.beginFill(0xFFD000, 1);
		thumb.graphics.drawRoundRect(-3.5, 0, 12, thumbHeight, 12, 12);
		thumb.graphics.endFill();
		thumb.y = max <= 0 ? 0 : offset / max * (height - thumbHeight);
	}

	public function dispose():Void {
		clear();
		end(null);
		if (root.parent != null)
			root.parent.removeChild(root);
	}
}
