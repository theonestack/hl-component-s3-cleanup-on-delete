CloudFormation do
  IAM_Role(:CleanBucketOnDeleteRole) {
    AssumeRolePolicyDocument({
      Version: '2012-10-17',
      Statement: [
        {
          Effect: 'Allow',
          Principal: {
            Service: [
              'lambda.amazonaws.com'
            ]
          },
          Action: 'sts:AssumeRole'
        }
      ]
    })
    Path '/'
    Policies([
      {
        PolicyName: 's3-bucket-cleanup',
        PolicyDocument: {
          Version: '2012-10-17',
          Statement: [
            {
              Effect: 'Allow',
              Action: [
                's3:DeleteObject'
              ],
              Resource: FnSplit(',', 
                FnJoin('/*,arn:aws:s3:::',
                  FnSplit(',', 
                    FnJoin('', ['arn:aws:s3:::', Ref(:Buckets), '/*'])
                  )
                )
              )
            },
            {
              Effect: 'Allow',
              Action: [
                's3:ListBucket'
              ],
              Resource: FnSplit(',', 
                FnJoin(',arn:aws:s3:::',
                  FnSplit(',', 
                    FnJoin('', ['arn:aws:s3:::', Ref(:Buckets)])
                  )
                )
              )
            },
            {
              Effect: 'Allow',
              Action: [
                'logs:CreateLogGroup',
                'logs:CreateLogStream',
                'logs:PutLogEvents'
              ],
              Resource: '*'
            }
          ]
        }
      }
    ])
  }

  Logs_LogGroup(:CleanBucketOnDeleteCustomResourceLogGroup) {
    LogGroupName FnSub("/aws/lambda/${CleanBucketOnDeleteCustomResourceFunction}")
    RetentionInDays 30
  }

  Lambda_Function(:CleanBucketOnDeleteCustomResourceFunction) {
    Code({
      ZipFile: <<~CODE
        import cfnresponse
        import boto3
        import logging

        logger = logging.getLogger(__name__)
        logger.setLevel(logging.INFO)

        def lambda_handler(event, context):
          try:
            logger.info(event)

            # Globals
            responseData = {}
            bucket_names = event['ResourceProperties']['BucketNames']

            if event['RequestType'] == 'Create':
              responseData['Message'] = "Resource creation successful!"

            elif event['RequestType'] == 'Update':
              responseData['Message'] = "Resource update successful!"

            elif event['RequestType'] == 'Delete':
              for bucket_name in bucket_names:
                # Need to empty the S3 bucket before it is deleted
                s3 = boto3.resource('s3')
                bucket = s3.Bucket(bucket_name)
                logger.info(f"deleting all objects from {bucket_name}")
                bucket.objects.all().delete()
              responseData['Message'] = "Resource deletion successful!"
            
            cfnresponse.send(event, context, cfnresponse.SUCCESS, responseData)
          except Exception as e:
            logger.error('failed to cleanup bucket', exc_info=True)
            cfnresponse.send(event, context, cfnresponse.FAILED, {})
      CODE
    })
    Handler "index.lambda_handler"
    Runtime "python3.7"
    Role FnGetAtt(:CleanBucketOnDeleteRole, :Arn)
    Timeout 60
  }

  Resource(:CleanUpBucketOnDelete) {
    Type "Custom::CleanUpBucket"
    DependsOn :CleanBucketOnDeleteCustomResourceLogGroup
    Property 'ServiceToken', FnGetAtt(:CleanBucketOnDeleteCustomResourceFunction, :Arn)
    Property 'BucketNames', FnSplit(',', Ref(:Buckets))
  }
end
