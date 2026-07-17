# helper-fakefit.R
fake_fit <- function(objf = 100,
                     parFixedDf = data.frame(
                       Estimate = c(0.5, 1.0, 3.4),
                       SE = c(0.05, 0.1, 0.2),
                       `%RSE` = c(10, 10, 6),
                       row.names = c("lka", "lcl", "lvc"),
                       check.names = FALSE),
                     omega = matrix(c(0.09, 0, 0, 0.04), 2, 2,
                                    dimnames = list(c("eta.cl","eta.vc"),
                                                    c("eta.cl","eta.vc"))),
                     sigma = c(propSd = 0.5),
                     shrink = data.frame(
                       eta.cl = 12, eta.vc = 20, row.names = "IWRES(%)"),
                     covMethod = "r,s",
                     message = "") {
  structure(
    list(objf = objf, parFixedDf = parFixedDf, omega = omega,
         sigma = sigma, shrink = shrink, covMethod = covMethod,
         message = message),
    class = "fakeNlmixrFit")
}

`$.fakeNlmixrFit` <- function(x, name) x[[name]]
