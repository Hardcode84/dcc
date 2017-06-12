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
    char[256] temp;
    File* f = &stream; // Workaround for closure scoped desctruction protection
    void sink(const(char)[] t) scope
    {
        assert(t.length > 0);
        f.write(escapeString(temp[], t));
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
    unescapeString(buff);
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

pure nothrow @safe:
const(char)[] escapeString(char[] temp, const(char)[] t)
{
    char[] tempBuff;
    size_t len = 0;

    foreach(i, char c; t[])
    {
        void initTempBuff() scope
        {
            if(tempBuff is null)
            {
                const newLen = t.length * 2;
                if(newLen <= temp.length)
                {
                    tempBuff = temp[0..newLen];
                }
                else
                {
                    tempBuff.length = newLen;
                }
                tempBuff[0..i] = t[0..i];
                assert(0 == len);
                len = i;
            }
        }

        void put(in const(char)[] str) scope
        {
            const strLen = str.length;
            assert(strLen > 0);
            if(strLen > 1 || tempBuff !is null)
            {
                initTempBuff();
                tempBuff[len..len + strLen] = str[];
                len += strLen;
            }
        }

        if('\r' == c)
        {
            put("\\r");
        }
        else if('\n' == c)
        {
            put("\\n");
        }
        else
        {
            put(t[i..i + 1]);
        }
    }

    if(tempBuff is null)
    {
        return t;
    }
    else
    {
        return tempBuff[0..len];
    }
}

void unescapeString(ref char[] t)
{
    size_t delta = 0;
    bool skip = false;
    foreach(i, char c; t[])
    {
        void put(char ch) scope
        {
            if(delta > 0)
            {
                t[i - delta] = ch;
            }
        }

        if(skip)
        {
            if('r' == c)
            {
                put('\r');
            }
            else if('n' == c)
            {
                put('\n');
            }
            else assert(false);
            skip = false;
        }
        else
        {
            if('\\' == c)
            {
                skip = true;
                ++delta;
            }
            else
            {
                put(c);
            }
        }
    }
    t = t[0..$ - delta];
}