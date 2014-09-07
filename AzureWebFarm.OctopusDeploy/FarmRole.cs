using System;
using System.Threading;
using AzureWebFarm.OctopusDeploy.Infrastructure;
using Microsoft.WindowsAzure.ServiceRuntime;
using Serilog;

namespace AzureWebFarm.OctopusDeploy
{
    /// <summary>
    /// Coordinates an OctopusDeploy-powered farm Azure Role.
    /// </summary>
    public class FarmRole
    {
        private readonly Infrastructure.OctopusDeploy _octopusDeploy;
        private readonly bool _workerRole;

        /// <summary>
        /// Create the web role coordinator.
        /// </summary>
        /// <param name="machineName">Specify the machineName if you would like to override the default machine name configuration.</param>
        /// <param name="workerRole">Specifies whether or not the role is a worker.</param>
        public FarmRole(string machineName = null, bool workerRole = false)
        {
            Log.Logger = AzureEnvironment.GetAzureLogger();
            var config = AzureEnvironment.GetConfigSettings();

            _workerRole = workerRole;

            machineName = machineName ?? AzureEnvironment.GetMachineName(config);
            var octopusRepository = Infrastructure.OctopusDeploy.GetRepository(config);
            var processRunner = new ProcessRunner();
            var registryEditor = new RegistryEditor();
            _octopusDeploy = new Infrastructure.OctopusDeploy(machineName, config, octopusRepository, processRunner, registryEditor);

            AzureEnvironment.RequestRecycleIfConfigSettingChanged(config);
        }

        /// <summary>
        /// Call from the RoleEntryPoint.OnStart() method.
        /// </summary>
        /// <returns>true; throws exception is there is an error</returns>
        public bool OnStart()
        {
            _octopusDeploy.ConfigureTentacle();
            _octopusDeploy.DeployAllCurrentReleasesToThisMachine();
            return true;
        }

        /// <summary>
        /// Call from the RoleEntryPoint.Run() method.
        /// Note: This method is an infinite loop; call from a Thread/Task if you want to run other code alongside.
        /// </summary>
        public void Run()
        {
            // Don't want to configure IIS if we are emulating; just sleep forever
            if (RoleEnvironment.IsEmulated || _workerRole)
                Thread.Sleep(Timeout.Infinite);

            while (true)
            {
                try
                {
                    IisEnvironment.ActivateAppInitialisationModuleForAllSites();
                }
                catch (Exception e)
                {
                    Log.Warning(e, "Failure to configure IIS");
                }

                Thread.Sleep(TimeSpan.FromMinutes(10));
            }
        // ReSharper disable FunctionNeverReturns
        }
        // ReSharper restore FunctionNeverReturns

        /// <summary>
        /// Call from RoleEntryPoint.OnStop().
        /// </summary>
        public void OnStop()
        {
            _octopusDeploy.UninstallTentacle();
            _octopusDeploy.DeleteMachine();

            if (!_workerRole)
                IisEnvironment.WaitForAllHttpRequestsToEnd();
        }
    }
}
