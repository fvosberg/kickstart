package postgres

import (
	"context"
	"fmt"

	"github.com/fvosberg/kickstart/hello-go/internal"
	"github.com/jackc/pgx/v4/pgxpool"
)

func Connect(ctx context.Context, postgresDSN string) (*Connection, error) {
	pool, err := pgxpool.Connect(ctx, postgresDSN)
	if err != nil {
		return nil, err
	}
	return &Connection{pool: pool}, nil
}

type Connection struct {
	pool *pgxpool.Pool
}

func (c *Connection) Close() {
	c.pool.Close()
}

func (c *Connection) SaveGreeting(ctx context.Context, g *internal.Greeting) error {
	err := c.pool.
		QueryRow(ctx, `INSERT INTO "greetings" ("first_name", "text") VALUES ($1, $2) RETURNING "uuid", "created_at";`, g.FirstName, g.Text).
		Scan(&g.UUID, &g.CreatedAt)
	return err
}

func (c *Connection) Greetings(ctx context.Context) ([]internal.Greeting, error) {
	rows, err := c.pool.Query(ctx, `SELECT "uuid", "first_name", "text", "created_at" FROM "greetings" ORDER BY created_at`)
	if err != nil {
		return nil, err
	}

	defer rows.Close()
	gg := []internal.Greeting{}

	var n uint32
	// TODO index über created_at
	for rows.Next() {
		gg = append(gg, internal.Greeting{})
		err = rows.Scan(&gg[n].UUID, &gg[n].FirstName, &gg[n].Text, &gg[n].CreatedAt)
		if err != nil {
			return nil, fmt.Errorf("scanning result failed: %w", err)
		}
		n++
	}
	return gg, nil
}

func (c *Connection) Migrate(ctx context.Context, migrationsPath string, skipFirstMigration bool) error {
	conn, err := c.pool.Acquire(ctx)
	if err != nil {
		return fmt.Errorf("acquiring conn failed: %w", err)
	}
	defer conn.Release()

	return migrateOnConnection(ctx, conn.Conn(), migrationsPath, skipFirstMigration)
}
