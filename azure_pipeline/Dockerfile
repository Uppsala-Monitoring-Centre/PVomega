# The version in the docker image tag (4.6.0) should match
# the version of R we use.
FROM rocker/r-ver:4.6.0

# The resulting container is used by `azure-validation.yaml`.

# Each line notes the R package that requires it.
#
# Some packages are not actually needed or another variant (e.g. libpq instead
# of libpq-dev) would actually suffice and result in small docker image but
# without them, renv may warn about missing system packages. This is because
# they are needed when building from source but we often use pre-built versions
# of the packages which do not need them.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        # fs
        cmake \
        # DatabaseConnector, SqlRender
        default-jdk \
        # stringi
        libicu-dev \
        # RPostgres
        libpq-dev \
        # fs
        libuv1 \
        # clipr
        libx11-dev \
        # xml2
        libxml2-dev \
        # knitr, rmarkdown
        pandoc && \
    rm -rf /var/lib/apt/lists/* && \
    # point R at the installed JDK so rJava can be built/loaded against it
    R CMD javareconf

# NOTE: R packages are NOT baked into this image. The pipeline installs renv and
# runs renv::restore() into a writable per-run library (R_LIBS_USER), so this
# image only needs rebuilding when the base R version or system libraries
# change.
