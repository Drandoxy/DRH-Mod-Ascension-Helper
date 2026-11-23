package mods.ascension_helper;

import account.ItemInfo;
import openfl.display.Sprite;
import openfl.display.MovieClip;
import openfl.geom.Rectangle;
import openfl.text.TextField;
import brain.assetRepository.AssetLoadingComponent;
import facade.DBFacade;

/** One retained row. Assets and hover widgets survive pixel-level scrolling. */
class PlanRow {
	public var root:Sprite;
	public var key:String;
	public var plan:Plan;
	public var deletion:brain.uI.UIButton;
	public var used = false;

	var artworkLoader:AssetLoadingComponent;
	var disposed = false;
	var modifiers:Array<ModifierIcon> = [];
	var rarityRenderer:brain.render.MovieClipRenderController;

	public static function signature(p:Plan, item:ItemInfo):String {
		var key = p.slot + ":" + p.level + ":" + p.uid;
		if (item == null)
			return key + ":missing";
		key += ":" + item.power + ":" + item.legendaryModifier;
		for (m in item.modifiers)
			if (m != null)
				key += ":" + m.Constant;
		return key;
	}

	public function new(ui:NativeUI, native:Native, parent:Sprite, p:Plan, width:Float, height:Float, remove:(String, Int, Int) -> Void) {
		plan = p.copy();
		var item = native.item(p.uid);
		key = signature(p, item);
		root = new Sprite();
		parent.addChild(root);
		root.graphics.lineStyle(1, 0x7B4A17);
		root.graphics.moveTo(0, height - 1);
		root.graphics.lineTo(width, height - 1);
		var star = ui.star(root);
		NativeUI.setLevel(star, Std.string(p.level));
		NativeUI.fit(star, new Rectangle(0, 4, 52, height - 8));
		var image = new MovieClip();
		root.addChild(image);
		image.x = 56;
		image.y = (height - 52) / 2;
		image.graphics.lineStyle(1, 0xB28130);
		image.graphics.beginFill(0x321D0C);
		image.graphics.drawRoundRect(0, 0, 52, 52, 12, 12);
		image.graphics.endFill();
		image.scrollRect = new Rectangle(0, 0, 52, 52);
		var clip = new Sprite();
		root.addChild(clip);
		clip.mouseEnabled = false;
		clip.graphics.beginFill(0xFFFFFF);
		clip.graphics.drawRoundRect(image.x, image.y, 52, 52, 12, 12);
		clip.graphics.endFill();
		image.mask = clip;
		var frame = new Sprite();
		frame.name = "thumbnailFrame";
		frame.mouseEnabled = false;
		root.addChild(frame);
		frame.x = image.x;
		frame.y = image.y;
		frame.graphics.lineStyle(2, 0x2A1709);
		frame.graphics.drawRoundRect(0.5, 0.5, 51, 51, 11, 11);
		frame.graphics.lineStyle(1, 0xBE963E);
		frame.graphics.drawRoundRect(1, 1, 50, 50, 10, 10);
		if (item != null) {
			artworkLoader = new AssetLoadingComponent(native.facade());
			if (item.hasColoredBackground) {
				artworkLoader.getSwfAsset(DBFacade.buildFullDownloadPath(item.backgroundSwfPath), function(asset:brain.assetRepository.SwfAsset) {
					if (disposed)
						return;
					var background:MovieClip = cast asset.instantiateRuntimeSymbol(item.backgroundIconName, []);
					if (background == null)
						return;
					background.gotoAndStop(1);
					image.addChildAt(background, 0);
					background.scaleX = background.scaleY = 56 / 72;
					background.x = background.y = 26;
					background.mouseEnabled = false;
					background.mouseChildren = false;
					rarityRenderer = new brain.render.MovieClipRenderController(native.facade(), background);
					rarityRenderer.play(0, true);
				});
			}
			artworkLoader.getSwfAsset(DBFacade.buildFullDownloadPath(item.uiSwfFilepath), function(asset:brain.assetRepository.SwfAsset) {
				if (disposed)
					return;
				var art:MovieClip = cast asset.instantiateRuntimeSymbol(item.iconName, []);
				if (art == null)
					return;
				art.stop();
				image.addChild(art);
				NativeUI.fit(art, new Rectangle(0, 0, 52, 52));
				art.mouseEnabled = false;
				art.mouseChildren = false;
			});
		}
		var nameX = 116.;
		var deleteX = width - 27;
		var modsX = nameX;
		var powerX = deleteX - 82;
		var nameWidth = Math.max(30, powerX - nameX - 5);
		var label = ui.text(root, item == null ? "MISSING WEAPON" : item.Name.toUpperCase(), new Rectangle(nameX, 2, nameWidth, 20), 0xFFE58A);
		var format = label.defaultTextFormat;
		format.size = 11;
		label.defaultTextFormat = format;
		label.setTextFormat(format);
		label.x = nameX;
		label.y = 8;
		label.width = nameWidth;
		label.height = 20;
		while (label.textWidth > nameWidth && label.text.length > 4)
			label.text = label.text.substr(0, label.text.length - 4) + "...";
		if (item != null) {
			ui.powerIcon(root, new Rectangle(powerX - 10, height / 2 - 15, 78, 30), Std.string(item.power));
			var index = 0;
			for (m in item.modifiers)
				if (m != null && index < 2) {
					var holder = new MovieClip();
					root.addChild(holder);
					holder.x = modsX + index * 32;
					holder.y = 25;

					modifiers.push(new ModifierIcon(native.facade(), holder, m.Constant));
					index++;
				}
			if (item.legendaryModifier > 0) {
				var holder = new MovieClip();
				root.addChild(holder);
				holder.x = modsX + index * 32;
				holder.y = 25;

				modifiers.push(new ModifierIcon(native.facade(), holder, "", item.legendaryModifier));
			}
		}
		deletion = ui.deleteButton(root, new Rectangle(deleteX, height / 2 - 13, 25, 26), function() {
			remove(plan.uid, plan.slot, plan.level);
		});
	}

	public function dispose():Void {
		if (rarityRenderer != null)
			rarityRenderer.destroy();
		rarityRenderer = null;
		for (m in modifiers)
			m.destroy();
		modifiers = [];
		disposed = true;
		if (artworkLoader != null)
			artworkLoader.destroy();
		artworkLoader = null;
		deletion.destroy();
		if (root.parent != null)
			root.parent.removeChild(root);
	}
}
