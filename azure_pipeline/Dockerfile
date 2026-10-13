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
        curl \
        libcurl4-openssl-dev \
        libglpk-dev \
        pkg-config \
        libfontconfig1-dev \
        libfreetype6-dev \
        libharfbuzz-dev \
        libfribidi-dev \
        libpng-dev \
        libtiff-dev \
        libjpeg-dev \
        libwebp-dev \
        # fs
        cmake \
        # DatabaseConnector, SqlRender
        default-jdk \
        # stringi
        libicu-dev \
        # RPostgres
        libpq-dev \
        # fs
        libuv1-dev \
        # clipr
        libx11-dev \
        # xml2
        libxml2-dev \
        # knitr, rmarkdown
        pandoc && \
    rm -rf /var/lib/apt/lists/* && \
    # point R at the installed JDK so rJava can be built/loaded against it
    R CMD javareconf

ENV R_LIBS_USER=/opt/R/library \
    RENV_PATHS_LIBRARY=/opt/R/library \
    RENV_CONFIG_CACHE_ENABLED=false \
    RENV_CONFIG_AUTOLOADER_ENABLED=false

COPY renv.lock /opt/renv/renv.lock

RUN mkdir -p /opt/R/library && \
    Rscript --vanilla -e "install.packages('renv', lib = Sys.getenv('R_LIBS_USER'), repos = c(CRAN = 'https://packagemanager.posit.co/cran/latest'))" && \
    Rscript --vanilla -e "renv::restore(project = '/opt/renv', lockfile = '/opt/renv/renv.lock', library = Sys.getenv('R_LIBS_USER'), prompt = FALSE)"
