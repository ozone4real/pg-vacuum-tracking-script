-- \set relname 'users' --
WITH vacuum_params AS (
      WITH relation_params AS (
            SELECT
                  split_part(unnest(reloptions), '=', 1) setting,
                  split_part(unnest(reloptions), '=', 2) value
            FROM
                  pg_class
            WHERE
                  relname = :'relname'
      ),
      params AS (
            SELECT
                  a.setting,
                  COALESCE(
                        relation_params.value,
                        current_setting(a.setting)
                  ) value
            FROM
                  unnest(
                        ARRAY [
      'autovacuum_vacuum_insert_scale_factor',
      'autovacuum_vacuum_insert_threshold',
      'autovacuum_vacuum_scale_factor',
      'autovacuum_vacuum_threshold',
      'autovacuum_analyze_threshold',
      'autovacuum_analyze_scale_factor'
    ]
                  ) AS a(setting)
                  LEFT JOIN relation_params USING (setting)
      )
      SELECT
            MAX(
                  CASE
                        WHEN setting = 'autovacuum_vacuum_scale_factor' THEN value :: float
                  END
            ) AS autovacuum_vacuum_scale_factor,
            MAX(
                  CASE
                        WHEN setting = 'autovacuum_vacuum_threshold' THEN value :: integer
                  END
            ) AS autovacuum_vacuum_threshold,
            MAX(
                  CASE
                        WHEN setting = 'autovacuum_vacuum_insert_threshold' THEN value :: integer
                  END
            ) AS autovacuum_vacuum_insert_threshold,
            MAX(
                  CASE
                        WHEN setting = 'autovacuum_vacuum_insert_scale_factor' THEN value :: float
                  END
            ) AS autovacuum_vacuum_insert_scale_factor,
            MAX(
                  CASE
                        WHEN setting = 'autovacuum_analyze_threshold' THEN value :: integer
                  END
            ) AS autovacuum_analyze_threshold,
            MAX(
                  CASE
                        WHEN setting = 'autovacuum_analyze_scale_factor' THEN value :: float
                  END
            ) AS autovacuum_analyze_scale_factor
      FROM
            params
)
SELECT
      pg_class.relname table_name,
      greatest(last_autovacuum, last_vacuum) last_vacuum,
      greatest(last_autoanalyze, last_analyze) last_analyze,
      reltuples estimated_no_of_rows_in_table,
      (n_dead_tup / reltuples :: float) * 100 bloat_percentage,
      n_dead_tup dead_tuples,
      n_mod_since_analyze modified_tuples_since_last_analyze,
      n_ins_since_vacuum inserted_tuples_since_last_vacuum,
      round(
            autovacuum_vacuum_threshold + (autovacuum_vacuum_scale_factor * reltuples)
      ) - n_dead_tup updates_and_deletes_till_next_autovacuum,
      round(
            autovacuum_analyze_threshold + (autovacuum_analyze_scale_factor * reltuples)
      ) - n_mod_since_analyze modifcations_till_next_autoanalyze,
      round(
            autovacuum_vacuum_insert_threshold + (
                  autovacuum_vacuum_insert_scale_factor * reltuples
            )
      ) - n_ins_since_vacuum inserts_till_next_autovacuum
FROM
      pg_stat_user_tables,
      vacuum_params,
      pg_class
WHERE
      pg_stat_user_tables.relname = :'relname'
      AND pg_class.relname = :'relname';