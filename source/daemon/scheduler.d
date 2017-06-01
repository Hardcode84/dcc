module scheduler;

import std.concurrency;
import std.range;
import std.array;
import std.exception;
import core.time;

import vibe.core.log;

import task;

alias TaskSink = immutable bool delegate(in TaskDesc desc);

struct SchedulerSettings
{
    TaskSink local_worker;
    TaskSink remote_worker;
    Duration task_wait_timeout = 100.msecs;
}


struct Scheduler
{
public:
    this(in SchedulerSettings settings)
    {
        assert(settings.local_worker !is null);
        assert(settings.remote_worker !is null);
        m_settings = settings;
    }

    this(this) @disable;

    TaskResultInfo processTaskGroup(ref TaskGroup tasks) const
    {
        assert(m_settings.local_worker !is null);
        assert(m_settings.remote_worker !is null);
        auto tid = thisTid();
        const scope void completionCallback(immutable(Task)* task, in TaskResultInfo result)
        {
            assert(task !is null);
            send(tid, TaskCompleted(task, result));
        }

        auto task_result = TaskResult.Success;
        auto task_stdout = appender!string;
        auto task_stderr = appender!string;

        const scope void scheduleTasks(ref TaskGroup tasks)
        {
            // Put local tasks first
            while(true)
            {
                auto task = tasks.getNextTask(true);
                if(task !is null &&
                   m_settings.local_worker(TaskDesc(&task.task, &completionCallback)))
                {
                    task.markInProgress();
                }
                else
                {
                    break;
                }
            }
            // Put remaining tasks
            while(true)
            {
                auto task = tasks.getNextTask(false);
                if(task !is null &&
                   (m_settings.local_worker(TaskDesc(&task.task, &completionCallback)) ||
                    m_settings.remote_worker(TaskDesc(&task.task, &completionCallback))))
                {
                    task.markInProgress();
                }
                else
                {
                    break;
                }
            }
        }

        const scope void waitTasks(ref TaskGroup tasks, in Duration timeout)
        {
            while(!tasks.inProgressTasks.empty)
            {
                const received = receiveTimeout(timeout,
                (TaskCompleted msg)
                {
                    static assert(0 == TaskWrapper.task.offsetof);
                    auto task = cast(TaskWrapper*)msg.task;
                    const taskResult = msg.result;
                    if(!taskResult.stdout.empty)
                    {
                        task_stdout ~= taskResult.stdout;
                    }
                    if(!taskResult.stderr.empty)
                    {
                        task_stderr ~= taskResult.stderr;
                    }
                    if(TaskResult.Success != taskResult.result)
                    {
                        task_result = TaskResult.Failure;
                    }
                    task.markCompleted();
                });

                if(!received)
                {
                    break;
                }
            }
        }

        while(true)
        {
            scheduleTasks(tasks);
            //waitTasks(tasks, m_settings.task_wait_timeout);

            if(TaskResult.Success != task_result || tasks.completed)
            {
                break;
            }
        }
        waitTasks(tasks, -1.msecs);
        assert(tasks.inProgressTasks.empty);

        return TaskResultInfo(task_result, task_stdout.data, task_stderr.data);
    }

private:
    const SchedulerSettings m_settings;

    struct TaskCompleted
    {
        immutable(Task)* task;
        TaskResultInfo result;
    }
}

