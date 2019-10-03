Set-SQLAgentOperatorEmails
{
<#
.SYNOPSIS
This script takes a the name of a SQLAgent Operator and updates it with the desired email addresses.
.DESCRIPTION
This script takes a the name of a SQLAgent Operator and updates it with the desired email addresses.
The email addresses need to be separated by a comma or a semicolon.
It will tell you if your operator is over 100 characters.
It will validate if you have an AG, and if you are primary. 
If you are not primary it will not run.
It will log to C:\salt\scripts\log\<datetime>_SetSQLAgentOperatorEmails.log
.NOTES
    File Name  : --
    Author     : Andy Schwabe, andy.schwabe@infor.com; Sandeep Puram sandeep.puram@infor.com
    Requires   : PowerShell V4
    Version    : 2015.12.07
.LINK
#> 
  
param([Parameter(Mandatory=$True)][string]$operator,
      [Parameter(Mandatory=$True)][string]$emailAddresses)
     
    #importing modules
    Import-Module SQLPS -DisableNameChecking
    Import-Module "C:\salt\scripts\modules\InforLogging\InforLogging.psm1" -DisableNameChecking

    #initial logging
    New-LogFile -Folder "C:\salt\scripts\log" -FilePrefix "SetSQLAgentOperatorEmails" -FileExtension "log" -SetEnvLogFile 1
    $startTime = Get-Date
    $startDTHR = ($startTime).ToString()
    $errorCount = 0
    Write-Log -Message "Starting Set-SQLAgentOperatorEmails at $startDTHR" -MessageType info
    Write-Log -Message "Requested SQL Agent Operator: $operator" -MessageType info
    Write-Log -Message "Requested Email Addresses: $emailAddresses" -MessageType info

    #validate if an ag or not
    $ag = 0
    $clusterGroup = Get-ClusterGroup
    foreach($group in $clusterGroup)
    {
        if($group.Name -eq 'AG1')
        {
            $ag = 1
        }
    }
    if($ag = 1)
    {
        Import-Module "C:\salt\scripts\modules\InforSQL\InforSQL.psm1" -DisableNameChecking
        $primary = SQLAG-GetPrimary
    }

    #validating if email addresses have a total length that is greater than 100 characters
    if($emailAddresses.Length -gt 100)
    {
        Write-Log -Message 'The inputted email addresses are more than 100 characters total and will be truncated by SQL Server. Please change the email addresses you are inputting and try again. Did not make any changes.' -MessageType error
        $errorCount++
    }
    else
    {
        #only making changes if this is not an AG or we are the primary
        if(($ag -eq 0) -or ($primary -eq $env:COMPUTERNAME))
        {
            try
            {
                Write-Log -Message "Configuring the $operator Operator." -MessageType info
                
                #building query to create operator if it doesn't exist and update it if it does exist
                $UpdateOperator = "
                IF NOT EXISTS ( SELECT * 
                                  FROM msdb..sysoperators 
                                 WHERE name = '$operator' )
                   BEGIN
                         EXEC msdb.dbo.sp_add_operator @name = '$operatorname'
                                                     , @enabled=1
                                                     , @weekday_pager_start_time=0
                                                     , @weekday_pager_end_time=235959
	                                                 , @saturday_pager_start_time=0
                                                     , @saturday_pager_end_time=235959
	                                                 , @sunday_pager_start_time=0
	                                                 , @sunday_pager_end_time=235959
	                                                 , @pager_days=127
                                                     , @email_address='$emailAddresses'
                                                     , @category_name = N'[Uncategorized]'
                     END
                ELSE
                   BEGIN
                         EXEC msdb.dbo.sp_update_operator @name = '$operator'
                                                        , @enabled=1
                                                        , @weekday_pager_start_time=0
                                                        , @weekday_pager_end_time=235959
                                                        , @saturday_pager_start_time=0
                                                        , @saturday_pager_end_time=235959
                                                        , @sunday_pager_start_time=0
                                                        , @sunday_pager_end_time=235959
                                                        , @pager_days=127
                                                        , @email_address='$emailAddresses'
                                                        , @pager_address=N''''
                                                        , @netsend_address=N''''
                     END"
                #executing the query
                Invoke-Sqlcmd -Query $UpdateOperator -ServerInstance $env:COMPUTERNAME
                Write-Log -Message "Successfully configured the $operator Operator." -MessageType info
            }
            catch
            {
                Write-Log -Message "Could not configure the $operator Operator." -MessageType error
                Write-Log -Message "$_" -MessageType ERROR
                $errorCount++
            }
        }
        else
        {
            Write-Log -Message "This server is part of an AG, and is not the primary node. As such, any config would be wiped out due to SyncSQLAgent. Did not make any changes." -MessageType error
            $errorCount++
        }
    }
    
    #finishing logging
    $endTime = Get-Date
    $endDTHR = ($endTime).ToString()
    $elapsedTime = New-TimeSpan -Start $startTime -End $endTime 
    $elapsedMinutes = $elapsedTime.Minutes
    $elapsedSeconds = $elapsedTime.Seconds
    Write-Log -Message "Ending DTC Configuration at $endDTHR" -MessageType INFO
    Write-Log -Message "SQL Agent Operator Configuration took $elapsedMinutes minutes and $elapsedSeconds seconds" -MessageType INFO
    Write-Log -Message "Error Count: $errorCount" -MessageType INFO
}

Set-TTLOn
{
<#
.SYNOPSIS
This script configures Local DTC as required by the Syteline Application 
.DESCRIPTION
This script will configure local DTC with the desired configuration for Syteline.
This script is silent. 
It will log to C:\salt\scripts\log\<datetime>_SLDTCConfig.log
.NOTES
    File Name  : --
    Author     : Andy Schwabe, andy.schwabe@infor.com; Sandeep Puram sandeep.puram@infor.com
    Requires   : PowerShell V4
    Version    : 2015.12.02
.LINK
#> 


}

Set-SLDTCConfig
{
<#
.SYNOPSIS
This script configures Local DTC as required by the Syteline Application 
.DESCRIPTION
This script will configure local DTC with the desired configuration for Syteline.
This script is silent. 
It will log to C:\salt\scripts\log\<datetime>_SLDTCConfig.log
.NOTES
    File Name  : --
    Author     : Andy Schwabe, andy.schwabe@infor.com; Sandeep Puram sandeep.puram@infor.com
    Requires   : PowerShell V4
    Version    : 2015.05.20
.LINK
#> 
    
    #logging preparations
    Import-Module "C:\salt\scripts\modules\InforLogging\InforLogging.psm1" -DisableNameChecking
    New-LogFile -Folder "C:\salt\scripts\log" -FilePrefix "SLDTCConfig" -FileExtension "log" -SetEnvLogFile 1
    $startTime = Get-Date
    $startDTHR = ($startTime).ToString()
    $errorCount = 0
    Write-Log -Message "Starting DTC Configuration at $startDTHR" -MessageType INFO

    #getting DTC object
    $dtc = Get-Dtc
    $dtcService = Get-Service -DisplayName 'Distributed Transaction Coordinator'

    #starting DTC
    try 
    {
        Write-Log -Message 'Starting DTC' -MessageType INFO
        Set-Service -InputObject $dtcService -StartupType Automatic -Status Running
        Write-Log -Message 'Started DTC' -MessageType INFO
    }
    catch
    {
        Write-Log -Message 'Starting DTC failed.' -MessageType ERROR
        Write-Log -Message "$_" -MessageType ERROR
        $errorCount++
    }

    #changing DTC trace settings
    try 
    {
        Write-Log -Message 'Changing Trace settings' -MessageType INFO
        Set-DtcTransactionsTraceSetting -AllTransactionsTracingEnabled $false 
        Write-Log -Message 'Successfully changed DTC trace settings' -MessageType INFO
    }
    catch
    {
        Write-Log -Message 'Could not change the DTC trace settings.' -MessageType ERROR
        Write-Log -Message "$_" -MessageType ERROR
        $errorCount++
    }

    #changing DTC transaction settings
    try
    {
        Write-Log -Message 'Changing DTC transaction settings' -MessageType INFO
        Set-DtcTransactionsTraceSetting -LongLivedTransactionsTracingEnabled $true -AbortedTransactionsTracingEnabled $true
        Write-Log -Message 'Successfully changed DTC transaction settings' -MessageType INFO

    }
    catch
    {
        Write-Log -Message 'Could not change the DTC transaction settings' -MessageType ERROR
        Write-Log -Message "$_" -MessageType ERROR
        $errorCount++
    }

    #changing DTC trace session settings
    try
    {
        Write-Log -Message 'Changing DTC trace session settings' -MessageType INFO
        Set-DtcTransactionsTraceSession -BufferCount 40 -Verbose
        Write-Log -Message 'Successfully changed DTC trace session settings' -MessageType INFO
    }
    catch
    {
        Write-Log -Message 'Could not DTC trace session settings' -MessageType ERROR
        Write-Log -Message "$_" -MessageType ERROR
        $errorCount++
    }

    #changing DTC log size
    try
    {
        Write-Log -Message 'Changing DTC log size' -MessageType INFO
        Set-DtcLog -DtcName $dtc.DtcName -Path "C:\Windows\sytem32\MSDtc" -SizeInMB 4 -MaxSizeInMB 512 -Verbose -Confirm:$false
        Write-Log -Message 'Successfully changed DTC log size' -MessageType INFO
    }
    catch
    {
        Write-Log -Message 'Could not change the DTC log size' -MessageType ERROR
        Write-Log -Message "$_" -MessageType ERROR
        $errorCount++
    }

    #changing DTC network settings
    try
    {
        Write-Log -Message 'Changing DTC network settings' -MessageType INFO
        Set-DtcNetworkSetting -DtcName $dtc.DtcName -InboundTransactionsEnabled $true -OutboundTransactionsEnabled $true -RemoteClientAccessEnabled $false -RemoteAdministrationAccessEnabled $false -XATransactionsEnabled $false -LUTransactionsEnabled $true -AuthenticationLevel NoAuth -Confirm:$false
        Write-Log -Message 'Successfully changed DTC network settings ' -MessageType INFO
    }
    catch
    {
        Write-Log -Message 'Could not change the DTC network settings' -MessageType ERROR
        Write-Log -Message "$_" -MessageType ERROR
        $errorCount++
    }

    #restarting the DTC service
    try
    {
        Write-Log -Message 'Restarting DTC service' -MessageType INFO
        Restart-Service -InputObject $dtcService
        Write-Log -Message 'Successfully restarted the DTC service' -MessageType INFO
    }
    catch
    {
        Write-Log -Message 'Could not restart the DTC service' -MessageType  ERROR
        Write-Log -Message "$_" -MessageType ERROR
        $errorCount++
    }

    #finishing logging
    Write-Log -Message "Ending DTC Configuration at $endDTHR" -MessageType INFO
}
