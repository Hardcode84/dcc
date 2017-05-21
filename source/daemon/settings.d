module settings;

import peer;

struct Settings
{
    ushort listenPort = 44444;
    PeerDesc[] peers;

    ushort driverListenPort = 55555;

    int maxInternalWorkers = 4;
    int maxExternalWorkers = 4;
}