# VERSION 0.0.1
# AUTHOR: Matthew Carter
# DESCRIPTION: Codecov Metrics Report
# BUILD: docker build --rm -t scalefactor/codecov-metrics .
# SOURCE: https://github.com/matthewcarter-sf/codecov-metrics

FROM ruby:2.6.3-alpine

RUN apk add --update \
  build-base \
  libxml2-dev \
  libxslt-dev \
  && rm -rf /var/cache/apk/*

# Airflow Xcom - whatever runs can add a file to return.json in this directory
# and Airflow will push it to XCom
RUN mkdir -p /airflow/xcom
RUN chmod 777 /airflow/xcom
ENV IS_DOCKER true

RUN mkdir -p /usr/local/exec
COPY ./ /usr/local/exec/

WORKDIR /usr/local/exec/
RUN set -ex && \
    bundle config build.nokogiri --use-system-libraries && \
    bundle install

ENTRYPOINT ./entrypoint.sh
