module cl_driver;

import std.range;
import std.path;
import std.exception;
import std.array;
import std.algorithm;

import driver;

final class ClDriver : DriverBase
{
public:
    override Command parseCommandLine(in string[] opts) const
    {
        bool link = false;
        Command ret;
        foreach(ref opt; opts)
        {
            assert(!opt.empty);
            if('/' == opt[0] || '-' == opt[0])
            {
                enum outStr = " out:";
                enum linkStr = "link";
                if(opt.length >= outStr.length && outStr[1..$] == opt[1..outStr.length])
                {
                    ret.outFile = opt[outStr.length..$];
                }
                else if (opt.length >= linkStr.length && linkStr == opt[1..$])
                {
                    link = true;
                }
                else
                {
                    ret.options ~= opt;
                }
            }
            else
            {
                ret.files ~= opt;
                if (ret.outFile.empty)
                {
                    ret.outFile = opt.stripExtension;
                }
            }
        }

        if (!ret.outFile.empty && !link)
        {
            ret.outFile ~= ".o";
        }
        return ret;
    }

    override Task[] processCommand(in Command command) const
    {
        assert(!command.files.empty);
        assert(!command.outFile.empty);
        enforce(1 == command.files.length, "Only single-file commands supported now");
        auto ret = appender!(Task[]);
        Task.IdType currId = 0;
        const preprocess_only = command.options.any!(a => "/P" == a || "-P" == a);
        foreach(file; command.files)
        {
            if(preprocess_only)
            {
                auto ppId = currId++;
                ret ~= Task(ppId, true, [], command.options, file, command.outFile);
            }
            else
            {
                // Preprocess
                auto tempFile = file ~ ".pp";
                auto ppId = currId++;
                ret ~= Task(ppId, true, [], command.options ~ "/P", file, tempFile);
                // Compie
                auto clId = currId++;
                ret ~= Task(clId, false, [ppId], command.options, tempFile, command.outFile);
            }
        }
        return ret.data;
    }

    override TaskResultInfo executeTask(in Task task) const
    {
        import std.stdio;
        stderr.write(task);
        return TaskResultInfo.init;
    }
}

static this()
{
    registerDriver!ClDriver("cl");
}