package util

import (
	"bytes"
	"text/template"

	"github.com/pkg/errors"
)

// ParseTemplate validates and parses passed as argument template
func ParseTemplate(strtmpl string, obj interface{}) ([]byte, error) {
	var buf bytes.Buffer
	tmpl, err := template.New("template").Parse(strtmpl)
	if err != nil {
		return nil, errors.Wrap(err, "error when parsing template")
	}
	err = tmpl.Execute(&buf, obj)
	if err != nil {
		return nil, errors.Wrap(err, "error when executing template")
	}
	return buf.Bytes(), nil
}
