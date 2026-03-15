package objects;

class MenuItem extends FlxSprite
{
	public var targetY:Float = 0;

public function new(x:Float, y:Float, weekName:String = '')
	{
		super(x, y);
		antialiasing = backend.ClientPrefs.data.antialiasing;

		frames = Paths.getSparrowAtlas('campaign_menu_UI_assets');

		// 1. Safely check if the animation exists in the XML
		var animExists = false;
		if (frames != null) {
			for (frame in frames.frames) {
				if (frame.name.indexOf(weekName + " basic") != -1 || frame.name.indexOf(weekName + " idle") != -1) {
					animExists = true;
					break;
				}
			}
		}

		// 2. If it exists, play it normally
		if (animExists) {
			animation.addByPrefix('idle', weekName + " basic", 24);
			animation.addByPrefix('selected', weekName + " white", 24);

			// Fallback for newer Psych Engine versions
			if (animation.getByName('idle') == null) animation.addByPrefix('idle', weekName + " idle", 24);
			if (animation.getByName('selected') == null) animation.addByPrefix('selected', weekName + " selected", 24);

			animation.play('idle');
			updateHitbox();
		} 
		// 3. If missing, KILL the Haxe logo and mark it
		else {
			makeGraphic(1, 1, 0x00000000); // Make it a 1x1 invisible pixel
			isMissingGraphic = true;
		}
	}
	public var isMissingGraphic:Bool = false;
	public var isFlashing(default, set):Bool = false;
	private var _flashingElapsed:Float = 0;
	final _flashColor = 0xFF33FFFF;
	final flashes_ps:Int = 6;

	public function set_isFlashing(value:Bool = true):Bool
	{
		isFlashing = value;
		_flashingElapsed = 0;
		color = (isFlashing) ? _flashColor : FlxColor.WHITE;
		return isFlashing;
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (isFlashing)
		{
			_flashingElapsed += elapsed;
			color = (Math.floor(_flashingElapsed * FlxG.updateFramerate * flashes_ps) % 2 == 0) ? _flashColor : FlxColor.WHITE;
		}
	}
}
