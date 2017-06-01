module workers_pool;

import std.algorithm;
import std.process;
import std.typecons;
import std.exception;
import std.format;
import std.range;
import core.atomic;

import vibe.core.log;
import vibe.core.concurrency;

import drivers;
import worker_comm;
import task;
import serialization;

struct WorkersPoolSettings
{
    size_t max_workers;
    string driver;
}

struct WorkersPool
{
public:
    this(in WorkersPoolSettings settings)
    {
        scope(success) logInfo("Worker pool created");
        scope(failure)
        {
            logInfo("Worker pool creation failed");
            close();
        }
        logInfo("Creating workers pool (%s workers)", settings.max_workers);
        const maxWorkers = settings.max_workers;
        assert(maxWorkers > 0);
        m_workers.length = maxWorkers;
        foreach(i; 0..maxWorkers)
        {
            m_workers[i] = createWorker(WorkerSettings(settings.driver));
        }
    }

    this(this) @disable;

    ~this()
    {
        close();
    }

    TaskSink taskSink(size_t maxWorkers) pure nothrow @nogc
    {
        assert(maxWorkers > 0);
        assert(maxWorkers <= m_workers.length);
        return TaskSink(&this, maxWorkers);
    }

    auto workersCount() const pure nothrow @nogc @safe
    {
        return m_workers.length;
    }

private:
    WorkerPtr[] m_workers;

    struct TaskSink
    {
        WorkersPool* pool = null;
        const size_t count = 0;
        size_t current_index = 0;

        bool tryPut(in TaskDesc desc)
        {
            assert(desc.task !is null);
            assert(pool !is null);
            assert(!pool.m_workers.empty);
            assert(count <= pool.m_workers.length);
            foreach(i; 0..count)
            {
                const ind = (i + current_index) % count;
                if (pool.m_workers[ind].tryPutTask(desc))
                {
                    current_index = ind;
                    return true;
                }
            }
            return false;
        }
    }

    void close()
    {
        foreach(ref worker; m_workers)
        {
            if (!worker.isEmpty)
            {
                worker.close();
            }
        }
        m_workers = m_workers.init;
    }

}

private:

struct WorkerSettings
{
    string driver;
}

alias WorkerPtr = Unique!Worker;

WorkerPtr createWorker(in WorkerSettings settings)
{
    WorkerPtr ret = new Worker(settings);
    return ret;
}

void threadFuncWrapper(shared Worker* worker, in WorkerSettings settings)
{
    Worker.threadFunc(worker, settings);
}

static struct Worker
{
public:
    this(in WorkerSettings settings)
    {
        scope(failure)
        {
            close();
        }
        m_tid = spawn(&threadFuncWrapper, cast(shared Worker*)&this, settings);
        m_alive = true;
        receive((CreateCompleted m) {});
    }

    this(this) @disable;

    ~this()
    {
        close();
    }

    void close()
    {
        if(m_alive)
        {
            prioritySend(m_tid, Terminate());
            m_alive = false;
        }
    }

    bool tryPutTask(in TaskDesc desc)
    {
        assert(desc.task !is null);
        assert(m_alive);
        if(!cas(&m_working, false, true))
        {
            return false;
        }
        scope(failure) atomicStore(m_working, false);
        send(m_tid, ExecuteTask(desc.task, desc.completion_callback));
        return true;
    }

private:
    Tid m_tid;
    bool m_alive = false;
    shared bool m_working = false;

    struct CreateCompleted{}
    struct Terminate{}
    struct ExecuteTask
    {
        immutable(Task)* task;
        TaskCompletionCallback completion_callback;
    }

    static void threadFunc(shared Worker* worker, in WorkerSettings settings)
    {
        // Not the most efficient implementation, but ok for now
        logInfo("Creating worker");
        auto pipes = pipeProcess(["dcc_worker", settings.driver], Redirect.stdin | Redirect.stdout);
        auto pid = pipes.pid;
        scope(exit)
        {
            const id = pid.processID;
            logInfo("Terminating worker %s", id);
            kill(pid);
            const ret = wait(pid);
            logInfo("Worker %s terminated with 0x%x", id, ret);
        }
        void checkWorker()
        {
            assert(pid);
            const result = tryWait(pid);
            enforce(!result.terminated, format("Worker terminated prematurely with status %s", result.status));
        }
        checkWorker();
        waitForReady(pipes.stdout,
            (str)
            {
                logInfo("%s", str);
            });
        checkWorker();
        logInfo("Worker created %s", pid.processID);
        send(ownerTid(), CreateCompleted.init);

        bool terminate = false;
        do
        {
            receive(
                (Terminate msg)
                {
                    terminate = true;
                },
                (ExecuteTask msg)
                {
                    scope(exit) atomicStore(worker.m_working, false);
                    const task = msg.task;
                    assert(task !is null);
                    const callback = msg.completion_callback;
                    sendMessage(pipes.stdin, WorkerTask(*task));
                    auto result = receiveMessage!WorkerTaskResult(pipes.stdout);
                    if(callback)
                    {
                        callback(task, result.result);
                    }
                });
        }
        while(!terminate);
    }
}
