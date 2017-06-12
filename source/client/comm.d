module comm;

import std.socket;
import std.range;
import std.exception;

import client_comm;

import driver;

auto process(in string driver, in Command command)
{
    auto socket = new TcpSocket(AddressFamily.INET);
    scope(exit) socket.close();
    socket.blocking = true;
    socket.connect(new InternetAddress(0x7F000001/*127.0.0.1*/, 55555));
    scope(exit) socket.shutdown(SocketShutdown.BOTH);
    return client_process(driver, command,
        (ref buff)
        {
            void[] temBuff = buff;
            while(!temBuff.empty)
            {
                const received = socket.receive(buff);
                enforce(Socket.ERROR != received, "Socket receive error");
                temBuff = temBuff[received..$];
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