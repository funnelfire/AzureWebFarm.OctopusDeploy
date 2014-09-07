using Microsoft.WindowsAzure.ServiceRuntime;
using System.Diagnostics;
using System.Threading;

namespace WorkerFarm
{
    public class WorkerRole : RoleEntryPoint
    {
        private readonly AzureWebFarm.OctopusDeploy.FarmRole _webFarmRole;

        public WorkerRole()
        {
            _webFarmRole = new AzureWebFarm.OctopusDeploy.FarmRole(workerRole: true);
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
