param([String]$configPath)

if (($configPath -eq $null) -or ($configPath -eq ""))
{
    Write-Error "No configuration file path specified."
    return
}

$environment = ".\ScriptEnvironment"

[xml]$config = Get-Content $configPath

rmdir environment -Force -ErrorAction SilentlyContinue -Recurse
git clone . environment

[xml]$serviceDef = Get-Content $environment\AzureWebFarm.OctopusDeploy.Example\ServiceDefinition.csdef
[xml]$serviceCfg = Get-Content $environment\AzureWebFarm.OctopusDeploy.Example\ServiceConfiguration.cscfg
[xml]$ccproj = Get-Content $environment\AzureWebFarm.OctopusDeploy.Example\AzureOctopusFarm.ccproj

$serviceDef.ServiceDefinition.name = $config.Service.name
$serviceCfg.ServiceConfiguration.serviceName = $config.Service.name

$protoWebRoleDef = $serviceDef.ServiceDefinition.WebRole
$protoWorkerRoleDef = $serviceDef.ServiceDefinition.WorkerRole
$protoRoleCfg = $serviceCfg.ServiceConfiguration.Role[0]
$protoWebRoleRef = $ccproj.Project.ItemGroup.ProjectReference[0]
$protoWorkerRoleRef = $ccproj.Project.ItemGroup.ProjectReference[1]

foreach ($childNode in $serviceDef.ServiceDefinition.ChildNodes) {
    $serviceDef.ServiceDefinition.RemoveChild($childNode)
}

foreach ($childNode in $serviceCfg.ServiceConfiguration.ChildNodes) {
    $serviceCfg.ServiceConfiguration.RemoveChild($childNode)
}

foreach ($childNode in $ccproj.Project.ItemGroup.ProjectReference) {
    $ccproj.Project.ItemGroup.RemoveChild($childNode)
}

$webRoles = $config.GetElementsByTagName("WebRole")
foreach ($webRole in $webRoles) {
    $webRoleDef = $protoWebRoleDef.Clone()
    $webRoleCfg = $protoRoleCfg.Clone()
    $webRoleRef = $protoWebRoleRef.Clone()

    $webRoleDef.name = $webRole.name
    $webRoleDef.vmsize = $webRole.vmsize

    $webRoleDef.RemoveChild($webRoleDef.Sites)
    $sites = $webRoleDef.OwnerDocument.ImportNode($webRole.Sites, $true)
    $webRoleDef.AppendChild($sites)

    $webRoleDef.RemoveChild($webRoleDef.Endpoints)
    $endpoints = $webRoleDef.OwnerDocument.ImportNode($webRole.Endpoints, $true)
    $webRoleDef.AppendChild($endpoints)
    
    $webRoleCfg.name = $webRole.name
    $webRoleCfg.Instances.count = $webRole.Instances.count

    if ($webRole.Certificates -ne $null) {
        $certificates = $webRoleCfg.OwnerDocument.ImportNode($webRole.Certificates, $true)
        foreach ($certificate in $certificates.ChildNodes) {
            $webRoleCfg.Certificates.AppendChild($certificate)
        }
    }

    $webRoleRef.Name.Value = $webRole.name
    $webRoleRef.RoleName.Value = $webRole.name

    $serviceDef.ServiceDefinition.AppendChild($webRoleDef)
    $serviceCfg.ServiceConfiguration.AppendChild($webRoleCfg)
    $ccproj.Project.ItemGroup.AppendChild($webRoleRef)
}

$workerRoles = $config.GetElementsByTagName("WorkerRole")
foreach ($workerRole in $workerRoles) {
    $workerRoleDef = $protoWorkerRoleDef.Clone()
    $workerRoleCfg = $protoRoleCfg.Clone()
    $workerRoleRef = $protoWorkerRoleRef.Clone()

    $workerRoleDef.name = $workerRole.name
    $workerRoleDef.vmsize = $workerRole.vmsize

    if ($workerRoleDef.Endpoints -ne $null) {
        $workerRoleDef.RemoveChild($workerRoleDef.Endpoints)
    }
    if ($workerRole.Endpoints -ne $null) {
        $endpoints = $workerRoleDef.OwnerDocument.ImportNode($workerRole.Endpoints, $true)
        $workerRoleDef.AppendChild($endpoints)
    }
    
    $workerRoleCfg.name = $workerRole.name
    $workerRoleCfg.Instances.count = $workerRole.Instances.count

    if ($workerRole.Certificates -ne $null) {
        $certificates = $workerRoleCfg.OwnerDocument.ImportNode($workerRole.Certificates, $true)
        foreach ($certificate in $certificates.ChildNodes) {
            $workerRoleCfg.Certificates.AppendChild($certificate)
        }
    }

    $workerRoleRef.Name.Value = $workerRole.name
    $workerRoleRef.RoleName.Value = $workerRole.name

    $serviceDef.ServiceDefinition.AppendChild($workerRoleDef)
    $serviceCfg.ServiceConfiguration.AppendChild($workerRoleCfg)
    $ccproj.Project.ItemGroup.AppendChild($workerRoleRef)
}

if ($config.Service.NetworkConfiguration -ne $null) {
    $serviceCfg.ServiceConfiguration.AppendChild($config.Service.NetworkConfiguration.Clone())
}