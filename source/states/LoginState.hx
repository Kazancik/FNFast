package states;

import flixel.FlxState;
import flixel.FlxG;
import flixel.text.FlxText;
import flixel.addons.ui.FlxInputText;
import flixel.ui.FlxButton;
import flixel.util.FlxSave;
import haxe.Http;
import haxe.Json;
import backend.OnlineManager;
import backend.ClientPrefs; // REQUIRED IMPORT

class LoginState extends FlxState
{
    var usernameInput:FlxInputText;
    var passwordInput:FlxInputText;
    var statusText:FlxText;

    var loginBtn:FlxButton;
    var registerBtn:FlxButton;
    var offlineBtn:FlxButton;

    var save:FlxSave;

    override public function create():Void
    {
        super.create();

        // ---------- SAVE SYSTEM ----------
        save = new FlxSave();
        save.bind("fnfOnline");

        // ---------- TITLE ----------
        var title = new FlxText(0, 40, FlxG.width, "FNF ONLINE LOGIN");
        title.setFormat(null, 32, 0xFFFFFFFF, "center");
        add(title);

        // ---------- USERNAME ----------
        usernameInput = new FlxInputText(300, 150, 200, "");
        add(usernameInput);

        // ---------- PASSWORD ----------
        passwordInput = new FlxInputText(300, 200, 200, "");
        passwordInput.passwordMode = true;
        add(passwordInput);

        // ---------- STATUS ----------
        statusText = new FlxText(0, 260, FlxG.width, "Connecting to server...");
        statusText.alignment = "center";
        add(statusText);

        // ---------- BUTTONS ----------
        loginBtn = new FlxButton(300, 320, "LOGIN", doLogin);
        registerBtn = new FlxButton(420, 320, "REGISTER", doRegister);
        offlineBtn = new FlxButton(540, 320, "OFFLINE MODE", doOffline);
        
        loginBtn.active = false;
        registerBtn.active = false;

        add(loginBtn);
        add(registerBtn);
        add(offlineBtn);

        // INIT ONLINE MANAGER
        OnlineManager.init(function() {
            statusText.text = "Connected. Ready to Login.";
            loginBtn.active = true;
            registerBtn.active = true;

            // ---------- AUTO LOGIN ----------
            if (save.data.token != null)
            {
                statusText.text = "Auto logging in...";
                autoLogin(save.data.token);
            }
        });
    }

    // =====================================================
    // LOGIN
    // =====================================================
    function doLogin():Void
    {
        statusText.text = "Logging in...";

        var http = new Http(OnlineManager.serverURL + "/login");
        http.setHeader("Content-Type", "application/json");
        http.setHeader("Accept", "application/json");

        http.setPostData(Json.stringify({
            username: usernameInput.text,
            password: passwordInput.text
        }));

        http.onData = function(data:String)
        {
            var response:Dynamic = Json.parse(data);

            if (response.success) {
                // Save for next time game opens
                save.data.token = response.token;
                save.flush();

                // FIX: Save for CURRENT session
                ClientPrefs.data.authToken = response.token;
                ClientPrefs.data.username = response.username;
                ClientPrefs.username = response.username; // --- IGNORE ---
                ClientPrefs.authToken = response.token; // --- IGNORE ---
                ClientPrefs.saveSettings();

                statusText.text = "Login success!";
                goToMenu();
            } else {
                statusText.text = "Login failed!";
            }
        };

        http.onError = function(err) {
            statusText.text = "Login failed: " + err;
        };

        http.request(true);
    }

    // =====================================================
    // REGISTER
    // =====================================================
    function doRegister():Void
    {
        statusText.text = "Registering...";

        var http = new Http(OnlineManager.serverURL + "/register");
        http.setHeader("Content-Type", "application/json");

        http.setPostData(Json.stringify({
            username: usernameInput.text,
            password: passwordInput.text
        }));

        http.onData = function(data:String) {
            statusText.text = "Registered! Now login.";
        };

        http.onError = function(err) {
            statusText.text = "Register failed: " + err;
        };

        http.request(true);
    }

    // =====================================================
    // AUTO LOGIN
    // =====================================================
    function autoLogin(token:String):Void
    {
        var http = new Http(OnlineManager.serverURL + "/token_login");
        http.setHeader("Content-Type", "application/json");
        http.setHeader("Accept", "application/json");

        http.setPostData(Json.stringify({
            token: token
        }));

        http.onData = function(data:String)
        {
            var json:Dynamic = haxe.Json.parse(data);

            if(json == null || json.success != true) {
                statusText.text = "Session Expired. Please login.";
                save.data.token = null;
                save.flush();
                return;
            }

            // FIX: Use .data for Psych 0.7+
            ClientPrefs.data.authToken = json.token;
            ClientPrefs.data.username = json.username;
            ClientPrefs.saveSettings();

            statusText.text = "Auto login success!";
            goToMenu();
        };

        http.onError = function(err)
        {
            statusText.text = "Session expired.";
            save.data.token = null;
            save.flush();
        };

        http.request(true);
    }

    // =====================================================
    // OFFLINE MODE
    // =====================================================
    function doOffline():Void
    {
        // Clear session so Anti-Cheat ignores scores and Publisher blocks uploads
        ClientPrefs.data.authToken = "";
        ClientPrefs.data.username = "Guest";
        ClientPrefs.saveSettings();
        
        goToMenu();
    }

    // =====================================================
    // NEXT STATE
    // =====================================================
    function goToMenu():Void
    {
        if (FlxG.sound.music == null) {
            FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
        }
        
        // FIX: Removed duplicate switchState call
        MusicBeatState.switchState(new MainMenuState());
    }
}