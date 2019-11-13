# +-------------------------------------------------------------------------
# | Copyright (C) 2019 Yunify, Inc.
# +-------------------------------------------------------------------------
# | Licensed under the Apache License, Version 2.0 (the "License");
# | you may not use this work except in compliance with the License.
# | You may obtain a copy of the License in the LICENSE file, or at:
# |
# | http://www.apache.org/licenses/LICENSE-2.0
# |
# | Unless required by applicable law or agreed to in writing, software
# | distributed under the License is distributed on an "AS IS" BASIS,
# | WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# | See the License for the specific language governing permissions and
# | limitations under the License.
# +-------------------------------------------------------------------------

.PHONY: all

PACKAGE_LIST=./cmd/... ./pkg/...
EMPTY_MODE=true

fmt:
	go fmt ${PACKAGE_LIST}

mod:
	go build ./...
	go mod download
	go mod tidy

qkeadm:
	go build -o _output/qkeadm cmd/qkeadm/qkeadm.go

tar: qkeadm
	rm -rf config
	_output/qkeadm generate configdir --enableemptymode ${EMPTY_MODE} --kvmid img-w1e9oiyv --kvmzone sh1a --dir _output/config
	$(shell cd _output && tar -cf config.tar config)

clean:
	go clean -r -x ./...
	rm -rf ./_output