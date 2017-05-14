module settings;

import peer;

struct Settings
{
    ushort listenPort = 44444;
    PeerDesc[] peers;

    ushort driverListenPort = 55555;
}