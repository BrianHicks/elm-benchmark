ELM_FILES = $(shell find src -name '*.elm' -or -name '*.js')

documentation.json: ${ELM_FILES} elm-package.json
	./docs/spellcheck-ci.sh $(shell find src -name '*.elm')
	elm make --yes --warn --docs=$@

elm-ops-tooling:
	git clone https://github.com/NoRedInk/elm-ops-tooling

tests/elm-stuff: elm-ops-tooling
	cd tests; ../elm-ops-tooling/with_retry.rb elm package install --yes

examples/elm-stuff: elm-ops-tooling
	cd examples; ../elm-ops-tooling/with_retry.rb elm package install --yes

.PHONY: test
test: tests/elm-stuff
	elm-test

.PHONY: spellcheck
spellcheck: $(shell find src -name '*.elm')
	./docs/spellcheck.sh $(shell find src -name '*.elm')

examples/%.html: examples/% examples/elm-stuff ${ELM_FILES}
	cd examples; elm make --warn --yes --output $(shell basename $@) $(shell basename $<)

.PHONY: clean
clean:
	find . -name 'elm-stuff' -type d | xargs rm -rf
	find . -name '*.html' -type f -delete

.PHONY: publish_cli
publish_cli:
	npm publish $(shell npm pack --cwd cli)
