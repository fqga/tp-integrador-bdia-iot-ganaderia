-- datos_simulados.sql
-- Datos de ejemplo para pruebas de la base de datos.
--
-- Estructura de este archivo:
--   1. Entidades de catálogo (estancias, usuarios, ubicaciones, dispositivos, sensores, animales)
--   2. Mediciones históricas (21 días previos, generadas con generate_series) para que las
--      consultas de tendencia y el trigger de detección de anomalías tengan una línea base
--      real. El animal 5 tiene una caída de consumo progresiva en los últimos 7 días,
--      simulando un cuadro de enfermedad detectable.
--   3. Mediciones "de hoy" (últimas ~24 horas), escritas a mano como ejemplos legibles.
--   4. Vectores de patrón de consumo (embedding_patron) de ejemplo sobre una medición
--      representativa por animal y día. Son vectores sintéticos (no generados por un modelo
--      real de embeddings): a los animales sanos se les asigna un vector con valores bajos en
--      todas las dimensiones; al animal enfermo, un vector con valores altos en los últimos 7
--      días. Esto alcanza para demostrar que una consulta de similitud por coseno agrupa a los
--      animales sanos entre sí y separa al enfermo — ver vectorial/modelo_vectorial.md.
--   5. Alertas generadas manualmente (además de las que el trigger genera automáticamente).
--
-- Todas las fechas son relativas a NOW()/CURRENT_DATE, no fechas fijas, para que el script
-- sea reproducible sin importar cuándo se ejecute.

SELECT setseed(0.42);

-- =====================================================================================
-- 1. ESTANCIAS
-- =====================================================================================
INSERT INTO estancias (id, nombre, descripcion, ubicacion_ciudad, ubicacion_provincia, tipo_produccion, contacto_responsable, activa)
VALUES
  (1, 'Estancia Las Flores', 'Producción de ganado de engorde', 'Tucumán', 'Tucumán', 'engorde', 'Juan Pérez', TRUE),
  (2, 'Ganadería San José', 'Producción lechera', 'Córdoba', 'Córdoba', 'lechería', 'María García', TRUE);

-- =====================================================================================
-- 2. USUARIOS
-- =====================================================================================
INSERT INTO usuarios (id, estancia_id, nombre, email, contraseña_hash, rol, activo)
VALUES
  (1, 1, 'Facundo Gómez', 'facundo@estancia.com', 'hash_bcrypt_1', 'admin', TRUE),
  (2, 1, 'Carlos López', 'carlos@estancia.com', 'hash_bcrypt_2', 'encargado', TRUE),
  (3, 1, 'José Martínez', 'jose@estancia.com', 'hash_bcrypt_3', 'peón', TRUE),
  (4, 1, 'Dr. Rodriguez', 'veterinario@estancia.com', 'hash_bcrypt_4', 'veterinario', TRUE),
  (5, 2, 'Ana Fernández', 'ana@sanjose.com', 'hash_bcrypt_5', 'admin', TRUE),
  (6, 2, 'Lucas Torres', 'lucas@sanjose.com', 'hash_bcrypt_6', 'peón', TRUE);

-- =====================================================================================
-- 3. UBICACIONES
-- =====================================================================================
INSERT INTO ubicaciones (id, estancia_id, nombre, tipo, descripcion, capacidad_animales, area_metros_cuadrados, responsable_usuario_id, activa)
VALUES
  (1, 1, 'Corral A', 'corral', 'Corral principal de engorde', 150, 5000.00, 2, TRUE),
  (2, 1, 'Corral B', 'corral', 'Corral secundario', 120, 4000.00, 2, TRUE),
  (3, 1, 'Encierre', 'encierre', 'Área de concentración', 200, 6000.00, 3, TRUE),
  (4, 1, 'Peseada', 'peseada', 'Área de pesaje', 50, 1500.00, 2, TRUE),
  (5, 2, 'Corral Lechería', 'corral', 'Área de ordeño', 100, 3500.00, 5, TRUE);

-- =====================================================================================
-- 4. DISPOSITIVOS (comederos y bebederos)
-- =====================================================================================
INSERT INTO dispositivos (id, serial_hardware, ubicacion_id, tipo_dispositivo, modelo, fabricante, fecha_instalacion, estado, configuracion)
VALUES
  (1, 'DEV-001-A', 1, 'comedero', 'FeedTrack Pro v2', 'FeedTech Industries', '2026-01-15', 'operacional', '{"calibracion_pesaje": 0.98, "umbral_presencia_kg": 100, "intervalo_reporte": 60}'),
  (2, 'DEV-002-A', 1, 'bebedero', 'WaterFlow 3000', 'AquaSense', '2026-01-20', 'operacional', '{"flujo_maximo_lpm": 50, "sensibilidad_presencia": "media"}'),
  (3, 'DEV-003-B', 2, 'comedero', 'FeedTrack Pro v2', 'FeedTech Industries', '2026-02-01', 'operacional', '{"calibracion_pesaje": 0.99, "umbral_presencia_kg": 100, "intervalo_reporte": 60}'),
  (4, 'DEV-004-B', 2, 'bebedero', 'WaterFlow 3000', 'AquaSense', '2026-02-05', 'operacional', '{"flujo_maximo_lpm": 50, "sensibilidad_presencia": "media"}'),
  (5, 'DEV-005-C', 3, 'comedero', 'FeedTrack Pro v2', 'FeedTech Industries', '2026-02-10', 'operacional', '{"calibracion_pesaje": 0.97, "umbral_presencia_kg": 150, "intervalo_reporte": 60}'),
  (6, 'DEV-006-E', 5, 'comedero', 'FeedTrack Pro v2', 'FeedTech Industries', '2026-01-25', 'operacional', '{"calibracion_pesaje": 0.98, "umbral_presencia_kg": 80, "intervalo_reporte": 60}');

-- =====================================================================================
-- 5. SENSORES
-- =====================================================================================
INSERT INTO sensores (id, dispositivo_id, tipo_sensor, unidad_medida, rango_minimo, rango_maximo, precision_declarada, estado, activo)
VALUES
  (1, 1, 'pesaje', 'kg', 0, 100, 0.05, 'operacional', TRUE),
  (2, 1, 'rfid', 'codigo', 0, 1000, 0.01, 'operacional', TRUE),
  (3, 1, 'temperatura', 'celsius', -40, 50, 0.5, 'operacional', TRUE),
  (4, 2, 'pesaje', 'litros', 0, 500, 0.1, 'operacional', TRUE),
  (5, 3, 'pesaje', 'kg', 0, 100, 0.05, 'operacional', TRUE),
  (6, 3, 'rfid', 'codigo', 0, 1000, 0.01, 'operacional', TRUE),
  (7, 4, 'pesaje', 'litros', 0, 500, 0.1, 'operacional', TRUE),
  (8, 5, 'pesaje', 'kg', 0, 150, 0.05, 'operacional', TRUE),
  (9, 5, 'rfid', 'codigo', 0, 1000, 0.01, 'operacional', TRUE),
  (10, 6, 'pesaje', 'kg', 0, 100, 0.05, 'operacional', TRUE),
  (11, 6, 'rfid', 'codigo', 0, 1000, 0.01, 'operacional', TRUE);

-- =====================================================================================
-- 6. ANIMALES
-- =====================================================================================
INSERT INTO animales (id, estancia_id, tag_rfid, nombre_alias, raza, sexo, fecha_nacimiento, peso_actual_kg, estado_salud, ubicacion_actual_id, fecha_ingreso_estancia)
VALUES
  (1, 1, '9E-54-3F-AB-CD-01', 'Blanca', 'Hereford', 'hembra', '2024-06-15', 450.00, 'sano', 1, '2026-01-01'),
  (2, 1, '9E-54-3F-AB-CD-02', 'Negra', 'Hereford', 'hembra', '2024-07-20', 480.00, 'sano', 1, '2026-01-10'),
  (3, 1, '9E-54-3F-AB-CD-03', 'Rojo', 'Aberdeen Angus', 'macho', '2024-05-10', 520.00, 'sano', 1, '2025-12-20'),
  (4, 1, '9E-54-3F-AB-CD-04', 'Manchado', 'Charolés', 'macho', '2024-08-01', 410.00, 'sano', 2, '2026-02-01'),
  (5, 1, '9E-54-3F-AB-CD-05', 'Oscuro', 'Hereford', 'macho', '2024-06-25', 460.00, 'en_tratamiento', 2, '2026-01-15'),
  (6, 1, '9E-54-3F-AB-CD-06', 'Claro', 'Aberdeen Angus', 'hembra', '2024-07-10', 420.00, 'sano', 1, '2026-01-20'),
  (7, 2, '7A-11-2C-DE-FF-07', 'Estrella', 'Holando', 'hembra', '2023-11-05', 560.00, 'sano', 5, '2026-01-25'),
  (8, 2, '7A-11-2C-DE-FF-08', 'Luna', 'Holando', 'hembra', '2024-01-12', 540.00, 'sano', 5, '2026-01-25');

-- =====================================================================================
-- 7. MEDICIONES HISTÓRICAS (21 días previos, 2 eventos/día por animal: 08:00 y 18:00)
-- =====================================================================================
-- El animal 5 (en_tratamiento) tiene una caída de consumo progresiva en los últimos 7 días
-- (de ~12kg a ~5kg), simulando el cuadro que dispara las alertas. El resto varía ±12% sobre
-- su consumo base, ruido normal de un animal sano.
INSERT INTO mediciones (id, dispositivo_id, sensor_id, animal_id, timestamp, valor_medido, duracion_evento_segundos, temperatura_ambiental_celsius, humedad_ambiental_pct)
SELECT
  row_number() OVER (ORDER BY t.ts) AS id,
  cfg.dispositivo_id,
  cfg.sensor_id,
  cfg.animal_id,
  t.ts,
  ROUND(
    (CASE
      WHEN cfg.animal_id = 5 AND dias_atras.n <= 7 THEN
        GREATEST(4.5, cfg.base_valor - (7 - dias_atras.n) * 1.05) + (random() - 0.5) * 0.6
      ELSE
        cfg.base_valor + (random() - 0.5) * cfg.base_valor * 0.12
    END)::numeric, 2
  ) AS valor_medido,
  (600 + random() * 500)::int AS duracion_evento_segundos,
  ROUND((15 + random() * 15)::numeric, 1) AS temperatura_ambiental_celsius,
  ROUND((45 + random() * 30)::numeric, 1) AS humedad_ambiental_pct
FROM (VALUES
    (1, 1, 1, 12.5),
    (2, 1, 1, 13.0),
    (3, 1, 1, 14.0),
    (6, 1, 1, 12.0),
    (4, 3, 5, 11.8),
    (5, 3, 5, 12.0),
    (7, 6, 10, 9.5),
    (8, 6, 10, 10.2)
  ) AS cfg(animal_id, dispositivo_id, sensor_id, base_valor)
CROSS JOIN generate_series(21, 1, -1) AS dias_atras(n)
CROSS JOIN unnest(ARRAY[8, 18]) AS hora(h)
CROSS JOIN LATERAL (
  SELECT (CURRENT_DATE - (dias_atras.n || ' days')::interval) + (hora.h || ' hours')::interval AS ts
) t
ORDER BY t.ts;

-- =====================================================================================
-- 8. MEDICIONES DE HOY (últimas ~24 horas, ejemplos legibles a mano)
-- =====================================================================================
INSERT INTO mediciones (id, dispositivo_id, sensor_id, animal_id, timestamp, valor_medido, duracion_evento_segundos, temperatura_ambiental_celsius, es_anomalia)
VALUES
  (9001, 1, 1, 1, NOW() - INTERVAL '24 hours', 12.5, 900, 22.1, FALSE),
  (9002, 1, 1, 1, NOW() - INTERVAL '23 hours', 12.3, 920, 22.3, FALSE),
  (9003, 1, 1, 1, NOW() - INTERVAL '22 hours', 12.1, 850, 21.9, FALSE),
  (9004, 1, 1, 1, NOW() - INTERVAL '21 hours', 12.4, 880, 22.0, FALSE),
  (9005, 1, 1, 2, NOW() - INTERVAL '24 hours', 13.2, 950, 22.1, FALSE),
  (9006, 1, 1, 2, NOW() - INTERVAL '23 hours', 13.0, 920, 22.3, FALSE),
  (9007, 1, 1, 2, NOW() - INTERVAL '22 hours', 12.9, 900, 21.9, FALSE),
  (9008, 1, 1, 3, NOW() - INTERVAL '24 hours', 14.1, 1000, 22.1, FALSE),
  (9009, 1, 1, 3, NOW() - INTERVAL '23 hours', 13.9, 980, 22.3, FALSE),
  (9010, 1, 1, 3, NOW() - INTERVAL '22 hours', 13.8, 950, 21.9, FALSE),
  -- Mediciones del animal en tratamiento (consumo bajo, continúa la caída de los últimos 7 días)
  (9011, 3, 5, 5, NOW() - INTERVAL '24 hours', 8.5, 600, 21.5, FALSE),
  (9012, 3, 5, 5, NOW() - INTERVAL '23 hours', 7.2, 500, 21.8, FALSE),
  (9013, 3, 5, 5, NOW() - INTERVAL '22 hours', 6.8, 450, 21.6, FALSE),
  (9014, 3, 5, 5, NOW() - INTERVAL '21 hours', 6.1, 400, 21.7, FALSE),
  (9015, 3, 5, 4, NOW() - INTERVAL '24 hours', 11.8, 850, 21.5, FALSE),
  (9016, 3, 5, 4, NOW() - INTERVAL '23 hours', 11.5, 870, 21.8, FALSE),
  (9017, 3, 5, 4, NOW() - INTERVAL '22 hours', 11.9, 880, 21.6, FALSE);
-- Nota: es_anomalia y puntuacion_anomalia arriba son solo el valor por defecto de la columna;
-- el trigger tg_detectar_anomalia los recalcula en el INSERT a partir del historial real.

-- =====================================================================================
-- 9. VECTORES DE PATRÓN DE CONSUMO (embedding_patron) DE EJEMPLO
-- =====================================================================================
-- Se vectoriza una medición representativa por animal y día (la última del día), no cada
-- evento individual: el "patrón diario" es la unidad de análisis, no la medición puntual.
-- Vectores sintéticos: dimensiones ~U(0, 0.4) para animales sanos; para el animal en
-- tratamiento, ~U(0.6, 1.0) en los días de caída de consumo (últimos 7), simulando que el
-- modelo de embeddings capturó el cambio de comportamiento. Ver vectorial/modelo_vectorial.md.
DO $$
DECLARE
  r RECORD;
  v_valores REAL[];
  v_offset REAL;
BEGIN
  FOR r IN
    SELECT DISTINCT ON (m.animal_id, date_trunc('day', m.timestamp))
      m.id, m.timestamp, a.estado_salud, m.timestamp > NOW() - INTERVAL '7 days' AS es_reciente
    FROM mediciones m
    JOIN animales a ON a.id = m.animal_id
    ORDER BY m.animal_id, date_trunc('day', m.timestamp), m.timestamp DESC
  LOOP
    v_offset := CASE WHEN r.estado_salud = 'en_tratamiento' AND r.es_reciente THEN 0.6 ELSE 0.0 END;

    SELECT array_agg((random() * 0.4 + v_offset)::real) INTO v_valores
    FROM generate_series(1, 768);

    UPDATE mediciones
    SET embedding_patron = v_valores::vector
    WHERE id = r.id AND timestamp = r.timestamp;
  END LOOP;
END $$;

-- =====================================================================================
-- 10. ALERTAS (manuales, además de las que genera automáticamente tg_generar_alerta_anomalia)
-- =====================================================================================
INSERT INTO alertas (id, animal_id, dispositivo_id, tipo_alerta, severidad, timestamp_alerta, descripcion, datos_contextuales, estado, usuario_responsable_id)
VALUES
  (5001, 5, NULL, 'bajo_consumo', 'alta', NOW() - INTERVAL '6 hours', 'Animal consume menos de lo esperado en últimas 24 horas',
    '{"consumo_esperado": 12.0, "consumo_actual": 6.8, "diferencia": -44.2, "promedio_7_dias": 12.5}', 'abierta', 4),
  (5002, 5, NULL, 'consumo_atipico', 'critica', NOW() - INTERVAL '5 hours', 'Consumo anómalo detectado automáticamente',
    ('{"valor_medido": 6.1, "puntuacion_anomalia": 0.87, "timestamp_evento": "' || (NOW() - INTERVAL '5 hours')::TEXT || '"}')::jsonb, 'en_progreso', 4),
  (5003, NULL, 2, 'falla_sensor', 'media', NOW() - INTERVAL '2 hours', 'Sensor de bebedero no reporta datos',
    ('{"sensor_id": 4, "dispositivo_id": 2, "ultima_lectura": "' || (NOW() - INTERVAL '6 hours')::TEXT || '"}')::jsonb, 'abierta', 2);

-- =====================================================================================
-- Resumen: 2 estancias, 6 usuarios, 5 ubicaciones, 6 dispositivos, 11 sensores, 8 animales,
-- 336 mediciones históricas (21 días) + 17 mediciones de hoy = 353 mediciones,
-- ~176 vectores de patrón de consumo (uno por animal/día con datos),
-- 3 alertas manuales + las que genere automáticamente el trigger de anomalías.
-- =====================================================================================
