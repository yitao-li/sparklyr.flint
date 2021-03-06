#' Utility functions for importing a Spark data frame into a TimeSeriesRDD
#'
#' These functions provide an interface for specifying how a Spark data frame
#' should be imported into a TimeSeriesRDD (e.g., which column represents time,
#' whether rows are already ordered by time, and time unit being used, etc)
#'
#' @param sc Spark connection
#' @param is_sorted Whether the rows being imported are already sorted by time
#' @param time_unit Time unit of the time column (must be one of the following
#'   values: "NANOSECONDS", "MICROSECONDS", "MILLISECONDS", "SECONDS",
#'   "MINUTES", "HOURS", "DAYS"
#' @param time_column Name of the time column
#'
#' @name sdf_utils
#'
#' @include globals.R
NULL

jtime_unit <- function(sc, time_unit = .sparklyr.flint.globals$kValidTimeUnits) {
  invoke_static(sc, "java.util.concurrent.TimeUnit", match.arg(time_unit))
}

new_ts_rdd_builder <- function(sc, is_sorted, time_unit, time_column) {
  invoke_new(
    sc,
    "com.twosigma.flint.timeseries.TimeSeriesRDDBuilder",
    is_sorted,
    jtime_unit(sc, time_unit),
    time_column
  )
}

new_ts_rdd <- function(jobj) {
  structure(list(.jobj = jobj), class = "ts_rdd")
}

.fromSDF <- function(builder, time_column) {
  impl <- function(sdf) {
    schema <- invoke(spark_dataframe(sdf), "schema")
    time_column_idx <- invoke(schema, "fieldIndex", time_column)
    time_column_type <- invoke(
      schema,
      "%>%",
      list("apply", time_column_idx),
      list("dataType"),
      list("typeName")
    )
    if (!time_column_type %in% c("long", "timestamp")) {
      time_column_sql <- dbplyr::translate_sql_(
        list(rlang::sym(time_column)),
        dbplyr::simulate_dbi()
      )
      dest_type <- (
        if (identical(time_column_type, "date")) "TIMESTAMP" else "LONG"
      )
      args <- list(
        dplyr::sql(paste0("CAST (", time_column_sql, " AS ", dest_type, ")"))
      )
      names(args) <- time_column
      sdf <- do.call(dplyr::mutate, c(list(sdf), args))
    }

    new_ts_rdd(invoke(builder, "fromDF", spark_dataframe(sdf)))
  }

  impl
}

.fromRDD <- function(builder, time_column) {
  from_df_impl <- .fromSDF(builder, time_column)
  impl <- function(rdd, schema) {
    sc <- spark_connection(rdd)
    session <- spark_session(sc)
    sdf <- invoke(session, "createDataFrame", rdd, schema) %>%
      sdf_register()

    from_df_impl(sdf)
  }

  impl
}

#' TimeSeriesRDD builder object
#'
#' Builder object containing all required info (i.e., isSorted, timeUnit, and
#' timeColumn) for importing a Spark data frame into a TimeSeriesRDD
#'
#' @inheritParams sdf_utils
#'
#' @return A reusable TimeSeriesRDD builder object
#'
#' @family Spark dataframe utility functions
#'
#' @export
ts_rdd_builder <- function(
                           sc,
                           is_sorted = FALSE,
                           time_unit = .sparklyr.flint.globals$kValidTimeUnits,
                           time_column = .sparklyr.flint.globals$kDefaultTimeColumn) {
  time_unit <- match.arg(time_unit)
  structure(list(
    .builder <- new_ts_rdd_builder(
      sc,
      is_sorted = is_sorted,
      time_unit = time_unit,
      time_column = time_column
    ),
    fromSDF = .fromSDF(.builder, time_column),
    fromRDD = .fromRDD(.builder, time_column)
  ))
}

#' Construct a TimeSeriesRDD from a Spark DataFrame
#'
#' Construct a TimeSeriesRDD containing time series data from a Spark DataFrame
#'
#' @inheritParams sdf_utils
#' @param sdf A Spark DataFrame object
#'
#' @return A TimeSeriesRDD useable by the Flint time series library
#'
#' @examples
#'
#' library(sparklyr)
#' library(sparklyr.flint)
#'
#' sc <- try_spark_connect(master = "local")
#'
#' if (!is.null(sc)) {
#'   sdf <- copy_to(sc, tibble::tibble(t = seq(10), v = seq(10)))
#'   ts <- from_sdf(sdf, is_sorted = TRUE, time_unit = "SECONDS", time_column = "t")
#' } else {
#'   message("Unable to establish a Spark connection!")
#' }
#'
#' @family Spark dataframe utility functions
#'
#' @export
from_sdf <- function(
                    sdf,
                    is_sorted = FALSE,
                    time_unit = .sparklyr.flint.globals$kValidTimeUnits,
                    time_column = .sparklyr.flint.globals$kDefaultTimeColumn) {
  sc <- spark_connection(sdf)
  builder <- ts_rdd_builder(sc, is_sorted, time_unit, time_column)
  builder$fromSDF(sdf)
}

#' @rdname from_sdf
#'
#' @family Spark dataframe utility functions
#'
#' @export
fromSDF <- from_sdf

#' Construct a TimeSeriesRDD from a Spark RDD of rows
#'
#' Construct a TimeSeriesRDD containing time series data from a Spark RDD of rows
#'
#' @inheritParams sdf_utils
#' @param rdd A Spark RDD[Row] object containing time series data
#' @param schema A Spark StructType object containing schema of the time series
#'   data
#'
#' @return A TimeSeriesRDD useable by the Flint time series library
#'
#' @examples
#'
#' library(sparklyr)
#' library(sparklyr.flint)
#'
#' sc <- try_spark_connect(master = "local")
#'
#' if (!is.null(sc)) {
#'   sdf <- copy_to(sc, tibble::tibble(t = seq(10), v = seq(10)))
#'   rdd <- spark_dataframe(sdf) %>% invoke("rdd")
#'   schema <- spark_dataframe(sdf) %>% invoke("schema")
#'   ts <- from_rdd(
#'     rdd, schema,
#'     is_sorted = TRUE, time_unit = "SECONDS", time_column = "t"
#'   )
#' } else {
#'   message("Unable to establish a Spark connection!")
#' }
#'
#' @family Spark dataframe utility functions
#'
#' @export
from_rdd <- function(
                    rdd,
                    schema,
                    is_sorted = FALSE,
                    time_unit = .sparklyr.flint.globals$kValidTimeUnits,
                    time_column = .sparklyr.flint.globals$kDefaultTimeColumn) {
  sc <- spark_connection(rdd)
  builder <- ts_rdd_builder(sc, is_sorted, time_unit, time_column)
  builder$fromRDD(rdd, schema)
}

#' @rdname from_rdd
#'
#' @family Spark dataframe utility functions
#'
#' @export
fromRDD <- from_rdd

#' Retrieve a Spark DataFrame
#'
#' Retrieve a Spark DataFrame from a TimeSeriesRDD object
#'
#' @param x An R object wrapping, or containing, a Spark DataFrame.
#' @param ... Optional arguments; currently unused.
#'
#' @examples
#'
#' library(sparklyr)
#' library(sparklyr.flint)
#'
#' sc <- try_spark_connect(master = "local")
#'
#' if (!is.null(sc)) {
#'   sdf <- copy_to(sc, tibble::tibble(t = seq(10), v = seq(10)))
#'   ts <- from_sdf(sdf, is_sorted = TRUE, time_unit = "SECONDS", time_column = "t")
#'   print(ts %>% spark_dataframe())
#'   print(sdf %>% spark_dataframe()) # the former should contain the same set of
#'                                    # rows as the latter does, modulo possible
#'                                    # difference in types of timestamp columns
#' } else {
#'   message("Unable to establish a Spark connection!")
#' }
#'
#' @family Spark dataframe utility functions
#'
#' @importFrom sparklyr spark_dataframe
#' @export
spark_dataframe.ts_rdd <- function(x, ...) {
  invoke(spark_jobj(x), "toDF")
}

#' Export data from TimeSeriesRDD to a Spark dataframe
#'
#' Construct a Spark dataframe containing time series data from a TimeSeriesRDD
#'
#' @param ts_rdd A TimeSeriesRDD object
#'
#' @return A Spark dataframe containing time series data exported from `ts_rdd`
#'
#' @examples
#'
#' library(sparklyr)
#' library(sparklyr.flint)
#'
#' sc <- try_spark_connect(master = "local")
#'
#' if (!is.null(sc)) {
#'   sdf <- copy_to(sc, tibble::tibble(t = seq(10), v = seq(10)))
#'   ts <- from_sdf(sdf, is_sorted = TRUE, time_unit = "SECONDS", time_column = "t")
#'   ts_avg <- summarize_avg(ts, column = "v", window = in_past("3s"))
#'   # now export the average values from `ts_avg` back to a Spark dataframe
#'   # named `sdf_avg`
#'   sdf_avg <- ts_avg %>% to_sdf()
#' } else {
#'   message("Unable to establish a Spark connection!")
#' }
#'
#' @family Spark dataframe utility functions
#'
#' @export
to_sdf <- function(ts_rdd) {
  ts_rdd %>% spark_dataframe() %>% sdf_register()
}

#' @rdname to_sdf
#'
#' @family Spark dataframe utility functions
#'
#' @export
toSDF <- to_sdf

#' Collect data from a TimeSeriesRDD
#'
#' Collect data from a TimeSeriesRDD into a R data frame
#'
#' @param x A com.twosigma.flint.timeseries.TimeSeriesRDD object
#' @param ... Additional arguments to `sdf_collect()`
#'
#' @return A R data frame containing the same time series data the input
#'   TimeSeriesRDD contains
#'
#' @examples
#'
#' library(sparklyr)
#' library(sparklyr.flint)
#'
#' sc <- try_spark_connect(master = "local")
#'
#' if (!is.null(sc)) {
#'   sdf <- copy_to(sc, tibble::tibble(t = seq(10), v = seq(10)))
#'   ts <- from_sdf(sdf, is_sorted = TRUE, time_unit = "SECONDS", time_column = "t")
#'   df <- ts %>% collect()
#' } else {
#'   message("Unable to establish a Spark connection!")
#' }
#'
#' @family Spark dataframe utility functions
#'
#' @importFrom dplyr collect
#' @export
collect.ts_rdd <- function(x, ...) {
  to_sdf(x) %>% collect()
}

#' Retrieve a Spark JVM Object Reference
#'
#' See \code{\link[sparklyr:spark_jobj]{spark_jobj}} for more details.
#'
#' @param x An R object containing, or wrapping, a 'spark_jobj'.
#' @param ... Optional arguments; currently unused.
#'
#' @examples
#'
#' library(sparklyr)
#' library(sparklyr.flint)
#'
#' sc <- try_spark_connect(master = "local")
#'
#' if (!is.null(sc)) {
#'   sdf <- copy_to(sc, tibble::tibble(t = seq(10), v = seq(10)))
#'   ts <- fromSDF(sdf, is_sorted = TRUE, time_unit = "SECONDS", time_column = "t")
#'   print(spark_jobj(ts))
#' } else {
#'   message("Unable to establish a Spark connection!")
#' }
#'
#' @family Spark dataframe utility functions
#'
#' @export
#' @importFrom sparklyr spark_jobj
spark_jobj.ts_rdd <- function(x, ...) {
  x$.jobj
}

#' Retrieve Spark connection associated with an R object
#'
#' See \code{\link[sparklyr:spark_connection]{spark_connection}} for more details.
#'
#' @param x An R object from which a 'spark_connection' can be obtained.
#' @param ... Optional arguments; currently unused.
#'
#' @examples
#'
#' library(sparklyr)
#' library(sparklyr.flint)
#'
#' sc <- try_spark_connect(master = "local")
#'
#' if (!is.null(sc)) {
#'   sdf <- copy_to(sc, tibble::tibble(t = seq(10), v = seq(10)))
#'   ts <- fromSDF(sdf, is_sorted = TRUE, time_unit = "SECONDS", time_column = "t")
#'   print(spark_connection(ts))
#' } else {
#'   message("Unable to establish a Spark connection!")
#' }
#'
#' @family Spark dataframe utility functions
#'
#' @export
#' @importFrom sparklyr spark_connection
spark_connection.ts_rdd <- function(x, ...) {
  x %>% spark_jobj() %>% sparklyr::spark_connection()
}
