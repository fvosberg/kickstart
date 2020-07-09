package postgres

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v4"
	"github.com/jackc/tern/migrate"
	"github.com/lib/pq"
)

func migrateOnConnection(ctx context.Context, conn *pgx.Conn, migrationsPath string, skipFirstMigration bool) error {

	migrator, err := migrate.NewMigrator(ctx, conn, "public.schema_version")
	if err != nil {
		return fmt.Errorf("creating migrator: %w", err)
	}

	err = migrator.LoadMigrations(migrationsPath)
	if err != nil {
		return fmt.Errorf("loading migrations failed: %w", err)
	}
	if skipFirstMigration {
		_, err = conn.Exec(
			ctx,
			fmt.Sprintf(
				"UPDATE %s SET version=1 WHERE version=0;",
				pq.QuoteIdentifier("schema_version"),
			),
		)
		if err != nil {
			return fmt.Errorf("setting migrations initial version to 1 to skip extension installation failed: %w", err)
		}
	}
	err = migrator.Migrate(ctx)
	if err != nil {
		return fmt.Errorf("migration failed: %w", err)
	}

	return nil
}
