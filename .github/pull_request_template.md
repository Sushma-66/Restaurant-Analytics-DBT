## What changed and why

<!-- One or two sentences. Link the ticket if there is one. -->

## Models touched

- [ ] staging
- [ ] intermediate
- [ ] marts (contract-enforced models need a version bump if columns are removed/renamed)

## Checklist

- [ ] `dbt build` passes locally
- [ ] New models have a description and at least `unique` + `not_null` on the primary key
- [ ] `sqlfluff lint models` is clean
- [ ] Downstream exposures checked (`dbt ls -s +exposure:*`)
