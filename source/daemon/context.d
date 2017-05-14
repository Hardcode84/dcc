module context;

import std.uuid;

import peer;

final class Context
{
public:
    this()
    {
    }

    bool addPeer(Connection connection, UUID peer_id)
    {
        assert(connection !is null);
        synchronized
        {
        }
        return true;
    }

    // Properties
    @property const pure nothrow @safe
    {
    }

private:
}

private:
UUID genId()
{
    UUID ret;
    import vibe.crypto.cryptorand;
    (new SystemRNG).read(ret.data[]);
    return ret;
}