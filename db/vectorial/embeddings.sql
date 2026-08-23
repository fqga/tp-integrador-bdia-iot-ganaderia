-- embeddings.sql
-- Funciones auxiliares para trabajar con mediciones.embedding_patron (pgvector).
-- Requiere que db/estructura/schema.sql, particiones.sql, indexes.sql y rls.sql ya se hayan
-- ejecutado (usa las tablas mediciones/animales y respeta RLS al ejecutarse como app_user).

-- Devuelve los N animales cuyo patrón de consumo más reciente es más parecido (similitud
-- coseno) al patrón más reciente de un animal de referencia. Encapsula la lógica de la
-- consulta representativa #5 (db/consultas/queries_representativas.sql) como función
-- reutilizable, para no repetir la subconsulta de "último embedding del animal" en cada
-- lugar de la aplicación que la necesite.
CREATE OR REPLACE FUNCTION animales_similares(p_animal_id BIGINT, p_limite INT DEFAULT 5)
RETURNS TABLE (
  animal_id BIGINT,
  nombre_alias VARCHAR,
  estado_salud VARCHAR,
  timestamp_patron TIMESTAMP,
  similitud_coseno NUMERIC
) AS $$
  WITH referencia AS (
    SELECT embedding_patron
    FROM mediciones
    WHERE animal_id = p_animal_id AND embedding_patron IS NOT NULL
    ORDER BY timestamp DESC
    LIMIT 1
  )
  SELECT
    m.animal_id,
    a.nombre_alias,
    a.estado_salud,
    m.timestamp,
    ROUND((1 - (m.embedding_patron <=> r.embedding_patron))::numeric, 4) AS similitud_coseno
  FROM mediciones m
  JOIN animales a ON a.id = m.animal_id
  CROSS JOIN referencia r
  WHERE m.embedding_patron IS NOT NULL
    AND m.animal_id != p_animal_id
  ORDER BY m.embedding_patron <=> r.embedding_patron
  LIMIT p_limite;
$$ LANGUAGE sql STABLE;

COMMENT ON FUNCTION animales_similares IS
  'Ranking de animales con patrón de consumo más similar (coseno, pgvector) al último patrón '
  'registrado de p_animal_id. RLS de mediciones/animales se aplica normalmente porque la '
  'función es SQL (no SECURITY DEFINER): corre con los permisos del rol que la invoca.';

GRANT EXECUTE ON FUNCTION animales_similares(BIGINT, INT) TO app_user;

-- Ejemplo de uso:
--   SET app.estancia_id = 1;
--   SELECT * FROM animales_similares(5, 5);
