module client;

import std.exception;
import std.stdio;

import log;
import drivers;
import comm;

int main(string[] args)
{
    enforce(args.length >= 2, "Invalid arguments count");
    const driverStr = args[1];
    auto driver = getDriver(driverStr);
    assert(driver !is null);
    auto cmd = driver.parseCommandLine(args[2..$]);
    if(cmd.empty)
    {
        writefln("dcc client");
        writefln("driver: %s", driver.getInfoString());
    }
    else
    {
        process(driverStr, cmd);
    }
    return 0;
}
