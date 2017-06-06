module serialization;

import std.exception;
import std.traits;
import std.conv: to;
import std.format;

void serialize(ObjT, StreamT)(ref StreamT stream, in ObjT obj)
{
    serialize(stream, obj);
}

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

struct BinaryStream
{
    alias OutSink = void delegate(const(void)[]);
    alias InSink = void delegate(ref void[]);

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
        else static if(isIntegral!T || isBoolean!T || isSomeChar!T)
        {
            const void* ptr = &val;
            out_sink(ptr[0..1]);
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
                void[] temp;
                temp.length = len;
                void[] buff = temp[];
                in_sink(buff);
                assert(buff.length == len);
                if (buff.ptr is temp.ptr)
                {
                    return (cast(string)buff).assumeUnique;
                }
                else
                {
                    return (cast(string)buff).idup;
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
        else static if(isIntegral!T || isBoolean!T || isSomeChar!T)
        {
            enum BuffSize = T.sizeof;
            void[BuffSize] temp = void;
            void[] buff = temp[];
            in_sink(buff);
            assert(buff.length == BuffSize);
            return *(cast(T*)buff.ptr);
        }
        else static assert(false, format("Unhandled type %s", T.stringof));
    }
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