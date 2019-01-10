FROM rocker/verse:3.5.1@sha256:3ab705fd5ef8970f19ba7ca256f1cd158c6d7514cd39f33ab3b8cde3ada42bbd

LABEL maintainer=analytics-platform-tech@digital.justice.gov.uk

ARG GITHUB_PAT
ARG NCPUS=1

ENV R_VERSION=${R_VERSION:-3.5.1}
ENV USER=rstudio
ENV LC_ALL=en_GB.UTF-8 \
    LANG=en_GB.UTF-8

# Add static list of apt & R packages
COPY files/*_packages /tmp/

# Set locale & install packages
# Need node for vega and vega lite npm packages to render high res vega charts
RUN echo "en_GB.UTF-8 UTF-8" >> /etc/locale.gen \
  && locale-gen en_GB.utf8 \
  && update-locale LANG=en_GB.UTF-8 \
  && apt-get -qq update \
  && apt-get -qq install -y --no-install-recommends locales gnupg2 \
  && wget -qO - https://deb.nodesource.com/setup_9.x | bash \
  && rm -rf /var/lib/apt/lists/*;

RUN apt-get -qq update \
    && apt-get -qq install -y \
    $(cat /tmp/apt_packages) \
    # Dependencies of rgl which itself is a dependency
    mesa-common-dev \
    libglu1-mesa-dev; \
    rm -rf /var/lib/apt/lists/*; \
    # Install texlive with LaTex binaries and tools (scheme-basic)
    wget http://mirror.ctan.org/systems/texlive/tlnet/install-tl-unx.tar.gz \
    && mkdir /install-tl-unx; \
    tar -xvf install-tl-unx.tar.gz -C /install-tl-unx --strip-components=1; \
      echo "selected_scheme scheme-basic" >> /install-tl-unx/texlive.profile; \
    /install-tl-unx/install-tl -profile /install-tl-unx/texlive.profile; \
    rm -r /install-tl-unx; \
    rm install-tl-unx.tar.gz; \
    # Install SimbaAthena ODBC drivers
    wget -q https://s3.amazonaws.com/athena-downloads/drivers/ODBC/SimbaAthenaODBC_1.0.3/Linux/simbaathena-1.0.3.1004-1.x86_64.rpm -P /tmp \
    && alien -i /tmp/simbaathena-1.0.3.1004-1.x86_64.rpm \
    && rm -f /tmp/simbaathena-1.0.3.1004-1.x86_64.rpm


# Configure R
RUN echo '\n.libPaths("~/R/library")' >> /usr/local/lib/R/etc/Rprofile.site \
    && echo "PATH=\"${PATH}\"" >> /usr/local/lib/R/etc/Renviron \
    && echo "AWS_DEFAULT_REGION=eu-west-1" >> /usr/local/lib/R/etc/Renviron \
    && echo "r-libs-user=~/R/library" >> /etc/rstudio/rsession.conf


# Users want nano when they git commit not vim
# Users will use the reticulate package within R to run Python code.  This makes sure we always use py3
RUN update-alternatives --set editor /bin/nano \
    && update-alternatives --install /usr/bin/python python /usr/bin/python3.5 2 \
    && update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 2

# The Altair python allows us to use this in R via the reticulate package
RUN npm config set unsafe-perm true \
    && npm install -g vega vega-lite \
    && pip install altair

# This allows users to interact with AWS using boto3 via reticulate
RUN pip install boto3

# Need the latest version of reticulate and altair which aren't yet on CRAm
# Install R S3 package
RUN R -e "devtools::install_github('eddelbuettel/littler')"
RUN R -e "devtools::install_github('vegawidget/altair')"


# Install etl_manager to allow analysts declare databases on athena via R (using reticulate)
RUN pip install git+git://github.com/moj-analytical-services/etl_manager.git@v1.0.4#egg=etl_manager


# Install R Packages
RUN R -e "source('https://bioconductor.org/biocLite.R')" \
    && install2.r --error \
    --deps TRUE $(cat /tmp/R_packages) \
    --ncpus $NCPUS \
    && rm -f /tmp/{apt_packages,R_packages}

# Install R S3 package
RUN install2.r --error \
    --deps TRUE --repos 'http://cloudyr.github.io/drat' \
    'aws.signature' \
    'aws.s3' \
    'aws.ec2metadata' \
    # Install MOJ S3tools package
    && R -e "devtools::install_github('moj-analytical-services/s3tools')" \
    && R -e "devtools::install_github('moj-analytical-services/s3browser')" \
    && R -e "devtools::install_github('moj-analytical-services/dbtools')" \
    # Install webshot (dependency => PhantomJS) for Doc/PDF with JS graphs in it
    && R -e "install.packages('webshot')" \
    && R -e "webshot::install_phantomjs()" \
    && mv /root/bin/phantomjs /usr/bin/phantomjs \
    && chmod a+rx /usr/bin/phantomjs

# We want all packages to use the default MRAN mirror so that when we upgrade users, they don't magically get new packages
# However, when they install their own packages, we want this to come from latest CRAN
# RUN echo "\nr-cran-repos=http://cran.rstudio.com" >> /etc/rstudio/rsession.conf  This one has no effect
RUN mv /usr/local/lib/R/etc/Rprofile.site /usr/local/lib/R/etc/Rprofile2.site
RUN grep -v options\(repos /usr/local/lib/R/etc/Rprofile2.site > /usr/local/lib/R/etc/Rprofile.site
RUN rm /usr/local/lib/R/etc/Rprofile2.site

# Can't use Cran-mirror as it only supports 3.4.x
RUN echo "options(repos = c(CRAN='https://cran.rstudio.com'), download.file.method = 'libcurl')" >> /usr/local/lib/R/etc/Rprofile.site

# Configure git
RUN git config --system credential.helper 'cache --timeout=3600' \
    && git config --system push.default simple

# Adds Athena ODBC driver configuration
COPY files/odbc* /etc/



COPY start.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/start.sh

EXPOSE 8787

CMD ["/usr/local/bin/start.sh"]
