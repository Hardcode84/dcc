module process;

import std.process;
import std.typecons;
import std.traits;

auto execute(in char[][] args)
{
    int ret = 1;
    string output;
    string errstr;
    try
    {
        //TODO: correctly handle stderr
        auto result = std.process.execute(args, null, Config.suppressConsole);
        ret = result.status;
        output = result.output;
    }
    catch(Exception e)
    {
        errstr = e.msg;
    }
    return tuple!("status", "stdout", "stderr")(ret, output, errstr);
}