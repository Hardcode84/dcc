module cl_driver;

import std.range;
import std.path;
import std.exception;
import std.array;
import std.algorithm;

import driver;
import process;

final class ClDriver : DriverBase
{
public:
    override string getInfoString() const
    {
        return "msvc cl driver";
    }

    override Command parseCommandLine(in string[] opts) const
    {
        return Command(opts.idup);
    }

    override Task[] processCommand(in Command command) const
    {
        bool link = true;
        bool dll = false;
        bool preprocessOnly = false;

        auto options = appender!(string[]);
        auto inFiles = appender!(string[]);
        auto inObjFiles = appender!(string[]);
        string outFile;
        foreach(ref opt; command.options)
        {
            assert(!opt.empty);
            if('/' == opt[0] || '-' == opt[0])
            {
                enum outStr = " out:";
                if(auto outName = checkOpt!"out:"(opt))
                {
                    outFile = opt[outStr.length..$];
                }
                else if(auto outName = checkOpt!"OUT:"(opt))
                {
                    outFile = opt[outStr.length..$];
                }
                else if (checkOpt!"P"(opt))
                {
                    preprocessOnly = true;
                }
                else if (checkOpt!"c"(opt))
                {
                    link = false;
                    options ~= opt;
                }
                else if (checkOpt!"LD"(opt) || checkOpt!"DLL"(opt)  || checkOpt!"dll"(opt))
                {
                    dll = true;
                }
                else
                {
                    options ~= opt;
                }
            }
            else
            {
                const ext = opt.extension;
                if(ext == "lib" || ext == "obj")
                {
                    inObjFiles ~= opt;
                }
                else
                {
                    inFiles ~= opt;
                }

                if (outFile.empty)
                {
                    outFile = opt.stripExtension;
                }
            }
        }

        auto objFiles = appender!(string[]);
        auto objFilesTaks = appender!(Task.IdType[]);
        auto ret = appender!(Task[]);
        Task.IdType currId = 0;
        foreach(file; inFiles.data[])
        {
            if(preprocessOnly)
            {
                const ppId = currId++;
                ret ~= Task(ppId, true, [], CompileCommand, options.data[].assumeUnique, [file], [outFile]);
            }
            else
            {
                // Preprocess
                auto tempFile = file ~ ".pp";
                const ppId = currId++;
                ret ~= Task(ppId, true, [], CompileCommand, (["/P"] ~ options.data[]).assumeUnique, [file], [tempFile]);
                // Compile
                auto tempObjFile = file ~ ".obj";
                const clId = currId++;
                ret ~= Task(clId, false, [ppId], CompileCommand, options.data[].assumeUnique, [tempFile], [tempObjFile]);
                if(link)
                {
                    objFiles ~= tempObjFile;
                    objFilesTaks ~= clId;
                }
            }
        }

        if(link)
        {
            const linkId = currId++;
            const inLinkFiles = (objFiles.data[] ~ inObjFiles.data[]).assumeUnique;
            const outLinkFiles = (dll ? [outFile ~ ".dll", outFile ~ ".lib"] : [outFile ~ ".exe"]).assumeUnique;
            ret ~= Task(linkId, true, objFilesTaks.data[].assumeUnique, CompileCommand, options.data[].assumeUnique, inLinkFiles, outLinkFiles);
        }
        return ret.data;
    }

    override TaskResultInfo executeTask(in Task task) const
    {
        import std.stdio;
        stderr.writeln(task);
        assert(!task.inFiles.empty);
        assert(!task.outFiles.empty);
        string[] cmd = [CompileCommand] ~ task.inFiles ~ task.options;
        if(task.options.find!(a => ("-link" == a || "/link" == a)).empty)
        {
            cmd ~= "/link";
        }
        cmd ~= "/out:"~task.outFiles[0];
        const res = execute(cmd);
        stderr.writeln(res);
        return TaskResultInfo((0 == res.status ? TaskResult.Success : TaskResult.Failure), res.stdout, res.stderr);
    }
}

static this()
{
    registerDriver!ClDriver("cl");
}

private:
enum CompileCommand = "cl.exe";

string checkOpt(string opt)(string val)
{
    if(val.length >= (opt.length + 1) && opt[] == val[1..opt.length])
    {
        return val[(opt.length + 1)..$];
    }
    return string.init;
}