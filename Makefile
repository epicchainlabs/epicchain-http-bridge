#!/usr/bin/make -f

SHELL = bash

VERSION ?= "$(shell git describe --tags --match "v*" --abbrev=8 2>/dev/null | sed -r 's,^v([0-9]+\.[0-9]+)\.([0-9]+)(-.*)?$$,\1 \2 \3,' | while read mm patch suffix; do if [ -z "$$suffix" ]; then echo $$mm.$$patch; else patch=`expr $$patch + 1`; echo $$mm.$${patch}-pre$$suffix; fi; done)"
SITE_DIR ?= send.fs.neo.org
RELEASE_DIR ?= $(SITE_DIR)-$(VERSION)
RELEASE_PATH ?= $(SITE_DIR)-$(VERSION).tar.gz
CURRENT_UID ?=  $(shell id -u $$USER)

PORT = 3000

$(SITE_DIR):
	docker run \
	-v $$(pwd)/src:/usr/src/app/src \
	-v $$(pwd)/public:/usr/src/app/public \
	-v $$(pwd)/package.json:/usr/src/app/package.json \
	-v $$(pwd)/.env:/usr/src/app/.env \
	-v $$(pwd)/$(SITE_DIR):/usr/src/app/$(SITE_DIR) \
	-e CURRENT_UID=$(CURRENT_UID) \
	-w /usr/src/app node:14-alpine \
	sh -c 'npm install && REACT_APP_VERSION=$(VERSION) npm run build && chown -R $$CURRENT_UID: $(SITE_DIR)'

start:
	docker run \
	-p $(PORT):3000 \
	-v `pwd`:/usr/src/app \
	-w /usr/src/app node:14-alpine \
	sh -c 'npm install --silent && npm run build && npm install -g serve && serve -s $(SITE_DIR) -p 3000'

release: $(SITE_DIR)
	cp $(SITE_DIR)/index.html $(SITE_DIR)/agreement
	@ln -sf $(SITE_DIR) $(RELEASE_DIR)
	@tar cfvhz $(RELEASE_PATH) $(RELEASE_DIR)

clean:
	@echo "Cleaning up ..."
	@rm -rf $(SITE_DIR) $(RELEASE_DIR) $(RELEASE_PATH)

release_name:
	@echo $(RELEASE_PATH)

version:
	@echo $(VERSION)
