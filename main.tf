data "aws_caller_identity" "current" {}

resource "aws_cloudtrail" "snifpolgen" {
  name                          = var.name
  s3_bucket_name                = aws_s3_bucket.snifpolgen.bucket
  s3_key_prefix                 = ""
  is_multi_region_trail         = false
  include_global_service_events = false
  is_organization_trail         = false
  enable_log_file_validation    = false
}

resource "aws_s3_bucket" "snifpolgen" {
  bucket = format("iam-sniffer-%s", data.aws_caller_identity.current.account_id)
  policy = data.aws_iam_policy_document.snifpolgen.json
}

data "aws_iam_policy_document" "snifpolgen" {
  statement {
    effect  = "Allow"
    actions = ["s3:GetBucketAcl"]
    principals {
      identifiers = ["cloudtrail.amazonaws.com"]
      type        = "Service"
    }
    resources = [format("arn:aws:s3:::iam-sniffer-%s", data.aws_caller_identity.current.account_id)]
  }

  statement {
    effect  = "Allow"
    actions = ["s3:PutObject"]
    principals {
      identifiers = ["cloudtrail.amazonaws.com"]
      type        = "Service"
    }
    resources = [format("arn:aws:s3:::iam-sniffer-%s/*", data.aws_caller_identity.current.account_id)]
  }
}

resource "aws_athena_database" "snifpolgen" {
  name   = var.name
  bucket = aws_s3_bucket.snifpolgen.bucket
}

resource "aws_athena_named_query" "snifpolgen" {
  name      = format("%s_cloudtrail_logs_create_table", var.name)
  workgroup = var.workgroup
  database  = aws_athena_database.snifpolgen.name
  query     = <<EOF
CREATE EXTERNAL TABLE snifpolgen_logs (
eventversion STRING,
useridentity STRUCT<
               type:STRING,
               principalid:STRING,
               arn:STRING,
               accountid:STRING,
               invokedby:STRING,
               accesskeyid:STRING,
               userName:STRING,
sessioncontext:STRUCT<
attributes:STRUCT<
               mfaauthenticated:STRING,
               creationdate:STRING>,
sessionissuer:STRUCT<
               type:STRING,
               principalId:STRING,
               arn:STRING,
               accountId:STRING,
               userName:STRING>>>,
eventtime STRING,
eventsource STRING,
eventname STRING,
awsregion STRING,
sourceipaddress STRING,
useragent STRING,
errorcode STRING,
errormessage STRING,
requestparameters STRING,
responseelements STRING,
additionaleventdata STRING,
requestid STRING,
eventid STRING,
resources ARRAY<STRUCT<
               ARN:STRING,
               accountId:STRING,
               type:STRING>>,
eventtype STRING,
apiversion STRING,
readonly STRING,
recipientaccountid STRING,
serviceeventdetails STRING,
sharedeventid STRING,
vpcendpointid STRING
)
ROW FORMAT SERDE 'com.amazon.emr.hive.serde.CloudTrailSerde'
STORED AS INPUTFORMAT 'com.amazon.emr.cloudtrail.CloudTrailInputFormat'
OUTPUTFORMAT 'org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat'
LOCATION 's3://iam-sniffer-${data.aws_caller_identity.current.account_id}/AWSLogs/${data.aws_caller_identity.current.account_id}/';
EOF
}
