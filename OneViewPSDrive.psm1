
using namespace Microsoft.PowerShell.SHiPS
#using Module 'c:\Program Files\WindowsPowerShell\modules\HPOneView.310\HPOneView.310.psd1'



$ICModuleTypes            = @{
    "VirtualConnectSE40GbF8ModuleforSynergy"    =  "SEVC40f8" ;
    "Synergy20GbInterconnectLinkModule"         =  "SE20ILM";
    "Synergy10GbInterconnectLinkModule"         =  "SE10ILM";
    "VirtualConnectSE16GbFCModuleforSynergy"    =  "SEVC16GbFC";
    "Synergy12GbSASConnectionModule"            =  "SE12SAS"
    }

    $FabricModuleTypes       = @{
    "VirtualConnectSE40GbF8ModuleforSynergy"    =  "SEVC40f8" ;
    "Synergy12GbSASConnectionModule"            =  "SAS";
    "VirtualConnectSE16GbFCModuleforSynergy"    =  "SEVCFC";

    }



Function Get-NamefromUri([string]$uri)
{
    $name = ""

    if ($Uri)
    { 
        try 
        {
            $name   = (Send-HPOVRequest $Uri).Name 
        }
        catch
        {
            $name = ""
        }
    }

    return $name
}

## -------------------------------------------------------
## 
##  Property class
##
## -------------------------------------------------------

Class Property : SHIPSLeaf
{
    static $name     = "Property"
    $value           = ""
    $resource        = ""
    $setting         = ""

    Property ([string]$setting, [string]$Value, [string]$resource): Base("Property")
    {
        $this.name      = $setting
        $this.setting   = $setting     # so you can either use name or setting
        $this.value     = $Value
        $this.resource  = $resource            
    }
}

## -------------------------------------------------------
## 
##  PropertiesfromPSObject class 
##
## -------------------------------------------------------

Class PropertiesfromPSObject : SHIPSDirectory
{
    static $name            = 'PropertiesfromPSObject'
    hidden $object          = @()
    hidden $buildproperty   = $false

    PropertiesfromPSObject([string]$name, $psobject, $Buildnamewithspace) : base('PropertiesfromPSObject')
    {
        $this.name          = $name
        $this.object        = $psobject
        $this.buildproperty = $Buildnamewithspace
    }

    [string]ConvertToStringSpace( [string]$str)
    {
        $newstr = ""
        
        foreach ($c in $str.ToCharArray())
        {
            if ($c -cmatch '[A-Z]')
            {
                $newstr +=  ' ' + $c.toString().tolower()
            }
            else
            { 
                $newstr += $c
            }
        }

        return $newstr
    }

    [object[]] GetChildItem()
    {
        $ListofObj      = @()
        foreach ($prop in $this.object)
        {
            $propname   = $prop.name
            $propvalue  = $prop.value
            if ($propname)
            {
                if ($this.buildproperty)
                {
                    $propname   = $this.ConvertToStringSpace($propname)
                }

                if ($propname.StartsWith("/rest/"))
                {
                    $propname   = $propname -replace 'uri',''
                    $propvalue  = Get-NamefromUri -uri $propvalue
                }

                $obj            = [Property]::new($propname, $propvalue , $this.name)
                $ListofObj     += $obj
            }
        }
        return $ListofObj
    }

}

## -------------------------------------------------------
## 
##  Capabilities class
##
## -------------------------------------------------------

Class Capabilities : SHIPSDirectory
{
    static $name            = 'Capabilities'
    hidden $capabilities    = @()

    Capabilities([string]$name, $capabilities) : base('Capabilities')
    {
        $this.name          = $name
        $this.capabilities  = $capabilities
    }

    [object[]] GetChildItem()
    {
        $ListofObj      = @()
        foreach ($val in $this.capabilities)
        {
            $obj        = [Property]::new($val, $val  , $this.name)
            $ListofObj += $obj
        }
        return $ListofObj
    }
}

## -------------------------------------------------------
## 
##   OV root drive
##
## -------------------------------------------------------


[SHiPSProvider(UseCache=$true)]  
Class OV : SHIPSDirectory
{
    OV([string]$name): base("OV")
    {
        if ($env:OVappliance)
        {
            if ($env:OVAdminName -and $env:OVAdminPassword)
            {
            $Global:applianceconnection = connect-hpovmgmt -Hostname $env:OVappliance -UserName $env:OVAdminName -Password $env:OVAdminPassword
            }
            else 
            {
                $cred = get-credential
                $Global:applianceconnection = connect-hpovmgmt -Hostname $env:OVappliance -Credential $cred    
            }
        }
        else 
        {
            write-verbose " Define env:OVappliance to point to an OneView appliance"    
        }
    }

    [object[]] GetChildItem()
    {
        $ListofObj =  @()
            # Ethernet and FC networks
            $ListofNetworks     = get-HPOVNetwork
            $obj                = [Network]::new("network", $ListofNetworks)
            $ListofObj         += $obj

            # Network Set
            $ListofNetworkSets  = Get-HPOVNetworkSet
            $obj                = [NetworkSet]::new("network set", $ListofNetworkSets)
            $ListofObj         += $obj

            #LIG 
            $ListofLIGs         = Get-HPOVLogicalInterconnectGroup | Sort Name
            $obj                = [LIG]::new("logical interconnect group", $ListofLIGs)
            $ListofObj         += $obj

            #EG 
            $ListofEGs          = Get-hpovEnclosureGroup  | sort Name
            $obj                = [EG]::new("enclosure group", $ListofEGs)
            $ListofObj         += $obj
            
            #SAN Managers
            $ListofSANMgrs      = Get-hpovSANManager | sort Name
            $obj                = [SANManager]::new("SAN manager", $ListofSANMgrs)
            $ListofObj         += $obj

            #Storage System
            $ListofStS          = Get-hpovStorageSystem | sort Name
            $obj                = [StorageSystem]::new("storage system", $ListofStS)
            $ListofObj         += $obj
            
            #Storage Pools
            $ListofStoragePools = Get-hpovStoragePool | sort Name
            $obj                = [StoragePool]::new("storage pool", $ListofStoragePools)
            $ListofObj         += $obj

            #Storage Volume Template
            $ListofvolTemplates = Get-hpovStorageVolumeTemplate | sort Name
            $obj                = [StorageVolumeTemplate]::new("storage volume template", $ListofvolTemplates)
            $ListofObj         += $obj

            #Storage Volume 
            $Listofvolumes      = Get-hpovStorageVolume | sort Name
            $obj                = [StorageVolume]::new("storage volume", $Listofvolumes)
            $ListofObj         += $obj

            #Server Hardware Type 
            $ListofSHTs         = Get-HPOVServerHardwareType | sort Name
            $obj                = [ServerHardwareType]::new("server hardware type", $ListofSHTs)
            $ListofObj         += $obj

            #Server Hardware 
            $ListofServers      = Get-HPOVServer | sort Name
            $obj                = [ServerHardware]::new("server hardware", $ListofServers)
            $ListofObj         += $obj

            #Enclosures
            $ListofEnclosures   = Get-HPOVEnclosure | sort Name
            $obj                = [Enclosure]::new("enclosure", $ListofEnclosures)
            $ListofObj         += $obj

            #Logical Enclosures
            $ListofLEs          = Get-HPOVLogicalEnclosure | sort Name
            $obj                = [LogicalEnclosure]::new("logical enclosure", $ListofLEs)
            $ListofObj         += $obj

            #Server Profile
            $Listofprofiles     = Get-HPOVServerProfile | sort Name
            $obj                = [ServerProfile]::new("server profile", $Listofprofiles)
            $ListofObj         += $obj

            #Server Profile Template
            $ListofSPTs         = Get-HPOVServerProfileTemplate | sort Name
            $obj                = [ServerProfileTemplate]::new("server profile template", $ListofSPTs)
            $ListofObj         += $obj

            # Settings
            $version            = Get-HPOVVersion  
            $version            = $version.$($global:ApplianceConnection.Name)
            $globalsetting      = Get-HPOVApplianceGlobalSetting
            $datetime           = Get-HPOVApplianceDateTime
            $addresspool        = Get-HPOVaddresspool | sort Name
            $addresspoolrange   = Get-HPOVaddresspoolrange
            $addresspoolsubnet  = Get-HPOVaddresspoolsubnet

            $obj                = [OVSettings]::new("Settings", $version, $globalsetting, $datetime ,$addresspool , $addresspoolrange, $addresspoolsubnet)
            $ListofObj         += $obj

        return $ListofObj
    }
}


#region networks

## -------------------------------------------------------
## 
##   Networks
##
## -------------------------------------------------------


Class Network : SHIPSDirectory
{
    static $name  = "Network" 
    $networks     = $null

    Network([string]$name,$Networks): base($name)
    {
        $this.name      = $name
        $this.networks  = $Networks
    }

    [object[]] GetChildItem()
    {
        $ListofObj =  @()
        $ListofNetworks = $this.networks
        foreach ($net in $ListofNetworks)
        {
            $Obj        = [NetworkName]::New($net.name, $net)
            $ListofObj += $obj
        }
        return $ListofObj
    }
}

Class NetworkName : SHIPSDirectory
{
    static $name  = 'NetworkName'
    hidden $net   = $NULL

    NetworkName([string]$name,$net): base('NetworkName')
    {
        $this.name  = $name
        $this.net   = $net
    }

    [object[]] GetChildItem()
    {
        $ListofObj =  @()

        $thisnet   = $this.net

            $obj            = [Property]::new('description', $thisnet.description , $this.name)
            $ListofObj     += $obj

            $NetworkType    = $thisnet.type.Split("-")[0] 
            $obj            = [Property]::new('type', $NetworkType , $this.name)
            $ListofObj     += $obj

            $defaultMaximumBandwidth = (1/1000 * $thisnet.DefaultMaximumBandwidth).ToString()    
            $defaultTypicalBandwidth = (1/1000 * $thisnet.DefaultTypicalBandwidth).ToString()

            $obj            = [Property]::new('preferred bandwidth', $defaultTypicalBandwidth , $this.name)
            $ListofObj     += $obj

            $obj            = [Property]::new('maximum bandwidth', $defaultMaximumBandwidth , $this.name)
            $ListofObj     += $obj

            if ($NetworkType -eq 'Ethernet')
            {
                
                $obj            = [Property]::new('smartlink', $thisnet.smartLink , $this.name)
                $ListofObj     += $obj

                
                $obj            = [Property]::new('privatenetwork', $thisnet.PrivateNetwork, $this.name)
                $ListofObj     += $obj

                $obj            = [Property]::new('purpose', $thisnet.Purpose , $this.name)
                $ListofObj     += $obj

                    $vLANType                   = $thisnet.ethernetNetworkType
                    $vLANID                     = ""
                    if ($vLAnType -eq 'Tagged')
                    {
                        $vLANID      = $thisnet.vLanId
                        if ($vLANID -lt 1)
                            { $vLANID = "" }
                    }

                $obj            = [Property]::new('vlan', $vLANID , $this.name)
                $ListofObj     += $obj

                    # Valid only for Synergy Composer
                    $subnetURI                      = $thisnet.subnetURI 
                    if ($Global:applianceconnection.ApplianceType -eq 'Composer')
                    {
                        $ThisSubnet = Get-HPOVAddressPoolSubnet | where URI -eq $subnetURI
                        if ($ThisSubnet)
                            { $subnet = $ThisSubnet.NetworkID }
                        else 
                            { $subnet = "" }
                    }
                    else 
                    { $subnet = ""}
            
                $obj            = [Property]::new('associated with subnet ID', $subnet , $this.name)
                $ListofObj     += $obj
            }
            else 
            {
                $obj            = [Property]::new('type', $thisnet.fabricType , $this.name)
                $ListofObj     += $obj
                
                $obj            = [Property]::new('link stability interval', $thisnet.linkStabilityTime , $this.name)
                $ListofObj     += $obj
            
                    $sanUri                     = $thisnet.sanUri
                    $SName                      = if ($sanUri) { Get-NamefromUri -uri $sanUri } else { "" }
                $obj            = [Property]::new('link stability interval', $SName , $this.name)
                $ListofObj     += $obj
            }
        
        return $ListofObj
    }
}


## -------------------------------------------------------
## 
##   NetworkSet
##
## -------------------------------------------------------


Class NetworkSet : SHIPSDirectory
{
    static $name  = "NetworkSet" 
    $networkSets     = $null

    NetworkSet([string]$name,$NetworkSets): base($name)
    {
        $this.name          = $name
        $this.networksets   = $NetworkSets
    }

    [object[]] GetChildItem()
    {
        $ListofObj =  @()
        $ListofNetworkSets = $this.networksets


        foreach ($ns in $ListofNetworkSets)
        {            
            # ----- networkset Name
    
            $nsname     = $ns.name
            $obj        = [NetworkSetName]::new($nsname,$ns)
            $ListofObj += $obj

    
        }
            return $ListofObj
    }
}

    Class NetworkSetName     : SHIPSDirectory
    {
        static $name   = "NetworkSetName"
        $nsobj         = $null

        NetworkSetName( $name, $NetworkSetObj)
        {
            $this.name  = $name
            $this.nsobj = $NetworkSetObj
        }

        [object[]] GetChildItem()
        {
            $ListofObj  =  @()
            $ns         = $this.nsobj

            # ----- Get information of networkset
            $obj        = [Property]::new('description', $ns.description , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('defaultTypicalBandwidth', $ns.TypicalBandwidth /1000 , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('defaultMaximumBandwidth', $ns.MaximumBandwidth /1000 , $this.name)
            $ListofObj += $obj

            $nativenet  = Get-NamefromUri -uri $ns.NativeNetworkUri
            $obj        = [Property]::new('nativeNetwork', $nativenet , $this.name)
            $ListofObj += $obj
            
            # ------ Get members of network set

            $ListofNetUris = $ns.networkUris
            $obj        = [NetworkSetMember]::new("members",$ListofNetUris)
            $ListofObj += $obj

            return $ListofObj
        }

    }


        Class NetworkSetMember : SHIPSDirectory
        {
            static $Name    = ""
            $neturis        = $null
            

            NetworkSetMember($name, $NetworkUris):base("NetworkSetMember")
            {
                $this.name      = $name
                $this.neturis   = $NetworkUris
            }

            [object[]] GetChildItem()
            {
                $ListofObj = @()

                # ------ Get members of network

                $ListofNetUris = $this.neturis
                foreach ($neturi in $ListofNeturis)
                {
                    $thisnet    = send-hpovrequest -uri $neturi
                    if ($thisnet)
                    {
                        $obj        = [NetworkName]::new($thisnet.name, $thisnet)
                        $ListofObj += $obj
                    }
                }
               
                return $ListofObj
            }

        }



#endregion networks

#region LIG

## -------------------------------------------------------
## 
##   Logical InterConnect Groups
##
## -------------------------------------------------------

Class LIG  : SHIPSDirectory
{
    static $name = "LIG"
    $ligs        = $null

    LIG([string]$name,$LIGs): base($name)
    {
        $this.name  = $name
        $this.ligs = $LIGs
    }

    [object[]] GetChildItem()
    {
        $ListofObj          = @()
        $script:ListofLIG   = $this.ligs 
        foreach ($Lig in $script:ListofLIG)
        {
            $obj        = [LIGname]::new($Lig.Name, $Lig)
            $ListofObj += $obj
        }
        return $ListofObj        
    }
}


Class LIGname : SHIPSDirectory
{
    static $name = "LIGname"
    hidden $Lig  = $Null

    LIGname([string]$name, $LIG) : base("LIGname")
    {
        $this.Name = $name
        $this.Lig  = $LIG
    }

    [object[]] GetChildItem()
    { 
        $ListofObj = @()
        #foreach ($Lig in $script:ListofLIG | where name -eq $this.name)
        #{
        $thisLig  = $this.Lig   

            $obj        = [Property]::new("enableFastMacCacheFailover", $thisLig.ethernetSettings.enableFastMacCacheFailover , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new("macRefreshInterval",$thisLig.ethernetSettings.macRefreshInterval , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new("enableIGMPSnooping",$thisLig.ethernetSettings.enableIGMPSnooping, $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new("igmpIdleTimeoutInterval",$thisLig.ethernetSettings.igmpIdleTimeoutInterval , $this.name)
            $ListofObj += $obj    
                
            $obj        = [Property]::new("enableNetworkLoopProtection", $thisLig.ethernetSettings.enableNetworkLoopProtection , $this.name)
            $ListofObj += $obj
        
            $obj        = [Property]::new("enablePauseFloodProtection", $thisLig.ethernetSettings.enablePauseFloodProtection , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new("RedundancyType", $thisLig.redundancyType , $this.name)
            $ListofObj += $obj
 
            $obj        = [Property]::new("enableRichTLV", $thisLig.EthernetSettings.enableRichTLV , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new("EnableTaggedLldp", $thisLig.EthernetSettings.enableTaggedLldp , $this.name)
            $ListofObj += $obj

                $telemetry             = $thisLig.telemetryConfiguration
            $obj        = [Property]::new("telemetrySampleCount", $Telemetry.sampleCount , $this.name)
            $ListofObj += $obj
            
            $obj        = [Property]::new("telemetrySampleInterval", $Telemetry.sampleInterval , $this.name)
            $ListofObj += $obj  
          
                $frameCount = $interconnectBaySet = ""
                if ($global:applianceconnection.ApplianceType -eq 'Composer')
                {
                    $frameCount         = $thisLig.EnclosureIndexes.Count
                    $interconnectBaySet = $thisLig.interconnectBaySet
                }
            $obj        = [Property]::new("frameCount", $frameCount , $this.name)
            $ListofObj += $obj 

            $obj        = [Property]::new("interconnectBaySet", $interconnectBaySet , $this.name)
            $ListofObj += $obj 

            ## Internal Networks
            $obj        = [LIGinternalNetwork]::new("Internal", $thisLig)
            $ListofObj += $obj

            ## UplinkSets
    
            $UpLinkSets     = $thisLig.UplinkSets | sort Name
            foreach ($upl in $UplinkSets)
            {
                $obj        = [LIGuplinkSet]::new($Upl.Name, $upl, $thisLig)
                $ListofObj += $obj
            }
          
        

        return $ListofObj 
    }
}

    Class LIGuplinkSet : SHIPSDirectory
    {
        static $Name        = "LIGuplinkset"
        hidden $Lig         = $Null
        hidden $UpLinkSet   = $Null

        LIGuplinkSet([string]$name,$uplinkset, $LIG) : base("LIGuplinkSet")
        {
            $this.Name      = $name
            $this.UplinkSet = $uplinkset
            $this.Lig       = $LIG
        }

        [object[]] GetChildItem()
        { 
            $ListofObj = @()
            
            $ThisUplinkSet  = $this.UplinkSet
            $thisLig        = $this.Lig
                
                if ($ThisUplinkSet  )
                {
                    $obj        = [Property]::new("networkType",$ThisUplinkSet.networkType , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new("mode",$ThisUplinkSet.Mode , $this.name)
                    $ListofObj += $obj

                        $lacpTimer  = $ThisUplinkSet.lacpTimer 
                        $lacpTimer  = if ([string]::IsNullOrWhiteSpace($lacpTimer) ) {'Short'} else { $lacpTimer}   
                    $obj        = [Property]::new("lacpTimer",$lacpTimer , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new("PrimaryPort",$ThisUplinkSet.PrimaryPort , $this.name)
                    $ListofObj += $obj

                        $NativenetUri   = $ThisUplinkSet.NativeNetworkUri
                        $NativeNetwork  = if ($NativeNetUri) { Get-NamefromUri -uri $NativenetUri} else {""}
                    $obj        = [Property]::new("nativeNetwork",$NativeNetwork , $this.name)
                    $ListofObj += $obj



                    # ----------------------------
                    #     Find networks

                    $obj        = [LIGUpLinkSetNetwork]::new("Networks", $ThisUplinkSet)
                    $ListofObj += $obj

                    # ----------------------------
                    #     Find uplink ports

                    $obj        = [LIGUpLinkSetuplinkPort]::new("Uplink Ports", $ThisupLinkSet, $thisLig)
                    $ListofObj += $obj

            }
            return $ListofObj

        }
    }
        Class LIGUpLinkSetNetwork : SHIPSDirectory
        {
            static $Name        = "LIGUpLinkSetNetwork"
            hidden $uplinkSet   = $null
        
        
            LIGUpLinkSetNetwork([string]$name,$UplinkSet) : base("LIGUpLinkSetNetwork")
            {
                $this.Name          = $name
                $this.uplinkSet     = $UplinkSet
            }
        
            [object[]] GetChildItem()
            {  
                $ListofObj = @()
                $ThisUplinkSet = $this.uplinkSet
        
                $networkUris = $ThisUplinkSet.networkUris
                $FCSpeed = ""
                switch ($ThisUplinkSet.networkType) 
                {
                    'Ethernet'      {
                                        foreach ($neturi in $networkUris)
                                        {
                                            $netname   = Get-NamefromUri -uri $neturi
                                            $obj        = [Property]::new($netname, $netname , $this.name)
                                            $ListofObj += $obj
                                        }
                                        
                                    }
        
        
                    'FibreChannel'  {   
                                        $netname    = Get-NamefromUri -uri $networkUris[0]
                                        $obj        = [Property]::new($netname, $netname , $this.name)
                                        $ListofObj += $obj
        
                                        $FCSpeed = if ($ThisUplinkSet.FCSpeed) { $ThisUplinkSet.FCSpeed } else {'Auto'} 
                                        $obj        = [Property]::new("FCSpeed",$FCSpeed , $this.name)
                                        $ListofObj += $obj
                                        
                                    }
                    Default {}
                }
                return $ListofObj 
            }
        }

        Class LIGUpLinkSetuplinkPort : SHIPSDirectory
        {
            static $Name        = "LIGUpLinkSetuplinkPort"
            hidden $Lig         = $null
            hidden $uplinkSet   = $null
        
        
            LIGUpLinkSetuplinkPort([string]$name,$upl,$LIG) : base("LIGUpLinkSetuplinkPort")
            {
                $this.Name      = $name
                $this.Lig       = $LIG
                $this.upLinkSet = $upl
            }
        
            [object[]] GetChildItem()
            {  
                $ListofObj      = @()
                $thisLig        = $this.LIG
                $thisUpLinkSet  = $this.upLinkSet
        
     
                $LigInterConnects = $thisLig.interconnectmaptemplate.interconnectmapentrytemplates
            
                foreach ($LigIC in $LigInterConnects | where permittedInterconnectTypeUri -ne $NULL )
                {
                    # -----------------
                    # Locate the Interconnect device 
        
                    $PermittedInterConnectType = send-hpovrequest $LigIC.permittedInterconnectTypeUri
        
                    # 1. Find port numbers and port names from permittedInterconnectType
                        
                    $PortInfos     = $PermittedInterConnectType.PortInfos
                    
                    # 2. Find Bay number and Port number on uplinksets
                    $ICLocation    = $LigIC.LogicalLocation.LocationEntries  
                    $ICBay         = ($ICLocation |where Type -eq "Bay").RelativeValue
                    $ICEnclosure   = ($IClocation  |where Type -eq "Enclosure").RelativeValue
        
        
                    foreach($logicalPort in $thisUplinkSet.logicalportconfigInfos)
                    {
        
                        $ThisLocation     = $Logicalport.LogicalLocation.LocationEntries
                        $ThisBayNumber    = ($ThisLocation |where Type -eq "Bay").RelativeValue
                        $ThisPortNumber   = ($Thislocation  |where Type -eq "Port").RelativeValue
                        $ThisEnclosure    = ($Thislocation  |where Type -eq "Enclosure").RelativeValue
                        $ThisPortName     = ($PortInfos | where PortNumber -eq $ThisPortNumber).PortName
        
                        if (( $ThisBaynumber -eq $ICBay) -and ($ThisEnclosure -eq $ICEnclosure))
                        {
                            if ($ThisEnclosure -eq -1)    # FC module
                            {
                                
                                #$UpLinkArray     += $("Bay" + $ThisBayNumber +":" + $ThisPortName)   # Bay1:1
                                    $s          = $Logicalport.DesiredSpeed
                                    $s          = if ($s) { $s } else {'Auto'}
                                $fcSpeed        = $s.TrimStart('Speed').TrimEnd('G')
                                $uplPortName    = "Bay$ThisBayNumber" +  "_$ThisportName"
        
        
                                $obj        = [Property]::new('uplink port' , $uplportname , $this.name)
                                $ListofObj += $obj

                                $obj        = [Property]::new('bay number' , $ThisBayNumber , $this.name)
                                $ListofObj += $obj
                                
                                $obj        = [Property]::new('port number' , $ThisPortName , $this.name)
                                $ListofObj += $obj

                                $obj        = [Property]::new('fc speed' , $fcSpeed , $this.name)
                                $ListofObj += $obj
                            }
                            else  # Synergy Frames or C7000
                            {
                                if ($global:applianceconnection.ApplianceType -eq 'Composer')
                                {
                                    $ThisPortName   = $ThisPortName -replace ":", "."    # In $POrtInfos, format is Q1:4, output expects Q1.4 
                                    #$UpLinkArray     += $("Enclosure" + $ThisEnclosure + ":" + "Bay" + $ThisBayNumber +":" + $ThisPortName)   # Ecnlosure#:Bay#:Q1.3
                                    $uplPortName    = "Enclosure$ThisEnclosure" +"_Bay$ThisBayNumber" +"_$ThisportName"
        

                                    $obj        = [Property]::new('uplink port' , $uplportname , $this.name)
                                    $ListofObj += $obj

                                    $obj        = [Property]::new('enclosure' , $ThisEnclosure , $this.name)
                                    $ListofObj += $obj
    
                                    $obj        = [Property]::new('bay number' , $ThisBayNumber , $this.name)
                                    $ListofObj += $obj
                                    
                                    $obj        = [Property]::new('port number' , $ThisPortName , $this.name)
                                    $ListofObj += $obj
                                }
                                else # C7000 
                                {
                                    #$UpLinkArray     += $("Bay" + $ThisBayNumber +":" + $ThisPortName)   # Bay#:Q1.3
                                    $uplPortName    = "Bay$ThisBayNumber" +"_$ThisportName"
                                
                                    $obj        = [Property]::new('uplink port' , $uplportname , $this.name)
                                    $ListofObj += $obj
                                    
                                    $obj        = [Property]::new('bay number' , $ThisBayNumber , $this.name)
                                    $ListofObj += $obj

                                    $obj        = [Property]::new('port number' , $ThisPortName , $this.name)
                                    $ListofObj += $obj
                                }
                                
                            }
                        }
        
                    }
                }
        
                return $ListofObj 
            }
        }
        

    Class LIGinternalNetwork : SHIPSDirectory
    {
        static $Name    = "LIGinternalNetwork"
        hidden $Lig     = $Null

        LIGinternalNetwork([string]$name,$LIG) : base("LIGinternalNetwork")
        {
            $this.Name      = $name
            $this.Lig       = $LIG
        }

        [object[]] GetChildItem()
        { 
            $ListofObj = @()
            $thisLig   = $this.Lig
            $InternalNetworkUris    = $thisLig.InternalNetworkUris

            foreach ( $uri in $InternalNetworkUris)
            {
                $IntNetworkName     = Get-NamefromUri -uri $uri
                $obj                = [LIGinternalNetworkName]::new($IntNetworkName)
                $ListofObj         += $obj
            }
            
            return $ListofObj
        }

    }

        Class LIGinternalNetworkName : SHIPSLeaf
        {
            static $Name    = "LIGinternalNetworkName"
            $LIGName        = ""    
            LIGinternalNetworkName([string]$name) : base("LIGinternalNetworkName")
            {
                $this.Name = $name
            }
        }

#endregion LIG

#region enclosures
## -------------------------------------------------------
## 
##   Enclosure Group
##
## -------------------------------------------------------

Class EG  : SHIPSDirectory
{
    static $name  = "EG" 
    $egs           = $null
    
    EG([string]$name, $EGs): base("EG")
    {
        $this.name  = $name
        $this.egs   = $EGs

    }

    [object[]] GetChildItem()
    {
        $ListofObj          = @()
        $ListofEncGroups    = $this.egs
        foreach ($EG in $ListofEncGroups)
        {
            $obj        = [EGname]::new($EG.Name, $EG)
            $ListofObj += $obj
        }
        return $ListofObj        
    }
}

Class EGname : SHIPSDirectory
{
    static $name = "EGname"
    hidden $EG   = $Null

    EGname([string]$name, $EG) : base("EGname")
    {
        $this.Name = $name
        $this.EG   = $EG
    }

    [object[]] GetChildItem()
    { 
        $ListofObj  = @()
        $thisEG     = $This.EG

        $obj        = [Property]::new("description",$thisEG.Description , $this.name)
        $ListofObj += $obj
        
        $obj        = [Property]::new("enclosurecount",$thisEG.Enclosurecount , $this.name)
        $ListofObj += $obj

        $obj        = [Property]::new("powermode",$thisEG.PowerMode , $this.name)
        $ListofObj += $obj
        
        ## OS Deployment Settings
            $osDeploy          = $thisEG.osDeploymentSettings
            $DeploySettings    = $osDeploy.deploymentModeSettings
            $EGDeployMode      = $DeploySettings.deploymentMode
            $EGDeployNetwork   = if ($DeploySettings.deploymentNetworkUri) { Get-NamefromUri -uri $DeploySettings.deploymentNetworkUri}
        
        $obj        = [Property]::new("deploymentMode",$EGDeployMode , $this.name)
        $ListofObj += $obj

        $obj        = [Property]::new("deploymentNetwork",$EGDeployNetwork , $this.name)
        $ListofObj += $obj

        ## Ip address management configuration
        $EGipV4AddressType   = $thisEG.ipAddressingMode
        if ($EGipV4AddressType -eq 'ipPool')
        {
            $ipRangeUris    = $thisEG.ipRangeUris  
            $obj            = [EGipManagementConfiguration]::new("IPv4 management address configuration",$ipRangeUris)
            $ListofObj     += $obj
        }
        else 
        {
            # It's either 'DHCP' or 'Manage Externally' - No IPaddress range
            $obj            = [Property]::new("IPv4 management address configuration",$EGipV4AddressType , $this.name)
            $ListofObj     += $obj
        }
        
        # Interconnect Bay Mappings
        $ListofICMappings = $thisEG.InterconnectBayMappings
        if ($ListofICMappings)
        {
            $obj        = [EGinterconnectBayMapping]::new("Interconnect Bay Mappings",$ListofICMappings,$thisEG)
            $ListofObj += $obj
        }

        return $ListofObj
    }
}

Class EGipManagementConfiguration : SHIPSDirectory
{
    static $name        = "EGipManagementConfiguration"
    hidden $iprangeuris = ""

    EGipManagementConfiguration([string]$name, $iprangeuris) : base ("EGipManagementConfiguration")
    {
        $this.name          = $name
        $this.iprangeuris   = $iprangeuris
    }

    [object[]] GetChildItem()
    { 
        $ListofObj  = @()
        
        foreach ($RangeUri in $this.iprangeuris)
        {
            $AddressRangeName   =  Get-NamefromUri -uri $RangeUri
            $obj                = [Property]::new($AddressRangeName,$AddressRangeName , $this.name)
            $ListofObj         += $obj
                
        }
        return $ListofObj
    }
}


Class EGipManagementConfigurationProperty : SHIPSLeaf
{
    static $Name    = "EGipManagementConfigurationProperty"
    $Value          = ""

    EGipManagementConfigurationProperty ([string]$name, [string]$Value): Base("EGipManagementConfigurationProperty")
    {
        $this.Name  = $name
        $this.Value = $value            
    }
}

Class EGinterconnectBayMapping : SHIPSDirectory
{
    static $name        = "EGinterconnectBayMapping"
    hidden $icmappings  = $null
    hidden $eg          = $null

    EGinterconnectBayMapping([string]$name, $icmappings, $EG) : base ("EGinterconnectBayMapping")
    {
        $this.name          = $name
        $this.icmappings    = $icmappings
        $this.eg            = $EG
    }

    [object[]] GetChildItem()
    { 
        $ListofObj              = @()
        $ListofICBayMappings    = $this.icmappings
        $thisEG                 = $this.eg
        $Sep        = ';' 
        $SepChar    = '|'

        if ($global:applianceconnection.ApplianceType -eq 'Composer')
        {
            $result              = $true
            # Check whether there are differenct ICs in different enclosures
            # We check the EnclosureIndex here. 
            # If those values are $NULL, it means either there is only 1 enclosure or all enclosures have the same ICmappings
            # If one of the values is not $NULL, there are differences of ICs in enclosures
            #
            foreach ($IC in $ListofICBayMappings)
            { $result = $result -and ($IC.EnclosureIndex -eq $NULL) }

            $EnclosureCount   = $thisEG.EnclosureCount
            
            $ListofICNames = ""

            if ($result)
            {
                # Either there is only 1 enclosure or multiple enclosures with the same LIG config
                for ($j=1 ; $j -le 3 ; $j++ )  # Just use the first 3 Interconnect Bay
                {
                    $ThisIC = $ListofICBayMappings | where InterConnectBay -eq $j
                    if ($ThisIC)
                    {
                        $ThisName       = Get-NamefromUri -uri $ThisIC.logicalInterconnectGroupURI
                        $ListofICNames += "$ThisName$Sep"
                    }
                    else 
                    {
                        $ListofICNames += $Sep   
                    }
                }
                for ($i=1 ; $i -le $EnclosureCount ; $i++)
                {
                    $Framesperenclosure += "Frame$i=$($ListofICNames.TrimEnd($Sep))" 
                    $obj                 = [EGFrame]::new("Frame$i", $ListofICNames, $FramesperEnclosure)
                    $ListofObj          += $obj
                }
                

            } 
            else 
            {
                # Multiple enclosures with different LIG
                
                $ListofICBayMappings = $ListofICBayMappings | sort enclosureindex,InterconnectBay

                for ($i=1 ; $i -le $EnclosureCount ; $i++)
                {
                    $FramesperEnclosure  = ""
                    $ListofICNames       = ""
                    for ($j=1 ; $j -le 2; $j++)
                    {
                        $ThisIC = $ListofICBayMappings | where {($_.EnclosureIndex -eq $i) -and ($_.InterConnectBay -eq $j)}
                        if ($ThisIC)
                        {
                            $ThisName       = Get-NamefromUri -uri $ThisIC.logicalInterconnectGroupURI
                            $ListofICNames += "$ThisName$Sep"
                        }
                        else 
                        {
                            $ListofICNames += $Sep  
                        }
                    }
                    # Last IC in Bay 3
                    $ThisIC = $ListofICBayMappings | where {($_.logicalInterconnectGroupURI) -and ($_.InterconnectBay -eq 3)}
                    if ($ThisIC)
                    {
                        $ThisName       = Get-NamefromUri -uri $ThisIC.logicalInterconnectGroupURI
                        $ListofICNames += "$ThisName$Sep"
                    }
                    
                    $FramesperEnclosure = "Frame$i=$($ListofICNames.TrimEnd($Sep))"
                    $obj                = [EGFrame]::new("Frame$i", $ListofICNames, $FramesperEnclosure)
                    $ListofObj         += $obj
                    
                    
                }

                

            }

        
        }
        else # C7000 here
        {
            
            $ListofICMappings = $thisEG.InterconnectBayMappings
            $LIGMappingArray = @()

            foreach ($LIC in $ListofICMappings)
            {
                $ThisLIGUri = $LIC.logicalInterconnectGroupURI
                if ($ThisLIGUri)
                {
                    $LIGName          = Get-NamefromUri -Uri $ThisLIGUri
                    $LigICBay         = $LIC.interconnectBay
                    $LIGMapping       = "$LigICBay=$LIGName"
                    EGFrameInterConnect ($LIGMapping , $LIGMapping )
                }
            }
            
        }

        return $ListofObj
    }
}

    Class EGFrame : SHIPSDirectory
    {
        static $name        = "EGFrame"
        $value              = ""
        hidden $icnamelist  = $null
        
        
    
        EGFrame([string]$name, $icNameList, $value) : base ("EGFrame")
        {
            $this.name          = $name
            $this.icnamelist    = $icNameList
            $this.value         = $value
        } 
        
        [object[]] GetChildItem()
        { 
            $Sep              = ';'
            $ListofObj        = @()
            $ListoficNames    = $this.icnamelist.Split($Sep)
            

            foreach ($icname in $ListoficNames)
            {
                if ($icname)
                {
                    $obj        =  [Property]::new($icname,$icname , $this.name)
                    $ListofObj += $obj
                }
            }         

            return $ListofObj
        }
    }


## -------------------------------------------------------
## 
##  Enclosures
##
## -------------------------------------------------------

Class Enclosure : SHiPSDirectory
{
    static $name                = 'Enclosure'
    hidden $enclosures          = @()
    
    

    Enclosure([string]$name, $enclosurelist) : base ('Enclosure')
    {
        $this.name              = $name
        $this.enclosures        = $enclosurelist
    }

    [object[]] GetChildItem()
    {
        $ListofObj              = @()
        foreach ($enclosure in $this.enclosures)
        {
            $obj        = [EnclosureName]::new($enclosure.Name, $enclosure)
            $ListofObj += $obj
        }

        return $ListofObj
    }   
}

    Class EnclosureName : SHiPSDirectory
    {
        static $name                = 'EnclosureName'
        hidden $enclosure           = @()
        
        

        EnclosureName([string]$name, $enclosure) : base ('EnclosureName')
        {
            $this.name              = $name
            $this.enclosure         = $enclosure 
        }

        [object[]] GetChildItem()
        {
            $ListofObj              = @()
            $Enc                   = $this.enclosure
            
            # ------------- hardware
            $obj        = [Property]::new('name', $Enc.name , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('description', $Enc.description , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('state', $Enc.state , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('uid state', $Enc.uidState , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('part number', $Enc.partNumber , $this.name)
            $ListofObj += $obj
            
            $obj        = [Property]::new('serial number', $Enc.serialNumber , $this.name)
            $ListofObj += $obj

            $EGName     = Get-NamefromUri $Enc.enclosureGroupUri
            $obj        = [Property]::new('enclosure group', $EGName , $this.name)
            $ListofObj += $obj
    
            $obj        = [Property]::new('licensing intent', $Enc.licensingIntent , $this.name)
            $ListofObj += $obj
 
            $obj        = [Property]::new('enclosure type', $Enc.enclosureType , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('enclosure model', $Enc.enclosureModel , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('version', $Enc.version , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('frame link module domain', $Enc.frameLinkModuleDomain , $this.name)
            $ListofObj += $obj

            # ------------------ Power
            $obj        = [Property]::new('power mode', $Enc.powerMode , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('watts - fans and managed devices', $Enc.fansAndManagementDevicesWatts , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('watts - power capacity boost', $Enc.powerCapacityBoostWatts , $this.name)
            $ListofObj += $obj
            
            $obj        = [Property]::new('watts - power capacity', $Enc.powerCapacityWatts , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('watts - power available', $Enc.powerAvailableWatts , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('watts - power allocated', $Enc.powerAllocatedWatts , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('watts - device bay', $Enc.deviceBayWatts , $this.name)
            $ListofObj += $obj
            
            $obj        = [Property]::new('watts - interconnect bay', $Enc.interconnectBayWatts , $this.name)
            $ListofObj += $obj

            # ---------------------- Inventory
            $obj        = [Property]::new('count - interconnect bay', $Enc.interconnectBayCount , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('count - device bay', $Enc.deviceBayCount , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('count - fan bay', $Enc.fanBayCount , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('count - powersupply bay', $Enc.powersupplyBayCount , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('count - manager bay', $Enc.managerBayCount , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('count - appliance bay', $Enc.applianceBayCount , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('firmware - baseline', $Enc.fwBaselineName , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('firmware - is managed', $Enc.isFWManaged , $this.name)
            $ListofObj += $obj
       
            # -------- Appliance Bays
            $obj        = [EnclosureApplianceBays]::new('appliance bays', $enc.applianceBays)
            $ListofObj += $obj

            # -------- Interconnect Bays
            $obj        = [EnclosureInterconnectBays]::new('interconnect bays', $enc.interconnectBays)
            $ListofObj += $obj

            # -------- Manager Bays
            $obj        = [EnclosureManagerBays]::new('manager bays', $enc.managerBays)
            $ListofObj += $obj

            # -------- Device Bays
            $obj        = [EnclosureDeviceBays]::new('device bays', $enc.deviceBays)
            $ListofObj += $obj

            # -------- Fan Bays
            $obj        = [EnclosureFanBays]::new('fan bays', $enc.fanBays)
            $ListofObj += $obj

            # -------- Power supply Bays
            $obj        = [EnclosurePowersupplyBays]::new('power supply bays', $enc.powerSupplyBays)
            $ListofObj += $obj


            
            ### TBD - Support data
            return $ListofObj
        }   
    }

        Class EnclosureApplianceBays : SHiPSDirectory
        {
            static $name                = 'EnclosureApplianceBays'
            hidden $appliancebays       = @()
            
            
            EnclosureApplianceBays([string]$name, $appliancebays) : base ('EnclosureApplianceBays')
            {
                $this.name              = $name
                $this.appliancebays     = $appliancebays
            }
        
            [object[]] GetChildItem()
            {
                $ListofObj              = @()

                foreach ($bay in $this.appliancebays)
                {
                    $baynumber  = "bay " + $bay.bayNumber
                    $obj        = [EnclosureApplianceBayProperty]::new($baynumber , $bay)
                    $ListofObj += $obj
                }

                
                return $ListofObj
            }   
        }

            Class EnclosureApplianceBayProperty : SHiPSDirectory
            {
                static $name                = 'EnclosureApplianceBayProperty'
                hidden $bay                 = @()

                EnclosureApplianceBayProperty([string]$name, $appliancebay) : base ('EnclosureApplianceBayProperty')
                {
                    $this.name              = $name
                    $this.bay               = $appliancebay
                }

                [object[]] GetChildItem()
                {
                    $ListofObj  = @()
                    $thisbay    = $this.bay
                    

                    $obj        = [Property]::new('bay number', $thisbay.bayNumber , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('device presence', $thisbay.devicePresence , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('part number', $thisbay.partNumber , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('powered on', $thisbay.poweredOn , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('bay power state', $thisbay.bayPowerState , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('spare part number', $thisbay.sparePartNumber , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('model', $thisbay.model , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new( 'status', $thisbay.status , $this.name)
                    $ListofObj += $obj

                    return $ListofObj
                }
            }


        Class EnclosurePowersupplyBays : SHiPSDirectory
        {
            static $name                    = 'EnclosurePowersupplyBays'
            hidden $powersupplybays         = @()
            
            
        
            EnclosurePowersupplyBays([string]$name, $powersupplybays) : base ('EnclosurePowersupplyBays')
            {
                $this.name                  = $name
                $this.powersupplybays       = $powersupplybays
            }
        
            [object[]] GetChildItem()
            {
                $ListofObj              = @()
                foreach ($bay in $this.powersupplybays)
                {
                    $baynumber  = "bay " + $bay.bayNumber
                    $obj        = [EnclosurePowersupplyBayProperty]::new($baynumber, $bay)
                    $ListofObj += $obj
                }

                return $ListofObj
            }   
        }

            Class EnclosurePowersupplyBayProperty : SHiPSDirectory
            {
                static $name                = 'EnclosurePowersupplyBayProperty'
                hidden $bay                 = @()

                EnclosurePowersupplyBayProperty([string]$name, $PowerSupplyBay) : base ('EnclosurePowersupplyBayProperty')
                {
                    $this.name              = $name
                    $this.bay               = $PowerSupplyBay
                }

                [object[]] GetChildItem()
                {
                    $ListofObj  = @()
                    $thisbay    = $this.bay


                    $obj        = [Property]::new('bay number', $thisbay.bayNumber , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('serial number', $thisbay.serialNumber , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('device presence', $thisbay.devicePresence , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('part number', $thisbay.partNumber , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('spare part number', $thisbay.sparePartNumber , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('power supply bay type', $thisbay.powerSupplyBayType , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('model', $thisbay.model , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new( 'status', $thisbay.status , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('change state', $thisbay.changeState , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('watts - output capacity', $thisbay.outputCapacityWatts , $this.name)
                    $ListofObj += $obj

                    return $ListofObj
                }
            }

        Class EnclosureFanBays : SHiPSDirectory
        {
            static $name                    = 'EnclosureFanBays'
            hidden $fanbays                 = @()
            
            
        
            EnclosureFanBays([string]$name, $fanbays) : base ('EnclosureFanBays')
            {
                $this.name                  = $name
                $this.fanbays               = $fanbays
            }
        
            [object[]] GetChildItem()
            {
                $ListofObj              = @()
                foreach ($bay in $this.fanbays)
                {
                    $baynumber  = "bay " + $bay.bayNumber
                    $obj        = [EnclosureFanBayProperty]::new($baynumber, $bay)
                    $ListofObj += $obj
                }
        
                return $ListofObj
            }   
        }

            Class EnclosureFanBayProperty : SHiPSDirectory
            {
                static $name                = 'EnclosureFanBayProperty'
                hidden $bay                 = @()

                EnclosureFanBayProperty([string]$name, $FanBay) : base ('EnclosureFanBayProperty')
                {
                    $this.name              = $name
                    $this.bay               = $FanBay
                }

                [object[]] GetChildItem()
                {
                    $ListofObj  = @()
                    $thisbay    = $this.bay

                    $obj        = [Property]::new('bay number', $thisbay.bayNumber , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('serial number', $thisbay.serialNumber , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('device presence', $thisbay.devicePresence , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('device required', $thisbay.deviceRequired , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('part number', $thisbay.partNumber , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('spare part number', $thisbay.sparePartNumber , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('fan bay type', $thisbay.fanBayType , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('model', $thisbay.model , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new( 'status', $thisbay.status , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('change state', $thisbay.changeState , $this.name)
                    $ListofObj += $obj
                    
                    return $ListofObj
                }
            }

        Class EnclosureDeviceBays : SHiPSDirectory
        {
            static $name                    = 'EnclosureDeviceBays'
            hidden $devicebays              = @()
            
            
        
            EnclosureDeviceBays([string]$name, $devicebays) : base ('EnclosureDeviceBays')
            {
                $this.name                  = $name
                $this.devicebays            = $devicebays
            }
        
            [object[]] GetChildItem()
            {
                $ListofObj              = @()
                foreach ($bay in $this.devicebays)
                {
                    $baynumber  = "bay " + $bay.bayNumber
                    $obj        = [EnclosureDeviceBayProperty]::new($baynumber, $bay)
                    $ListofObj += $obj
                }
        
                return $ListofObj
            }   
        }

            Class EnclosureDeviceBayProperty : SHiPSDirectory
            {
                static $name                = 'EnclosureDeviceBayProperty'
                hidden $bay                 = @()

                EnclosureDeviceBayProperty([string]$name, $DeviceBay) : base ('EnclosureDeviceBayProperty')
                {
                    $this.name              = $name
                    $this.bay               = $DeviceBay
                }

                [object[]] GetChildItem()
                {
                    $ListofObj  = @()
                    $thisbay    = $this.bay
                    
                    # TBD -profileUri
                    
                    $FullDouble     = $thisbay.availableForFullHeightDoubleWideProfile
                    if ($FullDouble)
                    {
                        $obj        = [Property]::new('full-height double-wide profile', $FullDouble , $this.name)
                        $ListofObj += $obj
                    }

                    $HalfDouble     = $thisbay.availableForHalfHeightDoubleWideProfile
                    if ($HalfDouble)
                    {
                        $obj        = [Property]::new('half-height double-wide profile', $HalfDouble , $this.name)
                        $ListofObj += $obj
                    }

                    $Half           = $thisbay.availableForHalfHeightProfile
                    if ($Half)
                    {
                        $obj        = [Property]::new('half-height profile', $Half , $this.name)
                        $ListofObj += $obj
                    }

                    $Full           = $thisbay.availableForFullfHeightProfile
                    if ($Full)
                    {
                        $obj        = [Property]::new('full-height profile', $full , $this.name)
                        $ListofObj += $obj
                    }

                    $obj        = [Property]::new('bay number', $thisbay.bayNumber , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('bay power state', $thisbay.bayPowerState , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('device presence', $thisbay.devicePresence , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('device form factor', $thisbay.deviceFormFactor , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('device bay type', $thisbay.deviceBayType , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('model', $thisbay.model , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('serial console', $thisbay.serialConsole , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new( 'changed state', $thisbay.changedState , $this.name)
                    $ListofObj += $obj


                    $obj        = [Property]::new('ipV4 setting', $thisbay.ipv4Setting , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('uuid', $thisbay.uuid , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('watts - power allocated', $thisbay.powerAllocatedWatts , $this.name)
                    $ListofObj += $obj
            
                    return $ListofObj
                }
            }


        Class EnclosureManagerBays : SHiPSDirectory
        {
            static $name                    = 'EnclosureManagerBays'
            hidden $managerbays             = @()
            
            
        
            EnclosureManagerBays([string]$name, $Managerbays) : base ('EnclosureManagerBays')
            {
                $this.name                  = $name
                $this.managerbays           = $Managerbays
            }
        
            [object[]] GetChildItem()
            {
                $ListofObj              = @()
                foreach ($bay in $this.managerbays)
                {
                    $baynumber  = "bay " + $bay.bayNumber
                    $obj        = [EnclosureManagerBayProperty]::new($baynumber, $bay)
                    $ListofObj += $obj
                }
        
                return $ListofObj
            }   
        }

            class EnclosureManagerBayProperty : SHiPSDirectory
            {
                static $name                = 'EnclosureManagerBayProperty'
                hidden $bay                 = @()

                EnclosureManagerBayProperty([string]$name, $ManagerBay) : base ('EnclosureManagerBayProperty')
                {
                    $this.name              = $name
                    $this.bay               = $ManagerBay
                }

                [object[]] GetChildItem()
                {
                    $ListofObj  = @()
                    $thisbay    = $this.bay

                    $obj        = [Property]::new('ip address', $thisbay.ipAddress , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('bay power state', $thisbay.bayPowerState , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new( 'change state', $thisbay.changeState , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new( 'uid state', $thisbay.uidState , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new( 'status', $thisbay.status , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('serial number', $thisbay.serialNumber , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('model', $thisbay.model , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('role', $thisbay.role , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('manager type', $thisbay.managerType , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('firmware version', $thisbay.fwVersion , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('firmware build date', $thisbay.fwBuildDate , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('bay number', $thisbay.bayNumber , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('device presence', $thisbay.devicePresence , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('part number', $thisbay.partNumber , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('spare part number', $thisbay.sparePartNumber , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('bay power state', $thisbay.bayPowerState , $this.name)
                    $ListofObj += $obj

                    ## ------- link port

                    #linkedEnclosure            : @{bayNumber=2; serialNumber=0000A66103}               

                    $obj        = [Property]::new('link port - negotiated speed(Gbs)', $thisbay.negotiatedLinkPortSpeedGbs , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('link port - speed(Gbs)', $thisbay.linkPortSpeedGbs , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('link port - state', $thisbay.LinkPortState , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('link port - status', $thisbay.LinkPortStatus , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('link port - isolation', $thisbay.LinkPortIsolated , $this.name)
                    $ListofObj += $obj

                    $obj        = [EnclosureManagerLinkedEnclosure]::new('linked enclosure', $thisbay.linkedEnclosure)
                    $ListofObj += $obj

                    ## ------- mgmt port
                    
                    $obj        = [Property]::new('mgmt port - negotiated speed(Gbs)', $thisbay.negotiatedMgmtPortSpeedGbs , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('mgmt port - state', $thisbay.mgmtPortState , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('mgmt port - link state', $thisbay.mgmtPortLinkState , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('mgmt port - status', $thisbay.mgmtPortStatus , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('mgmt port - speed(Gbs)', $thisbay.mgmtPortSpeedGbs , $this.name)
                    $ListofObj += $obj

                    $obj        = [EnclosureManagerBayNeighbor]::new('mgmt port - neighbor', $thisbay.mgmtPortNeighbor)
                    $ListofObj += $obj

                    return $ListofObj
                }
            }

                Class EnclosureManagerBayNeighbor : SHiPSDirectory
                {
                    static $name                    = 'EnclosureManagerBayNeighbor'
                    hidden $neighbor                = $null
                    
                    
                
                    EnclosureManagerBayNeighbor([string]$name, $neighbor) : base ('EnclosureManagerBayNeighbor')
                    {
                        $this.name                  = $name
                        $this.neighbor              = $neighbor
                    }
                
                    [object[]] GetChildItem()
                    {
                        $ListofObj  = @()
                        $n          = $this.neighbor

                        $obj        = [Property]::new('ip address', $n.ipAddress , $this.name)
                        $ListofObj += $obj

                        $obj        = [Property]::new('mac address', $n.macAddress , $this.name)
                        $ListofObj += $obj

                        $obj        = [Property]::new('description', $n.description , $this.name)
                        $ListofObj += $obj

                        $obj        = [Property]::new('port', $n.port , $this.name)
                        $ListofObj += $obj

                        return $ListofObj
                    }
                }

                Class EnclosureManagerLinkedEnclosure : SHiPSDirectory
                {
                    static $name                    = 'EnclosureManagerLinkedEnclosure'
                    hidden $linkedenclosure         = $null
                    
                    
                
                    EnclosureManagerLinkedEnclosure([string]$name, $linkedenclosure) : base ('EnclosureManagerLinkedEnclosure')
                    {
                        $this.name                  = $name
                        $this.linkedenclosure       = $linkedenclosure
                    }
                
                    [object[]] GetChildItem()
                    {
                        $ListofObj  = @()
                        $l          = $this.linkedenclosure

                        $obj        = [Property]::new('bay number', $l.baynumber , $this.name)
                        $ListofObj += $obj

                        $obj        = [Property]::new('serial number', $l.serialnumber , $this.name)
                        $ListofObj += $obj

                        return $ListofObj
                    }
                }

        Class EnclosureInterconnectBays : SHiPSDirectory
        {
            static $name                    = 'EnclosureInterconnectBays'
            hidden $interconnectbays        = @()
            
            
        
            EnclosureInterconnectBays([string]$name, $Interconnectbays) : base ('EnclosureInterconnectBays')
            {
                $this.name                  = $name
                $this.interconnectbays      = $Interconnectbays
            }
        
            [object[]] GetChildItem()
            {
                $ListofObj              = @()
                foreach ($bay in $this.interconnectbays)
                {
                    $baynumber  = "bay " + $bay.bayNumber
                    $obj        = [EnclosureInterconnectBayProperty]::new($baynumber, $bay)
                    $ListofObj += $obj
                }
        
                return $ListofObj
            }   
        }

            Class EnclosureInterconnectBayProperty : SHiPSDirectory
            {
                static $name                = 'EnclosureInterconnectBayProperty'
                hidden $bay                 = @()

                EnclosureInterconnectBayProperty([string]$name, $InterconnectBay) : base ('EnclosureInterconnectBayProperty')
                {
                    $this.name              = $name
                    $this.bay               = $InterconnectBay
                }

                [object[]] GetChildItem()
                {
                    $ListofObj  = @()
                    $thisbay    = $this.bay
                    
                    $obj        = [Property]::new('bay number', $thisbay.bayNumber , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('part number', $thisbay.partNumber , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('serial number', $thisbay.serialNumber , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('change state', $thisbay.changeState , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('serial console', $thisbay.serialConsole , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('power allocation in Watts', $thisbay.powerAllocationWatts , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new( 'ipv4 setting', $thisbay.ipv4Setting , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('interconnect model', $thisbay.interconnectModel , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('interconnect bay type', $thisbay.interconnectBayType , $this.name)
                    $ListofObj += $obj

                    $ic         = Get-NamefromUri -uri $thisbay.interconnectUri
                    $obj        = [Property]::new('interconnect', $ic , $this.name)
                    $ListofObj += $obj

                    $lic        = Get-NamefromUri -uri $thisbay.logicalInterconnectUri
                    $obj        = [Property]::new('logical interconnect', $lic , $this.name)
                    $ListofObj += $obj

                    return $ListofObj
                }
            }



            
## -------------------------------------------------------
## 
##  Logical Enclosure 
##
## -------------------------------------------------------

Class LogicalEnclosure : SHiPSDirectory
{
    static $name                = 'LogicalEnclosure'
    hidden $logicalenclosures   = @()
    
    

    LogicalEnclosure([string]$name, $logicalenclosurelist) : base ('LogicalEnclosure')
    {
        $this.name              = $name
        $this.logicalenclosures = $logicalenclosurelist
    }

    [object[]] GetChildItem()
    {
        $ListofObj              = @()
        foreach ($LE in $this.logicalenclosures)
        {
            $obj        = [LogicalEnclosureName]::new($LE.Name, $LE)
            $ListofObj += $obj
        }

        return $ListofObj
    }   
}

    Class LogicalEnclosureName : SHiPSDirectory
    {
        static $name                = 'LogicalEnclosureName'
        hidden $logicalenclosure    = @()
        
        

        LogicalEnclosureName([string]$name, $LE) : base ('LogicalEnclosureName')
        {
            $this.name              = $name
            $this.logicalenclosure  = $LE 
        }

        [object[]] GetChildItem()
        {
            $ListofObj              = @()
            $LE                     = $this.logicalenclosure


            # ------------------ Power
            $obj        = [Property]::new('power mode', $LE.powerMode , $this.name)
            $ListofObj += $obj

            # ------------- hardware
            $obj        = [Property]::new('name', $LE.name , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('description', $LE.description , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('state', $LE.state , $this.name)
            $ListofObj += $obj
            
            $obj        = [Property]::new('status', $LE.status , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('scaling state', $LE.scalingState , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('ambient temperature mode', $LE.ambientTemperatureMode , $this.name)
            $ListofObj += $obj

            # IP 
            $obj        = [Property]::new('ip addressing mode', $LE.ipAddressingMode , $this.name)
            $ListofObj += $obj

            # -------- ipV4 Address ranges
            $ipranges   = $LE.ipv4Addressranges
            if ( $ipranges)
            {
                $obj        =[OVipSubnetAddress]::new('ipV4 addresses and subnet ranges' , $ipranges, $null, $null) 
                $ListofObj += $obj
            }

            # ----------------- Enclosure Group links
            if ($LE.enclosureGroupUri)
            {
                $EG         = Send-HPOVRequest -uri $LE.enclosureGroupUri
                $obj        = [EG]::new('enclosure group', $EG)
                $ListofObj += $obj
            }

            # ----------------- Enclosures links
            if ($LE.enclosureUris)
            {
                $enclosures = @()
                foreach ($encUri in $LE.enclosureUris )
                {
                    $enclosures += Send-HPOVRequest -uri $encUri
                }
                $obj        = [Enclosure]::new('enclosure', $enclosures)
                $ListofObj += $obj
            }

            # ----------------- LIG links
            if ($LE.logicalInterconnectUris)
            {
                $LIGs = @()
                foreach ($ligUri in $LE.logicalInterconnectUris )
                {
                    $LIGs += Send-HPOVRequest -uri $ligUri
                }
                $obj        = [LIG]::new('logical interconnect group', $LIGs)
                $ListofObj += $obj
            }

            # -------------- firmware 
            $obj        = [LEfirmware]::new('firmware', $LE.firmware)
            $ListofObj += $obj


            # -------------- OS Deployment
            $ISsettings = $LE.deploymentManagerSettings
            if ($ISsettings)
            {
                ### /rest/deployment-appliance cannot be found
                #$deploycluster  = Send-HPOVRequest -uri $ISsettings.deploymentClusterUri
                #$obj            = [Property]::new('OS deployment - cluster', $deploycluster , $this.name)
                #$ListofObj     += $obj
                
                $obj            = [Property]::new('OS deployment - ismanaged', $ISsettings.manageOSDeployment , $this.name)
                $ListofObj     += $obj

                $OSdeploy       = $ISsettings.osdeploymentsettings
                $deploymode     = $OSdeploy.deploymentModeSettings.deploymentMode   
                $obj            = [Property]::new('OS deployment - mode', $deploymode , $this.name)
                $ListofObj     += $obj

                $deploynet      =  $OSdeploy.deploymentModeSettings.deploymentNetworkUri    
                if ($deploynet )
                {
                    $netname    = Get-NamefromUri -uri  $deploynet
                    $obj        = [Property]::new('OS deployment - network', $netname , $this.name)
                    $ListofObj += $obj
                }

            }


            return $ListofObj
        }   
    }
    
        Class LEfirmware : SHiPSDirectory
        {
            static $name              = 'LEfirmware'
            hidden $firmware          = @()
            
            

            LEfirmware([string]$name, $firmware) : base ('LEfirmware')
            {
                $this.name             = $name
                $this.firmware         = $firmware
            }

            [object[]] GetChildItem()
            {
                $ListofObj  = @()
                $fw         = $this.firmware

                if ($fw.firmwareBaselineUri)
                {
                    $fwname     = Get-NamefromUri -uri $fw.firmwareBaselineUri
                    $obj        = [Property]::new('firmware baseline' , $fwname  , $this.name)
                    $ListofObj += $obj
                }

                $obj        = [Property]::new('LI firmware update non disruptive' , $fw.validateIfLIFirmwareUpdateIsNonDisruptive  , $this.name)
                $ListofObj += $obj

                $obj        = [Property]::new('force install firmware' , $fw.forceInstallFirmware  , $this.name)
                $ListofObj += $obj

                $obj        = [Property]::new('logical interconnect update mode' , $fw.logicalInterconnectUpdateMode  , $this.name)
                $ListofObj += $obj

                $obj        = [Property]::new('update firmware on unmanaged interconnect' , $fw.updateFirmwareOnUnmanagedInterconnect  , $this.name)
                $ListofObj += $obj
                
                return $ListofObj
            }
        }


#endregion enclosures

#region storage
## -------------------------------------------------------
## 
##   SAN Manager
##
## -------------------------------------------------------

Class SANManager  : SHIPSDirectory
{
    static $name  = "SANManager" 
    $sanmgrs      = $null
    
    SANManager([string]$name, $SANmgrs): base("SANManager")
    {
        $this.name     = $name
        $this.sanmgrs  = $SANmgrs

    }

    [object[]] GetChildItem()
    {
        $ListofObj          = @()
        $ListofSANManagers  = $this.sanmgrs

        foreach ($SM in $ListofSANManagers)
        {
    
            $SMName         = $SM.Name
            $obj            = [SANManagerName]::new($SMname, $SM)

            $ListofObj     += $obj
        }

        return $ListofObj
    }

}

    Class SANManagerName  : SHIPSDirectory
    {
        static $name  = "SANManagerName" 
        $sanmgr       = $null
        
        SANManagerName([string]$name, $SANmgr): base("SANManagerName")
        {
            $this.name     = $name
            $this.sanmgr   = $SANmgr

        }

        [object[]] GetChildItem()
        {
            $ListofObj = @()
            $ThisSANManager   = $this.sanmgr
            
                # *********** No show for password
                $AuthPassword = $PrivPassword = $Password = '***Pwd N/A***'
                $Username     = $snmpUsername = $PrivProtocol = $Port = $AuthLevel = $AuthProtocol = ""
                $UseSSL        = 'No'

                    # SAN Type            
                $obj              =   [Property]::new('SAN manager type', $ThisSANManager.ProviderDisplayName , $this.name)
                $ListofObj       += $obj

                foreach ($CI in $ThisSANManager.ConnectionInfo)
                {
                    Switch ($CI.Name)
                    {
            
                        # ------ For HPE and Cisco 
                        'SnmpPort'          { $Port             = $CI.Value}
                        'SnmpUsername'      { $snmpUsername     = $CI.Value}
                        'SnmpAuthLevel'     { 
                                                $v = $CI.Value
            
                                                if ($v -notlike 'AUTH*')
                                                    { $AuthLevel     = 'None'}
                                                else 
                                                    {
                                                        if ($v -eq 'AUTHNOPRIV')
                                                            {$AuthLevel = 'AuthOnly'}
                                                        else
                                                            {$AuthLevel = 'AuthAndPriv'}
                                                    }
                                            }  
            
                        'SnmpAuthProtocol'  { $AuthProtocol  = $CI.Value}
                        'SnmpPrivProtocol'  { $PrivProtocol  = $CI.Value}
            
                        #---- For Brocade 
                        'Username'          { $Username  = $CI.Value}
                        'UseSSL'            { $UseSSL    = $CI.Value   }
                        'Port'              { $Port      = $CI.Value}
                    }
                }
                

                # SAN Manager - Username          
                if ($Username)
                {
                    $obj              =   [Property]::new('SAN Manager username', $username , $this.name)
                    $ListofObj       += $obj
                }

                # SAN Manager - Port     
                if ($Port)
                {
                    $obj              =   [Property]::new('SAN Manager Port', $Port , $this.name)
                    $ListofObj       += $obj
                }

                # SAN Manager - SSL     
                if ($UseSSL)
                {
                    $obj              =   [Property]::new('SAN Manager SSL', $UseSSL , $this.name)
                    $ListofObj       += $obj
                }

                # Snmp - Username      
                if ($snmpUsername)
                {
                    $obj              =   [Property]::new('snmp Username', $snmpUsername , $this.name)
                    $ListofObj       += $obj
                }

                # Snmp - Privacy Protocol     
                if ($PrivProtocol)
                {
                    $obj              =   [Property]::new('snmp Privacy Protocol', $PrivProtocol , $this.name)
                    $ListofObj       += $obj
                }

                # Snmp - Authentication Level     
                if ($AuthLevel)
                {
                    $obj              =   [Property]::new('snmp Security Level', $AuthLevel , $this.name)
                    $ListofObj       += $obj
                }

                # Snmp - Authentication Protocol     
                if ($AuthProtocol)
                {
                    $obj              =   [Property]::new('snmp Authentication Protocol', $AuthProtocol , $this.name)
                    $ListofObj       += $obj
                }
         
            return $ListofObj
        }
    }



## -------------------------------------------------------
## 
##   Storage Systems
##
## -------------------------------------------------------

Class StorageSystem  : SHIPSDirectory
{
    static $name    = "StorageSystem" 
    $storagesystems = $null
    
    StorageSystem([string]$name, $StsList): base("StorageSystem")
    {
        $this.name            = $name
        $this.storagesystems  = $StsList

    }

    [object[]] GetChildItem()
    {
        $ListofObj              = @()
        $ListofStorageSystems   = $this.storagesystems
        
        
        
        foreach ($StS in $ListofStorageSystems)
        {
            $obj        = [StorageSystemName]::new($StS.Name, $StS)
            $ListofObj += $obj
        }

        return $ListofObj        
    }
}
    Class StorageSystemName  : SHIPSDirectory
    {
        static $name            = "StorageSystemName" 
         $storagesystem   = $null
        
        StorageSystemName([string]$name, $StS): base("StorageSystemName")
        {
            $this.name          = $name
            $this.storagesystem = $StS

        }

        [object[]] GetChildItem()
        {
            $ListofObj = @()
            $StS   = $this.storagesystem
            
            $obj        = [Property]::new('IP_hostname', $StS.hostname , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('user name', $StS.Credentials.username , $this.name)
            $ListofObj += $obj

            $stsfamily  = $sts.family
            $obj        = [Property]::new('type', $stsfamily , $this.name)
            $ListofObj += $obj

            if ($stsfamily -eq 'StoreServ' )
                { 
                    $DomainName         =  $Sts.deviceSpecificAttributes.managedDomain 
                    $obj                = [Property]::new('storage domain', $Domainname , $this.name)
                    $ListofObj          += $obj
                }
            
            $ListofStsPorts = $Sts.Ports | sort Name
            $obj        = [StorageSystemPorts]::new('storage ports', $ListofStsPorts, $stsfamily)
            $ListofObj += $obj

            

            $Lib = Get-HPOVVersion 
            $Lib = $Lib.$($global:ApplianceConnection.Name)
            $StoragePoolNames = @()

            if (($Lib.Major -ge 3) -and ($Lib.Minor -ge 10))
            {
                $AllStoragePools    = (Send-HPOVRequest -uri $Sts.storagePoolsUri).members

            }
            else 
            {
                $AllStoragePools  = $sts.ManagedPools | % { get-NamefromUri -uri $_.Uri }
            }

            $obj        = [StorageSystemStoragePools]::new('storage pools',$AllStoragePools )
            $ListofObj += $obj

                        
            return $ListofObj
        }
    }

        Class StorageSystemPorts  : SHIPSDirectory
        {
            static $name   = "StorageSystemPorts" 
             $ports  = $null
             $family = ""
            
            StorageSystemPorts([string]$name, $ports, $stsfamily): base("StorageSystemPorts")
            {
                $this.name      = $name
                $this.ports     = $ports
                $this.family    = $stsfamily
        
            }
        
            [object[]] GetChildItem()
            {
                $ListofObj         = @()
                $ListofPorts       = $this.ports
                
                                       
                foreach ($MP in $ListofPorts) 
                {
                    if ($this.family -eq 'StoreServ')
                        { $Thisname    = $MP.actualSanName }
                    else 
                        { $Thisname    = $MP.ExpectedNetworkName  }
                    
                    if ($Thisname)
                    {
                        $Port           = $MP.Name + '=' + $Thisname    # Build Port syntax 0:1:2= VSAN10
                        $portname       = $port -replace ':' , '_'
                        $obj            = [Property]::new($portname, $Port , $this.name)
                        $ListofObj     += $obj

                    }
                }
                return $ListofObj        
            }
        }

        Class StorageSystemStoragePools  : SHIPSDirectory
        {
            static $name  = "StorageSystemStoragePools" 
            $StoragePools = @()
            
            StorageSystemStoragePools([string]$name,  $AllStoragePools): base("StorageSystemStoragePools")
            {
                $this.name           = $name
                $this.storagepools   = $AllStoragePools 
        
            }
        
            [object[]] GetChildItem()
            {
                $ListofObj          = @()
                $AllStoragePools      = $this.storagepools 
                foreach ($pool in $AllStoragePools)
                {
                    $obj        = [StoragePoolName]::new($pool.Name, $pool)
                    $ListofObj += $obj
                }
                return $ListofObj        
            }
        }   

    
## -------------------------------------------------------
## 
##   Storage Pools
##
## -------------------------------------------------------

Class StoragePool  : SHIPSDirectory
{
    static $name            = "StoragePool" 
    hidden $storagepools    = $null
    
    StoragePool([string]$name, $PoolList): base("StoragePool")
    {
        $this.name          = $name
        $this.storagepools  = $PoolList

    }

    [object[]] GetChildItem()
    {
        $ListofObj              = @()
        $ListofStoragePools    = $this.storagepools
        
        
        
        foreach ($pool in $ListofStoragePools)
        {
            $obj        = [StoragePoolName]::new($pool.Name, $pool)
            $ListofObj += $obj
        }

        return $ListofObj        
    }
}
    Class StoragePoolName  : SHIPSDirectory
    {
        static $name            = "StoragePoolName" 
        $storagepool     = $null
        
        StoragePoolName([string]$name, $pool): base("StoragePoolName")
        {
            $this.name                = $name
            $this.storagepool         = $pool

        }

        [object[]] GetChildItem()
        {
            $ListofObj  = @()
            $thispool   = $this.storagepool
            
            if ($thispool)
            {
                $total      =  1/1GB * $thispool.totalCapacity
                $total      = [math]::round( $total , 2)
                $obj        = [Property]::new('total capacity', $total , $this.name)
                $ListofObj += $obj

                $allocated  = 1/1GB * $thispool.allocatedCapacity
                $allocated  = [math]::round( $allocated , 2)
                $obj        = [Property]::new('allocated capacity', $allocated , $this.name)
                $ListofObj += $obj

                $SANname    = Get-NamefromUri -uri $Thispool.storageSystemUri
                if ($SANname)
                {
                    $obj        = [Property]::new('storage system', $SANname , $this.name)
                    $ListofObj += $obj
                }
            }

            return $ListofObj
        }
    }

## -------------------------------------------------------
## 
##   Storage Volume Template  
##
## -------------------------------------------------------

Class StorageVolumeTemplate  : SHIPSDirectory
{
    static $name                = "StoragVolumeTemplate" 
    hidden $voltemplatelist     = $null
    
    StorageVolumeTemplate([string]$name, $voltemplatelist): base("StorageVolumeTemplate")
    {
        $this.name              = $name
        $this.voltemplatelist   = $voltemplatelist

    }

    [object[]] GetChildItem()
    {
        $ListofObj              = @()
        $Listofvoltemplate      = $this.voltemplatelist
        
        foreach ($vol in $Listofvoltemplate)
        {
            $obj        = [StorageVolumeTemplateName]::new($vol.Name, $vol)
            $ListofObj += $obj
        }

        return $ListofObj        
    }
}
    Class StorageVolumeTemplateName  : SHIPSDirectory
    {
        static $name            = "StorageVolumeTemplateName" 
        hidden $voltemplate     = $null
        
        StorageVolumeTemplateName([string]$name, $voltemplate): base("StorageVolumeTemplateName")
        {
            $this.name          = $name
            $this.voltemplate   = $voltemplate

        }

        [object[]] GetChildItem()
        {
            $ListofObj  = @()
            $Template   = $this.voltemplate
 
            $desc       = $Template.Description

            $Sts             = Send-HPOVRequest -uri $Template.compatibleStorageSystemsUri
            $StorageSystem   = $sts.members.DisplayName

                $PoolName  = ""
                $lib         = (Get-HPOVVersion).LibraryVersion
                $libversion  = $lib.Major.ToString() + '.' + $lib.Minor.ToString() + '.' + $lib.build.ToString() + '.' + $lib.Revision.ToString()
            if ($Libversion -ge '3.10.1471.1581')
            {
                $properties         = $Template.Properties
                    $psize          = $properties.Size.default 
                    $Capacity       = if ($psize) {1/1GB * $pSize} else {0}

                    $pshare         = $properties.isShareable.default
                    $Shared         = if ($pshare) { 'Shared'} else { 'Private'}

                    $ProvisionType  = $properties.provisioningType.default

                    $stpuri         = $properties.storagePool.default
                    if ($stpuri)
                    {
                        $PoolName       = Get-NamefromUri -uri $stpuri
                    }

                    $SnapSPoolUri   = $properties.snapshotPool.default
                    if ($SnapSPoolUri)
                    {
                        $SnapShotPoolName = Get-NamefromUri -uri $SnapSPoolUri
                    }
            }
            else 
            {
                $SnapSPoolUri    = $Template.SnapShotPoolUri
                $StsUri          = $Template.StorageSystemUri 
                

                $p               = $Template.deviceSpecificAttributes

                    $ProvisionType = if ($p.ProvisionType -eq 'Full') { "Thick"}            else {"Thin"}
                    $Shared        = if ($p.Shareable)                { 'Yes'  }            else {'No'}
                    $Capacity      = if ($p.Capacity)                 { 1/1GB * $p.Capacity } else { 0 }

                    $StpUri          = $p.StoragePoolUri
                    
                    if ($stpuri)
                    {
                        $PoolName  = Get-NamefromUri -uri $stpuri
                    }   

                if ($SnapSPoolUri)
                {
                    $SnapShotPoolName = Get-NamefromUri -uri $SnapSPoolUri
                }


                if ($StsUri)
                {
                    $StorageSystem = Get-NamefromUri -Uri $StsUri
                }
                
            }
            
            $obj        = [Property]::new('name',$this.name, $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('description', $desc , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('provisionning', $ProvisionType , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('sharing', $Shared , $this.name)
            $ListofObj += $obj

            $Capacity   = $Capacity.ToString() + " GB"
            $obj        = [Property]::new('capacity', $Capacity , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('storage pool', $PoolName , $this.name)
            $ListofObj += $obj
                
            $obj        = [Property]::new('storage system', $StorageSystem , $this.name)
            $ListofObj += $obj
             
            return $ListofObj
        }
    }

## -------------------------------------------------------
## 
##   Storage Volume  
##
## -------------------------------------------------------

Class StorageVolume  : SHIPSDirectory
{
    static $name                = "StorageVolume" 
    hidden $volumelist          = $null
    
    StorageVolume([string]$name, $volumelist): base("StorageVolume")
    {
        $this.name         = $name
        $this.volumelist   = $volumelist

    }

    [object[]] GetChildItem()
    {
        $ListofObj          = @()
        $Listofvolumes      = $this.volumelist
        
        foreach ($vol in $Listofvolumes)
        {
            $obj        = [StorageVolumeName]::new($vol.Name, $vol)
            $ListofObj += $obj
        }

        return $ListofObj        
    }
}

    Class StorageVolumeName  : SHIPSDirectory
    {
        static $name            = "StorageVolumeName" 
        hidden $volume          = $null
        
        StorageVolumeName([string]$name, $volume): base("StorageVolumeName")
        {
            $this.name         = $name
            $this.volume       = $volume
        }

        [object[]] GetChildItem()
        {
            $ListofObj  = @()
            $vol   = $this.volume

            $volname         = $Vol.Name
            $description     = $Vol.Description
            
                $PoolName    = $StorageSystem = $volumeTemplate = $Snapshot = ""
                $aCapacity   = $pCapacity = ""
                $Shared      = $Permanent = $State = ""
                $AdaptOpt    = $dataProtection  = ""

                $lib         = (Get-HPOVVersion).LibraryVersion
                $libversion  = $lib.Major.ToString() + '.' + $lib.Minor.ToString() + '.' + $lib.build.ToString() + '.' + $lib.Revision.ToString()
            if ($Libversion -ge '3.10.1471.1581')
            {
                # More attributes defined here : State, ProvisionCapacity ,snaphot adavnced properties

                    $ProvisionType   = $Vol.provisioningType
                    $Shared          = if ($Vol.Ishareable) { 'Shared'} else { 'Private'}
                    $Permanent       = $Vol.IsPermanent
                    $State           = $Vol.State
                    
                    $aCapacity       = $Vol.allocatedCapacity
                    $aCapacity       = if ($aCapacity) { 1/1GB * $aCapacity } else { 0 }
    
                    $pCapacity       = $Vol.provisionedCapacity
                    $pCapacity       = if ($pCapacity) { 1/1GB * $pCapacity } else { 0 }

                    $p               = $Vol.devicespecificAttributes
                    

                    $dataProtection  = $p.dataProtectionLevel
                    $AdaptOpt        = $p.isAdaptiveOptimizationEnabled

                    $SnapShotPoolUri = $p.SnapShotPoolUri
                    if ($snapshotPoolUri) 
                    { 
                        $SnapshotPool    = Get-NamefromUri -uri $snapshotPoolUri  
                    } 

                    $StpUri          = $Vol.StoragePoolUri
                    if ($stpuri)
                    {
                       $PoolName       = Get-NamefromUri -uri $stpuri
                    }
                    
    
                    $VolTemplateUri  = $Vol.volumeTemplateUri
                    if ($VolTemplateUri) 
                    { 
                         $volTemplate    = Send-HPOVRequest -uri $VolTemplateUri 
                         $VolumeTemplate = $volTemplate.Name
                         $Sts            = Send-HPOVRequest -uri $volTemplate.compatibleStorageSystemsUri
                         $StorageSystem   = $sts.members.DisplayName
                    } 
                    
                    $snapshotUri     = $Vol.snapshotUri
                    if ($snapshotUri) 
                    { 
                        $Snapshot    = Get-NamefromUri -uri $snapshotUri  
                    }
    
    
            }
            else
            {
                $StpUri          = $Vol.StoragePoolUri
                $SnapSPoolUri    = $Vol.SnapShotPoolUri
                $StsUri          = $Vol.StorageSystemUri 
                $VolTemplateUri  = $Vol.volumeTemplateUri
    
                $Shared          = if ($Vol.Shareable) { 'Shared'} else { 'Private'}
                $ProvisionType   = if ($Vol.ProvisionType -eq 'Full') { "Thick"}            else {"Thin"}
                $pCapacity       = if ($Vol.provisionedCapacity)                 { 1/1GB * $Vol.provisionedCapacity } else { 0 }
    
    
                $PoolName      = "" 
                if ($StpUri)
                {
                    $PoolName =   Get-NamefromUri -uri $stpuri
                }   
    
                if ($SnapSPoolUri)
                {
                    $SnapShotPoolName =   Get-NamefromUri -uri $SnapSPoolUri
                }
    
                $StorageSystem = ""
    
                if ($StsUri)
                {
                    $ThisStorageSystem = get-hpovStorageSystem | where Uri -eq $StsUri
                    if ($ThisStorageSystem)
                    {
    
                        $StorageSystem = $ThisStorageSystem.hostname
                    }
                }
    
                $VolumeTemplate = if ($VolTemplateUri) { Get-NamefromUri -uri $VolTemplateUri } else {''}
            
            }

            $obj        = [Property]::new('name',$volname, $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('state', $State , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('description',$description, $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('storage pool',$poolname, $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('provisionning', $ProvisionType , $this.name)
            $ListofObj += $obj

            $aCapacity  = $aCapacity.ToString() + " GB"
            $obj        = [Property]::new('allocated capacity', $aCapacity , $this.name)
            $ListofObj += $obj

            $pCapacity   = $pCapacity.ToString() + " GB"
            $obj        = [Property]::new('provisioned capacity', $pCapacity , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('sharing', $Shared , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('lifecycle', $Permanent , $this.name)
            $ListofObj += $obj

            
            if ($volumeTemplate)
            {
                $obj        = [Property]::new('volume template', $volumeTemplate , $this.name)
                $ListofObj += $obj

                $obj        = [Property]::new('storage system', $StorageSystem , $this.name)
                $ListofObj += $obj
            }

            if ($Snapshot)
            {
                $obj        = [Property]::new('snapshot', $Snapshot , $this.name)
                $ListofObj += $obj

            }

            if ($AdaptOpt)
            {
                $obj        = [Property]::new('adaptive optimization', $AdaptOpt , $this.name)
                $ListofObj += $obj
            }

            if ($dataProtection)
            {
                $obj        = [Property]::new('data protection level', $dataProtection , $this.name)
                $ListofObj += $obj

            }


            return $ListofObj
        }
    }

#endregion storage

#region Settings

## -------------------------------------------------------
## 
##  OV Settings
##
## -------------------------------------------------------


Class OVSettings : SHiPSDirectory
{
    static $name                = 'Settings'
    hidden $version             = $null  # Get-HPOVVersion  - $Lib = $Lib.$($global:ApplianceConnection.Name)
    hidden $globalsetting       = $null  # Get-HPOVApplianceGlobalSetting
    hidden $datetime            = $null  # Get-HPOVApplianceDateTime
    hidden $addresspool         = $null  # Get-HPOVaddresspool
    hidden $addresspoolrange    = $null  # Get-HPOVaddresspoolrange
    hidden $addresspoolsubnet   = $null  # Get-HPOVaddresspoolsubnet
    

    OVSettings([string]$name, $ver, $glbsetting, $datetime, $addresspool , $addresspoolrange, $addresspoolsubnet) : base ('OVSettings')
    {
        $this.name              = $name
        $this.version           = $ver
        $this.globalsetting     = $glbsetting
        $this.datetime          = $datetime
        $this.addresspool       = $addresspool
        $this.addresspoolrange  = $addresspoolrange
        $this.addresspoolsubnet = $addresspoolsubnet
    }

    [object[]] GetChildItem()
    {
        $ListofObj              = @()
        
        # ----- Appliance FW
        $obj        = [OVAppliance]::new("appliance" , $this.version)
        $ListofObj += $obj

        # ----- Global Setting
        $obj        = [OVglobalSetting]::new("global setting" , $this.globalsetting)
        $ListofObj += $obj

        # ----- Date Time
        $obj        = [OVdatetime]::new("time and locale", $this.datetime)
        $ListofObj += $obj
    
        # ----- address and indetifier
        $obj        = [OVaddressidentifier]::new("address and identifier", $this.addresspool , $this.addresspoolrange, $this.addresspoolsubnet)
        $ListofObj += $obj

        return $ListofObj
    }

}

    class OVAppliance : SHIPSDirectory
    {
        static $name        = 'Firmware'
        hidden $version     = $null
    

        OVAppliance([string]$name , $version) : base ('OVAppliance')
        { 
            $this.name      = $name
            $this.version   = $version
        }

        [object[]] GetChildItem()
        {
            $ListofObj              = @()
                # ----- Appliance FW
                $Lib = $this.version
                $fw  = $Lib.ApplianceVersion
            $obj        = [Property]::new('Firmware', $fw , $this.name)

            $ListofObj += $obj

            return $ListofObj
        }
    }

    class OVglobalSetting : SHIPSDirectory
    {
        static $name            = 'OVglobalSetting'
        hidden $globalsetting   = $null
    

        OVglobalSetting([string]$name, $glb) : base ('OVglobalSetting')
        { 
            $this.name          = $name
            $this.globalsetting = $glb
        }

        [object[]] GetChildItem()
        {
            $ListofObj = @()
            # ----- Global Setting
            $ListofSettings = $this.globalsetting
            foreach ($setting in $ListofSettings)
            {
                $obj        = [Property]::new($setting.Name,$setting.value , $this.name)
                $ListofObj += $obj
            }

            return $ListofObj
        }
    }

    class OVdatetime : SHIPSDirectory
    {
        static $name        = 'OVdatetime'
        hidden $datetime    = $null      
    

        OVdatetime([string]$name, $datetime) : base ('OVdatetime')
        { 
            $this.name      = $name
            $this.datetime  =  $datetime
        }

        [object[]] GetChildItem()
        {
            $ListofObj = @()
            # ----- date time
            $dt = $this.datetime   

                $date_time  = ([datetime]$dt.datetime).ToUniversaltime()                
                $obj        = [Property]::new("time" ,$date_time , $this.name)
                $ListofObj += $obj

                $obj        = [Property]::new("locale" ,$dt.locale , $this.name)
                $ListofObj += $obj

                $obj        = [Property]::new("timezone" ,$dt.timezone , $this.name)
                $ListofObj += $obj

                if ($dt.pollinginterval)
                {
                    $obj        = [Property]::new("pollinginterval" ,$dt.pollinginterval , $this.name)
                    $ListofObj += $obj
                }

                $obj        = [OVntpserver]::new("ntp server" ,$dt.ntpservers)
                $ListofObj += $obj

            
            return $ListofObj
        }
    }   

        class OVntpserver : SHIPSDirectory
        {
            static $name    = 'ntp server'
            hidden $ntplist = $null

            OVntpserver([string]$name, $ntplist) : base('OVntpserver')
            {
                $this.name      = $name
                $this.ntplist   = $ntplist
            }

            [object[]] GetChildItem()
            {
                $ListofObj = @()
                
                foreach ($ntp in $this.ntplist)
                {
                    $obj        = [Property]::new($ntp ,$ntp , $this.name)
                    $ListofObj += $obj
                }
                return $ListofObj
            }

        }

    class OVaddressidentifier : SHIPSDirectory
    {
        static $name                = 'OVaddressidentifier'
        hidden $addresspool         = $null  # Get-HPOVaddresspool
        hidden $addresspoolrange    = $null  # Get-HPOVaddresspoolrange
        hidden $addresspoolsubnet   = $null  # Get-HPOVaddresspoolsubnet
    

        OVaddressidentifier([string]$name, $addresspool, $addresspoolrange, $addresspoolsubnet) : base ('OVaddressidentifier')
        { 
            $this.name                = $name
            $this.addresspool         = $addresspool
            $this.addresspoolrange    = $addresspoolrange
            $this.addresspoolsubnet   = $addresspoolsubnet
        }

        [object[]] GetRangeInfo( [string]$rangeuri)
        {
            $thisrange          = send-hpovrequest -uri $rangeuri
            $rangename          = $thisrange.name
            $enabled            = $thisrange.enabled
            $start              = $thisrange.startAddress
            $end                = $thisrange.endAddress
            $totalcount         = $thisrange.totalcount
            $freeIDcount        = $thisrange.freeIDcount
            $allocatedIDcount   = $thisrange.allocatedIDcount
            $reservedIDcount    = $thisrange.reservedIDcount
            

            return $rangename, $start, $end, $enabled, $totalcount, $freeIDcount , $allocatedIDcount, $reservedIDcount
        }

        [object[]] GetChildItem()
        {
            $ListofObj          = @()
            $ListofPools        = $this.addresspool
            
            foreach ($p in $ListofPools)
            {
                $obj = $null
                switch ($p.PoolType) 
                {
                    'VWWN'  { $obj = [OVaddress]::new('world wide names' , $p.RangeUris) }
                            
                    'VMAC'  { $obj = [OVaddress]::new('MAC addresses'    , $p.RangeUris) }
                            
                    'VSN'   { $obj = [OVaddress]::new('serial numbers'   , $p.RangeUris) }

                    'IPV4'  { $obj = [OVipSubnetAddress]::new('ipV4 addresses and subnet ranges' , $p.RangeUris, $this.addresspoolsubnet, $this.addresspoolrange) }
                            
                }
                $ListofObj += $obj
            }
    
            return $ListofObj
        }
    }   

        class OVipSubnetAddress : SHIPSDirectory
        {
            static $name                = 'ipV4 addresses and subnet ranges'
            hidden $rangeuris           = $null
            hidden $addresspoolsubnet   = $null
            hidden $addresspoolrange    = $null

            OVipSubnetAddress([string]$name, $rangeuris, $addresspoolsubnet, $addresspoolrange) : base ('OVipSubnetAddress')
            {
                $this.name              = $name
                $this.rangeuris         = $rangeuris
                $this.addresspoolsubnet = $addresspoolsubnet
                $this.addresspoolrange  = $addresspoolrange
            }


            [object[]] GetChildItem()
            {
                $ListofObj = @()
                if ($global:ApplianceConnection.ApplianceType -eq 'Composer')
                {
                    foreach ($subnet in $this.addresspoolsubnet)
                    {
                        $rangepersubnet  = $this.addresspoolrange | where subneturi -eq $subnet.uri 
                        $obj        = [OVipSubnetAddressProperty]::new($subnet.networkID , $subnet, $rangepersubnet)
                        $ListofObj += $obj                            
                    }
                }
                
                return $ListofObj
            }

        }

            class OVipSubnetAddressProperty : SHIPSDirectory
            {
                static $name            = 'OVipSubnetAddressProperty'
                hidden $subnet          = $null
                hidden $rangepersubnet  = $null

                OVipSubnetAddressProperty([string]$name, $subnet, $rangepersubnet)
                {
                    $this.name              = $name
                    $this.subnet            = $subnet
                    $this.rangepersubnet    = $rangepersubnet
                }
            
                [object[]] GetChildItem()
                {
                    $ListofObj  = @()
                    $ThisSubnet = $this.subnet

                    $obj        = [Property]::new('subnet ID' , $ThisSubnet.networkID , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('subnet mask' , $ThisSubnet.subnetmask , $this.name)
                    $ListofObj += $obj
                    
                    $obj        = [Property]::new('gateway' , $ThisSubnet.gateway , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('domain' , $ThisSubnet.domain , $this.name)
                    $ListofObj += $obj

                    $obj        = [OVipSubnetAddressRange]::new('address range' , $this.rangepersubnet)
                    $ListofObj += $obj

                    $obj        = [OVdnsserver]::new('dns server' , $ThisSubnet.dnsservers)
                    $ListofObj += $obj

                    return $ListofObj
                }
            }

                class OVipSubnetAddressRange : SHIPSDirectory
                {
                    static $name            = ' OVipSubnetAddressRange'
                    hidden $rangepersubnet  = @()

                    OVipSubnetAddressRange([string]$name, $rangepersubnet)
                    {
                        $this.name              = $name
                        $this.rangepersubnet    = $rangepersubnet
                    }

                    [object[]] GetChildItem()
                    {
                        $ListofObj      = @()
                        
                        foreach ($range in $this.rangepersubnet)
                        {
                            $obj        = [OVipSubnetAddressRangeProperty]::new($range.name, $range)
                            $ListofObj += $obj 
                        }

                        return $ListofObj

                    }
                }

                    class OVipSubnetAddressRangeProperty : SHIPSDirectory
                    {
                        static $name            = 'OVipSubnetAddressRangeProperty'
                        hidden $rangepersubnet  = $null
                    
                        OVipSubnetAddressRangeProperty([string]$name, $rangepersubnet)
                        {
                                $this.name              = $name
                                $this.rangepersubnet    = $rangepersubnet
                        }

                        [object[]]GetChildItem()
                        {
                            $ListofObj  = @()
                            $thisrange  = $this.rangepersubnet
                            
                            $obj        = [Property]::new('name' ,$thisrange.name , $this.name)
                            $ListofObj += $obj

                            $obj        = [Property]::new('start' ,$thisrange.startAddress , $this.name)
                            $ListofObj += $obj
        
                            $obj        = [Property]::new('end' ,$thisrange.endAddress , $this.name)
                            $ListofObj += $obj
                            
                            $obj        = [Property]::new('enabled' ,$thisrange.enabled , $this.name)
                            $ListofObj += $obj
        
                            $obj        = [Property]::new('count' ,$thisrange.totalcount , $this.name)
                            $ListofObj += $obj
        
                            $obj        = [Property]::new('remaining' ,$thisrange.freeIDcount , $this.name)
                            $ListofObj += $obj
        
                            $obj        = [Property]::new('allocated' ,$thisrange.allocatedIDcount , $this.name)
                            $ListofObj += $obj
        
                            $obj        = [Property]::new('reserved' ,$thisrange.reservedIDcount , $this.name)
                            $ListofObj += $obj
                    

                            return $ListofObj

                        }
                    }

                class OVdnsserver : SHIPSDirectory
                {
                    static $name        = 'OVdnsserver'           
                    hidden $dnsservers  = $null

                    OVdnsserver([string]$name, $dnsservers) : base ('OVdnsserver')
                    {
                        $this.name          = $name
                        $this.dnsservers    = $dnsservers
                    }

                    [object[]] GetChildItem()
                    {
                        $ListofObj = @()
                        foreach ($dns in $this.dnsservers)
                        {
                            $obj        = [Property]::new($dns , $dns , $this.name)
                            $ListofObj += $obj
                        }
                        return $ListofObj
                    }
                }

        class OVaddress : SHIPSDirectory
        {
            static $name        = 'OVAddress'           # Works for MAC, wwn and SN
            hidden $rangeuris   = $null

            OVaddress([string]$name, $rangeuris) : base ('OVaddress')
            {
                $this.name          = $name
                $this.rangeuris     = $rangeuris
            }

            [object[]] GetChildItem()
            {
                $ListofObj = @()
                
                foreach ($thisuri in $this.rangeuris)
                {
                    $thisrange = send-hpovrequest -uri $thisuri
                    if ($thisrange)
                    {
                        $obj        = [OVAddressProperty]::new($thisrange.startAddress ,$thisrange)
                        $ListofObj += $obj
                    }
                    
                }

                return $ListofObj
            }

        }

            class OVAddressProperty  : SHIPSDirectory
            {
                static $name        = 'OVAddressProperty'
                hidden $range       = $null

                OVAddressProperty([string]$name , $range)
                {
                    $this.name      = $name
                    $this.range     = $range
                }

                [object[]] GetChildItem()
                {
                    $ListofObj  = @()
                    $thisrange  = $this.range
                    if ($thisrange)
                    {
                        $obj        = [Property]::new('name' ,$thisrange.name , $this.name)
                        $ListofObj += $obj

                        $obj        = [Property]::new('start' ,$thisrange.startAddress , $this.name)
                        $ListofObj += $obj

                        $obj        = [Property]::new('end' ,$thisrange.endAddress , $this.name)
                        $ListofObj += $obj
                        
                        $obj        = [Property]::new('enabled' ,$thisrange.enabled , $this.name)
                        $ListofObj += $obj

                        $obj        = [Property]::new('count' ,$thisrange.totalcount , $this.name)
                        $ListofObj += $obj

                        $obj        = [Property]::new('remaining' ,$thisrange.freeIDcount , $this.name)
                        $ListofObj += $obj

                        $obj        = [Property]::new('allocated' ,$thisrange.allocatedIDcount , $this.name)
                        $ListofObj += $obj

                        $obj        = [Property]::new('reserved' ,$thisrange.reservedIDcount , $this.name)
                        $ListofObj += $obj
                    }

                    return $ListofObj

                }
            }

#endregion Settings

#region Server

## -------------------------------------------------------
## 
##  Server Hardware Type
##
## -------------------------------------------------------


Class ServerHardwareType : SHiPSDirectory
{
    static $name                = 'Server Hardware Type'
    hidden $SHTList             = @()
    
    

    ServerHardwareType([string]$name, $SHTList) : base ('ServerHardwareType')
    {
        $this.name              = $name
        $this.SHTList           = $SHTList
    }

    [object[]] GetChildItem()
    {
        $ListofObj              = @()
        foreach ($SHT in $this.SHTList)
        {
            $obj        = [ServerHardwareTypeName]::new($SHT.Name, $SHT)
            $ListofObj += $obj
        }

        return $ListofObj
    }

}

    Class ServerHardwareTypeName : SHiPSDirectory
    {
        static $name                = 'Server Hardware Type'
        hidden $SHT                 = @()
        
        

        ServerHardwareTypeName([string]$name, $SHT) : base ('ServerHardwareTypeName')
        {
            $this.name              = $name
            $this.SHT               = $SHT
        }

        [object[]] GetChildItem()
        {
            $ListofObj  = @()
            $thisSHT    = $this.SHT

            $obj        = [Property]::new('name' , $thisSHT.Name  , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('model' , $thisSHT.Model  , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('form factor' , $thisSHT.formFactor  , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('family' , $thisSHT.family  , $this.name)
            $ListofObj += $obj

            $obj        = [SHTpxeBootPolicies]::new('pxe boot policies' , $thisSHT.pxeBootPolicies)
            $ListofObj += $obj

            $obj        = [SHTBootModes]::new('boot modes' , $thisSHT.Bootmodes)
            $ListofObj += $obj

            $obj        = [Capabilities]::new('boot capabilities' , $thisSHT.bootCapabilities)
            $ListofObj += $obj

            $obj        = [Capabilities]::new('capabilities' , $thisSHT.Capabilities)
            $ListofObj += $obj

            $obj        = [SHTadapters]::new('adapters' , $thisSHT.adapters)
            $ListofObj += $obj       
            
            $obj        = [SHTstorageCapabilities]::new('storage capabilities' , $thisSHT.storageCapabilities)
            $ListofObj += $obj 

            $obj        = [SHTbiosSettings]::new('bios settings' , $thisSHT.biosSettings)
            $ListofObj += $obj 

            return $ListofObj
        }
    }

        Class SHTpxeBootPolicies : SHIPSDirectory
        {
            static $name    = 'SHTpxeBootPolicies'
            hidden $pxeboot = @()

            SHTpxeBootPolicies([string]$name, $pxebootpolicies) : base('SHTpxeBootPolicies')
            {
                $this.name          = $name
                $this.pxeboot       = $pxebootpolicies
            }

            [object[]] GetChildItem()
            {
                $ListofObj      = @()
                foreach ($val in $this.pxeboot)
                {
                    $obj        = [Property]::new($val, $val  , $this.name)
                    $ListofObj += $obj
                }
                return $ListofObj
            }
        }

        Class SHTBootModes : SHIPSDirectory
        {
            static $name        = 'SHTBootModes'
            hidden $bootmodes   = @()

            SHTBootModes ([string]$name, $bootmodes) : base('SHTBootModes')
            {
                $this.name          = $name
                $this.bootmodes     = $bootmodes
            }

            [object[]] GetChildItem()
            {
                $ListofObj      = @()
                foreach ($val in $this.bootmodes)
                {
                    $obj        = [Property]::new($val, $val  , $this.name)
                    $ListofObj += $obj
                }
                return $ListofObj
            }
        }

        Class SHTadapters : SHIPSDirectory
        {
            static $name            = 'SHTadapters'
            hidden $adapters        = @()

            SHTadapters([string]$name, $adapters) : base('SHTadapters')
            {
                $this.name          = $name
                $this.adapters      = $adapters
            }

            [object[]] GetChildItem()
            {
                $ListofObj      = @()
                foreach ($adapter in $this.adapters)
                {
                    $model      = $adapter.model -replace '/', '-'   # / is not allwed as folder name
                    $obj        = [SHTAdapterProperty]::new($model, $adapter)
                    $ListofObj += $obj 

                }
                return $ListofObj
            }
        }

            Class SHTAdapterProperty : SHIPSDirectory
            {
                static $name        = 'SHTAdapterProperty'
                hidden $adapter     = $null

                SHTAdapterProperty([string]$name, $adapter)
                {
                    $this.name      = $name
                    $this.adapter   = $adapter
                }

                [object[]]GetChildItem()
                {
                    $ListofObj      = @()
                    
                    $obj        = [Property]::new('model', $this.adapter.model  , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('location', $this.adapter.location  , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('slot', $this.adapter.slot  , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('device type', $this.adapter.deviceType  , $this.name)
                    $ListofObj += $obj

                    $obj        = [Capabilities]::new('capabilities' , $this.adapter.Capabilities)
                    $ListofObj += $obj

                    if ($this.adapter.storageCapabilities)
                    {
                        $obj        = [SHTstorageCapabilities]::new('storage capabilities' , $this.adapter.storageCapabilities)
                        $ListofObj += $obj
                    }

                    $obj        = [SHTadapterPorts]::new('ports' , $this.adapter.ports)
                    $ListofObj += $obj

                    return $ListofObj

                }
            }


                Class SHTstorageCapabilities : SHIPSDirectory
                {
                    static $name            = 'SHTstorageCapabilities'
                    hidden $stCapabilities  = @()

                    SHTstorageCapabilities([string]$name, $storageCapabilities) : base('SHTstorageCapabilities')
                    {
                        $this.name              = $name
                        $this.stCapabilities    = $storageCapabilities
                    }

                    [object[]] GetChildItem()
                    {
                        $ListofObj      = @()
                        foreach ($st in $this.stCapabilities)
                        {
                            $obj        = [Capabilities]::new('raid levels' , $st.raidLevels)
                            $ListofObj += $obj

                            $obj        = [Capabilities]::new('controller modes' , $st.controllerModes)
                            $ListofObj += $obj

                            $obj        = [Capabilities]::new('drive technologies' , $st.driveTechnologies)
                            $ListofObj += $obj

                            $obj        = [Property]::new('maximum drives' , $st.maximumDrives , $this.name)
                            $ListofObj += $obj

                            $obj        = [Property]::new('nvme backplane capable' , $st.nvmeBackplaneCapable , $this.name)
                            $ListofObj += $obj

                        }
                        return $ListofObj
                    }
                }

                Class SHTadapterPorts : SHIPSDirectory
                {
                    static $name            = 'SHTadapterPorts'
                    hidden $ports           = @()

                    SHTadapterPorts([string]$name, $ports) : base('SHTadapterPorts')
                    {
                        $this.name              = $name
                        $this.ports             = $ports
                    }

                    [object[]] GetChildItem()
                    {
                        $ListofObj      = @()
                        $ListofPorts    = $this.ports

                        $physicalport   = $ListofPorts.Count 
                        $obj            = [Property]::new('physical ports', $physicalport , $this.name)
                        $ListofObj     += $obj

                        $deviceType     = $ListofPorts[0].type
                        $obj            = [Property]::new('devicetype', $deviceType , $this.name)
                        $ListofObj     += $obj

                        $portSpeed      = (1/1000 * $ListofPorts[0].maxSpeedMbps).ToString() + " Gb/s"
                        $obj            = [Property]::new('max port speed', $portSpeed , $this.name)
                        $ListofObj     += $obj
                        
                        $maxVF          = $ListofPorts[0].maxVFsSupported
                        $VFFunction     = if ($maxVF -eq '-1') { 0} else {($physicalport * $maxVF).ToString()}
                        $obj            = [Property]::new('available virtual functions', $VFFunction , $this.name)
                        $ListofObj     += $obj

                        $VFAllocInc     = $ListofPorts[0].physicalFunctionCount
                        $obj            = [Property]::new('virtual function allocation increment', $VFAllocInc , $this.name)
                        $ListofObj     += $obj

                        $VirtualPorts   = $physicalport * $VFAllocInc
                        $obj            = [Property]::new('virtual ports', $VirtualPorts , $this.name)
                        $ListofObj     += $obj

                        $pcapabilities  = $ListofPorts[0].virtualports.capabilities | sort | Get-Unique

                        foreach ($capability in $pcapabilities)
                        {
                            $obj        = [Property]::new($capability, $capability , $this.name)
                            $ListofObj += $obj   
                        }

                        return $ListofObj
                    }
                }


        Class SHTbiosSettings : SHIPSDirectory
        {
            static $name         = 'SHTbiosSettings'
            hidden $biosSettings = @()

            SHTbiosSettings([string]$name, $biosSettings) : base('SHTbiosSettings')
            {
                $this.name          = $name
                $this.biosSettings  = $biosSettings
            }

            [object[]] GetChildItem()
            {
                $ListofObj      = @()
                foreach ($bios in $this.biosSettings)
                {
                    $obj        = [SHTbiosSettingsProperty]::new($bios.category, $bios)
                    $ListofObj += $obj

                    
                }
                return $ListofObj
            }
        }

            class SHTbiosSettingsProperty : SHIPSDirectory
            {
                static $name        = 'SHTbiosSettingsProperty'
                hidden $category    = $null

                SHTbiosSettingsProperty([string]$name, $category)
                {
                    $this.name      = $name
                    $this.category  = $category
                }

                [object[]]GetChildItem()
                {
                    $ListofObj      = @()
                    $bios           = $this.category

                    $obj        = [Property]::new('category', $bios.category  , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('id', $bios.id  , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('name', $bios.name  , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('type', $bios.type, $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('default value', $bios.defaultValue, $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('help text', $bios.helpText, $this.name)
                    $ListofObj += $obj
                    return $ListofObj

                }
            }

## -------------------------------------------------------
## 
##  Server Hardware
##
## -------------------------------------------------------


Class ServerHardware : SHiPSDirectory
{
    static $name                = 'Server Hardware Type'
    hidden $serverlist          = @()
    
    

    ServerHardware([string]$name, $ServerList) : base ('ServerHardware')
    {
        $this.name              = $name
        $this.serverlist        = $serverlist
    }

    [object[]] GetChildItem()
    {
        $ListofObj              = @()
        foreach ($Server in $this.serverlist)
        {
            $obj        = [ServerHardwareName]::new($Server.Name, $Server)
            $ListofObj += $obj
        }

        return $ListofObj
    }   
}

    Class ServerHardwareName : SHiPSDirectory
    {
        static $name            = 'Server'
        hidden $Server          = @()

        ServerHardwareName([string]$name, $server)
        {
            $this.name      = $name
            $this.server    = $server
        }

        [object[]]GetChildItem()
        {
            $ListofObj      = @()
            $thisServer     = $this.server

            # ------------- hardware
            $obj        = [Property]::new('state' , $thisServer.state , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('name' , $thisServer.Name , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('description' , $thisServer.description , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('form factor' , $thisServer.formFactor , $this.name)
            $ListofObj += $obj

            # -------------- OS related
            if ($thisServer.servername)
            {
                $obj        = [Property]::new('server name' , $thisServer.serverName , $this.name)
                $ListofObj += $obj
            }

            if ($thisServer.hostOsType)
            {
                $obj        = [Property]::new('host OS type' , $thisServer.hostOsType , $this.name)
                $ListofObj += $obj
            }

            # Hardware


            $obj        = [Property]::new('licensing intent' , $thisServer.licensingIntent , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('model' , $thisServer.model , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('serial number' , $thisServer.serialnumber , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('part number' , $thisServer.partNumber , $this.name)
            $ListofObj += $obj
            
            $obj        = [Property]::new('rom version' , $thisServer.romversion , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('uid state' , $thisServer.uidState , $this.name)
            $ListofObj += $obj

            $SHTName    = Get-NamefromUri -uri  $thisServer.serverHardwareTypeUri
            $obj        = [Property]::new('server hardware type' , $SHTName , $this.name)
            $ListofObj += $obj


            # ------- Firmware
            $obj        = [Property]::new('intelligent provisioning version' , $thisServer.intelligentProvisioningVersion , $this.name)
            $ListofObj += $obj

            if ($thisServer.serverFirmwareInventoryUri)
            {
                $fw         = send-hpovRequest -uri $thisServer.serverFirmwareInventoryUri
                $obj        = [ServerHardwareFWComponents]::new('firmware components' , $fw.Components)
                $ListofObj += $obj
            }

            # ----------------- Power State
            $obj        = [Property]::new('power lock' , $thisServer.powerLock , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('power state' , $thisServer.powerState , $this.name)
            $ListofObj += $obj

            # ----------------- Processor
            $obj        = [Property]::new('CPU type' , $thisServer.processorType , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('CPU cores' , $thisServer.processorCoreCount , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('CPU count' , $thisServer.processorCount , $this.name)
            $ListofObj += $obj

            $CPUSpeed   = ( 1/100 * $thisServer.processorSpeedMhz ).ToString() + ' Ghz'
            $obj        = [Property]::new('CPU speed' , $CPUSpeed , $this.name)
            $ListofObj += $obj

            # -------------------- Memory
            $memory     = (1/1KB * $thisServer.memoryMb).ToString() + ' GB'
            $obj        = [Property]::new('memory' , $memory , $this.name)
            $ListofObj += $obj

            # --------------------- Port Maps
            $obj        = [ServerHardwarePortMap]::new('ports', $thisServer.portMap.deviceSlots)
            $ListofObj += $obj
            

            # --------------------- iLO info
            $obj        = [ServerHardwareiLO]::new('iLO', $thisServer)
            $ListofObj += $obj

            ### TBD - Remote Support
            ### TBD - DataSupport

            return $ListofObj
        }
    }

        Class ServerHardwareFWComponents : SHIPSDirectory
        {
            static  $name           = 'ServerHardwareFWComponents'
            hidden  $FWComponents   = $Null

            ServerHardwareFWComponents([string]$name , $FWComponents) : base('ServerHardwareFWComponents')
            {
                $this.name          = $name
                $this.FWComponents = $FWComponents
            }

            [object[]]GetChildItem()
            {
                $ListofObj      = @()
                foreach ($fwc in $this.FWComponents)
                {
                    $componentname  = $fwc.Componentname -replace '/', '-'   # Folder does NOT support '/' in name
                    $obj            = [ServerHardwareFWComponentProperty]::new($componentname,$fwc)
                    $ListofObj     += $obj
                }
            
                return $ListofObj
            }

        }

            class ServerHardwareFWComponentProperty : SHIPSDirectory
            {
                static  $name       = 'ServerHardwareFWComponentProperty'
                hidden  $component  = $null

                ServerHardwareFWComponentProperty([string]$name , $component) : base('ServerHardwareFWComponentProperty')
                {
                    $this.name      = $name
                    $this.component = $component
                }

                [object[]]GetChildItem()
                {
                    $ListofObj      = @()
                    $c              = $this.component

                    $obj            = [Property]::new('component name', $c.componentName , $this.name)
                    $ListofObj     += $obj

                    $obj            = [Property]::new('component key', $c.componentKey , $this.name)
                    $ListofObj     += $obj

                    $obj            = [Property]::new('component location', $c.componentLocation , $this.name)
                    $ListofObj     += $obj

                    $obj            = [Property]::new('component version', $c.componentVersion , $this.name)
                    $ListofObj     += $obj

                    return $ListofObj
                }
            }

        Class ServerHardwarePortMap : SHIPSDirectory
        {
            static  $name           = 'ServerHardwarePortMap'
            hidden  $deviceslots    = $null

            ServerHardwarePortMap([string]$name , $dev) : base('ServerHardwarePortMap')
            {
                $this.name           = $name
                $this.deviceslots    = $dev
            }

            [object[]]GetChildItem()
            {
                $ListofObj      = @()
                foreach ($dev in $this.deviceslots)
                {
                    $obj            = [ServerHardwareDeviceSlot]::new($dev.devicenumber , $dev)
                    $ListofObj     += $obj
                }

                return $ListofObj
            }
        }

            Class ServerHardwareDeviceSlot : SHIPSDirectory
            {
                static  $name           = 'ServerHardwareDeviceSlot'
                hidden  $deviceslot     = $null

                ServerHardwareDeviceSlot([string]$name , $dev) : base('ServerHardwareDeviceSlot')
                {
                    $this.name          = $name
                    $this.deviceslot    = $dev
                }

                [object[]]GetChildItem()
                {
                    $ListofObj  = @()
                    $dev        = $this.deviceslot

                    $devname    = if ($dev.deviceName) {$dev.deviceName } else {'Empty'}
                    $obj        = [Property]::new($devname, $devname , $this.name)
                    $ListofObj += $obj
  
                    $obj        = [Property]::new($dev.location, $dev.location , $this.name)
                    $ListofObj += $obj

                    $obj        = [ServerHardwareDeviceSlotPhysicalPort]::new('physical ports', $dev.physicalports)
                    $ListofObj += $obj


                    return $ListofObj
                }
            }

                Class ServerHardwareDeviceSlotPhysicalPort : SHIPSDirectory
                {
                    static  $name           = 'ServerHardwareDeviceSlotPhysicalPort'
                    hidden  $physicalports  = $null
        
                    ServerHardwareDeviceSlotPhysicalPort([string]$name , $physicalports) : base('ServerHardwareDeviceSlotPhysicalPort')
                    {
                        $this.name          = $name
                        $this.physicalports = $physicalports
                    }
        
                    [object[]]GetChildItem()
                    {
                        $ListofObj  = @()
                        foreach ($port in $this.physicalports)
                        {
                            $portnumber = 'port ' + $port.number 
                            $obj        = [ServerHardwareDeviceSlotPhysicalPortProperty]::new($portnumber, $port)
                            $ListofObj += $obj                       
                        }
                        return $ListofObj
                    }
                }

                    class ServerHardwareDeviceSlotPhysicalPortProperty : SHIPSDirectory
                    {
                        static  $name       = 'ServerHardwareDeviceSlotPhysicalPortProperty'
                        hidden  $portobj    = $null

                        ServerHardwareDeviceSlotPhysicalPortProperty([string]$name, $port) : base('ServerHardwareDeviceSlotPhysicalPortProperty')
                        {
                            $this.name      = $name
                            $this.portobj   = $port
                        }

                        [object[]]GetChildItem()
                        {
                            $ListofObj      = @()
                            $port           = $this.portobj


                            $obj        = [Property]::new('port type', $port.type , $this.name)
                            $ListofObj += $obj 

                            $obj        = [Property]::new('port number', $port.number , $this.name)
                            $ListofObj += $obj 

                            $obj        = [Property]::new('mac address', $port.mac , $this.name)
                            $ListofObj += $obj 

                            $obj        = [Property]::new('world-wide number', $port.wwn , $this.name)
                            $ListofObj += $obj 


                            $obj        = [Property]::new('downlink port', $port.interconnectPort , $this.name)
                            $ListofObj += $obj                    

                            $icname     = Get-NamefromUri -uri $port.interconnectUri
                            $obj        = [Property]::new('interconnect', $icname , $this.name)
                            $ListofObj += $obj  
                            
                            $picname    = Get-NamefromUri -uri $port.physicalinterconnectUri
                            $obj        = [Property]::new('physical interconnect', $picname , $this.name)
                            $ListofObj += $obj  

                            $obj        = [Property]::new('physical downlink port', $port.physicalinterconnectPort , $this.name)
                            $ListofObj += $obj                                              
                            
                            return $ListofObj
                        }
                    }

        Class ServerHardwareiLO : SHIPSDirectory
        {
            static  $name           = 'ServerHardwareiLO'
            hidden  $server         = $null

            ServerHardwareiLO([string]$name , $server) : base('ServerHardwareiLO')
            {
                $this.name          = $name
                $this.server        = $server
            }

            [object[]]GetChildItem()
            {
                $ListofObj  = @()
                $s          = $this.server

                $obj        = [Property]::new('model', $s.mpModel , $this.name)
                $ListofObj += $obj
                
                $obj        = [Property]::new('host name', $s.mpHostInfo.mpHostName , $this.name)
                $ListofObj += $obj

                $addr       = $s.mpHostInfo.mpIpAddresses | % { $_.address}
                $obj        = [Capabilities]::new('addresses', $addr)
                $ListofObj += $obj
            
                return $ListofObj
            }
        }

## -------------------------------------------------------
## 
##  Server Profile Template TO BE TESTED
##
## -------------------------------------------------------


Class ServerProfileTemplate : SHiPSDirectory
{
    static $name                = 'ServerProfile'
    hidden $profilelist         = @()
    
    

    ServerProfileTemplate([string]$name, $profileList) : base ('ServerProfileTemplate')
    {
        $this.name              = $name
        $this.profilelist       = $profilelist
    }

    [object[]] GetChildItem()
    {
        $ListofObj              = @()
        foreach ($profile in $this.profilelist)
        {
            $obj        = [ServerProfileTemplateName]::new($profile.name, $profile)
            $ListofObj += $obj
        }

        return $ListofObj
    }   
}


    Class ServerProfileTemplateName : SHiPSDirectory
    {
        static $name            = 'ServerProfileTemplateName'
        hidden $profile         = $null

        ServerProfileTemplateName([string]$name, $profile) : base('ServerProfileTemplateName')
        {
            $this.name      = $name
            $this.profile   = $profile
        }

        [object[]]GetChildItem()
        {
            $ListofObj      = @()
            $thisprofile    = $this.profile
                            
            # ------------- standard attributes

            $obj        = [Property]::new('name' , $thisprofile.name , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('description' , $thisprofile.description , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('server profile description' , $thisprofile.serverProfileDescription , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('affinity' , $thisprofile.affinity , $this.name)
            $ListofObj += $obj
            
            $obj        = [Property]::new('mac type' , $thisprofile.macType , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('wwn type' , $thisprofile.wwnType , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('serial number type' , $thisprofile.serialNumberType , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('scsi initiator name type' , $thisprofile.scsiInitiatorNameType , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('status' , $thisprofile.status , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('state' , $thisprofile.state , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('hide unused flex nics' , $thisprofile.hideUnusedFlexNics , $this.name)
            $ListofObj += $obj

            # -------------- Hardware related
            if ($thisprofile.serverHardwareTypeUri)
            {
                $SHT        = send-HPOVRequest -uri $thisprofile.serverHardwareTypeUri
                $obj        = [ServerHardwareType]::new('server hardware type' , $SHT)
                $ListofObj += $obj
            }
             
            if ($thisprofile.enclosureGroupUri)
            {
                $EG         = send-HPOVRequest -uri $thisprofile.enclosureGroupUri
                $obj        = [EG]::new('enclosure group' , $EG)
                $ListofObj += $obj
            }

            
            # ------- Firmware
            if ($thisprofile.firmware)
            {
                $buildnamewithspace = $true
                $obj        = [PropertiesfromPSObject]::new('firmware' , $thisprofile.firmware , $buildnamewithspace)
                $ListofObj += $obj
            }

            # ------- Connection Settings
            if ($thisprofile.connectionSettings)
            {
                $obj        = [ServerProfileConnection]::new('connection Settings' , $thisprofile.ConnectionSettings )
                $ListofObj += $obj
            }

            # ------- Boot Mode
            if ($thisprofile.bootmode)
            {
                $buildnamewithspace = $true
                $obj        = [PropertiesfromPSObject]::new('boot mode' , $thisprofile.bootMode , $buildnamewithspace)
                $ListofObj += $obj
            }

            # ------- Boot Order
            if ($thisprofile.boot)
            {
                $obj        = [Capabilities]::new('boot order' , $thisprofile.boot.order )
                $ListofObj += $obj
            }

            # ------- Overriden BIOS settings
            if ($thisprofile.bios)
            {
                $obj        = [ServerProfileBios]::new('bios' , $thisprofile.bios )
                $ListofObj += $obj
            }

            # ------- Local Storage
            if ($thisprofile.localStorage)
            {
                $obj        = [ServerProfileLocalStorage]::new('local storage' , $thisprofile.localStorage )
                $ListofObj += $obj
            }

            # ------- SAN Storage
            if ($thisprofile.sanStorage)
            {
                $obj        = [ServerProfileSanStorage]::new('san storage' , $thisprofile.sanStorage )
                $ListofObj += $obj
            }

            # ------- OS deployment
            if ($thisprofile.osDeploymentSettings)
            {
                $obj        = [ServerProfileOsDeploymentSettings]::new('os deployment settings' , $thisprofile.osDeploymentSettings )
                $ListofObj += $obj
            }

            return $ListofObj
        }
    }

## -------------------------------------------------------
## 
##  Server Profile TO BE TESTED
##
## -------------------------------------------------------


Class ServerProfile : SHiPSDirectory
{
    static $name                = 'ServerProfile'
    hidden $profilelist         = @()
    
    

    ServerProfile([string]$name, $profileList) : base ('ServerProfile')
    {
        $this.name              = $name
        $this.profilelist       = $profilelist
    }

    [object[]] GetChildItem()
    {
        $ListofObj              = @()
        foreach ($profile in $this.profilelist)
        {
            $obj        = [ServerProfileName]::new($profile.name, $profile)
            $ListofObj += $obj
        }

        return $ListofObj
    }   
}


    Class ServerProfileName : SHiPSDirectory
    {
        static $name            = 'ServerProfileName'
        hidden $profile         = $null

        ServerProfileName([string]$name, $profile) : base('ServerProfileName')
        {
            $this.name      = $name
            $this.profile   = $profile
        }

        [object[]]GetChildItem()
        {
            $ListofObj      = @()
            $thisprofile    = $this.profile

            # ------------- standard attributes

            $obj        = [Property]::new('name' , $thisprofile.name , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('description' , $thisprofile.description , $this.name)
            $ListofObj += $obj

            
            $obj        = [Property]::new('serial number' , $thisprofile.serialnumber , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('uuid' , $thisprofile.uuid , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('mac type' , $thisprofile.macType , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('wwn type' , $thisprofile.wwnType , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('serial number type' , $thisprofile.serialNumberType , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('status' , $thisprofile.status , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('state' , $thisprofile.state , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('hide unused flex nics' , $thisprofile.hideUnusedFlexNics , $this.name)
            $ListofObj += $obj

            # -------------- iSCSI related

            $obj        = [Property]::new('iscsi initiator name' , $thisprofile.iscsiInitiatorName , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('iscsi initiator name type' , $thisprofile.iscsiInitiatorNameType , $this.name)
            $ListofObj += $obj

            # -------------- Hardware related
            if ($thisprofile.serverHardwareUri)
            {
                $hw         = send-hpovRequest -uri $thisprofile.serverHardwareUri
                $obj        = [ServerHardwareName]::new('server hardware' , $hw )
                $ListofObj += $obj
            }

            if ($thisprofile.serverHardwareTypeUri)
            {
                $SHT        = send-hpovRequest -uri $thisprofile.serverHardwareTypeUri
                $obj        = [ServerHardwareName]::new('server hardware type' , $SHT )
                $ListofObj += $obj

                # Check if DL or BL
                $IsDL       = $SHT.Model -like '*DL*'
                
            }

            if ($thisprofile.enclosureGroupUri)
            {
                $EG         = send-hpovRequest -uri $thisprofile.enclosureGroupUri
                $obj        = [EGName]::new('enclosure group' , $EG )
                $ListofObj += $obj
            }

            if ($thisprofile.enclosureUri)
            {
                $EG         = send-hpovRequest -uri $thisprofile.enclosureUri
                $obj        = [EnclosureName]::new('enclosure' , $EG )
                $ListofObj += $obj
                
                $obj        = [Property]::new('enclosure bay' , $thisprofile.enclosureBay , $this.name)
                $ListofObj += $obj

                $obj        = [Property]::new('affinity' , $thisprofile.affinity , $this.name)
                $ListofObj += $obj
            }

            # --------- Profile template
            if ($thisprofile.serverProfileTemplateUri)
            {
                $spt        = send-hpovRequest -uri $thisprofile.serverProfileTemplateUri
                $obj        = [ServerProfileTemplateName]::new('server profile template' , $spt )
                $ListofObj += $obj

                $obj        = [Property]::new('template compliance' , $thisprofile.templateCompliance , $this.name)
                $ListofObj += $obj
            }
            
            # ------- Firmware
            if ($thisprofile.firmware)
            {
                $buildnamewithspace = $true
                $obj        = [PropertiesfromPSObject]::new('firmware' , $thisprofile.firmware , $buildnamewithspace)
                $ListofObj += $obj
            }

            # ------- Connections
            if ($thisprofile.connections)
            {
                $obj        = [ServerProfileConnection]::new('connections' , $thisprofile.Connections )
                $ListofObj += $obj
            }

            # ------- Boot Mode
            if ($thisprofile.bootmode)
            {
                $buildnamewithspace = $true
                $obj        = [PropertiesfromPSObject]::new('boot mode' , $thisprofile.bootMode , $buildnamewithspace)
                $ListofObj += $obj
            }

            # ------- Boot Order
            if ($thisprofile.boot)
            {
                $obj        = [Capabilities]::new('boot order' , $thisprofile.boot.order )
                $ListofObj += $obj
            }

            # ------- Overriden BIOS settings
            if ($thisprofile.bios)
            {
                $obj        = [ServerProfileBios]::new('bios' , $thisprofile.bios )
                $ListofObj += $obj
            }

            # ------- Local Storage
            if ($thisprofile.localStorage)
            {
                $obj        = [ServerProfileLocalStorage]::new('local storage' , $thisprofile.localStorage )
                $ListofObj += $obj
            }

            # ------- SAN Storage
            if ($thisprofile.sanStorage)
            {
                $obj        = [ServerProfileSanStorage]::new('san storage' , $thisprofile.sanStorage )
                $ListofObj += $obj
            }

            # ------- OS deployment
            if ($thisprofile.osDeploymentSettings)
            {
                $obj        = [ServerProfileOsDeploymentSettings]::new('os deployment settings' , $thisprofile.osDeploymentSettings )
                $ListofObj += $obj
            }

            return $ListofObj
        }
    }

        Class ServerProfileConnection : SHIPSDirectory   
        {
            static  $name               = 'ServerProfileConnection'
            hidden  $connection         = $null

            ServerProfileConnection([string]$name , $connection) : base('ServerProfileConnection')
            {
                $this.name              = $name
                $this.connection        = $connection
            }

            [object[]]GetChildItem()
            {
                $ListofObj  = @()
                $c          = $this.connection

                $obj        = [Property]::new('name' , $c.name , $this.name)
                $ListofObj += $obj

                $obj        = [Property]::new('id' , $c.id , $this.name)
                $ListofObj += $obj

                $obj        = [Property]::new('port id' , $c.portId , $this.name)
                $ListofObj += $obj

                $obj        = [Property]::new('mac type' , $c.macType , $this.name)
                $ListofObj += $obj

                $obj        = [Property]::new('wwpn type' , $c.wwpnType , $this.name)
                $ListofObj += $obj

                $obj        = [Property]::new('mac' , $c.mac , $this.name)
                $ListofObj += $obj

                $obj        = [Property]::new('wwn' , $c.wwn , $this.name)
                $ListofObj += $obj
                
                $obj        = [Property]::new('wwpn' , $c.wwpn , $this.name)
                $ListofObj += $obj

                $obj        = [Property]::new('function type' , $c.functionType , $this.name)
                $ListofObj += $obj

                $obj        = [Property]::new('status' , $c.status , $this.name)
                $ListofObj += $obj

                $obj        = [Property]::new('state' , $c.state , $this.name)
                $ListofObj += $obj

                $obj        = [Property]::new('requested virtual function' , $c.requestedVFs , $this.name)
                $ListofObj += $obj

                $obj        = [Property]::new('allocated virtual function' , $c.allocatedVFs , $this.name)
                $ListofObj += $obj

                $bw         = (1/1000 * $c.requestedMbps).ToString() + " Gb/s"
                $obj        = [Property]::new('requested bandwidth' , $bw , $this.name)
                $ListofObj += $obj

                $bw         = (1/1000 * $c.allocatedMbps).ToString() + " Gb/s"
                $obj        = [Property]::new('allocated bandwidth' , $bw , $this.name)
                $ListofObj += $obj

                $bw         = (1/1000 * $c.maximumMbps).ToString() + " Gb/s"
                $obj        = [Property]::new('maximum bandwidth' , $bw , $this.name)
                $ListofObj += $obj

                $net        = $c.networkUri
                if ($net)
                {
                    $net        = Send-HPOVRequest -uri $net
                    $obj        = [NetworkName]::new($net.name, $net)
                    $ListofObj += $obj
                }
                
                $icname     = Get-NamefromUri -uri $c.interconnectUri
                $obj        = [Property]::new('interconnect' , $icname , $this.name)
                $ListofObj += $obj

                if ($c.boot)
                {
                    $buildnamewithspace = $true
                    $obj        = [PropertiesfromPSObject]::new('boot' , $c.boot , $buildnamewithspace)
                    $ListofObj += $obj
                }
        
                if ($c.ipv4)
                {
                    $buildnamewithspace = $true
                    $obj        = [PropertiesfromPSObject]::new('ipv4' , $c.ipv4 , $buildnamewithspace)
                    $ListofObj += $obj
                }

                return $ListofObj
            }
        }


        Class ServerProfileBoot : SHIPSDirectory   # NOT USED
        {
            static  $name               = 'ServerProfileBoot'
            hidden  $bootorder          = $null

            ServerProfileBoot([string]$name , $bootorder) : base('ServerProfileBoot')
            {
                $this.name              = $name
                $this.bootorder         = $bootorder
            }

            [object[]]GetChildItem()
            {
                $ListofObj  = @()

                $obj        = [ServerProfileBiosSetting]::new('bios setting', $this.bios)
                $ListofObj += $obj

                return $ListofObj
            }
        }

            Class ServerProfileBios : SHIPSDirectory
            {
                static  $name               = 'ServerProfileBios'
                hidden  $bios               = $null

                ServerProfileBios([string]$name , $bios) : base('ServerProfileBios')
                {
                    $this.name              = $name
                    $this.bios              = $bios 
                }

                [object[]]GetChildItem()
                {
                    #$ListofObj  = @()

                    #$obj        = [ServerProfileBiosSetting]::new('bios setting', $this.bios)
                    #$ListofObj += $obj

                    $ListofObj  = @()
                    
                    $obj        = [PropertiesfromPSObject]::new('overriden bios setting', $this.bios , $false)  
                    $ListofObj += $obj

                    $obj        = [Property]::new('bios management state' , $this.bios.manageBios , $this.name)
                    $ListofObj += $obj

                    
                    return $ListofObj
                }
            }

                Class ServerProfileBiosSetting : SHIPSDirectory
                {
                    static  $name               = 'ServerProfileBiosSetting'
                    hidden  $bios               = $null

                    ServerProfileBiosSetting([string]$name , $bios) : base('ServerProfileBiosSetting')
                    {
                        $this.name              = $name
                        $this.bios              = $bios 
                    }

                    [object[]]GetChildItem()
                    {
                        $ListofObj  = @()
                        
                        $obj        = [PropertiesfromPSObject]::new('overriden bios setting', $this.bios , $false)  
                        $ListofObj += $obj

                        $obj        = [Property]::new('bios management state' , $this.bios.manageBios , $this.name)
                        $ListofObj += $obj

                        return $ListofObj
                    }
                }

        Class ServerProfileLocalStorage : SHIPSDirectory   
        {
            static  $name               = 'ServerProfileLocalStorage'
            hidden  $local              = $null

            ServerProfileLocalStorage([string]$name , $local) : base('ServerProfileLocalStorage')
            {
                $this.name              = $name
                $this.local             = $local
            }

            [object[]]GetChildItem()
            {
                $ListofObj  = @()
                $s          = $this.san
            $a="sasLogicalJBODs : {} controllers     : {} "
                $obj        = [Property]::new('TBD - Local storage' , $s.manageSanStorage , $this.name)
                $ListofObj += $obj

                return $ListofObj
            }
        }

        Class ServerProfileSanStorage : SHIPSDirectory   
        {
            static  $name               = 'ServerProfileSanStorage'
            hidden  $san                = $null

            ServerProfileSanStorage([string]$name , $san) : base('ServerProfileSanStorage')
            {
                $this.name              = $name
                $this.san               = $san
            }

            [object[]]GetChildItem()
            {


                $ListofObj  = @()
                $s          = $this.san

                $obj        = [Property]::new('san storage management' , $s.manageSanStorage , $this.name)
                $ListofObj += $obj

                $obj        = [Property]::new('host os type' , $s.hostOSType , $this.name)
                $ListofObj += $obj

                if ($s.volumeAttachments)
                {
                    $buildnamewithspace = $true
                    $obj        = [PropertiesfromPSObject]::new('volume attachment' , $s.volumeAttachments, $buildnamewithspace)
                    $ListofObj += $obj
                }

                return $ListofObj
            }
        }

        Class ServerProfileOsDeploymentSettings : SHIPSDirectory
        {
            static  $name               = 'ServerProfileOsDeploymentSettings'
            hidden  $osdeploysettings   = $null

            ServerProfileOsDeploymentSettings([string]$name , $osdeploysettings) : base('ServerProfileOsDeploymentSettings')
            {
                $this.name              = $name
                $this.osdeploysettings  = $osdeploysettings 
            }

            [object[]]GetChildItem()
            {
                $ListofObj  = @()
                $settings   = $this.osdeploysettings 
                
                
                $obj            = [Property]::new('force os deployment', $settings.forceOsDeployment , $this.name)
                $ListofObj      += $obj

                if ($settings.osCustomAttributes)
                {
                    $ca         = send-hpovRequest -uri $settings.osCustomAttributes
                    $obj        = [ServerProfileOSDeploymentCustomAttribute]::new('custom attribute' , $ca , $false) # we do not buile new name with space on property name
                    $ListofObj += $obj
                }           
                
                if ($settings.osVolumeUri)
                {
                    $osvol      = send-hpovRequest -uri $settings.osVolumeUri
                    $obj        = [ServerProfileOSDeploymentVolumeName]::new('os volume' , $osvol)
                    $ListofObj += $obj
                }                

                if ($settings.osDeploymentPlanUri)
                {
                    $dp         = send-hpovRequest -uri $settings.osDeploymentPlanUri
                    $obj        = [OSDeploymentPlanName]::new('deployment plan' , $dp)
                    $ListofObj += $obj
                }
            
                return $ListofObj
            }
        }

            class ServerProfileOSDeploymentCustomAttribute : SHIPSDirectory
            {
                static  $name               = 'ServerProfileOSDeploymentCustomAttribute'
                hidden  $customattribute    = $null
                hidden $builnewname         = $false

                ServerProfileOSDeploymentCustomAttribute([string]$name, $customattribute, $buildnewname) : base('ServerProfileOSDeploymentCustomAttribute')
                {
                    $this.name              = $name
                    $this.customattribute   = $customattribute
                    $this.buildnewname      = $buildnewname
                }

                [object[]]GetChildItem()
                {
                    $ListofObj  = @()
                    $obj        = [PropertiesfromPSObject]::new('parameters or custom attributes', $this.customattribute , $this.buildnewname)  
                    $ListofObj += $obj

                    return $ListofObj
                }

            }

            class ServerProfileOSDeploymentVolumeName : SHIPSDirectory
            {
                static  $name               = 'ServerProfileOSDeploymentVolumeName'
                hidden  $volume             = $null

                ServerProfileOSDeploymentVolumeName([string]$name, $osvolume) : base('ServerProfileOSDeploymentVolumeName')
                {
                    $this.name              = $name
                    $this.volume            = $osvolume
                }

                [object[]]GetChildItem()
                {
                    $ListofObj  = @()
                    $vol        = $this.volume

                    $obj        = [Property]::new('name' , $vol.name , $this.name)
                    $ListofObj += $obj
        
                    $obj        = [Property]::new('description' , $vol.description , $this.name)
                    $ListofObj += $obj
        
                    $obj        = [Property]::new('id' , $vol.id , $this.name)
                    $ListofObj += $obj
        
                    $obj        = [Property]::new('status' , $vol.status , $this.name)
                    $ListofObj += $obj
        
                    $obj        = [Property]::new('state' , $vol.state , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('deployment type' , $vol.deploymentType , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('deployment server ip' , $vol.deployServerIP , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('target volume ip' , $vol.targetVolumeIP , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('target iqn' , $vol.targetIqn , $this.name)
                    $ListofObj += $obj
                    
                    $obj        = [Property]::new('os volume name' , $vol.osVolumeName , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('os volume status' , $vol.osVolumeStatus , $this.name)
                    $ListofObj += $obj
              
                    $obj        = [Property]::new('os volume port' , $vol.osVolumePort , $this.name)
                    $ListofObj += $obj
                    

                    return $ListofObj
                }

            }



#endregion Server

#region OSDeployment


## -------------------------------------------------------
## 
##  OS Deployment
##
## -------------------------------------------------------


Class OSDeployment : SHiPSDirectory
{
    static $name                = 'OSDeployment'
    hidden $osdServer           = $null
    hidden $deployplanlist      = $null
   
    

    OSDeployment([string]$name, $OSdeployServer, $OSdeployPlans) : base ('OSDeployment')
    {
        $this.name              = $name
        $this.osdServer         = $OSdeployServer
        $this.deployplanlist    = $OSdeployPlans
        
    }

    [object[]] GetChildItem()
    {
        $ListofObj              = @()

        $obj        = [OSDeploymentServerName]::new($this.osdServer.name, $this.osdServer)
        $ListofObj += $obj

        $obj        = [OSDeploymentPlan]::new('deployment plan', $this.deployplanlist)
        $ListofObj += $obj

        return $ListofObj
    }   
}


    Class OSDeploymentServerName : SHiPSDirectory
    {
        static $name            = 'OSDeploymentServerName'
        hidden $osdServer       = $null

        OSDeploymentServerName([string]$name, $OSdeployServer) : base('OSDeploymentServerName')
        {
            $this.name          = $name
            $this.osdServer     = $OSdeployServer
        }

        [object[]]GetChildItem()
        {
            $ListofObj      = @()
            $osdS           = $this.osdServer

            $obj        = [Property]::new('name' , $osdS.name , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('description' , $osdS.description , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('id' , $osdS.id , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('deployment manager type' , $osdS.deplManagersType , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('status' , $osdS.status , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('state' , $osdS.state , $this.name)
            $ListofObj += $obj
            
            $obj        = [Property]::new('primary ip v4 address' , $osdS.primaryIPV4 , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('primary ip v6 address' , $osdS.primaryIP , $this.name)   # IP V6
            $ListofObj += $obj

            $obj        = [Property]::new('primary cluster name' , $osdS.primaryClusterName , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('primary cluster status' , $osdS.primaryClusterstatus , $this.name)
            $ListofObj += $obj


            $obj        = [Property]::new('primary uuid' , $osdS.primaryUUID , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('checksum' , $osdS.checksum , $this.name)
            $ListofObj += $obj

            $obj        = [Property]::new('primary uuid' , $osdS.primaryUUID , $this.name)
            $ListofObj += $obj

            # ---------------- Primary Active Appliance
            if ($osdS.primaryActiveAppliance)
            {
                $paa        = send-hpovRequest -uri $osdS.primaryActiveAppliance
                $obj        = [OSDeploymentAppliance]::new('primary active appliance' , $paa)
                $ListofObj += $obj
            }

            # ---------------- Management network
            if ($osdS.mgmtNetworkUri)
            {
                $net        = send-hpovRequest -uri $osdS.mgmtNetworkUri
                $obj        = [NetworkName]::new('management network' , $net)
                $ListofObj += $obj
            }
            return $ListofObj
        }
    }

            Class OSDeploymentAppliance : SHIPSDirectory
            {
                static $name            = 'OSDeploymentAppliance'
                hidden $appliance       = $null
        
                OSDeploymentAppliance([string]$name, $appliance) : base('OSDeploymentAppliance')
                {
                    $this.name          = $name
                    $this.appliance     = $appliance
                }
        
                [object[]]GetChildItem()
                {
                    $ListofObj      = @()
                    $thisappliance  = $this.appliance

                    # ------------------- Appliance attributes
                    $obj        = [Property]::new('appliance - name' , $thisappliance.name , $this.name)
                    $ListofObj += $obj  

                    $obj        = [Property]::new('appliance - description' , $thisappliance.description , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('appliance - uuid' , $thisappliance.applianceUUID , $this.name)
                    $ListofObj += $obj  

                    $obj        = [Property]::new('appliance - id' , $thisappliance.applianceId , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('appliance - status' , $thisappliance.status , $this.name)
                    $ListofObj += $obj 

                    $obj        = [Property]::new('appliance - serial number' , $thisappliance.applianceSerialNumber , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('appliance - active state' , $thisappliance.isActive , $this.name)
                    $ListofObj += $obj  
                    
                    $obj        = [Property]::new('appliance - primary state' , $thisappliance.isPrimary , $this.name)
                    $ListofObj += $obj 

                    $obj        = [Property]::new('appliance - version' , $thisappliance.atlasVersion , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('appliance - need upgrade' , $thisappliance.needUpgrade , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('appliance - cert md5' , $thisappliance.certMd5 , $this.name)
                    $ListofObj += $obj
                    
                    $obj        = [Property]::new('appliance - claimed by OneView' , $thisappliance.claimedByOV , $this.name)
                    $ListofObj += $obj

                    #----------- Network config
                    $obj        = [Property]::new('appliance - domain name' , $thisappliance.domainName , $this.name)
                    $ListofObj += $obj
                    
                    $obj        = [Property]::new('appliance - vlan tag' , $thisappliance.vlanTagId , $this.name)   # IP V6
                    $ListofObj += $obj

                    $obj        = [Property]::new('appliance - ip v6 address' , $thisappliance.applianceIpv6Address , $this.name)   # IP V6
                    $ListofObj += $obj
                    
                    $obj        = [Property]::new('appliance - em(?) ip v6 address' , $thisappliance.emIpv6Address , $this.name)   # IP V6
                    $ListofObj += $obj

                    $obj        = [Property]::new('appliance - management ip v4 address' , $thisappliance.mgmtIpv4Address , $this.name)   # IP V6
                    $ListofObj += $obj

                    $obj        = [Property]::new('appliance - management dns server' , $thisappliance.mgmtDNSServer , $this.name)   # IP V6
                    $ListofObj += $obj

                    $obj        = [Property]::new('appliance - management gateway' , $thisappliance.mgmtGateway , $this.name)   # IP V6
                    $ListofObj += $obj

                    $obj        = [Property]::new('appliance - management subnet mask' , $thisappliance.mgmtSubnetMask , $this.name)   # IP V6
                    $ListofObj += $obj

                    $obj        = [Property]::new('appliance - data ip v4 address' , $thisappliance.dataIpv4Address , $this.name)   # IP V6
                    $ListofObj += $obj

                    $obj        = [Property]::new('appliance - data gateway' , $thisappliance.dataGateway , $this.name)   # IP V6
                    $ListofObj += $obj

                    $obj        = [Property]::new('appliance - data subnet mask' , $thisappliance.dataSubnetMask , $this.name)   # IP V6
                    $ListofObj += $obj

                    if ($thisappliance.managementNetworkUri)
                    {
                        $net        = send-hpovRequest -uri $thisappliance.managementNetworkUri
                        $obj        = [NetworkName]::new('management network' , $net)
                        $ListofObj += $obj
                    }

                    if ($thisappliance.alternateMgmtDNSServer)
                    {
                        $obj        = [Property]::new('appliance - alternate management dns server' , $thisappliance.alternateMgmtDNSServer , $this.name)
                        $ListofObj += $obj
                    }

                    if ($thisappliance.alternateprodDNSServer)
                    {
                        $obj        = [Property]::new('appliance - alternate production dns server' , $thisappliance.alternateprodDNSServer , $this.name)
                        $ListofObj += $obj
                    }

                    if ($thisappliance.prodDNSServer)
                    {
                        $obj        = [Property]::new('appliance - production dns server' , $thisappliance.prodDNSServer , $this.name)
                        $ListofObj += $obj
                    }

                    if ($thisappliance.prodDomain)
                    {
                        $obj        = [Property]::new('appliance - production domain name' , $thisappliance.prodDomain , $this.name)
                        $ListofObj += $obj
                    }
                    
                    # ------------------- Cluster attributes
                    $obj        = [Property]::new('cluster - ip v4 address' , $thisappliance.clusterIpv4Address , $this.name)
                    $ListofObj += $obj
        
                    $obj        = [Property]::new('cluster - ip v6 address' , $thisappliance.clusterIpv6Address , $this.name)   # IP V6
                    $ListofObj += $obj

                    $obj        = [Property]::new('cluster - name' , $thisappliance.ClusterName , $this.name)
                    $ListofObj += $obj
        
                    $obj        = [Property]::new('cluster - status' , $thisappliance.ClusterStatus , $this.name)
                    $ListofObj += $obj

                    
                    # ----------------- Deployment
                    if ($thisappliance.deploymentNetworkUri)
                    {
                        $deploynet  = Get-NamefromUri -uri $thisappliance.deploymentNetworkUri
                        $obj        = [Property]::new('deployment network' , $deploynet , $this.name)
                        $ListofObj += $obj
                    }

                    if ($thisappliance.deploymentManagerUri)
                    {
                        $deploymgr  = Get-NamefromUri -uri $thisappliance.deploymentManagerUri
                        $obj        = [Property]::new('deployment manager' , $deploymgr , $this.name)
                        $ListofObj += $obj
                    }

                    #------------------ am VM
                    $obj        = [Property]::new('am virtual machine - data ip v4 address' , $thisappliance.amvmDataIPv4Address , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('am virtual machine - management ip v4 address' , $thisappliance.amvmMgmtIPv4Address , $this.name)
                    $ListofObj += $obj

                    #------------------ OneView
                    $obj        = [Property]::new('OneView - ip v4 address' , $thisappliance.oneViewIPv4Address , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('OneView - ip v6 address' , $thisappliance.oneViewIPv6Address , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('OneView - appliance uuid' , $thisappliance.oneViewApplianceUUID , $this.name)
                    $ListofObj += $obj

                    #------------------ VSA
                    $obj        = [Property]::new('vsa - data ip v4 address' , $thisappliance.vsaDataIPv4Address , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('vsa - management ip v4 address' , $thisappliance.vsaMgmtIPv4Address , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('vsa - data cluster ip v4 address' , $thisappliance.vsaDataClusterIPv4Address , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('vsa - version' , $thisappliance.vsaVersion , $this.name)
                    $ListofObj += $obj
                                
                    $obj        = [Property]::new('vsa - quorum' , $thisappliance.quorumString , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('vsa - create storage cluster expected time (in seconds)' , $thisappliance.createStorageClusterExpectedTimeInSec , $this.name)
                    $ListofObj += $obj

                    # ------------------ CIM
                    $obj        = [Property]::new('cim enclosure - name' , $thisappliance.cimEnclosureName , $this.name)
                    $ListofObj += $obj

                    $obj        = [Property]::new('cim enclosure - bay' , $thisappliance.cimBay , $this.name)
                    $ListofObj += $obj

                    if ($thisappliance.cimEnclosureUri)
                    {
                        $enclosure  = Send-HPOVRequest -uri $thisappliance.cimEnclosureUri
                        $obj        = [Enclosure]::new('cim enclosure' , $enclosure) 
                        $ListofObj += $obj
                    }

                    # -------- Logical Enclosure
                    $obj        = [Property]::new('logical enclosure - name' , $thisappliance.leName , $this.name)
                    $ListofObj += $obj

                    # --------- interconnect-link-topology
                    $obj        = [Property]::new('TBD-interconnect-link-topology' , $thisappliance.ilturi , $this.name)
                    $ListofObj += $obj

                    return $ListofObj
                }
            }


    Class OSDeploymentPlan : SHIPSDirectory
    {
            static $name            = 'OSDeploymentPlan'
            hidden $planlist       = $null
    
            OSDeploymentPlan([string]$name, $OSdeployPlanList) : base('OSDeploymentPlan')
            {
                $this.name          = $name
                $this.planlist     = $OSdeployPlanList
            }
    
            [object[]]GetChildItem()
            {
                $ListofObj      = @()
                foreach ($plan in $this.planlist)
                {
                    $obj        = [OSDeploymentPlanName]::new($plan.name , $plan)
                    $ListofObj += $obj
                }
                return $ListofObj
            }
    }

        Class OSDeploymentPlanName  : SHIPSDirectory
        {
            static $name            = 'OSDeploymentPlan'
            hidden $plan            = $null
    
            OSDeploymentPlanName([string]$name, $Plan) : base('OSDeploymentPlanName')
            {
                $this.name          = $name
                $this.plan          = $Plan
            }
    
            [object[]]GetChildItem()
            {
                $ListofObj      = @()
                $p              = $this.plan

                $obj        = [Property]::new('name' , $p.name , $this.name)
                $ListofObj += $obj

                $obj        = [Property]::new('description' , $p.description , $this.name)
                $ListofObj += $obj

                $obj        = [Property]::new('id' , $p.id , $this.name)
                $ListofObj += $obj

                $obj        = [Property]::new('type' , $p.type , $this.name)
                $ListofObj += $obj
                
                $obj        = [Property]::new('os type' , $p.osType , $this.name)
                $ListofObj += $obj

                $obj        = [Property]::new('architecture' , $p.architecture , $this.name)
                $ListofObj += $obj

                $obj        = [Property]::new('status' , $p.status , $this.name)
                $ListofObj += $obj

                $obj        = [Property]::new('state' , $p.state , $this.name)
                $ListofObj += $obj

                $obj        = [Property]::new('deployment - os volume size' , $p.osDpSize , $this.name)
                $ListofObj += $obj

                $obj        = [Property]::new('deployment - type' , $p.deploymentType , $this.name)
                $ListofObj += $obj

                $obj        = [Property]::new('deployment - ip v6 address' , $p.deploymentAppliance , $this.name)
                $ListofObj += $obj

                $obj        = [Property]::new('deployment - ip v4 address' , $p.deploymentApplianceIpv4 , $this.name)
                $ListofObj += $obj

                $obj        = [OSDeploymentCustomAttribute]::new('deployment - custom attributes' , $p.additionalParameters)
                $ListofObj += $obj

                return $ListofObj
            }
        }

            class OSDeploymentCustomAttribute : SHIPSDirectory
            {
                static $name            = 'OSDeploymentCustomAttribute'
                hidden $calist          = $null
        
                OSDeploymentCustomAttribute([string]$name, $calist) : base('OSDeploymentCustomAttribute')
                {
                    $this.name          = $name
                    $this.calist        = $calist
                }
        
                [object[]]GetChildItem()
                {
                    $ListofObj      = @()
                    foreach ($ca in $this.calist)
                    {
                        $obj    = [OSDeploymentCustomAttribute]::new( $ca.name, $ca)
                        $ListofObj += $obj
                    }
                    return $ListofObj
                }
            }

                class OSDeploymentCustomAttributeName : SHIPSDirectory
                {
                    static $name                = 'OSDeploymentCustomAttributeName'
                    hidden $customattribute     = $null
            
                    OSDeploymentCustomAttributeName([string]$name, $customattribute) : base('OSDeploymentCustomAttributeName')
                    {
                        $this.name              = $name
                        $this.customattribute   = $customattribute
                    }
            
                    [object[]]GetChildItem()
                    {
                        $ListofObj      = @()
                        $ca             = $this.customattribute

                        $obj        = [Property]::new('name' , $ca.name , $this.name)
                        $ListofObj += $obj

                        $obj        = [Property]::new('description' , $ca.description , $this.name)
                        $ListofObj += $obj

                        $obj        = [Property]::new('value' , $ca.value , $this.name)
                        $ListofObj += $obj

                        $obj        = [Property]::new('id' , $ca.caId , $this.name)
                        $ListofObj += $obj

                        $obj        = [Property]::new('editable' , $ca.caEditable , $this.name)
                        $ListofObj += $obj

                        $obj        = [Property]::new('type' , $ca.caType , $this.name)
                        $ListofObj += $obj

                        $obj        = [Property]::new('constraints' , $ca.caConstraints , $this.name)
                        $ListofObj += $obj

                        return $ListofObj
                    }
                }
                
            
#endregion OSDeployment
