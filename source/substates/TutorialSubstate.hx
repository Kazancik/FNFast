package substates;



import flixel.FlxSubState;
import flixel.FlxG;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.FlxSprite;

class TutorialSubState extends FlxSubState
{
    public function new()
    {
        super();
    }

    override function create()
    {
        super.create();

        var bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
        bg.alpha = 0.85;
        add(bg);

        var text = new FlxText(0, 0, FlxG.width - 200, 
            "WELCOME TO FNFast!\n\n" +
            "1. Create charts in the 'Creator' menu.\n" +
            "2. Use community uploaded materials to give your charts a unique look.\n" +
            "3. Rank up by beating verified charts.\n\n" +
            "By accepting, you agree to the Terms of Service & Privacy Policy.\n" +
            "Join our Discord and Wiki for tutorials!\n\n" +
            "PRESS ACCEPT TO START", 24);
        text.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
        text.screenCenter();
        add(text);
    }

    override function update(elapsed:Float)
    {
        super.update(elapsed);

        // Close substate when they press Accept
        if (FlxG.keys.justPressed.ENTER)
        {
            FlxG.sound.play(Paths.sound('confirmMenu'));
            close();
        }
    }
}