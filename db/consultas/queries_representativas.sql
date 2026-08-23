-- queries_representativas.sql
-- Consultas representativas del caso de uso "Monitoreo IoT con análisis predictivo".
-- Todas fueron probadas contra los datos de ejemplo (data/ejemplos/datos_simulados.sql).
--
-- Para reproducir el aislamiento multi-tenant en las consultas que lo requieren, conectarse
-- como app_user (no como postgres, que es superusuario y bypassea RLS) y fijar la estancia:
--   SET app.estancia_id = 1;
-- Ver README.md, sección "Probar el aislamiento multi-tenant (RLS)".

-- =====================================================================================
-- 1. Consumo total y promedio de cada animal en los últimos 7 días
-- =====================================================================================
-- Pregunta que responde: ¿cuánto consumió cada animal esta semana y cuántas veces se
-- registró en el comedero? Es la consulta base que ve un encargado al empezar el día.
-- Filtrado (WHERE por rango de fecha) + JOIN + agregación (SUM/COUNT/AVG) + GROUP BY.
SET app.estancia_id = 1;

SELECT
  a.id AS animal_id,
  a.nombre_alias,
  a.tag_rfid,
  a.estado_salud,
  COUNT(m.id) AS eventos_registrados,
  ROUND(SUM(m.valor_medido), 2) AS consumo_total_7_dias_kg,
  ROUND(AVG(m.valor_medido), 2) AS consumo_promedio_kg,
  ROUND(STDDEV(m.valor_medido), 2) AS desviacion_estandar
FROM animales a
JOIN mediciones m ON m.animal_id = a.id
WHERE m.timestamp > NOW() - INTERVAL '7 days'
GROUP BY a.id, a.nombre_alias, a.tag_rfid, a.estado_salud
ORDER BY consumo_total_7_dias_kg ASC;

-- =====================================================================================
-- 2. Animales con consumo actual significativamente por debajo de su propio histórico
-- =====================================================================================
-- Pregunta que responde: ¿qué animales están comiendo menos de lo habitual *para ellos
-- mismos* (no contra un umbral fijo para todo el rodeo)? Es la base de la detección
-- temprana de problemas de salud descripta en el caso de uso. Compara el promedio de las
-- últimas 24 horas contra el promedio de los 7 días previos mediante dos CTEs.
WITH consumo_reciente AS (
  SELECT animal_id, AVG(valor_medido) AS promedio_24h
  FROM mediciones
  WHERE timestamp > NOW() - INTERVAL '24 hours'
  GROUP BY animal_id
),
consumo_historico AS (
  SELECT animal_id, AVG(valor_medido) AS promedio_7_dias, STDDEV(valor_medido) AS desvio_7_dias
  FROM mediciones
  WHERE timestamp BETWEEN NOW() - INTERVAL '8 days' AND NOW() - INTERVAL '1 day'
  GROUP BY animal_id
)
SELECT
  a.id AS animal_id,
  a.nombre_alias,
  a.estado_salud,
  ROUND(h.promedio_7_dias, 2) AS promedio_historico_kg,
  ROUND(r.promedio_24h, 2) AS promedio_actual_kg,
  ROUND(100 * (r.promedio_24h - h.promedio_7_dias) / NULLIF(h.promedio_7_dias, 0), 1) AS variacion_pct
FROM animales a
JOIN consumo_reciente r ON r.animal_id = a.id
JOIN consumo_historico h ON h.animal_id = a.id
WHERE r.promedio_24h < h.promedio_7_dias - 1.5 * COALESCE(h.desvio_7_dias, 0)
ORDER BY variacion_pct ASC;

-- =====================================================================================
-- 3. Consumo promedio por ubicación (comparación entre corrales)
-- =====================================================================================
-- Pregunta que responde: ¿hay corrales con consumo sistemáticamente distinto? Útil para
-- detectar problemas de un comedero puntual (no de un animal) o de manejo de un sector.
-- JOIN de 3 niveles (mediciones -> dispositivos -> ubicaciones) + agregación.
SELECT
  u.id AS ubicacion_id,
  u.nombre AS ubicacion,
  u.tipo,
  COUNT(DISTINCT m.animal_id) AS animales_distintos,
  COUNT(m.id) AS eventos_registrados,
  ROUND(AVG(m.valor_medido), 2) AS consumo_promedio_kg,
  ROUND(AVG(m.temperatura_ambiental_celsius), 1) AS temperatura_promedio
FROM ubicaciones u
JOIN dispositivos d ON d.ubicacion_id = u.id
JOIN mediciones m ON m.dispositivo_id = d.id
WHERE m.timestamp > NOW() - INTERVAL '21 days'
GROUP BY u.id, u.nombre, u.tipo
ORDER BY consumo_promedio_kg DESC;

-- =====================================================================================
-- 4. Alertas sin resolver, priorizadas por severidad y antigüedad
-- =====================================================================================
-- Pregunta que responde: ¿qué casos abiertos hay que atender primero? Es la consulta que
-- alimenta la bandeja de trabajo de peones/veterinarios. Usa el índice parcial
-- idx_alertas_estado_timestamp (WHERE estado IN ('abierta','en_progreso')), que evita
-- escanear alertas ya resueltas -- son la mayoría a medida que el sistema acumula historia.
SELECT
  al.id,
  al.tipo_alerta,
  al.severidad,
  a.nombre_alias AS animal,
  d.serial_hardware AS dispositivo,
  al.descripcion,
  al.timestamp_alerta,
  NOW() - al.timestamp_alerta AS tiempo_abierta
FROM alertas al
LEFT JOIN animales a ON a.id = al.animal_id
LEFT JOIN dispositivos d ON d.id = al.dispositivo_id
WHERE al.estado IN ('abierta', 'en_progreso')
ORDER BY
  CASE al.severidad
    WHEN 'critica' THEN 1
    WHEN 'alta' THEN 2
    WHEN 'media' THEN 3
    ELSE 4
  END,
  al.timestamp_alerta ASC;

-- =====================================================================================
-- 5. Búsqueda por similitud: animales con patrón de consumo parecido al de un animal dado
-- =====================================================================================
-- Pregunta que responde: dado un animal con un embedding de patrón de consumo reciente,
-- ¿qué otros animales tuvieron un patrón similar? Sirve tanto para encontrar "animales de
-- referencia" sanos comparables como para detectar si una anomalía es aislada o si varios
-- animales del mismo corral empezaron a comportarse parecido (posible foco sanitario).
-- Usa el operador <=> (distancia coseno) de pgvector sobre el índice ivfflat
-- idx_mediciones_embedding; 1 - distancia = similitud coseno (1 = idéntico).
WITH referencia AS (
  SELECT embedding_patron, timestamp
  FROM mediciones
  WHERE animal_id = 5 AND embedding_patron IS NOT NULL
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
  AND m.animal_id != 5
ORDER BY m.embedding_patron <=> r.embedding_patron
LIMIT 5;

-- =====================================================================================
-- 6. Desviación de cada medición respecto al promedio móvil del animal (función de ventana)
-- =====================================================================================
-- Pregunta que responde: para un animal puntual, ¿cómo evolucionó su consumo medición a
-- medición comparado con su propio promedio móvil de 5 eventos? Es la vista "de detalle"
-- a la que un veterinario entra después de ver la alerta de la consulta 4.
SELECT
  m.timestamp,
  m.valor_medido,
  ROUND(AVG(m.valor_medido) OVER (
    ORDER BY m.timestamp
    ROWS BETWEEN 4 PRECEDING AND CURRENT ROW
  ), 2) AS promedio_movil_5_eventos,
  m.es_anomalia
FROM mediciones m
WHERE m.animal_id = 5
ORDER BY m.timestamp DESC
LIMIT 20;

-- =====================================================================================
-- 7. Alertas activas por estancia y severidad (usa la vista alertas_activas_por_estancia)
-- =====================================================================================
-- Pregunta que responde: panorama ejecutivo multi-estancia -- ¿cuántas alertas críticas hay
-- abiertas en cada unidad de negocio ahora mismo? Pensada para un rol admin de plataforma,
-- que sí necesita ver todas las estancias (por eso se ejecuta como postgres/superusuario,
-- no como app_user: es la excepción intencional a la regla de aislamiento por RLS).
SELECT * FROM alertas_activas_por_estancia
ORDER BY criticas DESC, sin_resolver DESC;

-- =====================================================================================
-- 8. Historial completo de un caso: mediciones y alertas de un animal en tratamiento
-- =====================================================================================
-- Pregunta que responde: reconstrucción completa del caso de un animal para el veterinario
-- (auditoría/trazabilidad) -- todas sus mediciones anómalas y las alertas que generaron,
-- en una sola línea de tiempo.
SELECT
  'medicion' AS origen,
  m.timestamp AS momento,
  m.valor_medido::text AS detalle,
  m.es_anomalia AS es_relevante
FROM mediciones m
WHERE m.animal_id = 5 AND m.es_anomalia = TRUE
UNION ALL
SELECT
  'alerta' AS origen,
  al.timestamp_alerta AS momento,
  al.tipo_alerta || ' (' || al.severidad || '): ' || al.descripcion AS detalle,
  TRUE AS es_relevante
FROM alertas al
WHERE al.animal_id = 5
ORDER BY momento;
