module worker_comm;

import std.stdio;
import std.exception;
import std.string;

import serialization;

void writeReady(File stream)
{
    stream.writeln(WorkerReady);
    stream.flush();
}

void waitForReady(File stream, scope void delegate(in string) flushSink)
{
    char[] buf;
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

void sendMessage(T)(File stream, const ref T msg)
{
    auto writer = TextStream((a) =>
        {
            assert(a.length > 0);
            stream.write(a);
        });
    serialize(stream, msg);
    stream.flush();
}

T receiveMessage(T)(File stream)
{
    char[256] temp;
    char[] buff = temp[];
    enforce(stream.readln(buff) > 0, "Stream was closed");
    auto reader = TextStream(null, (a) =>
        {
            const len = a.length;
            enforce(len >= buff.length, "Unexpected end of stream");
            assert(len > 0);
            a = buff[0..len];
            buff = buff[len..$];
        });
}

private:
enum WorkerReady = "dcc-wrk-rdy";