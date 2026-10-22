# ---------------------------------------------------------------
#  Hoshi Kitchen analytics - common tasks
#  make help   to list targets
# ---------------------------------------------------------------
export DBT_PROFILES_DIR := $(CURDIR)
TARGET ?= dev
PY     ?= python3

.PHONY: help install data deps seed build test lint fix docs serve-docs ci clean fresh

help:  ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

install:  ## Install Python dependencies + pre-commit hooks
	$(PY) -m pip install -r requirements.txt
	pre-commit install || true

data:  ## Generate synthetic raw POS/CRM exports into data/raw
	$(PY) scripts/generate_raw_data.py --out data/raw

deps:  ## Install dbt packages
	dbt deps

build: deps  ## Seed, snapshot, run and test everything (DAG order)
	dbt build --target $(TARGET)

test:  ## Run data tests + unit tests only
	dbt test --target $(TARGET)

lint:  ## Lint SQL models with sqlfluff
	sqlfluff lint models

fix:  ## Auto-fix lint issues
	sqlfluff fix models

docs:  ## Generate the dbt docs site
	dbt docs generate --target $(TARGET)

serve-docs: docs  ## Serve dbt docs at http://localhost:8080
	dbt docs serve --port 8080

ci: data deps  ## What GitHub Actions runs
	dbt build --target ci
	dbt docs generate --target ci

fresh: clean data build  ## Wipe everything and rebuild from scratch

clean:  ## Remove build artefacts and local warehouse
	dbt clean || true
	rm -f *.duckdb *.duckdb.wal
