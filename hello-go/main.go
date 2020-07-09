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
	HTTPAddress string `conf:"default::80"`
	BasePath    string
	Postgres    struct {
		DB       string `conf:"default:hello-go"`
		User     string `conf:"required"`
		Password string `conf:"noprint,required"`
		Host     string `conf:"required"`
	}
	MigrationsPath      string `conf:"default:./migrations"`
	InstallDBExtensions bool   `conf:"INSTALL_DB_EXTENSIONS,default:true"`
}

func (c config) postgresDSN() string {
	// TODO what about the port for postgres in AWS?
	return fmt.Sprintf(
		"dbname=%s host=%s user=%s password=%s",
		c.Postgres.DB,
		c.Postgres.Host,
		c.Postgres.User,
		c.Postgres.Password,
	)
}

func parseConfig() (config, error) {
	var cfg config
	confPrefix := "HELLO"

	err := conf.Parse(os.Args, confPrefix, &cfg)
	if err != nil {
		return cfg, err
	}

	// adaption for GCP - the platform has to set the port via this env var
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

	pgres, err := postgres.Connect(ctx, cfg.postgresDSN())
	if err != nil {
		return fmt.Errorf("connection to postgres failed: %w", err)
	}
	err = pgres.Migrate(ctx, cfg.MigrationsPath, !cfg.InstallDBExtensions)
	if err != nil {
		return fmt.Errorf("migration failed: %w", err)
	}

	log.WithField("addr", cfg.HTTPAddress).Info("Starting server")
	err = http.ListenAndServe(cfg.HTTPAddress, rest.NewRouter(log, cfg.BasePath, pgres))
	if err != nil {
		return fmt.Errorf("critical server error: %w", err)
	}

	return nil
}
