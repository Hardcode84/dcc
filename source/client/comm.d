module comm;

import std.socket;
import std.range;
import std.exception;

import client_comm;

import driver;

void process(in string driver, in Command command)
{
    auto socket = new TcpSocket(AddressFamily.INET);
    scope(exit) socket.close();
    socket.blocking = true;
    socket.connect(new InternetAddress(0x7F000001/*127.0.0.1*/, 55555));
    scope(exit) socket.shutdown(SocketShutdown.BOTH);
    client_process(driver, command,
        (ref buff)
        {
            while(!buff.empty)
            {
                const received = socket.receive(buff);
                enforce(Socket.ERROR != received, "Socket receive error");
                buff = buff[received..$];
            }
        },
        (buff)
        {
            while(!buff.empty)
            {
                const sent = socket.send(buff);
                enforce(Socket.ERROR != sent, "Socket send error");
                buff = buff[sent..$];
            }
        });
}