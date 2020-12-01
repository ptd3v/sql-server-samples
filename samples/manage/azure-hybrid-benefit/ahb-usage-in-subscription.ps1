﻿# This scripts calculates the AHB usage by all the SQL resources in a specific subscription 
# based on the selected Azure Hybrid Benefit option 

# Set the subscription Id
$SubcriptionId = read-host -Prompt "Enter Subscription ID"
Set-AzContext -SubscriptionId $SubcriptionId

# Variables to keep track of SQL VMs and VCPUs count
$total_std_vcores = 0
$total_ent_vcores = 0

#Get all SQL databadses in the subscription
$databases = Get-AzSqlServer | Get-AzSqlDatabase

# Get the databases with License Included and add to VCore count
foreach ($db in $databases){
    if (($db.SkuName -ne "ElasticPool") -and ($db.LicenseType -eq "LicenseIncluded")) {
        if ($db.Edition -eq "BusinessCritical") {
            $total_ent_vcores += $db.Capacity
        } elseif ($db.Edition -eq "GeneralPurpose") {
            $total_std_vcores += $db.Capacity
        }
    }
}

#Get all SQL elastic pools in the subscription
$pools = Get-AzSqlServer | Get-AzSqlElasticPool

# Get the elastic pools with License Included and and add to VCore count
foreach ($pool in $pools){
    if ($pool.LicenseType -eq "LicenseIncluded") {
        if ($pool.Edition -eq "BusinessCritical") {
            $total_ent_vcores += $pool.Capacity
        } elseif ($pool.Edition -eq "GeneralPurpose") {
            $total_std_vcores += $pool.Capacity
        }
    }
}

#Get all SQL managed instances in the subscription
$instances = Get-AzSqlInstance

# Get the SQL managed instances with License Included and add to VCore count
foreach ($ins in $instances){
    if (($ins.InstancePoolName -eq $null) -and ($ins.LicenseType -eq "LicenseIncluded")) {
        if ($ins.Sku.Tier -eq "BusinessCritical") {
            $total_ent_vcores += $ins.VCores
        } elseif ($ins.Sku.Tier -eq "GeneralPurpose") {
            $total_std_vcores += $ins.VCores
        }
    }
}

#Get all instance pools in the subscription
$ipools = Get-AzSqlInstancePool

# Get the instance pools with License Included and add to VCore count
foreach ($ip in $ipools){
    if ($ip.LicenseType -eq "LicenseIncluded") {
        if ($ip.Edition -eq "BusinessCritical") {
            $total_ent_vcores += $ip.VCores
        } elseif ($ip.Edition -eq "GeneralPurpose") {
            $total_std_vcores += $ip.VCores
        }
    }
}

#Get All Sql VMs with AHB license configured
$sql_vms= Get-AzSqlVM | where {$_.LicenseType.Contains("AHUB")}

# Get the VM size, match it with the corresponding VCPU count and add to VCore count
foreach ($sql_vm in $sql_vms){
    $vm = Get-AzVm -Name $sql_vm.Name -ResourceGroupName $sql_vm.ResourceGroupName
    $vm_size = $vm.HardwareProfile.VmSize
    # Select first size and get the VCPus available
    $size_info = Get-AzComputeResourceSku | where {$_.ResourceType.Contains('virtualMachines') -and $_.Name -like $vm_size} | Select-Object -First 1
    # Save the VCPU count
    $vcpu= $size_info.Capabilities | Where-Object {$_.name -eq "vCPUsAvailable"}

    if ($vcpu){
        $data = [pscustomobject]@{vm_resource_uri=$vm.Id;sku=$sql_vm.Sku;size=$vm_size;vcpus=$vcpu.value}
        $array += $data

        if ($data.sku -like "Enterprise"){
            $total_ent_vcores += $data.vcpus
        }elseif ($data.sku -like "Standard"){
            $total_std_vcores += $data.vcpus
        }
    }
}

Write-Host "Total number of VCores for SQL Enterprise: "  $total_ent_vcores
Write-Host "Total number of VCores for SQL Standard: "  $total_std_vcores