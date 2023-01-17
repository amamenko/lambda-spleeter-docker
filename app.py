from spleeter.separator import Separator
from urllib.parse import unquote_plus
import lambdawarmer
import json
import os
import boto3

os.environ["NUMBA_CACHE_DIR"] = "/tmp/"

s3 = boto3.client("s3")

@lambdawarmer.warmer
def handler(event, context):
    print("Lambda execution starting!")
    is_warmer = event.get("warmer")
    if is_warmer:
        print("Lambda function warmed by Cloudwatch rule!")
        return true
    else:
        try:
            # Input
            input_file_obj = event["Records"][0]
            input_bucket_name = str(input_file_obj["s3"]["bucket"]["name"])
            input_file = unquote_plus(str(input_file_obj["s3"]["object"]["key"]))
            # Downloading file to /tmp directory within Lambda
            input_lambda_file_path = f"/tmp/{input_file}"

            # Output
            output_bucket_name = os.environ.get("OUTPUT_BUCKET") or ""
            output_bucket_location = s3.get_bucket_location(Bucket=output_bucket_name)
            output_destination = os.environ.get("OUTPUT_DESTINATION") or "audio_output"
            output_destination_file_path = f"/tmp/{output_destination}"

            # Downloading file
            s3.download_file(input_bucket_name, input_file, input_lambda_file_path)

            print(f"Downloaded input file to {input_lambda_file_path}, splitting now...")

            os.chdir("/tmp")
            audio_codec = os.environ.get("OUTPUT_AUDIO_CODEC") or "mp3"
            filename_format = os.environ.get("OUTPUT_FILENAME_FORMAT") or "{instrument}.{codec}"
            separator = Separator("spleeter:2stems", multiprocess=False)
            separator.separate_to_file(input_file, output_destination, filename_format=filename_format, codec=audio_codec, synchronous=True)

            output_url_list = []

            def uploadDirectory(path,bucketname):
                for root,dirs,files in os.walk(path):
                    for file in files:
                        # Uploading stem files
                        file_url = "https://{0}.amazonaws.com/{1}/{2}".format(
                            f"s3-{output_bucket_location['LocationConstraint']}" if output_bucket_location["LocationConstraint"] else "s3",
                            output_bucket_name,
                            file)
                        file_path = os.path.join(root,file)
                        print(f"Now uploading file {file_path} to output S3")
                        s3.upload_file(file_path, bucketname, file)
                        output_url_list.append(file_url)
                        print(f"Successfully uploaded file to {file_url} in output S3")

            uploadDirectory(output_destination_file_path, output_bucket_name)
            print("Lambda execution completed!")
            return {"statusCode": 200, "body": json.dumps(output_url_list)}
        except Exception as err:
            print(err)
            raise err