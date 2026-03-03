# Phase 3: Unstructured Data

Upload quarterly earnings report PDFs to the SFTP server and deploy the Openflow SFTP pipeline to land them in a Snowflake stage.

## 3.1 Upload Earnings Reports to SFTP

Upload the PDF earnings reports to the SFTP server:

> **Cortex Code CLI**
>
> ```
> Read the upload_reports.sh script in nasdaq-demo/sftp/. It uses the
> SSH key (aws_sftp_key) and server endpoint from terraform/sftp/.
> Verify the key and Terraform outputs exist. Before uploading, list
> the files on the SFTP server -- if earnings reports already exist,
> ask me whether to keep them or delete and replace them with the
> reports from data/reports/. Then run the script to upload. After
> uploading, list the files on the SFTP server again and confirm all
> reports from data/reports/ are present.
> ```

Manual steps:

```bash
cd nasdaq-demo/sftp
chmod +x upload_reports.sh
./upload_reports.sh
```

To upload reports for a single company:

```bash
./upload_reports.sh ../data/reports/TSLA
```

**Checkpoint** -- verify the files are on the SFTP server:

```bash
cd ../terraform/sftp
echo "ls -la" | sftp -i aws_sftp_key openflow-user@$(terraform output -raw server_endpoint)
```

## 3.2 Configure Network Access

The Openflow runtime needs network access to reach the SFTP server.

> **Cortex Code CLI**
>
> ```
> Using the terraform/sftp/ outputs, get the SFTP server endpoint
> and configure the following:
>
> 1. Create a network rule with the SFTP server endpoint (port 22)
> 2. Create or update an external access integration (EAI) that
>    references the network rule
> 3. Grant USAGE on the EAI to OPENFLOW_RUNTIME_ROLE
> 4. Tell me to attach the EAI to the Openflow runtime via the
>    Control Plane UI and wait for my confirmation before proceeding
> ```

For manual reference:

```sql
USE ROLE ACCOUNTADMIN;
USE DATABASE NASDAQ_DEMO;

CREATE OR REPLACE NETWORK RULE SFTP_NETWORK_RULE
    MODE = EGRESS
    TYPE = HOST_PORT
    VALUE_LIST = ('<sftp-server-endpoint>:22');

CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION SFTP_EAI
    ALLOWED_NETWORK_RULES = (SFTP_NETWORK_RULE)
    ENABLED = TRUE;

GRANT USAGE ON INTEGRATION SFTP_EAI TO ROLE OPENFLOW_RUNTIME_ROLE;
```

Replace `<sftp-server-endpoint>` with your SFTP server endpoint from `terraform output`.

## 3.3 Deploy the Openflow SFTP Pipeline

Deploy the SFTP pipeline to Openflow so it picks up the PDFs and writes them to a Snowflake internal stage.

> **Cortex Code CLI**
>
> ```
> Check your skills for Openflow. Install or upgrade the NiPyApi
> Python library using uv and update pyproject.toml. When using
> nipyapi, check function signatures with help() before calling
> them -- the API has non-obvious parameter names. Reference the
> Openflow skill documentation for common patterns.
>
> Verify that the Openflow runtime exists -- it should have "nasdaq"
> in the name. The Openflow runtime role is OPENFLOW_RUNTIME_ROLE.
>
> Do not modify or remove any existing connectors, process groups,
> or parameter contexts in the runtime. Deploy the SFTP pipeline
> flow defined in nasdaq-demo/openflow/default/nasdaq-demo-sftp.json
> to the runtime with its own new parameter context.
>
> SFTP configuration (from terraform/sftp/ outputs):
> - Hostname: SFTP server endpoint
> - Username: the terraform-created SFTP user
> - Private Key: upload the SSH key from terraform/sftp/aws_sftp_key
>   as a NEW asset (do not reuse existing assets). Set the Private
>   Key parameter to reference this newly uploaded asset.
>
> Destination: EARNINGS_REPORTS_STAGE in NASDAQ_DEMO.PUBLIC
> Auth: SNOWFLAKE_SESSION_TOKEN (leave account identifier, username,
> and private key empty -- SPCS resolves these from the session)
>
> Before starting the flow, verify:
> 1. The parameter context has the correct hostname from terraform
>    outputs
> 2. The Private Key parameter references the newly uploaded asset
> 3. The EAI is attached to the runtime (confirm with me)
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

You should see the uploaded PDF files listed in the stage. The exact count depends on the stocks and quarters you chose -- for example, Tesla (TSLA) earnings reports from the `data/reports/` directory.
