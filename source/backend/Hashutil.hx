package backend;

import sys.io.File;
import haxe.crypto.Md5;
import sys.FileSystem;

class HashUtil
{
    /**
     * Returns the MD5 hash of a file's content.
     */
    public static function getFileHash(path:String):String
    {
        if (!FileSystem.exists(path)) return "";
        
        try {
            var bytes = File.getBytes(path);
            return Md5.encode(bytes.toString());
        } catch(e:Dynamic) {
            return "";
        }
    }
}