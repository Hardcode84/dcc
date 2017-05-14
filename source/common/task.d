module task;

import std.range;
import std.array;

import intrusive_list;
import serialization;

struct Task
{
    alias IdType = ushort;
    IdType id = 0;
    bool local = true;
    IdType[] dependsOn;
    const(string)[] options;
    string inFile;
    string outFile;
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
    const Task task;
    TaskState state = TaskState.Ready;
    ushort unresolvedDeps = 0;
    Task.IdType[] nextTasks;
    TaskGroup* group = null;

    IntrusiveListLink link;

    alias task this;

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
        link.unlink();
        group.inProgressTasks.insertBack(&this);
        state = TaskState.InProgress;
    }

    void markCompleted()
    {
        assert(TaskState.InProgress == state);
        assert(group !is null);
        link.unlink();
        group.completedTasks.insertBack(&this);
        foreach(id; nextTasks)
        {
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

    this(in Task[] src)
    {
        tasks.length = src.length;
        foreach(i, const ref task; src)
        {
            auto newTask = &tasks[i];
            *newTask = TaskWrapper(task);
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
        foreach(i, ref task; tasks)
        {
            foreach(id; task.dependsOn)
            {
                assert(id < tasks.length);
                ++tasks[id].unresolvedDeps;
            }
        }
        foreach(i, ref task; tasks)
        {
            foreach(id; task.dependsOn)
            {
                assert(id < tasks.length);
                assert(tasks[id].unresolvedDeps > 0);
                if(tasks[id].nextTasks.empty)
                {
                    tasks[id].nextTasks.reserve(tasks[id].unresolvedDeps);
                }
                tasks[id].nextTasks ~= id;
            }
        }
    }

    bool completed() const
    {
        assert(!tasks.empty);
        return tasksWithDeps.empty() && availableTasks.empty() && availableLocalTasks.empty() && inProgressTasks.empty();
    }

    TaskWrapper* getNextTask(bool local)
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