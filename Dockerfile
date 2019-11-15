# VERSION 0.0.1
# AUTHOR: Peter Myers
# DESCRIPTION: Jira Metrics Report
# BUILD: docker build --rm -t scalefactor/jira-metrics .
# SOURCE: https://github.com/petermyers/jira-metrics

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
