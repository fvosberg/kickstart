package postgres

import (
	"context"
	"os"
	"reflect"
	"testing"

	"github.com/fvosberg/kickstart/hello-go/internal"
	"github.com/gofrs/uuid"
)

func TestGreetings(t *testing.T) {
	dsn := os.Getenv("POSTGRES_DSN")
	if dsn == "" {
		t.Skip("Skipping postgres integration test, because env:POSTGRES_DSN is empty")
	}
	ctx := context.Background()

	c, err := Connect(ctx, dsn)
	if err != nil {
		t.Fatalf("Connection to postgres (%q) failed: %s", dsn, err)
	}
	defer c.Close()

	err = c.Migrate(ctx, "../../migrations")
	if err != nil {
		t.Fatalf("Migration failed: %s", err)
	}
	err = c.Truncate(ctx)
	if err != nil {
		t.Fatalf("Tuncate failed: %s", err)
	}

	phia := internal.Greeting{
		FirstName: "Phia",
		Text:      "Haaallllooooo",
	}
	err = c.SaveGreeting(ctx, &phia)
	if err != nil {
		t.Fatalf("Saving first greeting failed: %s", err)
	}
	if phia.UUID == uuid.Nil {
		t.Errorf("The UUID of the phia greeting should not be \"\" after saving")
	}
	if phia.CreatedAt.IsZero() {
		t.Errorf("The CreatedAt of the phia greeting should not be zero after saving")
	}

	fredi := internal.Greeting{
		FirstName: "Fredi",
		Text:      "Hoi",
	}
	err = c.SaveGreeting(ctx, &fredi)
	if err != nil {
		t.Fatalf("Saving first greeting failed: %s", err)
	}
	if fredi.UUID == uuid.Nil {
		t.Errorf("The UUID of the fredi greeting should not be \"\" after saving")
	}
	if fredi.CreatedAt.IsZero() {
		t.Errorf("The CreatedAt of the fredi greeting should not be zero after saving")
	}

	greetings, err := c.Greetings(ctx)
	if err != nil {
		t.Fatalf("Querying greetings failed: %s", err)
	}
	if len(greetings) != 2 {
		t.Fatalf("Should have returned 2 greetings from the db, but got %d", len(greetings))
	}
	if !reflect.DeepEqual(greetings[0], phia) {
		t.Errorf(
			"The first returned greeting should be the one from phia\nactual:\t%#v\nexpect:\t%#v",
			greetings[0],
			phia,
		)
	}
	if !reflect.DeepEqual(greetings[1], fredi) {
		t.Errorf(
			"The second returned greeting should be the one from fredi\nactual:\t%#v\nexpect:\t%#v",
			greetings[0],
			fredi,
		)
	}
}

func (c *Connection) Truncate(ctx context.Context) error {
	_, err := c.pool.Exec(ctx, "TRUNCATE greetings")
	return err
}
