-- Sostituisci 'spartiti_andr' e 'primolink' con i nomi reali della tua tabella e colonna
WITH RECURSIVE
  -- Step 1: Normalizza i percorsi
  NormalizedPaths AS (
    SELECT
      primolink,
      REPLACE(primolink, '\', '/') AS norm_path
    FROM
      spartiti_andr
    WHERE
      primolink IS NOT NULL AND primolink != ''
  ),
  -- Step 2 (Ricorsivo): Trova la posizione di TUTTI i '/' in ogni percorso
  Slashes(norm_path, slash_pos) AS (
    SELECT
      norm_path,
      INSTR(norm_path, '/')
    FROM
      NormalizedPaths
    UNION ALL
    SELECT
      norm_path,
      INSTR(SUBSTR(norm_path, slash_pos + 1), '/') + slash_pos
    FROM
      Slashes
    WHERE
      INSTR(SUBSTR(norm_path, slash_pos + 1), '/') > 0
  ),
  -- Step 3: Trova l'ULTIMA posizione di '/' per ogni percorso
  LastSlash AS (
    SELECT
      norm_path,
      MAX(slash_pos) AS last_slash_pos
    FROM
      Slashes
    GROUP BY
      norm_path
  ),
  -- Step 4: Calcola gli indici finali
  FinalIndexes AS (
    SELECT
      np.primolink,
      np.norm_path,
      ls.last_slash_pos,
      INSTR(np.norm_path, 'JamsetPDF/') + LENGTH('JamsetPDF/') AS perc_resto_start
    FROM
      NormalizedPaths np
      JOIN LastSlash ls ON np.norm_path = ls.norm_path
  )
-- Step 5: Estrai le sottostringhe finali
SELECT
  primolink,
  SUBSTR(norm_path, last_slash_pos + 1) AS Volume,
  SUBSTR(norm_path, perc_resto_start, last_slash_pos - perc_resto_start) AS PercResto
FROM
  FinalIndexes;