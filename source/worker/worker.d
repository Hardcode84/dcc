module worker;

import std.stdio;
import std.exception;

import worker_comm;
import drivers;

void main(string[] args)
{
    enforce(2 == args.length, "Invalid arguments count");
    const driver_name = args[1];
    writefln("Initializing worker (driver=%s)", driver_name);
    auto driver = getDriver(driver_name);
    writeReady(stdout);
    while(true)
    {
        const task = receiveMessage!WorkerTask(stdin);
        const result = driver.executeTask(task.task);
        sendMessage(stdout, WorkerTaskResult(result));
    }
}
