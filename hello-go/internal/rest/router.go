package rest

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"path"

	"github.com/fvosberg/kickstart/hello-go/internal"
	"github.com/gorilla/mux"
	"github.com/sirupsen/logrus"
)

//go:generate moq -out storage_moq_test.go . storage
type storage interface {
	Greetings(ctx context.Context) ([]internal.Greeting, error)
	SaveGreeting(ctx context.Context, g *internal.Greeting) error
}

func NewRouter(log *logrus.Logger, basePath string, repository storage) http.Handler {
	s := server{
		log:     log,
		storage: repository,
	}

	r := mux.NewRouter()

	// TODO subrouter?
	r.HandleFunc("/"+path.Join(basePath, "greetings"), s.serveCreateGreeting).Methods("POST")
	r.HandleFunc("/"+path.Join(basePath, "greetings"), s.serveGreetingsList).Methods("GET")
	// TODO check postgres
	r.HandleFunc("/"+path.Join(basePath, "internal/health"), s.serveHealthCheck).Methods("GET")

	r.NotFoundHandler = http.HandlerFunc(s.serveNotFound)
	r.MethodNotAllowedHandler = http.HandlerFunc(s.serveMethodNotAllowed)

	return r
}

type server struct {
	log     *logrus.Logger
	storage storage
}

func (s server) serveCreateGreeting(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")

	g, err := s.createGreeting(r)
	if errors.Is(err, badInputError{}) {
		s.writeError("create greetings endpoint", w, err, 400, 1593455104)
		return
	} else if err != nil {
		s.writeError("create greetings endpoint", w, err, 500, 1593453934)
		return
	}

	w.Header().Set("Location", "/greetings/"+g.UUID.String())
	w.WriteHeader(201)
	err = json.NewEncoder(w).Encode(g)
	if err != nil {
		s.log.WithError(err).Error("create greetings endpoint: encoding greeting response failed")
	}
}

func (s server) createGreeting(r *http.Request) (internal.Greeting, error) {
	var g internal.Greeting

	err := json.NewDecoder(r.Body).Decode(&g)
	if err != nil {
		return g, badInputf(err, "decoding request body")
	}

	err = s.storage.SaveGreeting(r.Context(), &g)
	if err != nil {
		return g, fmt.Errorf("saving: %w", err)
	}

	return g, nil
}

func (s server) serveGreetingsList(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")

	gg, err := s.storage.Greetings(r.Context())
	if err != nil {
		s.writeError("list greetings endpoint", w, err, 500, 1593458357)
		return
	}

	err = json.NewEncoder(w).Encode(gg)
	if err != nil {
		s.log.WithError(err).Error("create greetings endpoint: encoding greeting response failed")
	}

}

type badInputError struct {
	msg     string
	wrapped error
}

func (e badInputError) Error() string {
	return e.msg
}

func (e badInputError) Unwrap() error {
	return e.wrapped
}

func (e badInputError) Is(err error) bool {
	_, ok := err.(badInputError)
	return ok
}

func badInputf(err error, msg string, args ...interface{}) badInputError {
	return badInputError{
		msg:     fmt.Sprintf("%s: %s", fmt.Sprintf(msg, args...), err),
		wrapped: err,
	}
}

func (s server) serveNotFound(w http.ResponseWriter, r *http.Request) {
	err := fmt.Errorf("endpoint %s %s", r.Method, r.URL.String())
	s.writeError("Not Found Handler", w, err, 404, 1593621251)
}

func (s server) serveMethodNotAllowed(w http.ResponseWriter, r *http.Request) {
	err := fmt.Errorf("endpoint %s %s", r.Method, r.URL.String())
	s.writeError("Not Found Handler", w, err, 405, 1593621251)
}
func (s server) serveHealthCheck(w http.ResponseWriter, r *http.Request) {
	_, _ = w.Write([]byte(`{"status":"ok"}`))
}

func (s server) writeError(endpointName string, w http.ResponseWriter, err error, httpCode, errorCode int) {
	l := s.log.WithError(err)
	msg := http.StatusText(httpCode)
	if httpCode < 500 {
		l.Warningf("%s in %s", msg, endpointName)
		msg = fmt.Sprintf("%s: %s", msg, err.Error())
	} else {
		l.Errorf("%s in %s", msg, endpointName)
	}
	w.WriteHeader(httpCode)
	encodingError := json.NewEncoder(w).Encode(errorResponse{
		Err: responseError{
			Code: errorCode,
			Msg:  msg,
		},
	})
	if encodingError != nil {
		s.log.Errorf("encoding of error response failed in %s", endpointName)
	}
}

type errorResponse struct {
	Err responseError `json:"err"`
}

type responseError struct {
	Code int    `json:"code"`
	Msg  string `json:"msg"`
}
