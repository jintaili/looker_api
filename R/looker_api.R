# init should be in the following format; all fields are mandatory:
#
# [Looker]
# api_version=3.1
# base_url=https://[YOUR_ORG].looker.com:19999
# client_id=[YOUR_CLIENT_ID]
# client_secret=[YOUR_CLIENT_SECRET]

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0) y else x
}

read_looker_config <- function(init) {
  if (missing(init) || !nzchar(as.character(init))) {
    stop("Please provide a config file path.", call. = FALSE)
  }

  if (!file.exists(init)) {
    stop(sprintf("Config file does not exist: %s", init), call. = FALSE)
  }

  init_txt <- configr::read.config(init)
  looker_cfg <- init_txt$Looker

  if (is.null(looker_cfg)) {
    stop(sprintf("Missing [Looker] section in %s", init), call. = FALSE)
  }

  required_fields <- c("api_version", "base_url", "client_id", "client_secret")
  missing_fields <- required_fields[vapply(required_fields, function(field) {
    value <- looker_cfg[[field]]
    is.null(value) || !nzchar(trimws(as.character(value)))
  }, logical(1))]

  if (length(missing_fields) > 0) {
    stop(
      sprintf(
        "Missing required field(s) in %s: %s",
        init,
        paste(missing_fields, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  list(
    api_version = trimws(as.character(looker_cfg$api_version)),
    base_url = trimws(as.character(looker_cfg$base_url)),
    client_id = trimws(as.character(looker_cfg$client_id)),
    client_secret = trimws(as.character(looker_cfg$client_secret))
  )
}

build_api_path <- function(base_url, api_version) {
  sprintf("%s/api/%s", sub("/+$", "", base_url), api_version)
}

has_valid_access_token <- function() {
  token <- Sys.getenv("LOOKER_ACCESS_TOKEN", "")
  api_path <- Sys.getenv("LOOKER_API_PATH", "")
  expiry_raw <- Sys.getenv("LOOKER_ACCESS_TOKEN_EXPIRY", "")
  expiry <- suppressWarnings(as.numeric(expiry_raw))

  nzchar(token) && nzchar(api_path) && is.finite(expiry) && as.numeric(Sys.time()) < expiry
}

set_access_token <- function(init) {
  cfg <- read_looker_config(init)
  api_path <- build_api_path(cfg$base_url, cfg$api_version)

  request <- httr2::request(sprintf("%s/login", api_path)) |>
    httr2::req_method("POST") |>
    httr2::req_url_query(
      client_id = cfg$client_id,
      client_secret = cfg$client_secret
    ) |>
    httr2::req_timeout(30) |>
    httr2::req_error(is_error = function(resp) FALSE)

  response <- httr2::req_perform(request)
  status_code <- httr2::resp_status(response)

  if (status_code != 200) {
    body <- tryCatch(httr2::resp_body_string(response), error = function(e) "")
    detail <- if (nzchar(body)) sprintf(": %s", body) else ""
    stop(sprintf("status code %s%s", status_code, detail), call. = FALSE)
  }

  payload <- httr2::resp_body_json(response, simplifyVector = TRUE)
  access_token <- as.character(payload$access_token %||% "")
  expires_in <- suppressWarnings(as.numeric(payload$expires_in %||% 0))

  if (!nzchar(access_token)) {
    stop("Looker login succeeded but no access_token was returned.", call. = FALSE)
  }

  expiry <- as.numeric(Sys.time()) + max(expires_in - 30, 0)

  Sys.setenv("LOOKER_API_PATH" = api_path)
  Sys.setenv("LOOKER_ACCESS_TOKEN" = access_token)
  Sys.setenv("LOOKER_ACCESS_TOKEN_EXPIRY" = as.character(expiry))
  Sys.setenv("LOOKER_INIT_FILE" = normalizePath(init, winslash = "/", mustWork = FALSE))

  invisible(access_token)
}

refresh_access_token_if_possible <- function() {
  if (has_valid_access_token()) {
    return(invisible(TRUE))
  }

  init <- Sys.getenv("LOOKER_INIT_FILE", "")
  if (nzchar(init) && file.exists(init)) {
    set_access_token(init)
    return(invisible(TRUE))
  }

  invisible(FALSE)
}

get_look <- function(look_id, limit = 500, result.format = "json", json.to.data.table = FALSE) {
  if (!nzchar(as.character(look_id))) {
    stop("Please provide a valid look_id.", call. = FALSE)
  }

  if (!refresh_access_token_if_possible()) {
    stop(
      "Run set_access_token() first to establish authentication.",
      call. = FALSE
    )
  }

  query <- sprintf(
    "%s/looks/%s/run/%s",
    Sys.getenv("LOOKER_API_PATH"),
    as.character(look_id),
    as.character(result.format)
  )

  request <- httr2::request(query) |>
    httr2::req_url_query(
      limit = as.character(limit),
      access_token = Sys.getenv("LOOKER_ACCESS_TOKEN")
    ) |>
    httr2::req_timeout(60) |>
    httr2::req_retry(max_tries = 3) |>
    httr2::req_error(is_error = function(resp) FALSE)

  cat("Retrieving Look...\n")
  response <- httr2::req_perform(request)
  status_code <- httr2::resp_status(response)

  if (status_code != 200) {
    body <- tryCatch(httr2::resp_body_string(response), error = function(e) "")
    detail <- if (nzchar(body)) sprintf(": %s", body) else ""
    stop(sprintf("status code %s%s", status_code, detail), call. = FALSE)
  }

  if (identical(result.format, "json")) {
    payload <- httr2::resp_body_json(response, simplifyVector = FALSE)
    if (isTRUE(json.to.data.table)) {
      if (!length(payload)) return(data.table::data.table())
      return(data.table::rbindlist(payload, fill = TRUE))
    }
    return(payload)
  }

  httr2::resp_body_string(response)
}
