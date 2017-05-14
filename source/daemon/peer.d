module peer;

import std.exception;
import std.algorithm;
import std.format;

import context;

import vibe.d;

struct PeerDesc
{
    string host;
    ushort port;
}

alias Connection = TCPConnection;

final class Peer
{
public:
    this(Context context, Connection connection)
    {
        assert(context ! is null);
        assert(connection !is null);
        m_context = context;
        m_connection = connection;
    }

    // Properties
    @property const pure nothrow @safe
    {
        PeerDesc desc() { return m_desc; }
    }
private:
    Context m_context;
    Connection m_connection;
    PeerDesc m_desc;
}

void acceptPeer(Context context, Connection connection)
{
    assert(context !is null);
    assert(connection !is null);
    serverHandshake(context, connection);
    logInfo("accepted %s %s", connection.localAddress, connection.peerAddress);
}

void connectPeer(Context context, Connection connection)
{
    assert(context !is null);
    assert(connection !is null);
    clientHandshake(context, connection);
    logInfo("connected %s %s", connection.localAddress, connection.peerAddress);
}

private:
// 
// SERVER<-Hello<-CLIENT
// SERVER<-ProtoVer<-CLIENT
// SERVER->HelloResp->CLIENT
// SERVER<-HelloAck<-CLIENT

enum ProtoVer = 1;
enum Hello = "dcc-hel";
enum HelloResp = "dcc-hel-ack";
enum HelloAck = "dcc-ack";

void checkString(alias S)(Connection connection)
{
    ubyte[S.length] buff;
    connection.read(buff[]);
    enforce(equal(buff[], S[]), format("Unexpected responce %s (expected %s)", buff, S));
}

auto readVal(T)(Connection connection)
{
    union U
    {
        ubyte[T.sizeof] buff;
        T val;
    }
    U u;
    connection.read(u.buff[]);
    return u.val;
}

void writeVal(T)(Connection connection, in T val)
{
    union U
    {
        ubyte[T.sizeof] buff;
        T val;
    }
    U u;
    u.val = val;
    connection.write(u.buff[]);
}

void checkVal(string Desc, T)(Connection connection, in T expected)
{
    const val = readVal!T(connection);
    enforce(val == expected, format("%s (expected %s, got %s)", Desc, expected, val));
}

void serverHandshake(Context context, Connection connection)
{
    checkString!Hello(connection);
    checkVal!"Invalid protocol version"(connection, cast(ubyte)ProtoVer);
    connection.write(HelloResp);
    checkString!HelloAck(connection);
}

void clientHandshake(Context context, Connection connection)
{
    connection.write(Hello);
    writeVal(connection, cast(ubyte)ProtoVer);
    checkString!HelloResp(connection);
    connection.write(HelloAck);
}