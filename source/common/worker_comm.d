module worker_comm;

import std.stdio;
import std.exception;
import std.string;
import std.format;

import serialization;
import task;

void writeReady(File stream)
{
    stream.writeln(WorkerReady);
    stream.flush();
}

void waitForReady(File stream, scope void delegate(in string) flushSink)
{
    char[256] temp;
    char[] buf = temp[];
    size_t charsRead = 0;
    while (stream.readln(buf))
    {
        auto str = buf.strip;
        if(WorkerReady == str)
        {
            break;
        }
        flushSink(cast(string)str);
        charsRead += str.length;
        enforce(charsRead < 4096, "Too much garbage in stream");
    }
}

void sendMessage(T)(File stream, in T msg)
{
    File* f = &stream; // Workaround for closure scoped desctruction protection
    void sink(const(char)[] t) scope
    {
        assert(t.length > 0);
        f.write(t);
    }
    auto writer = TextStream(&sink, null);
    serialize(writer, msg);
    stream.writeln();
    stream.flush();
}

T receiveMessage(T)(File stream)
{
    char[256] temp;
    char[] buff = temp[];
    enforce(stream.readln(buff) > 0, "Stream was closed");
    void sink(ref char[] t) scope
    {
        const len = t.length;
        assert(len > 0);
        enforce(len <= buff.length, format("Unexpected end of stream (expected %s got %s)", buff.length, len));
        t = buff[0..len];
        buff = buff[len..$];
    }
    auto reader = TextStream(null, &sink);
    return deserialize!T(reader);
}

struct WorkerTask
{
    Task task;
}

struct WorkerTaskResult
{
    TaskResultInfo result;
}

private:
enum WorkerReady = "dcc-wrk-rdy";