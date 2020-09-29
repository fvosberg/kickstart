FROM golang:1.15-alpine as build

LABEL stage=intermediate

ENV CGO_ENABLED=0
ENV GO111MODULE=on
ENV GOOS=linux

RUN apk add --update --no-cache git ca-certificates tzdata && update-ca-certificates
RUN addgroup -g 1000 -S appgroup && adduser -u 1001 -S appuser -G appgroup

# ---------
WORKDIR /app-build

ARG GOPROXY

# Copy dependencies
COPY go.mod go.mod
COPY go.sum go.sum
RUN go mod download

# Copy code and build - add irrelevant files to .dockerignore or change the COPY
# to not unnecessarily invalidate the image layer
COPY . .

ARG BUILD_TAG
ARG GIT_COMMIT=unknown

# Final build
RUN go build -ldflags "-X main.build=${BUILD_TAG} -w -s" -o service

###############################################################################
#########################  SERVICE STAGE ######################################
###############################################################################
FROM scratch

COPY --from=build /etc/passwd /etc/passwd

EXPOSE 80/TCP

USER appuser

COPY --from=build /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=build /etc/ssl/certs/ /etc/ssl/certs/
COPY --from=build /app-build/service ./service
COPY --from=build /app-build/migrations /migrations

ARG BUILD_TAG
ARG GIT_COMMIT=unknown

LABEL git-commit=${GIT_COMMIT}
LABEL build-tag=${BUILD_TAG}

ENTRYPOINT ["./service"]
