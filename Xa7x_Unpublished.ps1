If ((Get-PSSnapin -Name "Citrix*" -ErrorAction SilentlyContinue | Measure-Object).count -eq 0) {asnp "Citrix*"}
clear
 
$Ver="1.0" 

$CtxblogHeader = @"
****************************************************
   _____ _________   ______  _      ____   _____
  / ____|__   __\ \ / /  _ \| |    / __ \ / ____|
 | |       | |   \ V /| |_) | |   | |  | | |  __
 | |       | |    > < |  _ <| |   | |  | | | |_ |
 | |____   | |   / . \| |_) | |___| |__| | |__| |
  \_____|  |_|  /_/ \_\____/|______\____/ \_____|
                                                
  Remove user or group in Publish Dekstop and Apps
     on the "Citrix Virtual Apps and Desktops"
 
ver : $Ver
****************************************************
`r
`r
"@
 
Write-Host $CtxblogHeader -ForegroundColor Green

$Path = Split-Path -Parent $MyInvocation.MyCommand.Path
$PathFile = $Path +"\Xa7x_Unpublished.log"

$Controller = "127.0.0.1"
$CountFoundUsr=0
 
Foreach ($i in 1..3)
{
	try
	{
	$Farm = get-brokersite -adminaddress $Controller
	break
	}
	catch
	{
		if (!$Farm)
		{
		Write-host "***** Warning this server are not a Controller please enter a valid controller on the next step *****" -F Black -B Yellow
		$Controller = Read-Host -Prompt "Please enter a valid controller"
		}
	}
           
If ($i -eq 3) {Write-host "***** Warning your enter bad controller x3 exit script *****" -F Yellow -B Red;return}
}
  
$UsrGrp = Read-Host -Prompt "Please enter the username (domain\username or domain\group )"


########################################
#Choice to remove or display application
########################################
do {
    try {
        $numOk = $true
        [int]$Statut = Read-Host -Prompt "Type 1 to remove or 2 to display"
        } # end try
    catch {$numOK = $false}
    } # end do 
until (($Statut -eq 1) -or ($Statut -eq 2) -and $numOK)


#create file log
if (!(Test-Path $PathFile)) {New-Item -type file $PathFile | Out-Null}

$date = get-date

$Log = @"
****************************************************
$Date
$($Farm.name)
$UsrGrp
****************************************************
`r
"@

$DGs = Get-BrokerDesktopGroup -AdminAddress $Controller -MaxRecordCount 2147483647|select -ExpandProperty Name



#####################################
#Search User/group on Delivery Group
#####################################
Write-Host "Search in Delivery Group" -f yellow
 
Foreach ($Dg in $Dgs)
{
$SearchUsr = Get-BrokerAccessPolicyRule -AdminAddress $Controller -DesktopGroupName $Dg | select -expandproperty IncludedUsers|?{$_.Name -eq $UsrGrp}
 
	if ($SearchUsr)
	{
	Write-Host "Delivery Group : $DG"
	$Log+="Delivery Group : $DG `r`n"
	$CountFoundUsr++
	$PolicyRules = get-BrokerAccessPolicyrule -AdminAddress $Controller -DesktopGroupName $Dg
			   
		Foreach ($PolicyRule in $PolicyRules)
		{
		#$CountFoundUsr++
			if ($statut -eq 1) 
			{Set-BrokerAccessPolicyRule -AdminAddress $Controller -Name $PolicyRule.Name -RemoveIncludedUsers  $UsrGrp
			Write-Host "Remove in " $PolicyRule.Name -f red
			$Log+="Remove in $($PolicyRule.Name) `r`n"
			}
		}
	}
}


#####################################
#Search User/group on Delivery Group
#####################################
Write-Host "Search in Publish Deskop on Delivery Group" -f yellow
$PublihDsks = Get-BrokerEntitlementPolicyRule|?{$_.IncludedUserFilterEnabled -eq $True}|select -ExpandProperty Name
 
foreach ($PublihDsk in $PublihDsks)
{
$SearchUsrDsk = Get-BrokerEntitlementPolicyRule -AdminAddress $Controller -Name $PublihDsk |select -ExpandProperty IncludedUsers|?{$_.Name -eq $UsrGrp}
 
	if ($SearchUsrDsk)
	{
	$CountFoundUsr++
	Write-Host "Publish Dekstop : $PublihDsk"
	$Log+="Publich Dekstop : $PublihDsk `r`n"
		if ($statut -eq 1) 
		{
		Set-BrokerEntitlementPolicyRule -Name $PublihDsk -RemoveIncludedUsers $UsrGrp
		Write-Host "Remove in $PublihDsk" -f red
		$Log+="Remove in $PublihDsk `r`n"
		}   
	}
}



#####################################
#Search User/group on Apps
#####################################
Write-Host "Search in Publish application" -f yellow
$PublihApps = get-brokerApplication -AdminAddress $Controller -MaxRecordCount 2147483647
 
Foreach ($PublihApp in $PublihApps)
{
$SearchUsrApp = get-brokerApplication -AdminAddress $Controller -uid $PublihApp.uid |select -ExpandProperty AssociatedUserNames|?{$_ -eq $UsrGrp}
 
	if ($SearchUsrApp)
	{
	$CountFoundUsr++
	Write-Host "Application : $($PublihApp.Name)"
	$Log+="Application : $($PublihApp.Name)`r`n"
		if ($statut -eq 1) 
		{
		Remove-BrokerUser -AdminAddress $Controller -Application $PublihApp.uid -Name $UsrGrp
		Write-Host "Remove in $($PublihApp.Name)" -f red
		$Log+="Remove in $($PublihApp.Name)`r`n"
		}    
	}
}

Add-Content -path $PathFile -value $Log
Write-Host @"
`r
`r
******************************************************
Number of occurence(s) : $CountFoundUsr
******************************************************
`r
"@
