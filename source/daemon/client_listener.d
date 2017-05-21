module client_listener;

import settings;

import vibe.d;

import client_comm;

struct ClientListener
{
public:
    this(in Settings settings)
    {
        scope(success) logInfo("Clent listener created");
        scope(failure) logInfo("Clent listener creation failed");
        m_listeners = listenTCP(settings.driverListenPort, &listen);
    }

private:
    TCPListener[] m_listeners;

    void listen(TCPConnection connection)
    {
        logInfo("Connected");
        server_process(
            (buff)
            {
                connection.read(cast(ubyte[])buff);
            },
            (buff)
            {
                connection.write(cast(const(ubyte[]))buff);
            },
            (driver, command)
            {
                logInfo("Process %s %s", driver, command);
            });
    }
}