% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/sdf_utils.R
\name{from_rdd}
\alias{from_rdd}
\alias{fromRDD}
\title{Construct a TimeSeriesRDD from a Spark RDD of rows}
\usage{
from_rdd(
  rdd,
  schema,
  is_sorted = FALSE,
  time_unit = .sparklyr.flint.globals$kValidTimeUnits,
  time_column = .sparklyr.flint.globals$kDefaultTimeColumn
)

fromRDD(
  rdd,
  schema,
  is_sorted = FALSE,
  time_unit = .sparklyr.flint.globals$kValidTimeUnits,
  time_column = .sparklyr.flint.globals$kDefaultTimeColumn
)
}
\arguments{
\item{rdd}{A Spark RDD[Row] object containing time series data}

\item{schema}{A Spark StructType object containing schema of the time series
data}

\item{is_sorted}{Whether the rows being imported are already sorted by time}

\item{time_unit}{Time unit of the time column (must be one of the following
values: "NANOSECONDS", "MICROSECONDS", "MILLISECONDS", "SECONDS",
"MINUTES", "HOURS", "DAYS"}

\item{time_column}{Name of the time column}
}
\value{
A TimeSeriesRDD useable by the Flint time series library
}
\description{
Construct a TimeSeriesRDD containing time series data from a Spark RDD of rows
}
\examples{

library(sparklyr)
library(sparklyr.flint)

sc <- try_spark_connect(master = "local")

if (!is.null(sc)) {
  sdf <- copy_to(sc, tibble::tibble(t = seq(10), v = seq(10)))
  rdd <- spark_dataframe(sdf) \%>\% invoke("rdd")
  schema <- spark_dataframe(sdf) \%>\% invoke("schema")
  ts <- from_rdd(
    rdd, schema,
    is_sorted = TRUE, time_unit = "SECONDS", time_column = "t"
  )
} else {
  message("Unable to establish a Spark connection!")
}

}
\seealso{
Other Spark dataframe utility functions: 
\code{\link{collect.ts_rdd}()},
\code{\link{from_sdf}()},
\code{\link{spark_connection.ts_rdd}()},
\code{\link{spark_dataframe.ts_rdd}()},
\code{\link{spark_jobj.ts_rdd}()},
\code{\link{to_sdf}()},
\code{\link{ts_rdd_builder}()}

Other Spark dataframe utility functions: 
\code{\link{collect.ts_rdd}()},
\code{\link{from_sdf}()},
\code{\link{spark_connection.ts_rdd}()},
\code{\link{spark_dataframe.ts_rdd}()},
\code{\link{spark_jobj.ts_rdd}()},
\code{\link{to_sdf}()},
\code{\link{ts_rdd_builder}()}
}
\concept{Spark dataframe utility functions}
