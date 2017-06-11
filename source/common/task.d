module task;

import std.range;
import std.array;

import intrusive_list;
import serialization;

struct Command
{
    immutable(string)[] options;
    immutable(string)[] files;
    string outFile;

    @property bool empty() const pure nothrow @nogc
    {
        return options.empty && files.empty && outFile.empty;
    }
}

struct Task
{
    alias IdType = ushort;
    IdType id = 0;
    bool local = true;
    immutable(IdType)[] dependsOn;
    immutable(string)[] options;
    string inFile;
    string outFile;
}

alias TaskCompletionCallback = void delegate(immutable(Task)* task, in TaskResultInfo result) immutable;

struct TaskDesc
{
    immutable(Task)* task;
    TaskCompletionCallback completion_callback;
}

enum TaskResult
{
    Success,
    Failure
}

struct TaskResultInfo
{
    TaskResult result = TaskResult.Failure;
    string stdout;
    string stderr;
}

enum TaskState
{
    HasDeps,
    Ready,
    InProgress,
    Completed
}

struct TaskWrapper
{
    immutable Task task;
    TaskState state = TaskState.Ready;
    ushort unresolvedDeps = 0;
    Task.IdType[] nextTasks;
    TaskGroup* group = null;

    IntrusiveListLink link;

    //alias task this;

    void depReady()
    {
        assert(TaskState.HasDeps == state);
        assert(unresolvedDeps > 0);
        assert(link.isLinked());
        assert(group !is null);
        if(0 == --unresolvedDeps)
        {
            link.unlink();
            group.availableTasks.insertBack(&this);
            state = TaskState.Ready;
        }
    }

    void markInProgress()
    {
        assert(TaskState.Ready == state);
        assert(group !is null);
        assert(link.isLinked());
        link.unlink();
        group.inProgressTasks.insertBack(&this);
        state = TaskState.InProgress;
    }

    void markCompleted()
    {
        assert(TaskState.InProgress == state);
        assert(group !is null);
        assert(link.isLinked());
        link.unlink();
        group.completedTasks.insertBack(&this);
        foreach(id; nextTasks)
        {
            assert(id != task.id);
            assert(id < group.tasks.length);
            group.tasks[id].depReady();
        }
        state = TaskState.Completed;
    }
}

struct TaskGroup
{
    TaskWrapper[] tasks;

    alias NodeList = IntrusiveList!(TaskWrapper,"link");
    NodeList tasksWithDeps;
    NodeList availableTasks;
    NodeList availableLocalTasks;
    NodeList inProgressTasks;
    NodeList completedTasks;

    this(in Task[] src) pure nothrow
    {
        tasks.length = src.length;
        foreach(i, const ref task; src)
        {
            auto newTask = &tasks[i];
            *newTask = TaskWrapper(task);
            newTask.group = &this;
            const hasDeps = !task.dependsOn.empty;
            newTask.state = (hasDeps ? TaskState.HasDeps : TaskState.Ready);
            if(hasDeps)
            {
                tasksWithDeps.insertBack(newTask);
            }
            else
            {
                if(task.local)
                {
                    availableLocalTasks.insertBack(newTask);
                }
                else
                {
                    availableTasks.insertBack(newTask);
                }
            }
        }

        foreach(ref task; tasks)
        {
            task.unresolvedDeps = cast(ushort)task.task.dependsOn.length;
            foreach(id; task.task.dependsOn)
            {
                assert(id < tasks.length);
                tasks[id].nextTasks ~= task.task.id;
            }
        }
    }

    this(this) @disable;

    ~this()
    {
        foreach(ref task; tasks)
        {
            task.link.unlink();
        }
    }

    bool completed() const pure nothrow @nogc
    {
        assert(!tasks.empty);
        return tasksWithDeps.empty() && availableTasks.empty() && availableLocalTasks.empty() && inProgressTasks.empty();
    }

    TaskWrapper* getNextTask(bool local) pure nothrow @nogc
    {
        auto list = (local ? &availableLocalTasks : &availableTasks);
        if (list.empty)
        {
            return null;
        }
        auto ret = list.front;
        return ret;
    }
}