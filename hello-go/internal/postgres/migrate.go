package postgres

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v4"
	"github.com/jackc/tern/migrate"
)

// TODO: use pool.Acquire and release
func Migrate(ctx context.Context, postgresDSN, migrationsPath string) error {

	conn, err := pgx.Connect(ctx, postgresDSN)
	if err != nil {
		return fmt.Errorf("Unable to connect to database: %w", err)
	}
	defer conn.Close(ctx)


	return migrateOnConnection(ctx, conn, migrationsPath)
}

func migrateOnConnection(ctx context.Context, conn *pgx.Conn, migrationsPath string) error {

	migrator, err := migrate.NewMigrator(ctx, conn, "public.schema_version")
	if err != nil {
		return fmt.Errorf("creating migrator: %w", err)
	}

	err = migrator.LoadMigrations(migrationsPath)
	if err != nil {
		return fmt.Errorf("loading migrations failed: %w", err)
	}
	err = migrator.Migrate(ctx)
	if err != nil {
		return fmt.Errorf("migration failed: %w", err)
	}

	return nil
}
