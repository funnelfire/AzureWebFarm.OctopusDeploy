using Microsoft.WindowsAzure.ServiceRuntime;

namespace WebFarm
{
    public class WebRole : RoleEntryPoint
    {
        private readonly AzureWebFarm.OctopusDeploy.FarmRole _webFarmRole;

        public WebRole()
        {
            _webFarmRole = new AzureWebFarm.OctopusDeploy.FarmRole();
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
