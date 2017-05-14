import std.process;

enum client_exec = "dcc_client";
enum driver = "cl";

int main(string[] args)
{
    return wait(spawnProcess([client_exec, driver] ~ args[1..$]));
}
