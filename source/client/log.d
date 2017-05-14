module log;

import std.stdio;
import std.file;
import std.array;
import std.format;

void logInfo(Args...)(in string fmt, Args args)
{
    std.file.append("out.log", format(fmt, args));
    std.file.append("out.log", "\n");
}