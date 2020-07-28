FROM python:3.8
RUN apt-get update && \
  apt-get --no-install-recommends -yqq install \
    bash-completion \
    build-essential \
    cmake \
    libcurl4  \
    libcurl4-openssl-dev  \
    libssl-dev  \
    libxml2 \
    libxml2-dev  \
    libssl1.1 \
    pkg-config \
    ca-certificates \
    xclip \
    zip \
    jq && \
  git clone https://github.com/lastpass/lastpass-cli.git && \
  cd lastpass-cli && \
  make install && \
  pip install awscli