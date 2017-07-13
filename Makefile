ELM_FILES = $(wildcard src/*.elm) $(wildcard src/**/*.elm) $(wildcard src/**/*.js)

documentation.json: ${ELM_FILES}
	elm make --yes --docs=$@

elm-ops-tooling:
	git clone https://github.com/NoRedInk/elm-ops-tooling

tests/elm-stuff: elm-ops-tooling
	cd tests; ../elm-ops-tooling/with_retry.rb elm package install --yes

examples/elm-stuff: elm-ops-tooling
	cd examples; ../elm-ops-tooling/with_retry.rb elm package install --yes

.PHONY: test
test: tests/elm-stuff
	elm-test

examples/%.html: examples/% examples/elm-stuff
	cd examples; elm make --yes --output $(shell basename $@) $(shell basename $<)

.PHONY: clean
clean:
	find . -name 'elm-stuff' -type d | xargs rm -rf
	find . -name '*.html' -type f -delete
