package internal

import (
	"time"

	"github.com/gofrs/uuid"
)

type Greeting struct {
	UUID      uuid.UUID `json:"uuid"`
	FirstName string    `json:"firstName"`
	Text      string    `json:"text"`
	CreatedAt time.Time `json:"createdAt"`
}
