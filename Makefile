debug:
	go run cmd/main.go -O usr-MRiIUq7M -R appv-tzssw6ay -f app/app.tar.gz
build:
	go build -o bin/upload-app cmd/main.go