FROM docker.io/library/alpine:latest
ENV RUNNING_IN_DOCKER=true
ENTRYPOINT ["/bin/bash"]
CMD ["/app/pbs_exporter.sh"]
RUN addgroup -g 10001 user \
    && adduser -H -D -G user user
RUN apk add --quiet --no-cache bash curl jq
USER user:user