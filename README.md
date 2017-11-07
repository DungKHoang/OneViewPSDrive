# OneView PS Drive

OneViewPSDrive.psm1 is a PowerShell module that enables administrators to browse OneView resources just like a file system


## Prerequisites
The PSM1 module requires:
   * PowerShell v5.0 ( inlcuded in Windows 10 / Windows Server 2016). For older versions, install the Windows Management Framework v5.0
   * Windows .NET framework 4.6 
   * OneView PowerShell library : https://github.com/HewlettPackard/POSH-HPOneView/releases
   * SHiPS (Simple Hierarchy in PowerShell) module : https://github.com/PowerShell/SHiPS  

## Install pre-requisites
   * If needed, install Windows Management Framework v5.0 : https://www.microsoft.com/en-us/download/details.aspx?id=50395
   * Install Windows .NET framework 4.6 : https://www.microsoft.com/en-us/download/confirmation.aspx?id=48137
   * Reboot the system
   * Download the OneViewPSDrive module and unpack in a folder , for example: C:\OneViewPSdrive
   * Install SHiPS 
```
    install-module SHIPS
```
   * Install OneView library 
```
    install-module HPOneView.310
```


## Configure the environment 

   * Import PS modules
```
    import-module SHiPS
    Import-module HPOneView.310
```   
   *  Define environment variables
```
    $env:OVappliance        = "<your-Appliance-name-or-ip>"
    $env:OVAdminName        = "administrator"
    $env:OVAdminPassword    = "<your password>"
    $env:OVLibraryModule    = 'HPOneView.310'
```
   * Create a drive that maps to OneView 
```
    new-psdrive -name OV -psprovider SHiPS -root OneViewPSDrive#OV
``` 

## Explore OneView resources

   * Simple commands. Note : A dot ('.') means that the output is a leaf (end-node). A plus (+) means that the output is a folder
```
    Dir OV:
    ls OV:
    dir -recurse OV:
    ls -r OV:
    cd OV:
    cd settings
    dir 'OV:\server hardware'
```   

   * View setting of OneView resource
```
   dir OV:\enclosure\F1-CN75140CR5 | select resource,setting,value
```

   * View all settings of all server hardware and server hardware type
```
   dir 'OV:\server hardware' -recurse | select resource,setting,value
   dir 'OV:\server hardware type' -recurse | select resource,setting,value
```

   * Refresh OneView resources
```
   dir OV: -force
```

   * Remove PS drive 
```
   remove-psdrive OV
```

## Known issues

   * Not TESTED on OneView 3.00
   * Not TESTED with PowerShell OneView library 3.00
   * Server prfiles may have some issues