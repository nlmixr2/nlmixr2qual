# Every parallel worker pins its inner-thread count from the runner's env var,
# so process-level (worker) and thread-level (rx) parallelism never multiply.
qual_set_threads(qual_inner_threads())
