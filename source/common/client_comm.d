module client_comm;

import std.exception;
import std.format;
import std.algorithm;

import serialization;
import driver;
import task;

alias OutSink = void delegate(const(void)[]);
alias InSink = void delegate(ref void[]);

TaskResultInfo client_process(in string driver, in Command command, scope InSink readSink, scope OutSink writeSink)
{
    auto stream = BinaryStream(writeSink, readSink);
    serialize(stream, ClientHello.init);
    const serverHello = deserialize!ServerHello(stream);
    enforce(serverHello.header == ServerHelloStr, "Invalid server response");
    serialize(stream, ClientCommand(driver, command));
    const response = deserialize!ServerResult(stream);
    return response.result;
}

alias ProcessSink = TaskResultInfo delegate(in string, in Command);
void server_process(scope InSink readSink, scope OutSink writeSink, scope ProcessSink processSink)
{
    auto stream = BinaryStream(writeSink, readSink);
    const clientHello = deserialize!ClientHello(stream);
    enforce(clientHello.header == ClientHelloStr, "Invalid client response");
    enforce(clientHello.protocolVersion == ProtocolVersion, format("Invalid protocol version (expected %s got %s)",ProtocolVersion,clientHello.protocolVersion));
    serialize(stream, ServerHello.init);
    const command = deserialize!ClientCommand(stream);
    const result = processSink(command.driver, command.command);
    serialize(stream, ServerResult(result));
}

private:
// 
// SERVER<-ClientHello<-CLIENT
// SERVER->ServerHello->CLIENT
// SERVER<-ClientCommand<-CLIENT
// SERVER->ServerResult->CLIENT
//
// END

enum ProtocolVersion = 1;
enum ClientHelloStr = "dcc-cl-hel";
enum ServerHelloStr = "dcc-cl-ack";

struct ClientHello
{
    char[ClientHelloStr.length] header = ClientHelloStr;
    byte protocolVersion = ProtocolVersion;
}

struct ServerHello
{
    char[ServerHelloStr.length] header = ServerHelloStr;
}

struct ClientCommand
{
    string driver;
    Command command;
}

struct ServerResult
{
    TaskResultInfo result;
}