ELM_FILES = $(shell find src -name '*.elm' -or -name '*.js')
NPM_BIN = $(shell npm bin)
ELM = env PATH=${NPM_BIN}:${PATH} elm

documentation.json: ${ELM_FILES} elm-package.json node_modules
	./docs/spellcheck-ci.sh $(shell find src -name '*.elm')
	${ELM} make --yes --warn --docs=$@

elm-ops-tooling:
	git clone https://github.com/NoRedInk/elm-ops-tooling

elm-stuff: elm-package.json node_modules
	${ELM} package install --yes
	touch -m $@

tests/elm-stuff: tests/elm-package.json elm-ops-tooling node_modules
	cd tests; ${ELM} package install --yes
	touch -m $@

examples/elm-stuff: examples/elm-package.json elm-ops-tooling node_modules
	cd examples; ${ELM} package install --yes
	touch -m $@

node_modules: package.json
	npm install
	touch -m $@

.PHONY: test
test: tests/elm-stuff node_modules
	${ELM} test

.PHONY: check-formatting
check-formatting: node_modules
	${ELM} format --validate $(shell find src tests -name '*.elm' -not -path '*elm-stuff*')
	${NPM_BIN}/prettier -l $(shell find src cli -name '*.js')

.PHONY: spellcheck
spellcheck: $(shell find src -name '*.elm')
	./docs/spellcheck.sh $(shell find src -name '*.elm')

examples/%.html: examples/% examples/elm-stuff ${ELM_FILES} node_modules
	cd examples; ${ELM} make --warn --yes --output $(shell basename $@) $(shell basename $<)

.PHONY: clean
clean:
	rm -rf node_modules
	find . -name 'elm-stuff' -type d | xargs rm -rf
	find . -name '*.html' -type f -delete

.PHONY: flow
flow: node_modules
	${NPM_BIN}/flow
