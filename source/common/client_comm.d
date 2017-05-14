module client_comm;

import std.exception;
import std.format;
import std.algorithm;

import serialization;
import driver;

void client_process(in string driver, in Command command, scope InSink readSink, scope OutSink writeSink)
{
    ClientHello.write_string(writeSink);
    checkString!ClientHelloResp(readSink);
    driver.write_string(writeSink);
    command.serialize(writeSink);
    checkString!ClientCommReady(readSink);
}

alias ProcessSink = void delegate(in string, in Command);
void server_process(scope InSink readSink, scope OutSink writeSink, scope ProcessSink processSink)
{
    checkString!ClientHello(readSink);
    ClientHelloResp.write_string(writeSink);
    const driver = read_string(readSink);
    const command = Command.deserialize(readSink);
    processSink(driver, command);
    ClientCommReady.write_string(writeSink);
}

private:
// 
// SERVER<-ClientHello<-CLIENT
// SERVER->ClientHelloResp->CLIENT
// SERVER<-driver_string<-CLIENT
// SERVER<-command<-CLIENT
// SERVER->ClientCommReady->CLIENT
//
// END

enum ClientHello = "dcc-cl-hel";
enum ClientHelloResp = "dcc-cl-ack";
enum ClientCommReady = "dcc-cl-rdy";

void checkString(alias S)(scope InSink sink)
{
    const str = read_string(sink);
    enforce(equal(str[], S[]), format("Unexpected responce %s (expected %s)", str, S));
}

void checkVal(string Desc, T)(scope InSink sink, in T expected)
{
    const val = read_val!T(sink);
    enforce(val == expected, format("%s (expected %s, got %s)", Desc, expected, val));
}