package backend;

import sys.io.File;
import sys.FileSystem;
import haxe.io.Bytes;
import haxe.io.BytesInput;

class BrokenZipReader
{
    public static function unpack(zipPath:String, outputDir:String):Void
    {
        var bytes:Bytes = File.getBytes(zipPath);
        var input = new BytesInput(bytes);

        while (input.position < bytes.length)
        {
            var sig = readU32LE(input);

            // central directory = stop
            if (sig == 0x02014B50 || sig == 0x06054B50)
            {
                trace("End of ZIP entries.");
                break;
            }

            if (sig != 0x04034B50)
            {
                trace("Bad signature, stopping.");
                break;
            }

            readU16LE(input);
            var flags = readU16LE(input);
            var compression = readU16LE(input);
            readU16LE(input);
            readU16LE(input);
            readU32LE(input);

            var compressedSize = readU32LE(input);
            var uncompressedSize = readU32LE(input);

            var nameLen = readU16LE(input);
            var extraLen = readU16LE(input);

            if (compressedSize <= 0 || compressedSize > bytes.length)
                break;

            var filename = input.readString(nameLen);

            if (extraLen > 0)
                input.read(extraLen);

            var fileData = input.read(compressedSize);

            installFile(filename, fileData, outputDir);
        }
    }

    static function installFile(filename:String, fileData:Bytes, outputDir:String):Void
    {
        var outPath = outputDir + filename;

        createFolders(outPath);
        File.saveBytes(outPath, fileData);

        trace("Extracted: " + outPath + " (" + fileData.length + " bytes)");
    }

    static function createFolders(path:String):Void
    {
        var parts = path.split("/");
        var current = "";

        for (i in 0...parts.length - 1)
        {
            current += parts[i] + "/";
            if (!FileSystem.exists(current))
                FileSystem.createDirectory(current);
        }
    }

    static function readU16LE(input:BytesInput):Int
    {
        var b0 = input.readByte();
        var b1 = input.readByte();
        return b0 | (b1 << 8);
    }

    static function readU32LE(input:BytesInput):Int
    {
        var b0 = input.readByte();
        var b1 = input.readByte();
        var b2 = input.readByte();
        var b3 = input.readByte();
        return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24);
    }
}