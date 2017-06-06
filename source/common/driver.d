module driver;

import std.range;

public import task;
import intrusive_list;
import serialization;

interface DriverBase
{
    Command parseCommandLine(in string[] opts) const;
    Task[] processCommand(in Command command) const;
    TaskResultInfo executeTask(in Task task) const;
}

void registerDriver(T)(in string name)
{
    assert(!name.empty);
    if(name !in drivers)
    {
        drivers[name] = new T;
    }
}

DriverBase getDriver(in string name)
{
    assert(!name.empty);
    assert(name in drivers);
    return drivers[name];
}

private:
__gshared DriverBase[string] drivers;
