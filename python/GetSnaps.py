#!/usr/bin/python
# -*- coding: utf-8 -*-
import boto
import boto.ec2
import sys
from tabulate import tabulate

# test path for simple json and tabulate /usr/local/lib/python2.7/site-packages

#Regions = ["eu-west-1","ap-southeast-1","ap-southeast-2","eu-central-1","ap-northeast-2","ap-northeast-1","us-east-1","sa-east-1","us-west-1","us-west-2"]
#Accounts = ["devops-dev","auto","sb","int","prd-ncr","prd","pprd1"]
Accounts = ["pprd1","prd-ncr"]
Regions = ["eu-west-1","us-east-1"]

#define variables
AccountsOut = ["Account"]
RegionsOut = ["Region"]
NumSnapsOut = ["Number Of Snaps"]

#define function to get snap count
def get_snap_count(Account,Region):
    conn = boto.ec2.connection.EC2Connection(region=boto.ec2.get_region(Region),profile_name=Account)
    snaps = conn.get_all_snapshots()
    strsnaps = str(snaps)
    arrSnaps = strsnaps.split(', ')
    numsnaps = len(arrSnaps)
    AccountsOut.append(Account)
    RegionsOut.append(Region)
    NumSnapsOut.append(numsnaps)

for Account in Accounts:
    for Region in Regions:
        get_snap_count(Account,Region)

print tabulate(zip(AccountsOut,RegionsOut,NumSnapsOut),headers="firstrow")

