using Microsoft.WindowsAzure.ServiceRuntime;
using System.Diagnostics;
using System.Threading;

namespace WorkerFarm
{
    public class WorkerRole : RoleEntryPoint
    {
        private readonly AzureWebFarm.OctopusDeploy.WebFarmRole _webFarmRole;

        public WorkerRole()
        {
            SpinWait.SpinUntil(() => Debugger.IsAttached);
            _webFarmRole = new AzureWebFarm.OctopusDeploy.WebFarmRole(workerRole: true);
        }

        public override bool OnStart()
        {
            return _webFarmRole.OnStart();
        }

        public override void Run()
        {
            _webFarmRole.Run();
        }

        public override void OnStop()
        {
            _webFarmRole.OnStop();
        }
    }
}
