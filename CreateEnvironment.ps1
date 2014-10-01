param([String]$configPath)

if (($configPath -eq $null) -or ($configPath -eq ""))
{
    Write-Error "No configuration file path specified."
    return
}

$environment = ".\ScriptEnvironment"

[xml]$config = Get-Content $configPath

try {
    rmdir $environment -Force -Recurse
} catch {
[ItemNotFoundException]
}
git clone . $environment

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

$children = $serviceDef.ServiceDefinition.ChildNodes | foreach { $_ }
$children | % { $serviceDef.ServiceDefinition.RemoveChild($_) }

$children = $serviceCfg.ServiceConfiguration.ChildNodes | foreach { $_ }
$children | % { $serviceCfg.ServiceConfiguration.RemoveChild($_) }

$children = $ccproj.Project.ItemGroup.ProjectReference | foreach { $_ }
$children | % { $ccproj.Project.ItemGroup.RemoveChild($_) }

$roles = $config.GetElementsByTagName("WebRole") + $config.GetElementsByTagName("WorkerRole")
foreach ($role in $roles) {
    $tagName = $role.get_Name()
    $roleCfg = $protoRoleCfg.Clone()
    if ($tagName -eq "WebRole") {
        $roleDef = $protoWebRoleDef.Clone()
        $roleRef = $protoWebRoleRef.Clone()
        $type = "Web"
    } else {
        $roleDef = $protoWorkerRoleDef.Clone()
        $roleRef = $protoWorkerRoleRef.Clone()
        $type = "Worker"
    }

    $roleDef.name = $role.name
    $roleDef.vmsize = $role.vmsize

    $settings = @(@($role.ConfigurationSettings.ChildNodes) + @($config.Service.ConfigurationSettings.ChildNodes) -ne $null)
    $config.Service.ConfigurationSettings
    foreach ($setting in $settings) {
        $settingDef = $roleDef.ConfigurationSettings.Setting | ? { $_.name -eq $setting.name }
        if ($settingDef -eq $null) {
            $settingDef = $serviceDef.CreateElement("Setting")
            $settingDef.SetAttribute("name", $setting.name)
            $roleDef.ConfigurationSettings.AppendChild($settingDef)
        }

        $settingCfg = $roleCfg.ConfigurationSettings.Setting | ? { $_.name -eq $setting.name }
        if ($settingCfg -eq $null) {
            $settingCfg = $serviceCfg.CreateElement("Setting")
            $settingCfg.SetAttribute("name", $setting.name)
            $roleCfg.ConfigurationSettings.AppendChild($settingCfg)
        }
        $settingCfg.SetAttribute("value", $setting.value)
    }

    if ($roleDef.Sites -ne $null) {
        $roleDef.RemoveChild($roleDef.Sites)
        $sites = $roleDef.OwnerDocument.ImportNode($role.Sites, $true)
        $roleDef.AppendChild($sites)
        $sites.SetAttribute("xmlns", $serviceDef.ServiceDefinition.NamespaceUri)
    }

    if ($roleDef.Endpoints -ne $null) {
        $roleDef.RemoveChild($roleDef.Endpoints)
        $endpoints = $roleDef.OwnerDocument.ImportNode($role.Endpoints, $true)
        $roleDef.AppendChild($endpoints)
        $endpoints.SetAttribute("xmlns", $serviceDef.ServiceDefinition.NamespaceUri)
    }
    
    $roleCfg.name = $role.name
    $roleCfg.Instances.count = $role.Instances.count

    if ($role.Certificates -ne $null) {
        $certificates = $roleCfg.OwnerDocument.ImportNode($role.Certificates, $true)
        foreach ($certificate in $certificates.ChildNodes) {
            $roleCfg.Certificates.AppendChild($certificate)
            $certificate.SetAttribute("xmlns", $serviceCfg.ServiceConfiguration.NamespaceUri)
        }
    }

    $name = $role.name
    $protoName = "Example${Type}Farm"
    mkdir $environment\$name
    copy $environment\Example${Type}Farm\* $environment\$name -Recurse

    [xml]$csproj = Get-Content $environment\$protoName\$protoName.csproj
    $guid = ([guid]::NewGuid()).ToString("b")
    $csproj.Project.PropertyGroup[0].ProjectGuid = $guid
    $csproj.Save("$environment\$name\$protoName.csproj")

    $roleRef["Name"]."#text" = $name
    $roleRef["RoleName"]."#text" = $name
    $roleRef["RoleType"]."#text" = $type
    $roleRef["Project"]."#text" = $guid
    $roleRef.Include = "..\$name\$protoName.csproj"

    $serviceDef.ServiceDefinition.AppendChild($roleDef)
    $serviceCfg.ServiceConfiguration.AppendChild($roleCfg)
    $ccproj.Project.ItemGroup.AppendChild($roleRef)
}

if ($config.Service.NetworkConfiguration -ne $null) {
    $nwconfig = $serviceCfg.ImportNode($config.Service.NetworkConfiguration, $true)
    $serviceCfg.ServiceConfiguration.AppendChild($nwconfig)
    $nwconfig.SetAttribute("xmlns", $serviceCfg.ServiceConfiguration.NamespaceUri)
}

$serviceDef.Save("$environment\AzureWebFarm.OctopusDeploy.Example\ServiceDefinition.csdef")
$serviceCfg.Save("$environment\AzureWebFarm.OctopusDeploy.Example\ServiceConfiguration.cscfg")
$ccproj.Save("$environment\AzureWebFarm.OctopusDeploy.Example\AzureOctopusFarm.ccproj")