#!/usr/bin/python
# -*- coding: utf-8 -*-
import boto3
import botocore
import datetime

Regions = [
    "eu-west-1",
    "ap-southeast-1",
    "ap-southeast-2",
    "eu-central-1",
    "ap-northeast-2",
    "ap-northeast-1",
    "us-east-1",
    "sa-east-1",
    "us-west-1",
    "us-west-2",
]
# Accounts = ["devops-dev","auto","sb","int","prd-ncr","prd"]
Accounts = ["devops-dev", "auto"]
Keys = []


def get_files(Account, Region):
    # build a session
    Session = boto3.session.Session(region_name=Region, profile_name=Account)
    s3 = Session.resource("s3")

    # build bucket name
    BucketName = "infor-{}-dbasecure-{}".format(Account, Region)
    Bucket = s3.Bucket(BucketName)
    Exists = True

    # check for bucket
    try:
        s3.meta.client.head_bucket(Bucket=BucketName)
    except botocore.exceptions.ClientError as e:
        # If a client error is thrown, then check that it was a 404 error.
        # If it was a 404 error, then the bucket does not exist.
        error_code = int(e.response["Error"]["Code"])
        if error_code == 404:
            Exists = False
    # if the bucket exists add it to the list of buckets
    if Exists == True:
        for obj in Bucket.objects.all():
            Key = obj.key
            if Key.startswith("restoretesting"):
                Now = (datetime.datetime.now()).strftime("%Y%m%d-%H%M%S")
                LocalFile = "/tmp/{}_temp.json".format(Now)
                s3.meta.client.download_file(BucketName, Key, LocalFile)


for Account in Accounts:
    for Region in Regions:
        get_files(Account, Region)

