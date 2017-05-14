module client;

import std.exception;

import log;
import driver;
import cl_driver;

import comm;

int main(string[] args)
{
    enforce(args.length >= 2, "Invalid argumnets count");
    logInfo("%s", args);
    const driverStr = args[1];
    auto driver = getDriver(driverStr);
    assert(driver !is null);
    auto cmd = driver.parseCommandLine(args[2..$]);
    logInfo("%s", cmd);
    process(driverStr, cmd);
    return 0;
}
