FROM rocker/verse:3.4.2@sha256:f82e4b3a2c5410f338c7c199de0557ea75ca537e51220e8925747d75989377cd

LABEL maintainer=analytics-platform-tech@digital.justice.gov.uk

ENV R_VERSION=${R_VERSION:-3.4.2}
ENV USER=rstudio
ENV PHANTOMJS_VERSION="2.1.1+dfsg-2"

# Replace default debian package mirrors with bytemark package mirrors
RUN sed -i 's%deb.debian.org%mirror.bytemark.co.uk%' /etc/apt/sources.list

# Set locale
RUN apt-get update \
    && apt-get install -y --no-install-recommends locales; \
    echo "en_GB.UTF-8 UTF-8" >> /etc/locale.gen \
    && locale-gen en_GB.utf8 \
    && /usr/sbin/update-locale LANG=en_GB.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

ENV LC_ALL=en_GB.UTF-8 \
    LANG=en_GB.UTF-8

# Configure R
RUN mkdir -p /etc/R; echo '\n\
    \n .libPaths("~/R/library") \
    \n# Configure httr to perform out-of-band authentication if HTTR_LOCALHOST \
    \n# is not set since a redirect to localhost may not work depending upon \
    \n# where this Docker container is running. \
    \nif(is.na(Sys.getenv("HTTR_LOCALHOST", unset=NA))) { \
    \n  options(httr_oob_default = TRUE) \
    \n}' >> /etc/R/Rprofile.site \
    && echo "PATH=\"${PATH}\"" >> /etc/R/Renviron \
    && echo "r-libs-user=~/R/library" >> /etc/rstudio/rsession.conf \

    ## Configure RStudio profile
    && echo '\n\
    \n[*] \
    \nmax-memory-mb = 12288 \
    \n' >> /etc/rstudio/profiles

# Add static list of apt packages
ADD apt_packages /tmp/apt_packages

# Install (R Packages) dependencies
RUN apt-get update && apt-get install -y \
    $(cat /tmp/apt_packages) \
    # Dependencies of rgl which itself is a dependency
    mesa-common-dev \
    libglu1-mesa-dev \
    # Dependency of R package Webshot
    phantomjs=$PHANTOMJS_VERSION; \
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
	wget https://s3.amazonaws.com/athena-downloads/drivers/ODBC/Linux/simbaathena-1.0.2.1003-1.x86_64.rpm -P /tmp \
	&& alien -i /tmp/simbaathena-1.0.2.1003-1.x86_64.rpm \
	&& rm -f /tmp/simbaathena-1.0.2.1003-1.x86_64.rpm

# Add static list of R packages
ADD R_packages /tmp/R_packages

# Install R Packages
RUN R -e "source('https://bioconductor.org/biocLite.R')" \
    && install2.r --error \
    --deps TRUE $(cat /tmp/R_packages)

# Install R S3 package
RUN install2.r --error \
    --deps TRUE --repos 'http://cloudyr.github.io/drat' \
    'aws.signature' \
    'aws.s3' \
    'aws.ec2metadata' \

    # Install MOJ S3tools package
    && R -e "devtools::install_github('moj-analytical-services/s3tools')" \
    && R -e "devtools::install_github('moj-analytical-services/s3browser')" \

    # Install webshot (dependency => PhantomJS) for Doc/PDF with JS graphs in it
    && R -e "install.packages('webshot')"

# Configure git
RUN git config --system credential.helper 'cache --timeout=3600' \
    && git config --system push.default simple

COPY start.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/start.sh

EXPOSE 8787

CMD ["/usr/local/bin/start.sh"]
