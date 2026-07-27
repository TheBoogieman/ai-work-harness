# SQL-Writing — SKILL.md

## WHEN TO USE
Reach for this module when the task is to write, refactor, or review a SQL query or a dbt model:
any `SELECT`/`JOIN`/CTE work, an aggregation or window function, a transformation model, or debugging
a query that returns the wrong rows or the wrong count. Trigger keywords: sql, query, select, join,
cte, window, aggregation, dbt model, warehouse query. Dialect-agnostic — the guidance holds across
Postgres, BigQuery, Snowflake, Redshift, and dbt-compiled SQL.

## CRAFT GUIDANCE
- Lead with CTEs, not nested subqueries: name each step (`with filtered as (...), joined as (...)`)
  so the query reads top-to-bottom as a pipeline. One transformation per CTE.
- Select explicit columns, never `SELECT *`, in anything another query or a model depends on — `*`
  makes the output schema drift silently when a source column is added or dropped.
- Qualify every column with its table or CTE alias in a multi-table query; an unqualified column is a
  bug waiting for two sources to grow a column of the same name.
- Filter early, on the indexed or partitioned column where the engine has one: push predicates into
  the CTE that first touches the table, not the final SELECT.
- Be explicit about JOIN grain: know the key you are joining on and whether it is unique on each side.
  A fan-out join that silently multiplies rows is the most common wrong-count bug.
- Prefer readable set-based logic over cleverness; a correlated subquery a JOIN or window can express
  is usually slower and harder to reason about.
- In dbt, reference upstream models with `ref()` and raw tables with `source()` rather than hard-coded
  names, and keep one model at one grain — the grain is the model's contract.

## NAMED TOOLS
Check each named tool exists before relying on it; if it is absent, degrade gracefully to guidance-only
(residual constraints declared, never assumed). TOOLS ADVISE, NEVER GATE: lint and compile output is
craft feedback for you to heed — it never gates a commit, reddens a check, or blocks a flow.

- `sqlfluff lint <path/to/query.sql> --dialect <dialect>` — style and lint the SQL for a dialect.
  Absent? Apply the CRAFT GUIDANCE by hand (CTEs, explicit columns, aliasing) and note that lint was skipped.
- `sqlfluff fix <path/to/query.sql> --dialect <dialect>` — auto-apply the fixable lint rules; review the diff before keeping it.
- `dbt compile --select <model>` — render a model's final SQL without running it, to inspect what will execute.
- `dbt build --select <model>` — run the model and its tests; read the test output as feedback, never as a merge gate.

Last reviewed: 2026-07-23
