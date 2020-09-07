package main

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"os"

	"github.com/ardanlabs/conf"
	"github.com/fvosberg/kickstart/hello-go/internal/postgres"
	"github.com/fvosberg/kickstart/hello-go/internal/rest"
	"github.com/sirupsen/logrus"
)

// main should only call run, to have a consistent error handling
func main() {
	err := run()
	if err != nil {
		logrus.WithError(err).Error("Critical Error")
		os.Exit(1)
	}
}

// run is responsible for parsing the config,
// starting the concurrent tasks and handling
// OS signals
func run() error {
	cfg, err := parseConfig(os.Args)
	if err != nil {
		return fmt.Errorf("parsing config: %w", err)
	}

	// TODO configure logger
	log := logrus.StandardLogger()

	confLog, err := conf.String(&cfg)
	if err != nil {
		return fmt.Errorf("creating debug config output: %w", err)
	}
	logrus.WithField("config", confLog).Info("Parsed config")

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

func parseConfig(args []string) (config, error) {
	var cfg config
	confPrefix := "HELLO"

	err := conf.Parse(args, confPrefix, &cfg)
	if err != nil {
		return cfg, err
	}

	// adaption for GCP - the platform has to set the port via this env var
	port := os.Getenv("PORT")
	if port != "" {
		if cfg.HTTPAddress != ":80" {
			return cfg, errors.New("setting PORT and HTTP_ADDRESS is not allowed")
		}
		cfg.HTTPAddress = fmt.Sprintf(":%s", port)
	}

	return cfg, nil
}
