package mods.ascension_helper;

import openfl.display.Sprite;
import openfl.text.TextField;
import openfl.text.TextFormat;

/**
 * One message at a time, centered on the screen in a small wood-style box. A message counts as seen
 * only after 3 seconds on screen outside a loading screen; one cut short by loading is shown again,
 * in the same place and style, once loading has finished.
 */
class Toast {
	public static inline var SHOW_SECONDS = 4.0;
	public static inline var SEEN_SECONDS = 3.0;

	var parent:Sprite;
	var label:TextField;
	var box:Sprite;
	var message:String;
	var good = true;
	var shownFor = 0.0;
	var lastTick = -1.0;

	public function new(parent:Sprite) {
		this.parent = parent;
		label = new TextField();
		label.multiline = true;
		label.wordWrap = false;
		label.selectable = false;
		label.mouseEnabled = false;
		label.visible = false;
		// Dark outline plus a soft drop shadow keep the text readable on any background.
		label.filters = [
			new openfl.filters.GlowFilter(0x1A1A1A, 1, 3, 3, 8, 1),
			new openfl.filters.DropShadowFilter(3, 45, 0x000000, 0.75, 4, 4, 1, 1)
		];
		box = new Sprite();
		box.mouseEnabled = false;
		box.visible = false;
		parent.addChild(box);
		parent.addChild(label);
	}

	public function show(text:String, isGood:Bool):Void {
		message = text;
		good = isGood;
		shownFor = 0;
		lastTick = -1;
		display();
	}

	function display():Void {
		var f = new TextFormat("_sans", 24, good ? 0x75E18A : 0xFFD08C, true);
		f.align = "center";
		label.defaultTextFormat = f;
		// The field is sized to the text itself, so the box drawn around it always lines up.
		label.width = 2000;
		label.text = message;
		label.width = label.textWidth + 6;
		label.height = label.textHeight + 6;
		if (parent.stage != null) {
			// The overlay is scaled by the game: convert the screen point (center, 80% down) to its space.
			var anchor = parent.globalToLocal(new openfl.geom.Point(parent.stage.stageWidth / 2, parent.stage.stageHeight * 0.8));
			label.x = anchor.x - label.width / 2;
			label.y = anchor.y - label.height;
		}
		label.visible = true;
		drawBox();
	}

	function drawBox():Void {
		var padX = 14.;
		var padY = 6.;
		var g = box.graphics;
		g.clear();
		g.lineStyle(2, 0xB8862E);
		g.beginFill(0x2E1608, 0.92);
		g.drawRoundRect(label.x - padX, label.y - padY, label.width + padX * 2, label.height + padY * 2, 14, 14);
		g.endFill();
		if (box.parent == label.parent && box.parent != null)
			box.parent.setChildIndex(box, Std.int(Math.max(0, box.parent.getChildIndex(label) - 1)));
		box.visible = true;
	}

	/** `loading`: a loading screen is up, so the message cannot be seen and waits. */
	public function tick(now:Float, loading:Bool):Void {
		if (message == null) {
			lastTick = now;
			return;
		}
		var step = lastTick < 0 ? 0 : now - lastTick;
		lastTick = now;
		if (loading) {
			hide();
			if (shownFor >= SEEN_SECONDS)
				message = null;
			return;
		}
		if (!label.visible) {
			// Back from loading: the time spent there does not count as seen.
			display();
			step = 0;
		}
		shownFor += step;
		if (shownFor >= SHOW_SECONDS) {
			hide();
			message = null;
		}
	}

	function hide():Void {
		label.visible = false;
		box.visible = false;
	}

	public function dispose():Void {
		if (label.parent != null)
			label.parent.removeChild(label);
		if (box.parent != null)
			box.parent.removeChild(box);
	}
}
