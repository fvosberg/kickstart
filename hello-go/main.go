package main

import (
	"context"
	"fmt"
	"net/http"
	"os"

	"github.com/ardanlabs/conf"
	"github.com/fvosberg/kickstart/hello-go/internal/postgres"
	"github.com/fvosberg/kickstart/hello-go/internal/rest"
	"github.com/sirupsen/logrus"
)

func main() {
	cfg, err := parseConfig()
	if err != nil {
		logrus.WithError(err).Error("Parsing config failed")
		os.Exit(1)
	}

	// TODO configure logger
	logConf, err := conf.String(&cfg)
	if err != nil {
		logrus.WithError(err).Error("Creating debug config output failed")
		os.Exit(1)
	}
	logrus.WithField("config", logConf).Info("Parsed config")

	err = run(logrus.StandardLogger(), cfg)
	if err != nil {
		logrus.WithError(err).Error("Critical error")
		os.Exit(1)
	}
}

type config struct {
	HTTPAddress    string `conf:"default::80"`
	PostgresDSN    string `conf:"env:POSTGRES_DSN,noprint"`
	MigrationsPath string `conf:"default:./migrations"`
}

func parseConfig() (config, error) {
	var cfg config
	confPrefix := "HELLO"

	err := conf.Parse(os.Args, confPrefix, &cfg)
	if err != nil {
		return cfg, err
	}

	port := os.Getenv("PORT")
	if port != "" {
		if cfg.HTTPAddress != ":80" {
			logrus.Error("Setting PORT and HTTP_ADDRESS is not allowed")
			os.Exit(1)
		}
		cfg.HTTPAddress = fmt.Sprintf(":%s", port)
	}

	return cfg, nil
}

func run(log *logrus.Logger, cfg config) error {
	ctx := context.Background()

	pgres, err := postgres.Connect(ctx, cfg.PostgresDSN)
	if err != nil {
		return fmt.Errorf("connection to postgres failed: %w", err)
	}
	err = pgres.Migrate(ctx, cfg.MigrationsPath)
	if err != nil {
		return fmt.Errorf("migration failed: %w", err)
	}

	log.WithField("addr", cfg.HTTPAddress).Info("Starting server")
	err = http.ListenAndServe(cfg.HTTPAddress, rest.NewRouter(log, pgres))
	if err != nil {
		return fmt.Errorf("critical server error: %w", err)
	}

	return nil
}
