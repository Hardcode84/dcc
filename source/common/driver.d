module driver;

import std.range;

public import task;
import intrusive_list;
import serialization;

struct Command
{
    immutable(string)[] options;
    immutable(string)[] files;
    string outFile;

    @property bool empty() const pure nothrow @nogc 
    {
        return options.empty && files.empty && outFile.empty;
    }

    void serialize(scope OutSink sink) const
    {
        options.write_string_list(sink);
        files.write_string_list(sink);
        outFile.write_string(sink);
    }

    static Command deserialize(scope InSink sink)
    {
        auto options = read_string_list(sink);
        auto files = read_string_list(sink);
        auto outFile = read_string(sink);
        return Command(options, files, outFile);
    }
}

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
