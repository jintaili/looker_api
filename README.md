# looker_api

This is simply two functions designed to do one thing: running and downloading a look on Looker. In order to do this, create a text config file with the following fields, all of which are mandatory.
```
[Looker]
api_version=3.1
base_url=https://[YOUR_ORG].looker.com:19999
client_id=[YOUR_CLIENT_ID]
client_secret=[YOUR_CLIENT_SECRET]
```
Save this file, for example, as 'looker.init'. In order to access a look, such as one with look ID '123', run the following code.
```
set_access_token('looker.init')
get_look(
  look_id = 123, 
  limit = 500,
  result.format = 'json',
  json.to.data.table = FALSE
  )
```
To retrieve the results without row limit, set argument `limit = -1`.
