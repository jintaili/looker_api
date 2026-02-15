# looker_api

`looker_api` provides two focused helpers to authenticate with the Looker API and run/download a Look.

## Config file

Create an init file (for example `looker.init`) with the following required fields:

```ini
[Looker]
api_version=3.1
base_url=https://[YOUR_ORG].looker.com:19999
client_id=[YOUR_CLIENT_ID]
client_secret=[YOUR_CLIENT_SECRET]
```

## Usage

```r
source("R/looker_api.R")

set_access_token("looker.init")

results <- get_look(
  look_id = 123,
  limit = 500,
  result.format = "json",
  json.to.data.table = FALSE
)
```

To retrieve results without a row limit, set `limit = -1`.

To return JSON results as a `data.table`, set `json.to.data.table = TRUE`.

```r
dt <- get_look(
  look_id = 123,
  limit = -1,
  result.format = "json",
  json.to.data.table = TRUE
)
```

## Notes

- Public function names and usage stay the same: `set_access_token()` and `get_look()`.
- Tokens are cached in environment variables and refreshed automatically if possible.
- Network calls now include timeouts, retries, and improved error messages.
