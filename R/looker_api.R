# init should be in the following format, all fields are mandatory:

# [Looker]
# api_version=3.1
# base_url=https://[YOUR_ORG].looker.com:19999
# client_id=[YOUR_CLIENT_ID]
# client_secret=[YOUR_CLIENT_SECRET]


set_access_token = function(init) {
    init_txt = configr::read.config(init)
    api_version = as.character(init_txt$Looker$api_version)
    base_url = as.character(init_txt$Looker$base_url)
    client_id = as.character(init_txt$Looker$client_id)
    client_secret = as.character(init_txt$Looker$client_secret)

    if (api_version == '') stop(sprintf('variable %s missing from file %s', 'api_version', init))
    if (base_url == '') stop(sprintf('variable %s missing from file %s', 'base_url', init))
    if (client_id == '') stop(sprintf('variable %s missing from file %s', 'client_id', init))
    if (client_secret == '') stop(sprintf('variable %s missing from file %s', 'client_secret', init))
    Sys.setenv('LOOKER_API_PATH' = sprintf('%s/api/%s',
        base_url,
        api_version
        ))
    query = sprintf(
        '%s/api/%s/login?client_id=%s&client_secret=%s',
        base_url,
        api_version,
        client_id,
        client_secret
    )
    response = httr::POST(query)
    status_code = httr::status_code(response)
    if (status_code != 200) {
        stop(sprintf('status code %s', status_code))
    } else {
        Sys.setenv('LOOKER_ACCESS_TOKEN_EXPIRY' = as.numeric(Sys.time()) + httr::content(response)$expires_in)
        Sys.setenv('LOOKER_ACCESS_TOKEN' = httr::content(response)$access_token)
    }
}

get_look = function(look_id, limit=500, result.format = 'json', 
    json.to.data.table = F) {
    if (
        Sys.getenv('LOOKER_ACCESS_TOKEN') == '' | 
        as.numeric(Sys.time()) >= Sys.getenv('LOOKER_ACCESS_TOKEN_EXPIRY') |
        Sys.getenv('LOOKER_API_PATH') == ''
    ) stop(sprintf('Run set_access_token() first to establish authentication.'))
    query = sprintf(
        '%s/looks/%s/run/%s?limit=%s&access_token=%s',
        Sys.getenv('LOOKER_API_PATH'),
        look_id,
        result.format,
        as.character(limit),
        Sys.getenv('LOOKER_ACCESS_TOKEN')
    )
    cat('Retrieving Look...\n')
    response = httr::GET(query)
    status_code = httr::status_code(response)
    if (status_code != 200) {
        stop(sprintf('status code %s', status_code))
    } else {
        if (result.format == 'json' & json.to.data.table) {
            rbindlist(httr::content(response), fill = T)
        } else {
            httr::content(response)
        } 
    }
}
