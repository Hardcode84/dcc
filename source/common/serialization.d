module serialization;

import std.exception;
import std.traits;
import std.conv: to;
import std.format;

void serialize(ObjT, StreamT)(ref StreamT stream, const ref ObjT obj)
{
    alias T = Unqual!ObjT;
    static if(is(T == struct) ||
              is(T == class))
    {
        foreach(const ref field; obj.tupleof)
        {
            serialize(stream, field);
        }
    }
    else static if(isArray!T)
    {
        alias ElemT = Unqual!(typeof(obj[0]));
        static if(isBasicType!ElemT)
        {
            stream.write(obj);
        }
        else
        {
            const len = obj.length;
            serialize(stream, len);
            foreach(const ref elem; obj[])
            {
                serialize(stream, elem);
            }
        }
    }
    //else static if(isAssociativeArray!T) {}
    else
    {
        stream.write(obj);
    }
}

ObjT deserialize(ObjT, StreamT)(ref StreamT stream)
{
    alias T = Unqual!ObjT;
    static if(is(T == struct) ||
              is(T == class))
    {
        T obj = make!T;
        foreach(ref field; obj.tupleof)
        {
            field = deserialize!(typeof(field))(stream);
        }
        return obj;
    }
    else static if(isArray!ObjT)
    {
        T dummy = void;
        alias ElemT = Unqual!(typeof(dummy[0]));
        static if(isBasicType!ElemT)
        {
            return stream.read!ObjT;
        }
        else
        {
            const len = deserialize!(typeof(dummy.length))(stream);
            static if(isDynamicArray!T)
            {
                ElemT[] temp;
                temp.length = len;
            }
            else
            {
                ElemT[T.sizeof / ElemT.sizeof] temp;
            }

            foreach(i; 0..len)
            {
                temp[i] = deserialize!(Unqual!(ElemT))(stream);
            }

            static if(isMutable!(typeof(dummy[0])))
            {
                return temp;
            }
            else
            {
                return temp.assumeUnique;
            }
        }
    }
    //else static if(isAssociativeArray!T) {}
    else
    {
        return stream.read!T;
    }
}

struct TextStream
{
    alias OutSink = void delegate(const(char)[]);
    alias InSink = void delegate(ref char[]);

    OutSink out_sink = null;
    InSink in_sink = null;

    alias SizeT = ushort;

    void write(T)(in T val) const
    {
        assert(out_sink !is null);
        static if(isSomeString!T)
        {
            write(val.length.to!SizeT);
            if(val.length > 0)
            {
                out_sink(val);
            }
        }
        else static if(isArray!T)
        {
            if(isDynamicArray!T)
            {
                write(val.length.to!SizeT);
            }

            foreach(elem; val[])
            {
                write(elem);
            }
        }
        else static if(isIntegral!T || isBoolean!T)
        {
            enum BuffSize = (isBoolean!T ? 1 : T.sizeof * 2);
            char[BuffSize] buff = void;
            enum formatStr = format("%%0%sx", BuffSize);
            const str = sformat(buff, formatStr, val);
            assert(str.length == BuffSize);
            out_sink(str);
        }
        else static assert(false, format("Unhandled type %s", T.stringof));
    }

    T read(T)() const
    {
        assert(in_sink !is null);
        static if(isSomeString!T)
        {
            const len = read!SizeT();
            if(len > 0)
            {
                char[] temp;
                temp.length = len;
                char[] buff = temp[];
                in_sink(buff);
                assert(buff.length == len);
                if (buff.ptr is temp.ptr)
                {
                    return buff.assumeUnique;
                }
                else
                {
                    return buff.idup;
                }
            }
            else
            {
                return (char[]).init;
            }
        }
        else static if(isArray!T)
        {
            T dummy = void;
            alias ElemT = Unqual!(typeof(dummy[0]));
            static if(isDynamicArray!T)
            {
                const len = read!SizeT();
                ElemT[] ret;
                ret.length = len;
            }
            else
            {
                ElemT[T.sizeof / ElemT.sizeof] ret = void;
            }

            foreach(ref elem; ret[])
            {
                elem = read!ElemT();
            }

            static if(isMutable!(typeof(dummy[0])))
            {
                return ret;
            }
            else
            {
                return ret.assumeUnique;
            }
        }
        else static if(isIntegral!T || isBoolean!T)
        {
            enum BuffSize = (isBoolean!T ? 1 : T.sizeof * 2);
            char[BuffSize] temp = void;
            char[] buff = temp[];
            in_sink(buff);
            assert(buff.length == temp.length);
            Unqual!(OriginalType!T) ret;
            enforce(1 == buff.formattedRead("%x",&ret), format("Unable to parse \"%s\" as %s", buff, (Unqual!T).stringof));
            return cast(T)ret;
        }
        else static assert(false, format("Unhandled type %s", T.stringof));
    }
}


alias OutSink = void delegate(const(void)[]);
alias InSink = void delegate(void[]);

void write_val(T)(in T val, scope OutSink sink)
{
    union U
    {
        ubyte[T.sizeof] buff;
        T val;
    }
    U u;
    u.val = val;
    sink(cast(void[])u.buff);
}

alias SizeType = ushort;

void write_string(in string str, scope OutSink sink)
{
    enum MaxLen = SizeType.max;
    assert(str.length <= MaxLen);
    const len = cast(SizeType)str.length;
    len.write_val(sink);
    if(len > 0)
    {
        sink(cast(void[])str);
    }
}

void write_string_list(in string[] str, scope OutSink sink)
{
    enum MaxLen = SizeType.max;
    assert(str.length <= MaxLen);
    const len = cast(SizeType)str.length;
    len.write_val(sink);
    foreach(s; str[])
    {
        write_string(s, sink);
    }
}

T read_val(T)(scope InSink sink)
{
    union U
    {
        ubyte[T.sizeof] buff;
        T val;
    }
    U u;
    sink(cast(void[])u.buff);
    return u.val;
}

string read_string(scope InSink sink)
{
    const size = read_val!SizeType(sink);
    string ret;
    if(size > 0)
    {
        ret.length = size;
        sink(cast(void[])(ret[]));
    }
    return ret;
}

immutable(string)[] read_string_list(scope InSink sink)
{
    import std.exception: assumeUnique;
    const size = read_val!SizeType(sink);
    string[] ret;
    ret.length = size;
    foreach(i; 0..size)
    {
        ret[i] = read_string(sink);
    }
    return assumeUnique(ret);
}

private:
template make(T)
if (is(T == struct) || is(T == class))
{
    T make(Args...)(Args arguments)
    if (is(T == struct) && __traits(compiles, T(arguments)))
    {
        return T(arguments);
    }

    T make(Args...)(Args arguments)
    if (is(T == class) && __traits(compiles, new T(arguments)))
    {
        return new T(arguments);
    }
}