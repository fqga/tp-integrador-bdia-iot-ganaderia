-- particiones.sql
-- Particiones mensuales de MEDICIONES (tabla particionada por RANGE(timestamp) en schema.sql).
--
-- Se crea una partición por mes de 2026 (año de puesta en marcha del sistema y de los datos
-- de ejemplo) más una partición DEFAULT que captura cualquier timestamp fuera de ese rango
-- (por ejemplo, mediciones de prueba fechadas en 2025 o inserciones futuras antes de que se
-- cree la partición del mes correspondiente). La partición DEFAULT evita que un INSERT falle
-- por no encontrar partición: sin ella, PostgreSQL rechaza la fila.
--
-- Mantenimiento en producción: un job mensual (cron / pg_cron) debería crear la partición del
-- mes siguiente con anticipación y, opcionalmente, migrar filas nuevas fuera de DEFAULT hacia
-- su partición definitiva. Ver docs/04_arquitectura_datos.md para la estrategia de rotación y
-- purga de particiones antiguas.

CREATE TABLE mediciones_2026_01 PARTITION OF mediciones
  FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');

CREATE TABLE mediciones_2026_02 PARTITION OF mediciones
  FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');

CREATE TABLE mediciones_2026_03 PARTITION OF mediciones
  FOR VALUES FROM ('2026-03-01') TO ('2026-04-01');

CREATE TABLE mediciones_2026_04 PARTITION OF mediciones
  FOR VALUES FROM ('2026-04-01') TO ('2026-05-01');

CREATE TABLE mediciones_2026_05 PARTITION OF mediciones
  FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');

CREATE TABLE mediciones_2026_06 PARTITION OF mediciones
  FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');

CREATE TABLE mediciones_2026_07 PARTITION OF mediciones
  FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');

CREATE TABLE mediciones_2026_08 PARTITION OF mediciones
  FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');

CREATE TABLE mediciones_2026_09 PARTITION OF mediciones
  FOR VALUES FROM ('2026-09-01') TO ('2026-10-01');

CREATE TABLE mediciones_2026_10 PARTITION OF mediciones
  FOR VALUES FROM ('2026-10-01') TO ('2026-11-01');

CREATE TABLE mediciones_2026_11 PARTITION OF mediciones
  FOR VALUES FROM ('2026-11-01') TO ('2026-12-01');

CREATE TABLE mediciones_2026_12 PARTITION OF mediciones
  FOR VALUES FROM ('2026-12-01') TO ('2027-01-01');

-- Partición de respaldo: todo lo que no cae en un rango mensual explícito
-- (mediciones históricas anteriores a 2026, o de años futuros aún no particionados).
CREATE TABLE mediciones_default PARTITION OF mediciones DEFAULT;

COMMENT ON TABLE mediciones_default IS 'Partición de respaldo para timestamps fuera de los rangos mensuales definidos';
