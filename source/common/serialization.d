module serialization;

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

string[] read_string_list(scope InSink sink)
{
    const size = read_val!SizeType(sink);
    string[] ret;
    ret.length = size;
    foreach(i; 0..size)
    {
        ret[i] = read_string(sink);
    }
    return ret;
}