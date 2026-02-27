# Phase 3: Unstructured Data

Upload quarterly earnings report PDFs to the SFTP server and deploy the Openflow SFTP pipeline to land them in a Snowflake stage.

## 3.1 Set Up the SFTP User

Before uploading files, create an S3 bucket, generate SSH keys, and add a user to the SFTP server. This only needs to be done once.

> **Cortex Code CLI**
>
> ```
> Read the README at terraform/sftp/README.md for the "Adding Users"
> instructions. Create the S3 bucket, generate SSH keys, and create the
> SFTP user using the Terraform outputs.
> ```

For manual steps, see the "Adding Users" section in [terraform/sftp/README.md](../../terraform/sftp/README.md).

## 3.2 Upload Earnings Reports to SFTP

Upload the PDF earnings reports for MSFT and TSLA to the SFTP server:

> **Cortex Code CLI**
>
> ```
> Run the upload_reports.sh script in nasdaq-demo/ to upload all
> earnings report PDFs from data/reports/ to the SFTP server.
> ```

Manual steps:

```bash
cd nasdaq-demo
chmod +x upload_reports.sh
./upload_reports.sh
```

To upload reports for a single company:

```bash
./upload_reports.sh data/reports/TSLA
```

**Checkpoint** -- verify the files are on the SFTP server:

```bash
cd ../terraform/sftp
echo "ls -la" | sftp -i aws_sftp_key openflow-user@$(terraform output -raw server_endpoint)
```

## 3.3 Deploy the Openflow SFTP Pipeline

Deploy the SFTP pipeline to Openflow so it picks up the PDFs and writes them to a Snowflake internal stage.

> **Cortex Code CLI**
>
> ```
> Check your skills for Openflow. Deploy the SFTP pipeline flow defined
> in nasdaq-demo/openflow/default/nasdaq-demo-sftp.json to the Openflow
> runtime. The pipeline should list and fetch PDF files from my SFTP
> server and write them to the EARNINGS_REPORTS_STAGE stage in the
> NASDAQ_DEMO database.
> ```

For details on the flow definition, see [openflow/default/nasdaq-demo-sftp.json](../openflow/default/nasdaq-demo-sftp.json).

## 3.4 Checkpoint

Verify the earnings reports have landed in the Snowflake stage:

```sql
ALTER STAGE NASDAQ_DEMO.PUBLIC.EARNINGS_REPORTS_STAGE REFRESH;

SELECT
    RELATIVE_PATH,
    SIZE,
    LAST_MODIFIED
FROM DIRECTORY(@NASDAQ_DEMO.PUBLIC.EARNINGS_REPORTS_STAGE)
ORDER BY RELATIVE_PATH;
```

You should see 15 PDF files (8 for MSFT, 7 for TSLA).
