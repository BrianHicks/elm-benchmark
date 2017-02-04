ELM_FILES = $(wildcard src/*.elm) $(wildcard src/**/*.elm) $(wildcard src/**/*.js)

documentation.json: ${ELM_FILES}
	elm make --docs=$@
