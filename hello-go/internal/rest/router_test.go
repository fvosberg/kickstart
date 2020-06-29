package rest

import (
	"context"
	"encoding/json"
	"io/ioutil"
	"math/rand"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/Pallinder/go-randomdata"
	"github.com/bluele/factory-go/factory"
	"github.com/fvosberg/kickstart/hello-go/internal"
	"github.com/gofrs/uuid"
	"github.com/sirupsen/logrus"
)

func TestServerCreateGreetingSucceess(t *testing.T) {
	repository := &storageMock{
		SaveGreetingFunc: func(ctx context.Context, g *internal.Greeting) error {
			g.UUID = uuid.FromStringOrNil("b9e1d614-ca3e-4c54-a159-8e95a197544f")
			g.CreatedAt = time.Date(1989, 8, 21, 12, 0, 0, 0, time.UTC)
			return nil
		},
	}

	log := logrus.New()

	r := NewRouter(log, repository)
	s := httptest.NewServer(r)
	defer s.Close()

	reqBody := strings.NewReader(`{"firstName":"fredi","text":"Haaaaloooooo"}`)
	req, err := http.NewRequest("POST", s.URL+"/greetings", reqBody)
	if err != nil {
		t.Fatalf("creating request: %s", err)
	}

	res, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("http request: %s", err)
	}

	if res.StatusCode != 201 {
		t.Errorf("Expected status code 201, got %d", res.StatusCode)
	}

	if len(repository.SaveGreetingCalls()) != 1 {
		t.Errorf(
			"Expected the repositories SaveGreeting function to be called 1, has been called %d times",
			len(repository.SaveGreetingCalls()),
		)
	} else {
		if repository.SaveGreetingCalls()[0].G.FirstName != "fredi" {
			t.Errorf(
				"Expected the greetings first name in the repository to be \"fredi\", but got %q",
				repository.SaveGreetingCalls()[0].G.FirstName,
			)
		}
		if repository.SaveGreetingCalls()[0].G.Text != "Haaaaloooooo" {
			t.Errorf(
				"Expected the greetings text in the repository to be \"Haaaaloooooo\", but got %q",
				repository.SaveGreetingCalls()[0].G.Text,
			)
		}
	}

	expectedLocationHeader := "/greetings/b9e1d614-ca3e-4c54-a159-8e95a197544f"
	if res.Header.Get("Location") != expectedLocationHeader {
		t.Errorf(
			"Expected the Location Header to be %q, but got %q",
			expectedLocationHeader,
			res.Header.Get("Location"),
		)
	}
	expectedContentType := "application/json; charset=utf-8"
	if res.Header.Get("Content-Type") != expectedContentType {
		t.Errorf(
			"Expected the Content-Type Header to be %q, but got %q",
			expectedContentType,
			res.Header.Get("Content-Type"),
		)
	}

	b, err := ioutil.ReadAll(res.Body)
	if err != nil {
		t.Fatalf("Reading response body failed: %s", err)
	}

	expected := `{"uuid":"b9e1d614-ca3e-4c54-a159-8e95a197544f","firstName":"fredi","text":"Haaaaloooooo","createdAt":"1989-08-21T12:00:00Z"}`
	if strings.TrimSpace(string(b)) != expected {
		t.Errorf("Response body not as expected\nactual:\t%#v\nexpect:\t%#v", string(b), expected)
	}
}

func TestServerCreateGreetingFailure(t *testing.T) {
	t.Run("invalid_req_body", func(t *testing.T) {
		repository := &storageMock{}
		log := logrus.New()
		log.SetOutput(ioutil.Discard)

		s := server{log: log, storage: repository}
		res := httptest.NewRecorder()
		req, err := http.NewRequest("TEAPOT", "/asdas/", strings.NewReader(`{`))
		if err != nil {
			t.Fatalf("Creating request failed: %s", err)
		}

		s.serveCreateGreeting(res, req)

		if res.Code != 400 {
			t.Errorf("Expecting a status code of 400, got %d", res.Code)
		}
		expectedBody := `{"err":{"code":1593455104,"msg":"Bad Request: decoding request body: unexpected EOF"}}`
		if strings.TrimSpace(res.Body.String()) != expectedBody {
			t.Errorf("Unexpected response body\nactual:\t%s\nexpect:\t%s", res.Body.String(), expectedBody)
		}
		expectedContentType := "application/json; charset=utf-8"
		if res.Header().Get("Content-Type") != expectedContentType {
			t.Errorf(
				"Expected the Content-Type Header to be %q, but got %q",
				expectedContentType,
				res.Header().Get("Content-Type"),
			)
		}

	})
}

func greetingsFactory() *factory.Factory {
	return factory.NewFactory(
		&internal.Greeting{},
	).SeqInt("UUID", func(n int) (interface{}, error) {
		return uuid.NewV4()
	}).Attr("FirstName", func(args factory.Args) (interface{}, error) {
		return randomdata.FirstName(randomdata.RandomGender), nil
	}).Attr("Text", func(args factory.Args) (interface{}, error) {
		return randomdata.StringSample(), nil
	}).Attr("CreatedAt", func(args factory.Args) (interface{}, error) {
		min := time.Date(1970, 1, 0, 0, 0, 0, 0, time.UTC).Unix()
		max := time.Date(2070, 1, 0, 0, 0, 0, 0, time.UTC).Unix()
		delta := max - min

		sec := rand.Int63n(delta) + min
		return time.Unix(sec, 0), nil
	})
}

func TestServerGreetings(t *testing.T) {
	expectedGreetings := "[{\"uuid\":\"562e2aad-f442-4aac-b26f-55de4e39e3dc\",\"firstName\":\"Aubrey\",\"text\":\"\",\"createdAt\":\"2016-04-30T05:32:31+02:00\"},{\"uuid\":\"7011dd90-c418-490e-9937-cff7d8647a55\",\"firstName\":\"Natalie\",\"text\":\"\",\"createdAt\":\"2060-08-01T17:34:11+01:00\"},{\"uuid\":\"95f3d7ac-c688-4763-a242-8f04d86244d0\",\"firstName\":\"Elizabeth\",\"text\":\"\",\"createdAt\":\"2027-12-29T23:55:20+01:00\"},{\"uuid\":\"26fe050a-d711-4784-a32e-17d8af750577\",\"firstName\":\"Elizabeth\",\"text\":\"\",\"createdAt\":\"1977-01-15T10:49:08+01:00\"},{\"uuid\":\"66b029ce-4711-4b65-9378-ec7ff537cd19\",\"firstName\":\"Benjamin\",\"text\":\"\",\"createdAt\":\"2009-09-23T15:37:29+02:00\"},{\"uuid\":\"f3cf0d34-aa9a-4670-bf03-f2a66ada729e\",\"firstName\":\"David\",\"text\":\"\",\"createdAt\":\"2059-02-14T16:41:27+01:00\"},{\"uuid\":\"72c59cc2-f922-488e-855b-7228e478c63c\",\"firstName\":\"Noah\",\"text\":\"\",\"createdAt\":\"2016-03-03T14:40:36+01:00\"},{\"uuid\":\"82163caf-2066-40a5-a269-071ee68add74\",\"firstName\":\"Michael\",\"text\":\"\",\"createdAt\":\"2035-03-10T11:47:53+01:00\"},{\"uuid\":\"5b6cc810-7ef6-4ec1-a69b-a4ae560700c1\",\"firstName\":\"Charlotte\",\"text\":\"\",\"createdAt\":\"1970-04-24T05:01:31+01:00\"},{\"uuid\":\"f1a6d7e2-8987-4276-b883-2b25390e0c91\",\"firstName\":\"Zoey\",\"text\":\"\",\"createdAt\":\"2040-12-17T09:48:51+01:00\"}]\n"

	greetings := make([]internal.Greeting, 0)
	err := json.Unmarshal([]byte(expectedGreetings), &greetings)
	if err != nil {
		t.Fatalf("decoding expected greetings failed: %s", err)
	}

	repository := &storageMock{
		GreetingsFunc: func(ctx context.Context) ([]internal.Greeting, error) {
			return greetings, nil
		},
	}

	log := logrus.New()
	log.SetOutput(ioutil.Discard)

	r := NewRouter(log, repository)
	s := httptest.NewServer(r)
	defer s.Close()

	req, err := http.NewRequest("GET", s.URL+"/greetings", nil)
	if err != nil {
		t.Fatalf("creating request: %s", err)
	}

	res, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("http request: %s", err)
	}

	if res.StatusCode != 200 {
		t.Errorf("Expected status code 200, got %d", res.StatusCode)
	}

	if len(repository.GreetingsCalls()) != 1 {
		t.Errorf(
			"Expected the repositories Greetings function to be called 1, has been called %d times",
			len(repository.GreetingsCalls()),
		)
	}

	expectedContentType := "application/json; charset=utf-8"
	if res.Header.Get("Content-Type") != expectedContentType {
		t.Errorf(
			"Expected the Content-Type Header to be %q, but got %q",
			expectedContentType,
			res.Header.Get("Content-Type"),
		)
	}

	b, err := ioutil.ReadAll(res.Body)
	if err != nil {
		t.Fatalf("Reading response body failed: %s", err)
	}

	if string(b) != expectedGreetings {
		t.Errorf("Response body not as expected\nactual:\t%#v\nexpect:\t%#v", string(b), expectedGreetings)
	}
}
