context("slack")

test_that("slack payload is correct", {
  server_url <- "https://example.com"
  server_is_primary <- FALSE
  server_name <- "myserver"
  dat <- list(elapsed = 10,
              git = NULL,
              id = "20181213-123456-fedcba98",
              name = "example")
  d <- slack_data(dat, server_name, server_url, server_is_primary)

  report_url <- sprintf("%s/reports/%s/%s/", server_url, dat$name, dat$id)
  expect_equal(
    d,
    list(
      username = "orderly",
      icon_emoji = ":ambulance:",
      attachments = list(list(
        title = "Ran report 'example'",
        text = "on server *myserver* in 10 secs",
        color = "warning",
        fallback = sprintf("Ran '%s' as '%s'; view at %s",
                           dat$name, dat$id, report_url),
        fields = list(list(
          title = "id", value = sprintf("`%s`", dat$id), short = TRUE)),
        actions = list(list(
          type = "button", text = ":clipboard: View report",
          style = "primary", url = report_url))))))

  skip_if_no_internet()
  slack_url <- "https://httpbin.org/post"
  r <- do_slack_post_success(slack_url, d)

  str <- httr::content(r, "text", encoding = "UTF-8")
  cmp <- jsonlite::fromJSON(str, FALSE)$json

  expect_setequal(names(d), names(cmp))
  expect_equal(d$username, cmp$username)
  expect_equal(d$icon_emoji, cmp$icon_emoji)
  expect_setequal(names(d$attachments[[1]]), names(cmp$attachments[[1]]))
})


test_that("git information is collected correctly", {
  server_url <- "https://example.com"
  server_is_primary <- FALSE
  server_name <- "myserver"
  dat <- list(elapsed = 10,
              git = NULL,
              id = "20181213-123456-fedcba98",
              name = "example")
  d <- slack_data(dat, server_name, server_url, server_is_primary)

  expect_equal(length(d$attachments[[1]]$fields), 1L)

  dat <- list(elapsed = 10,
              git = list(branch = "master", sha_short = "abcdefg"),
              id = "20181213-123456-fedcba98",
              name = "example")
  d <- slack_data(dat, server_name, server_url, server_is_primary)
  expect_equal(length(d$attachments[[1]]$fields), 2L)
  expect_equal(d$attachments[[1]]$fields[[2L]],
               list(title = "git", value = "master@abcdefg", short = TRUE))

  dat <- list(elapsed = 10,
              git = list(branch = "master", sha_short = "abcdefg",
                         github_url = "https://github.com/vimc/repo"),
              id = "20181213-123456-fedcba98",
              name = "example")
  d <- slack_data(dat, server_name, server_url, server_is_primary)
  expect_equal(
    d$attachments[[1]]$fields[[2]]$value,
    paste0("<https://github.com/vimc/repo/tree/master|master>@",
           "<https://github.com/vimc/repo/tree/abcdefg|abcdefg>"))
})


test_that("primary server changes colour", {
  server_url <- "https://example.com"
  server_is_primary <- FALSE
  server_name <- "myserver"
  dat <- list(elapsed = 10,
              git = NULL,
              id = "20181213-123456-fedcba98",
              name = "example")
  d1 <- slack_data(dat, server_name, server_url, TRUE)
  d2 <- slack_data(dat, server_name, server_url, FALSE)
  expect_equal(d1$attachments[[1]]$color, "good")
  expect_equal(d2$attachments[[1]]$color, "warning")
  d2$attachments[[1]]$color <- d1$attachments[[1]]$color
  expect_identical(d1, d2)
})


test_that("sending messages is not a failure", {
  skip_if_no_internet()

  server_url <- "https://example.com"
  server_is_primary <- FALSE
  server_name <- "myserver"
  dat <- list(elapsed = 10,
              git = NULL,
              id = "20181213-123456-fedcba98",
              name = "example")
  d <- slack_data(dat, server_name, server_url, server_is_primary)

  slack_url <- "https://httpbin.org/status/403"
  expect_message(r <- do_slack_post_success(slack_url, d),
                 "NOTE: running slack hook failed")
})


test_that("main interface", {
  skip_if_no_internet()
  dat <- list(elapsed = 10,
              git = NULL,
              id = "20181213-123456-fedcba98",
              name = "example")
  config <- list(api_server_identity = "myserver",
                 api_server = list(
                   myserver = list(
                     slack_url = "https://httpbin.org/post",
                     name = "myserver",
                     url_www = "https://example.com")))
  r <- slack_post_success(dat, config)
  expect_equal(r$status_code, 200L)
})