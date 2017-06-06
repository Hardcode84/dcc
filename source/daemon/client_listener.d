module client_listener;

import settings;

import vibe.d;

import client_comm;
import drivers;

alias TaskProcessor = TaskResultInfo delegate(ref TaskGroup tasks);

struct ClientListenerSettings
{
    ushort listenPort;
    TaskProcessor processor;
}

struct ClientListener
{
public:
    this(in ClientListenerSettings settings)
    {
        scope(success) logInfo("Client listener created (%s listeners)", m_listeners.length);
        scope(failure) logInfo("Client listener creation failed");
        assert(settings.processor !is null);
        m_listeners = listenTCP(settings.listenPort, &listen);
        m_processor = settings.processor;
    }

    this(this) @disable;

private:
    TCPListener[] m_listeners;
    const TaskProcessor m_processor;

    void listen(TCPConnection connection)
    {
        scope(exit) connection.close();
        logInfo("Connected");
        server_process(
            (ref buff)
            {
                connection.read(cast(ubyte[])buff);
            },
            (buff)
            {
                connection.write(cast(const(ubyte[]))buff);
            },
            (driverName, command)
            {
                assert(m_processor !is null);
                auto driver = getDriver(driverName);
                auto tasks = TaskGroup(driver.processCommand(command));
                return m_processor(tasks);
            });
    }
}