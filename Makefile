ELM_FILES = $(shell find src -name '*.elm' -or -name '*.js')
NPM_BIN = $(shell npm bin)
ELM = env PATH=${NPM_BIN}:${PATH} elm

.PHONY: all
all: documentation.json test examples/Example.elm.html flow

# package management

elm-stuff: elm-package.json node_modules
	${ELM} package install --yes
	touch -m $@

%elm-stuff: elm-package.json node_modules
	cd $(@D); ${ELM} package install --yes
	touch -m $@

node_modules: package.json
	npm install
	touch -m $@

# Elm

documentation.json: ${ELM_FILES} elm-package.json node_modules
	${ELM} make --yes --warn --docs=$@

.PHONY: test
test: tests/elm-stuff node_modules
	${ELM} test

examples/%.html: examples/% examples/elm-stuff ${ELM_FILES} node_modules
	cd examples; ${ELM} make --warn --yes --output $(shell basename $@) $(shell basename $<)

# CLI

.PHONY: flow
flow: node_modules
	${NPM_BIN}/flow

# Linting

.PHONY: check-formatting
check-formatting: node_modules
	${ELM} format --validate $(shell find src tests -name '*.elm' -not -path '*elm-stuff*')
	${NPM_BIN}/prettier -l $(shell find src cli -name '*.js')

# Meta

.PHONY: clean
clean:
	rm -rf node_modules
	find . -name 'elm-stuff' -type d | xargs rm -rf
	find . -name '*.html' -type f -delete

.PHONY: spellcheck
spellcheck:
	./docs/spellcheck.sh $(shell find src -name '*.elm')
