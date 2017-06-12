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
        return 0;
    }
    else
    {
        auto res = process(driverStr, cmd);
        stdout.write(res.stdout);
        stderr.write(res.stderr);
        return (res.result == TaskResult.Success ? 0 : 1);
    }
}
