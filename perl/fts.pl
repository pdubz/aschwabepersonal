#!/usr/bin/perl
#
# Written by Kevin Beaudreau
#
# This script Adds/Removes entries to/from Route53 using Cloudformation stacks.
#
# https://wiki.infor.com/confluence/display/CTS/File+Transfer+Service+CLI+Tool
# Syntax:  tam-dns.pl [options]
#
# Algorithm:
#    1.
#    2.
#    3.
#
# Change History:
#    08/24/2016 initial builduse strict;
use strict;
use warnings;
use Getopt::Long qw(:config posix_default bundling permute);
use vars qw/$opt_create $opt_update $opt_tenant $opt_environment $opt_stsprofile $opt_application $opt_password $opt_sshkey $opt_statuscheck $opt_help $opt_region/;
#
#
# Variables
my $Reply;
my $rc = GetOptions(
    'tenant|t=s'      => \$opt_tenant,
    'environment|e=s' => \$opt_environment,
    'application|a=s' => \$opt_application,
    'profile|P=s'     => \$opt_stsprofile,
    'password|p=s'    => \$opt_password,
    'region|r=s'      => \$opt_region,
    'sshkey|s=s'      => \$opt_sshkey,
    'create|C'        => \$opt_create,
    'update|U'        => \$opt_update,
    'status|S'        => \$opt_statuscheck,
    'help|h'          => \$opt_help
);
my %Endpoint = (
    us => "https://ftsapi.inforcloudsuite.com/api",
    eu => "https://ftsapi.eu1.inforcloudsuite.com/api",
);
my %AWSRegion = (
    us => "us-east-1",
    eu => "eu-central-1",
);
#
#
# Logic
        if ($opt_help){Usage();}
	if (!$opt_stsprofile){Usage();}
        if (!$opt_tenant || !$opt_environment || !$opt_region){
                printf "Error:  required information missing.  Please supply a tenant";
                Usage();
        }
        if (($opt_region ne "us") && ($opt_region ne "eu")){die "Error: region (-r) must be \"us\" or \"eu\"\n";}
#	if (!$opt_password){$opt_password=qx{getPassword 16};chomp $opt_password;}
        if ($opt_statuscheck){checkUser();}
	if ($opt_create){createUser();}
#	if ($opt_update){updateUser();} #reserved for future use
	exit 0;
#
#
# Functions
sub Usage
{
    my $text;
    $text .= <<END;
    Usage:
    Can be used to update DNS with supplied Parameters.  The two parameters are required.
    The Actions are optional, but at least one MUST be specified - otherwise, what's the point?

    Syntax:
    perl $0 <--tenant|-t> <--environment|-e> <--stack|-s> [<--help>]

    Parameters:
    --tenant      or -t   REQUIRED.  tenant name.  Example "pilot" or "bcbsnc" or "whitelodging"
    --environment or -e   REQUIRED.  environment type.  must be one of <prd,trn,tst,dev,ax1,ax2>
    --application or -a   REQUIRED.  application name.  must be one of <ts or tam>
    --profile     or -P   REQUIRED.  This is the STS profile that grants access to the Route53 role.
    --password    or -p   OPTIONAL.  Required if updating or creating.  This is the password that will be set on the account.  It is NOT the sshkey passphrase.
    --region      or -r   REQUIRED.  Must be one of <us,eu>.
    --sshkey      or -s   OPTIONAL.  This is the OpenSSH format of the Public key.
    --create      or -C   specify this to create the entry.  otherwise a text file will be created, but not sent to Route53.
    --update      or -u   update information for user account.  this will replace the user with a new config.  Reserved for future use.
    --status      or -S   Get status of customer account.
    --help        or -h   display this help message

END
    printf "$text\n";
    exit 0;
}
sub createUser 
{
    $Reply=`ftscli --profile $opt_stsprofile --region $AWSRegion{$opt_region} --endpoint $Endpoint{$opt_region} --application-name $opt_application --client-name $opt_tenant\_$opt_environment put-client`;
    printf "$Reply\n";
    if ($opt_sshkey){
    $Reply=`ftscli --profile $opt_stsprofile --region $AWSRegion{$opt_region} --endpoint $Endpoint{$opt_region} put-user --application-name $opt_application --client-name $opt_tenant\_$opt_environment --user-name $opt_tenant\_$opt_environment\_ftp --permission read,write,view,delete,deletedir,makedir,rename,resume --ip-restriction SortOrder=0,StartIP=0.0.0.0,StopIP=255.255.255.255,Type=A --password $opt_password --directory AdminConsole --directory ElectronicPay --directory GHRTransfer --sftp-enabled --ssh-key "$opt_sshkey"`;}
    else{
    $Reply=`ftscli --profile $opt_stsprofile --region $AWSRegion{$opt_region} --endpoint $Endpoint{$opt_region} put-user --application-name $opt_application --client-name $opt_tenant\_$opt_environment --user-name $opt_tenant\_$opt_environment\_ftp --permission read,write,view,delete,deletedir,makedir,rename,resume --ip-restriction SortOrder=0,StartIP=0.0.0.0,StopIP=255.255.255.255,Type=A --password $opt_password --directory AdminConsole --directory ElectronicPay --directory GHRTransfer --sftp-enabled`;}
    printf "$Reply\n";
    exit 0;
}
#
#
#
sub checkUser 
{
    $Reply=`ftscli --profile $opt_stsprofile --region $AWSRegion{$opt_region} --endpoint $Endpoint{$opt_region} get-user --application-name $opt_application --client-name $opt_tenant\_$opt_environment --user-name $opt_tenant\_$opt_environment\_ftp | jq -r "."`;
    printf "$Reply\n";
    exit 0;
}
#
#  
#  UpdateUser isn't really used rightnow.
#sub updateUser 
#{
#    $Reply=`ftscli --profile $opt_stsprofile --region $AWSRegion{$opt_region} --endpoint $Endpoint{$opt_region} get-user --application-name $opt_application --client-name $opt_tenant\_$opt_environment --user-name $opt_tenant\_$opt_environment\_ftp | jq -r ".data.sftp_enabled"`;
#    if ("$opt_tenant\_$opt_environment\_ftp" ne $Reply){
#        printf "\nThe user: $opt_tenant\_$opt_environment\_ftp\ndoes not exist.\n";
#        exit 1;
#    }
#    if ($opt_sshkey){
#        $Reply=`ftscli --profile $opt_stsprofile --region $AWSRegion{$opt_region} --endpoint $Endpoint{$opt_region} put-user --application-name $opt_application --client-name $opt_tenant\_$opt_environment --user-name $opt_tenant\_$opt_environment\_ftp --password $opt_password --ip-restriction SortOrder=0,StartIP=0.0.0.0,StopIP=255.255.255.255,Type=A --sftp-enabled --ssh-key "$opt_sshkey"`;
#    }
#    else {
#        $Reply=`ftscli --profile $opt_stsprofile --region $AWSRegion{$opt_region} --endpoint $Endpoint{$opt_region} put-user --application-name $opt_application --client-name $opt_tenant\_$opt_environment --user-name $opt_tenant\_$opt_environment\_ftp --password $opt_password --ip-restriction SortOrder=0,StartIP=0.0.0.0,StopIP=255.255.255.255,Type=A --sftp-enabled`;
#    }
#    printf "$Reply\n";
#    exit 0;
#}
