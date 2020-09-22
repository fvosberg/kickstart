# Go build
FROM golang:1.15 as build-go

ARG BUILD_TAG

ENV CGO_ENABLED=0
ENV GO111MODULE=on
ENV GOOS=linux
ENV GOPATH=/

WORKDIR /src/service/

COPY go.mod .
COPY go.sum .
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 go build -ldflags "-X main.build=${BUILD_TAG}" -a -o "service" -installsuffix cgo

# Service definition
FROM alpine

RUN apk add --update libcap tzdata ca-certificates && rm -rf /var/cache/apk/*

COPY --from=build-go /src/service/service service
COPY --from=build-go /src/service/migrations /migrations

ENV HELLO_MIGRATIONS_PATH /migrations

EXPOSE 80/TCP
RUN setcap CAP_NET_BIND_SERVICE=+eip ./service

RUN update-ca-certificates

RUN addgroup -g 1000 -S runnergroup && adduser -u 1001 -S apprunner -G runnergroup
USER apprunner

ARG GIT_COMMIT=unknown
LABEL git-commit=$CI_COMMIT_SHA
LABEL build-tag=$BUILD_TAG

ENTRYPOINT ["/service"]
