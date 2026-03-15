package backend;

import haxe.Http;
import haxe.crypto.Base64;
import haxe.io.Bytes;

class OnlineManager {
    public static var serverURL:String = ""; 
    public static var isReady:Bool = false;

    private static var bootstrapURL:String = "https://kazancik.github.io/A//////////"; // Put some "/" so to increase compatibility with Private Servers being too long. Make sure to keep the length the same as the original URL to prevent issues with the decryption.
    private static var PASS:String = "ABCD";

    /**
     * Fetches the Base64 string from GitHub, decodes it, XORs it, and sets the IP.
     */
    public static function init(onComplete:Void->Void) {
        var http = new Http(bootstrapURL);
        
        http.onData = function(data:String) {
            try {
                // 1. Clean the input string (remove newlines/spaces)
                var encoded:String = StringTools.trim(data);

                // 2. Base64 Decode to bytes (matches PowerShell [System.Convert]::FromBase64String)
                var bytes:Bytes = Base64.decode(encoded);

                // 3. XOR Decrypt (matches PowerShell -bxor loop)
                var passBytes:Bytes = Bytes.ofString(PASS);
                for (i in 0...bytes.length) {
                    var byte = bytes.get(i);
                    var keyByte = passBytes.get(i % passBytes.length);
                    bytes.set(i, byte ^ keyByte);
                }

                // 4. Convert bytes back to a readable String
                serverURL = bytes.toString();

                trace("Server Discovered: " + serverURL);
                isReady = true;
                onComplete();
            } catch (e:Dynamic) {
                trace("Decryption Error: " + e + " | Data received: " + data);
                serverURL = "http://127.0.0.1:8000"; // Fallback to local
                onComplete();
            }
        };
        
        http.onError = function(err) {
            trace("Bootstrap fetch failed: " + err);
            serverURL = "http://127.0.0.1:8000"; 
            onComplete();
        };
        
        http.request();
    }
}