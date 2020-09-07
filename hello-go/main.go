package main

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/ardanlabs/conf"
	"github.com/fvosberg/kickstart/hello-go/internal/postgres"
	"github.com/fvosberg/kickstart/hello-go/internal/rest"
	"github.com/sirupsen/logrus"
	"golang.org/x/sync/errgroup"
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
	log.SetLevel(logrus.DebugLevel)

	confLog, err := conf.String(&cfg)
	if err != nil {
		return fmt.Errorf("creating debug config output: %w", err)
	}
	logrus.WithField("config", confLog).Info("Parsed config")

	ctx, shutdown := context.WithCancel(context.Background())
	defer shutdown()

	// ==================================================
	// ===================== BOOT =======================
	pgres, err := postgres.Connect(ctx, cfg.postgresDSN())
	if err != nil {
		return fmt.Errorf("connection to postgres failed: %w", err)
	}
	defer pgres.Close()

	err = pgres.Migrate(ctx, cfg.MigrationsPath, !cfg.InstallDBExtensions)
	if err != nil {
		return fmt.Errorf("migration failed: %w", err)
	}

	// ==================================================
	// ================= START WORKER ===================
	// ==================================================
	// The worker leverage the errgroup, so each worker should
	// satisfy the following requirements
	// - It should return an error, when it failes to boot
	// - It should return an error, when a critical runtime error occures
	// - It should not return, but log a non critical error
	// - It should "listen" on the workerContext and shutdown, when it's cancelled
	// - It should return nil, when shutdown successfully
	g, workerContext := errgroup.WithContext(ctx)

	g.Go(func() error {
		return startOtherWorker(workerContext, log)
	})
	g.Go(func() error {
		return startServer(workerContext, cfg, log, pgres)
	})

	signals := make(chan os.Signal, 1)
	signal.Notify(signals, syscall.SIGINT, syscall.SIGTERM)
	select {
	case <-workerContext.Done():
		// a worker returned a non nil value
		// TODO make this code more robust for code changes to the context / not ignoring the error
	case sig := <-signals:
		// TODO enrich error message with this?
		log.WithField("sig", sig).Info("Got OS signal")
		shutdown()
	}

	// Wait returns only the first non nil error from the workers
	// TODO can we provide all errors? Is this critical?
	return g.Wait()
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

func startServer(ctx context.Context, cfg config, log *logrus.Logger, pgres *postgres.Connection) error {
	server := &http.Server{
		Addr:    cfg.HTTPAddress,
		Handler: rest.NewRouter(log, cfg.BasePath, pgres),
	}

	errs := make(chan error)
	defer close(errs)

	go func() {
		log.WithField("addr", server.Addr).Info("Starting HTTP server")
		err := server.ListenAndServe()

		errs <- fmt.Errorf("critical server error: %w", err)
	}()

	go func() {
		<-ctx.Done()
		log.WithError(ctx.Err()).Debug("Shutting down HTTP server")

		shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer shutdownCancel()

		errs <- server.Shutdown(shutdownCtx)
	}()

	for {
		err := <-errs
		if errors.Is(err, http.ErrServerClosed) {
			// expected err, because the server should run until it is shut down
			log.Info("Closed HTTP server for incoming connections")
			continue
		}
		log.WithError(err).Debug("got other error on server shutdown")
		if err != nil {
			return fmt.Errorf("shutting down HTTP server: %w", err)
		}
		return nil
	}
}

func startOtherWorker(ctx context.Context, log *logrus.Logger) error {
	defer log.Info("Shut down other worker")
	for {
		select {
		case <-ctx.Done():
			log.WithError(ctx.Err()).Debug("Shutting down other worker")
			return nil
		case <-time.After(time.Second):
			log.Debug("Other worker is working")
		}
	}
}
