#' Compute the primary event censored CDF for delays
#'
#' This function computes the primary event censored cumulative distribution
#' function (CDF) for a given set of quantiles. It adjusts the CDF of the
#' primary event distribution by accounting for the delay distribution and
#' potential truncation at a maximum delay (D). The function allows for
#' custom primary event distributions and delay distributions.
#'
#' @param q Vector of quantiles
#'
#' @param pdist Distribution function (CDF)
#'
#' @param pwindow Primary event window
#'
#' @param D Maximum delay (truncation point). If finite, the distribution is
#' truncated at D. If set to Inf, no truncation is applied. Defaults to Inf.
#'
#' @param dprimary Function to generate the probability density function
#' (PDF) of primary event times. This function should take a value `x` and a
#' `pwindow` parameter, and return a probability density. It should be
#' normalized to integrate to 1 over \[0, pwindow\]. Defaults to a uniform
#' distribution over \[0, pwindow\]. Users can provide custom functions or use
#' helper functions like `dexpgrowth` for an exponential growth distribution.
#' See `primary_dists.R` for examples.
#'
#' @param dprimary_args List of additional arguments to be passed to
#' dprimary. For example, when using `dexpgrowth`, you would
#' pass `list(min = 0, max = pwindow, r = 0.2)` to set the minimum, maximum,
#' and rate parameters
#'
#' @param pdist_name A string specifying the name of the delay distribution
#' function. If NULL, the function name is extracted using
#' [.extract_function_name()]. Used to determine if a analytical solution
#' exists for the primary censored distribution. Must be set if `pdist` is
#' passed a pre-assigned variable rather than a function name.
#'
#' @param dprimary_name A string specifying the name of the primary event
#' distribution function. If NULL, the function name is extracted using
#' [.extract_function_name()]. Used to determine if a analytical solution
#' exists for the primary censored distribution. Must be set if `dprimary` is
#' passed a pre-assigned variable rather than a function name.
#'
#' @param ... Additional arguments to be passed to pdist
#'
#' @return Vector of primary event censored CDFs, normalized by D if finite
#' (truncation adjustment)
#'
#' @aliases ppcens
#'
#' @importFrom stats dunif
#'
#' @export
#'
#' @details
#' The primary event censored CDF is computed by integrating the product of
#' the delay distribution function (CDF) and the primary event distribution
#' function (PDF) over the primary event window. The integration is adjusted
#' for truncation if a finite maximum delay (D) is specified.
#'
#' The primary event censored CDF, \eqn{F_{\text{cens}}(q)}, is given by:
#' \deqn{
#' F_{\text{cens}}(q) = \int_{0}^{pwindow} F(q - p) \cdot f_{\text{primary}}(p)
#' \, dp
#' }
#' where \eqn{F} is the CDF of the delay distribution,
#' \eqn{f_{\text{primary}}} is the PDF of the primary event times, and
#' \eqn{pwindow} is the primary event window.
#'
#' If the maximum delay \eqn{D} is finite, the CDF is normalized by dividing
#' by \eqn{F_{\text{cens}}(D)}:
#' \deqn{
#' F_{\text{cens,norm}}(q) = \frac{F_{\text{cens}}(q)}{F_{\text{cens}}(D)}
#' }
#' where \eqn{F_{\text{cens,norm}}(q)} is the normalized CDF.
#'
#' This function creates a `primarycensored` object using
#' [new_pcens()] and then computes the primary event
#' censored CDF using [pcens_cdf()]. This abstraction allows
#' for automatic use of analytical solutions when available, while
#' seamlessly falling back to numerical integration when necessary.
#'
#' Note: For analytical detection to work correctly, `pdist` and `dprimary`
#' must be directly passed as distribution functions, not via assignment or
#' `pdist_name` and `dprimary_name` must be used to override the default
#' extraction of the function name.
#'
#' @family primarycensored
#' @seealso [new_pcens()] and [pcens_cdf()]
#'
#' @examples
#' # Example: Lognormal distribution with uniform primary events
#' pprimarycensored(c(0.1, 0.5, 1), plnorm, meanlog = 0, sdlog = 1)
#'
#' # Example: Lognormal distribution with exponential growth primary events
#' pprimarycensored(
#'   c(0.1, 0.5, 1), plnorm,
#'   dprimary = dexpgrowth,
#'   dprimary_args = list(r = 0.2), meanlog = 0, sdlog = 1
#' )
pprimarycensored <- function(
    q, pdist, pwindow = 1, D = Inf, dprimary = stats::dunif,
    dprimary_args = list(), pdist_name = NULL, dprimary_name = NULL, ...) {
  check_pdist(pdist, D, ...)
  check_dprimary(dprimary, pwindow, dprimary_args)

  if (is.null(pdist_name)) {
    pdist_name <- .extract_function_name(substitute(pdist))
  }
  if (is.null(dprimary_name)) {
    dprimary_name <- .extract_function_name(substitute(dprimary))
  }

  # Create a new primarycensored object
  pcens_obj <- new_pcens(
    pdist,
    dprimary,
    dprimary_args,
    pdist_name = pdist_name,
    dprimary_name = dprimary_name,
    ...
  )

  # Compute the CDF using the S3 method
  result <- pcens_cdf(pcens_obj, q, pwindow)

  if (!is.infinite(D)) {
    # Compute normalization factor for finite D
    normalizer <- if (max(q) == D) {
      result[length(result)]
    } else {
      pprimarycensored(D, pdist, pwindow, Inf, dprimary, dprimary_args, ...)
    }
    result <- result / normalizer

    result <- ifelse(q > D, 1, result)
  }

  return(result)
}

#' @rdname pprimarycensored
#' @export
ppcens <- pprimarycensored
