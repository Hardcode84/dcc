module serialization;

void serialize(ObjT, StreamT)(ref StreamT stream, const ref ObjT obj)
{
    import std.traits: isArray, isAssociativeArray, isBasicType, Unqual;
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
    import std.container.util : make;
    import std.traits: isArray, isAssociativeArray, isBasicType, Unqual;
    alias T = Unqual!ObjT;
    ObjT obj;
    static if(is(T == struct) ||
              is(T == class))
    {
        obj = make!T;
        foreach(ref field; obj.tupleof)
        {
            field = deserialize!(typeof(field))(stream);
        }
    }
    else static if(isArray!ObjT)
    {
        alias ElemT = typeof(obj[0]);
        static if(isBasicType!ElemT)
        {
            obj = stream.read!ObjT;
        }
        else
        {
            import std.traits: isMutable;
            import std.exception: assumeUnique;
            const len = deserialize!(typeof(T.length))(stream);
            T temp;
            temp.length = len;
            foreach(i; 0..len)
            {
                temp[i] = deserialize!(Unqual!(ElemT))(stream);
            }

            static if(isMutable!ElemT)
            {
                obj = temp;
            }
            else
            {
                obj = assumeUnique(temp);
            }
        }
    }
    //else static if(isAssociativeArray!T) {}
    else
    {
        obj = stream.read!T;
    }
    return obj;
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
        import std.traits: isSomeString, isIntegral, Unqual;
        import std.conv: to;
        import std.format: format, sformat;
        assert(out_sink !is null);
        static if(isSomeString!T)
        {
            write(val.length.to!SizeT);
            out_sink(val);
        }
        else
        {
            static assert(isIntegral!T);
            char[64] buff = void;
            enum formatStr = format("%%0%sx", T.sizeof * 2);
            const str = sformat(buff, formatStr, val);
            assert(str.length == (T.sizeof * 2));
            out_sink(str);
        }
    }

    T read(T)() const
    {
        import std.traits: isSomeString, Unqual;
        import std.conv: to;
        import std.format: formattedRead, format;
        assert(in_sink !is null);
        static if(isSomeString!T)
        {
            const len = read!(typeof(ret.length));
            char[] temp;
            temp.length = len;
            char[] buff = temp[];
            in_sink(buff);
            assert(ret.length == len);
            if (buff.ptr is temp.ptr)
            {
                return buff;
            }
            else
            {
                return buff.idup;
            }
        }
        else
        {
            static assert(isIntegral!T);
            char[T.sizeof * 2] temp = void;
            char[] buff = temp[];
            in_sink(buff);
            assert(buff.length == temp.length);
            Unqual!T ret;
            enforce(1 == formattedRead!"%x"(buff, ret), format("Unable to parse \"%s\" as %s", buff, (Unqual!T).stringof));
            return ret;
        }
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
