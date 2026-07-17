# test-versiongate.R
test_that("version gate flags mismatches and missing packages", {
  base <- data.frame(package = c("A","B","C"),
                     version = c("1.0","2.0","3.0"), stringsAsFactors = FALSE)
  installed <- c(A = "1.0", B = "2.1")  # B differs, C missing
  g <- qual_version_gate(base, installed = installed)
  expect_false(g$pass)
  expect_true(g$detail$pass[g$detail$package == "A"])
  expect_false(g$detail$pass[g$detail$package == "B"])
  expect_equal(g$detail$status[g$detail$package == "C"], "missing")
})

test_that("all matching versions pass", {
  base <- data.frame(package = "A", version = "1.0", stringsAsFactors = FALSE)
  expect_true(qual_version_gate(base, installed = c(A = "1.0"))$pass)
})
