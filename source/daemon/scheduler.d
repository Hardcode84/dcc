module scheduler;

struct SchedulerSettings
{
    uint maxInternalJobs;
    uint maxExternalJobs;
}

final class Scheduler
{
public:
    this()
    {

    }

private:
    Worker[] m_workers;
}

final class Worker
{

}