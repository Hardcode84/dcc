module daemon;

import std.algorithm;

import settings;
import context;
import peer;
import settings;
import client_listener;
import workers_pool;
import scheduler;
import drivers;

import vibe.d;

int run()
{
    logInfo("Running");
    scope(exit) logInfo("Exiting");

    Settings settings;
    auto workersPool = WorkersPool(WorkersPoolSettings(max(settings.maxInternalWorkers, settings.maxExternalWorkers), "cl"));
    auto localWorkerSink = workersPool.taskSink(settings.maxInternalWorkers);
    auto scheduler = scheduler.Scheduler(SchedulerSettings(&localWorkerSink.tryPut, &localWorkerSink.tryPut));
    auto clientListener = ClientListener(ClientListenerSettings(settings.driverListenPort, &scheduler.processTaskGroup));

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
