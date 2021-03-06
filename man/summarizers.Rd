% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/summarizers.R
\name{summarizers}
\alias{summarizers}
\title{Wrapper functions for commonly used summarizer functions}
\arguments{
\item{ts_rdd}{Timeseries RDD being summarized}

\item{window}{Either an R expression specifying time windows to be summarized
(e.g., `in_past("1h")` to summarize data from looking behind 1 hour at
each time point, `in_future("5s")` to summarize data from looking forward
5 seconds at each time point), or `NULL` to compute aggregate statistics
on records grouped by timestamps}

\item{column}{Column to be summarized}

\item{key_columns}{Optional list of columns that will form an equivalence
relation associating each record with the time series it belongs to (i.e.,
any 2 records having equal values in those columns will be associated with
the same time series, and any 2 records having differing values in those
columns are considered to be from 2 separate time series and will therefore
be summarized separately)
By default, `key_colums` is empty and all records are considered to be part
of a single time series.}

\item{incremental}{If FALSE and `key_columns` is empty, then apply the
summarizer to all records of `ts_rdd`.
If FALSE and `key_columns` is non-empty, then apply the summarizer to all
records within each group determined by `key_columns`.
If TRUE and `key_columns` is empty, then for each record in `ts_rdd`,
the summarizer is applied to that record and all records preceding it, and
the summarized result is associated with the timestamp of that record.
If TRUE and `key_columns` is non-empty, then for each record within a group
of records determined by 1 or more key columns, the summarizer is applied
to that record and all records preceding it within its group, and the
summarized result is associated with the timestamp of that record.}
}
\description{
R wrapper functions for commonly used Flint summarizer functionalities such as
sum and count.
}
