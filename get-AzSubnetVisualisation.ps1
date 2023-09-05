#Create a visualisation of the subnets in an Azure VNET
#Write html output, 255 (/24) per line
#WARNING:   We assume address space Subnets are sorted in order for us, and it's a contiguous IPv4 space.
#           Also, the address space of the VNET is at least a /24, and no subnets are larger than a /24

function get-AzSubnetVisualisationHTML([string]$VnetName){
    #Get Details of Subnet    
    $subnets=get-AzSubnetDetails -VnetName $VnetName
    #Write Header of HTML and start table
    "<html><body><table style='border:1px solid'>"
    #Get ip space from VNET
    $Vnet=Get-AzVirtualNetwork -Name $vnetName
    #Get the first address in the first prefix of the address space.
    $startAddress=($Vnet.addressSpace.AddressPrefixes[0] -split "/")[0]
    #Calculate the last address in the last prefix of the address space
    $endAddress=($Vnet.addressSpace.AddressPrefixes[$Vnet.addressSpace.AddressPrefixes.Count-1] -split "/")[0] 
    $Mask=($Vnet.addressSpace.AddressPrefixes[$Vnet.addressSpace.AddressPrefixes.Count-1] -split "/")[1]
    $size=(([System.Math]::Pow(2, 32-$Mask)) -1) 
    $IPBytes=([ipaddress]$endAddress).GetAddressBytes()
    [array]::Reverse($IPBytes) 
    $EndIPBytes=([ipaddress](([ipaddress]($IPBytes -join ("."))).address + ([int]$size))).GetAddressBytes()
    [array]::Reverse($EndIPBytes)
    $endAddress=$EndIPBytes -join "."

    #header row on table could go here.

    #Loop through IPs from our startAddress to endAddress
    #This loop logic isn't quite right, but will suffice for > /24 VNETs with a contiguous address space
    for ($firstOctet=[int](($startaddress -split("\."))[0]);$firstOctet -le [int](($endaddress -split("\."))[0]) ;$firstOctet++ ){
        for ($secondOctet=[int](($startaddress -split("\."))[1]);$secondOctet -le [int](($endaddress -split("\."))[1]) ;$secondOctet++ ){
            for ($thirdOctet=[int](($startaddress -split("\."))[2]);$thirdOctet -le [int](($endaddress -split("\."))[2]) ;$thirdOctet++ ){
                #Start a table row and add the /24 prefix in the first column
                " <tr>" 
                "     <td>"+([string]$firstOctet+"."+[string]$secondOctet+"."+[string]$thirdOctet+".0/24 ").PadLeft(18," ")+"</td>"
                for ($fourthOctet=0;$fourthoctet -le 255 ;$fourthOctet++ ){
                    #Build the IP from the Octets                    
                    $IP=[string]$firstOctet+"."+[string]$secondOctet+"."+[string]$thirdOctet+"."+[string]$fourthOctet
                    #Create a sortable representation - 172.0.1.2 becomes 172000001002 for example
                    $temp=Foreach ($octet in ($IP -split ("\."))){$octet.PadLeft(3,"0")}  
                    $sortingstring=$temp -join ""
                    #Check if this IP is in a subnet, set the flag to false until we get a match
                    $InUse=$false
                    #Loop through the subnets retrieved earlier
                    Foreach ($subnet in $subnets) {
                        #If the InUse flag is already set, don't bother looking
                        if (!$InUse){
                            #Get/ retrieve the sortable representation of the start and end address of the subnet
                            $temp=Foreach ($octet in ($subnet.EndAddress -split ("\."))){$octet.PadLeft(3,"0")}  
                            $EndAddressSortingString= $temp -join ""
                            $thisstartAddress=[int64]$subnet.sortingstring.Replace(".","")
                            $thisAddress=[int64]$sortingstring
                            $thisendAddress=[int64]$EndAddressSortingString
                            #Is the IP address inside this subnet?
                            if ( $thisstartAddress -le $thisAddress -and $thisendAddress -ge $thisAddress) {
                                #This IP is inside an existing subnet, check to see if it's the last address
                                if ($thisAddress -eq $thisendAddress) {
                                    #It is the last address, so add a table cell the width of the subnet in the in-use colour with the name and prefix of the subnet written in
                                    "<td colspan="+[string]($subnet.size+1)+" style='background-color: #106ebe; color: white;' title='"+$IP+" ("+$subnet.name+")'>"+$subnet.name+" "+$subnet.AddressPrefix+"</td>"
                                }
                                #Set the flag to true
                                $InUse=$true
                            }
                        }
                    }
                    #If the IP is outside of the subnet create a single table cell in the empty colour
                    If (!$Inuse){
                        "     <td style='background-color: #7fcb31;' title='"+$IP+" (available)'>&nbsp;</td>"
                    }
                }
                " </tr>" #end of table row (end of this /24)
            }
        }
    }
    #End table and HTML output
    "</table></body></html>"
}

function get-AzSubnetDetails ([string]$VnetName){
    #Get the VNET
    $Vnet=Get-AzVirtualNetwork -Name $vnetName
    #Loop through Subnets in VNET collecting name and address prefix.
    $subnets=@()
    foreach($Subnet In $Vnet.Subnets) {
        #Create an empty object to represent the subnet details
        $object = New-Object -TypeName PSObject
        #Get the name given to the subnet
        $object | Add-Member -Name 'Name' -MemberType Noteproperty -Value $Subnet.Name
        #Get the Address Prefix of the subnet
        $object | Add-Member -Name 'AddressPrefix' -MemberType Noteproperty -Value $Subnet.AddressPrefix[0]
        #Get the start address of the subnet
        $object | Add-Member -Name 'StartAddress' -MemberType Noteproperty -Value ($Subnet.AddressPrefix -split "/")[0]
        #Get the / notation subnet mask
        $object | Add-Member -Name 'Mask' -MemberType Noteproperty -Value ($Subnet.AddressPrefix -split "/")[1]
        #Get the dot Notation subnet mask
        $temp=ForEach( $byteString in  (("1"*$Object.Mask + "0"*(32-$Object.Mask)) -split '(.{8})' -ne '')){[convert]::ToInt32($byteString,2)}
        $object | Add-Member -Name 'MaskString' -MemberType Noteproperty -Value ($temp -join ".")
        #Get the Size- the number of IP addresses in this subnet
        $object | Add-Member -Name 'Size' -MemberType Noteproperty  -Value (([System.Math]::Pow(2, 32-$object.Mask)) -1)
        #Calculate the last address in the subnet
        $IPBytes=([ipaddress]$Object.StartAddress).GetAddressBytes()
        [array]::Reverse($IPBytes) 
        $EndIPBytes=([ipaddress](([ipaddress]($IPBytes -join ("."))).address + ([int]$object.size))).GetAddressBytes()
        [array]::Reverse($EndIPBytes)
        $object | Add-Member -Name 'EndAddress' -MemberType Noteproperty -Value ($EndIPBytes -join ".")
        #Add the Start Address in a format useful for sorting
        $temp=Foreach ($octet in ($object.StartAddress -split ("\."))){$octet.PadLeft(3,"0")}  
        $object | Add-Member -Name 'SortingString' -MemberType Noteproperty -Value ($temp -join ".")
        $subnets+=$object
    }
    #Return the subnets in order of their starting address.
    $subnets | sort-object -Property SortingString
}