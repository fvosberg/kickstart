FROM oryd/kratos:v0.4-sqlite

USER root

RUN apk add --update libcap tzdata ca-certificates && rm -rf /var/cache/apk/*
RUN setcap CAP_NET_BIND_SERVICE=+eip /migrate-and-run.sh
RUN setcap CAP_NET_BIND_SERVICE=+eip /usr/bin/kratos


ENV MIGRATE_ARGS="-c /etc/config/kratos/.kratos.yml migrate sql -e --yes"

COPY migrate-and-run.sh /migrate-and-run.sh
COPY email-password /etc/config/kratos

RUN addgroup -g 1000 -S runnergroup && adduser -u 1001 -S apprunner -G runnergroup
USER apprunner

CMD [ "serve", "-c", "/etc/config/kratos/.kratos.yml"]
ENTRYPOINT ["/migrate-and-run.sh"]
