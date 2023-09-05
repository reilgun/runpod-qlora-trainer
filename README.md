# Runpod.io QLoRA Trainer
This container lets you quickly and easily train a QLoRA for an LLM on runpod.io using https://github.com/LagPixelLOL/qlora which supports flash attention.
It will shut down your pod automatically after the training has completed. It won't delete your pod, though.
It will fetch your own training script (see `scripts/run_flash.sh` as an example) with your parameters from a URL, as well as your own dataset for training.
Optionally, it can upload the full output with all checkpoints to a specified S3 Bucket of your choice using your credentials, supporting third party S3 compatibles as well.

## Getting started
You only need to set two environment variables
`DATASET` should be set to a URL from which the container will download your dataset. It will be saved to `/workspace/dataset.jsonl`. This value is not necessary if you're specifying a named dataset from huggingface in your lora script, which will be downloaded automatically by qlora.py.

`LORA_SCRIPT` is the URL from which your training script will be downloaded. This is mandatory. Refer to `scripts/run_flash.sh` for an example. It should call `qlora.py` or `flash_qlora.py` depending on whether you want to use Flash Attention, and pass all the training arguments. Make sure to specify an output folder under `/workspace/output/` as the ouput in the script like in the example file.
You can just use `scripts/run_flash.sh` as a base and edit the parameters you need to change.

The container will download your dataset and script, run the script, then shut down.

### S3 Bucket support
Optionally, you can specify S3 credentials and a bucket to upload the training results to. In this case, after training has completed, the script will zip all your checkpoints, and upload the file to the bucket under a filename like `output_2023-09-05-12-30-45.zip`

In order to use S3, you need to set the following environment variables:

`AWS_ACCESS_KEY_ID`
`AWS_SECRET_ACCESS_KEY`
`S3_BUCKET`

S3 bucket should be the bucket *name* and nothing else, for example: `train-results` and *not* `s3://train-results` nor `train-results.s3.amazonaws.com`

If your S3 Bucket is **not** on Amazon Web Services, you also need to specify `S3_ENDPOINT_URL` as appropriate for your provider.

#### Dataset from S3 Bucket
If AWS credentials are provided, and your `DATASET` environment variable is set to a value starting with `s3://`, it will attempt to download your dataset from the bucket using your credentials.