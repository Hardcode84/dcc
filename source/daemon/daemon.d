module daemon;

import std.algorithm;

import settings;
import context;
import peer;
import settings;
import client_listener;
import workers_pool;

import vibe.d;

int run()
{
    //auto context = new Context;
    logInfo("Running");
    scope(exit) logInfo("Exiting");
    Settings settings;
    auto workersPool = WorkersPool(WorkersPoolSettings(max(settings.maxInternalWorkers, settings.maxExternalWorkers), "cl"));
    auto clientListener = ClientListener(settings);

    /*auto listener = listenTCP(port1, (connection)
    {
        acceptPeer(context, connection);
    });*/
    /*auto task = runTask(()
    {
        while(true)
        {
            try
            {
                logInfo("Trying to connect");
                auto connection = connectTCP("127.0.0.1", port2);
                connectPeer(context, connection);
            }
            catch(Exception e)
            {
                logInfo("Exception %s", e.msg);
            }
            sleep(1000.msecs);
        }
    });*/

    auto ret = runApplication((string[])
    {

    });
    logInfo("Returned from main loop");
    return ret;
}