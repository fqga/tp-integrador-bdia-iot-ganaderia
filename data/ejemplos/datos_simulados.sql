-- datos_simulados.sql
-- Datos de ejemplo realistas para pruebas de la base de datos

-- Insertar estancia
INSERT INTO estancias (id, nombre, descripcion, ubicacion_ciudad, ubicacion_provincia, tipo_produccion, contacto_responsable, activa)
VALUES 
  (1, 'Estancia Las Flores', 'Producción de ganado de engorde', 'Tucumán', 'Tucumán', 'engorde', 'Juan Pérez', TRUE),
  (2, 'Ganadería San José', 'Producción lechera', 'Córdoba', 'Córdoba', 'lechería', 'María García', TRUE);

-- Insertar usuarios
INSERT INTO usuarios (id, estancia_id, nombre, email, contraseña_hash, rol, activo)
VALUES 
  (1, 1, 'Facundo Gómez', 'facundo@estancia.com', 'hash_bcrypt_1', 'admin', TRUE),
  (2, 1, 'Carlos López', 'carlos@estancia.com', 'hash_bcrypt_2', 'encargado', TRUE),
  (3, 1, 'José Martínez', 'jose@estancia.com', 'hash_bcrypt_3', 'peón', TRUE),
  (4, 1, 'Dr. Rodriguez', 'veterinario@estancia.com', 'hash_bcrypt_4', 'veterinario', TRUE),
  (5, 2, 'Ana Fernández', 'ana@sanJose.com', 'hash_bcrypt_5', 'admin', TRUE);

-- Insertar ubicaciones
INSERT INTO ubicaciones (id, estancia_id, nombre, tipo, descripcion, capacidad_animales, area_metros_cuadrados, responsable_usuario_id, activa)
VALUES 
  (1, 1, 'Corral A', 'corral', 'Corral principal de engorde', 150, 5000.00, 2, TRUE),
  (2, 1, 'Corral B', 'corral', 'Corral secundario', 120, 4000.00, 2, TRUE),
  (3, 1, 'Encierre', 'encierre', 'Área de concentración', 200, 6000.00, 3, TRUE),
  (4, 1, 'Peseada', 'peseada', 'Área de pesaje', 50, 1500.00, 2, TRUE),
  (5, 2, 'Corral Lechería', 'corral', 'Área de ordeño', 100, 3500.00, 5, TRUE);

-- Insertar dispositivos (comederos y bebederos)
INSERT INTO dispositivos (id, serial_hardware, ubicacion_id, tipo_dispositivo, modelo, fabricante, fecha_instalacion, estado, configuracion)
VALUES 
  (1, 'DEV-001-A', 1, 'comedero', 'FeedTrack Pro v2', 'FeedTech Industries', '2026-01-15', 'operacional', '{"calibracion_pesaje": 0.98, "umbral_presencia_kg": 100, "intervalo_reporte": 60}'),
  (2, 'DEV-002-A', 1, 'bebedero', 'WaterFlow 3000', 'AquaSense', '2026-01-20', 'operacional', '{"flujo_maximo_lpm": 50, "sensibilidad_presencia": "media"}'),
  (3, 'DEV-003-B', 2, 'comedero', 'FeedTrack Pro v2', 'FeedTech Industries', '2026-02-01', 'operacional', '{"calibracion_pesaje": 0.99, "umbral_presencia_kg": 100, "intervalo_reporte": 60}'),
  (4, 'DEV-004-B', 2, 'bebedero', 'WaterFlow 3000', 'AquaSense', '2026-02-05', 'operacional', '{"flujo_maximo_lpm": 50, "sensibilidad_presencia": "media"}'),
  (5, 'DEV-005-C', 3, 'comedero', 'FeedTrack Pro v2', 'FeedTech Industries', '2026-02-10', 'operacional', '{"calibracion_pesaje": 0.97, "umbral_presencia_kg": 150, "intervalo_reporte": 60}');

-- Insertar sensores
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
  (9, 5, 'rfid', 'codigo', 0, 1000, 0.01, 'operacional', TRUE);

-- Insertar animales
INSERT INTO animales (id, estancia_id, tag_rfid, nombre_alias, raza, sexo, fecha_nacimiento, peso_actual_kg, estado_salud, ubicacion_actual_id, fecha_ingreso_estancia, activa)
VALUES 
  (1, 1, '9E-54-3F-AB-CD-01', 'Blanca', 'Hereford', 'hembra', '2024-06-15', 450.00, 'sano', 1, '2026-01-01', TRUE),
  (2, 1, '9E-54-3F-AB-CD-02', 'Negra', 'Hereford', 'hembra', '2024-07-20', 480.00, 'sano', 1, '2026-01-10', TRUE),
  (3, 1, '9E-54-3F-AB-CD-03', 'Rojo', 'Aberdeen Angus', 'macho', '2024-05-10', 520.00, 'sano', 1, '2025-12-20', TRUE),
  (4, 1, '9E-54-3F-AB-CD-04', 'Manchado', 'Charolés', 'macho', '2024-08-01', 410.00, 'sano', 2, '2026-02-01', TRUE),
  (5, 1, '9E-54-3F-AB-CD-05', 'Oscuro', 'Hereford', 'macho', '2024-06-25', 460.00, 'en_tratamiento', 2, '2026-01-15', TRUE),
  (6, 1, '9E-54-3F-AB-CD-06', 'Claro', 'Aberdeen Angus', 'hembra', '2024-07-10', 420.00, 'sano', 1, '2026-01-20', TRUE);

-- Insertar mediciones (últimas 24 horas aproximadamente)
INSERT INTO mediciones (id, dispositivo_id, sensor_id, animal_id, timestamp, valor_medido, duracion_evento_segundos, temperatura_ambiental_celsius, es_anomalia)
VALUES 
  (1, 1, 1, 1, NOW() - INTERVAL '24 hours', 12.5, 900, 22.1, FALSE),
  (2, 1, 1, 1, NOW() - INTERVAL '23 hours', 12.3, 920, 22.3, FALSE),
  (3, 1, 1, 1, NOW() - INTERVAL '22 hours', 12.1, 850, 21.9, FALSE),
  (4, 1, 1, 1, NOW() - INTERVAL '21 hours', 12.4, 880, 22.0, FALSE),
  (5, 1, 1, 2, NOW() - INTERVAL '24 hours', 13.2, 950, 22.1, FALSE),
  (6, 1, 1, 2, NOW() - INTERVAL '23 hours', 13.0, 920, 22.3, FALSE),
  (7, 1, 1, 2, NOW() - INTERVAL '22 hours', 12.9, 900, 21.9, FALSE),
  (8, 1, 1, 3, NOW() - INTERVAL '24 hours', 14.1, 1000, 22.1, FALSE),
  (9, 1, 1, 3, NOW() - INTERVAL '23 hours', 13.9, 980, 22.3, FALSE),
  (10, 1, 1, 3, NOW() - INTERVAL '22 hours', 13.8, 950, 21.9, FALSE),
  -- Mediciones para animal enfermo (consumo bajo)
  (11, 3, 5, 5, NOW() - INTERVAL '24 hours', 8.5, 600, 21.5, FALSE),
  (12, 3, 5, 5, NOW() - INTERVAL '23 hours', 7.2, 500, 21.8, FALSE),
  (13, 3, 5, 5, NOW() - INTERVAL '22 hours', 6.8, 450, 21.6, TRUE),
  (14, 3, 5, 5, NOW() - INTERVAL '21 hours', 6.1, 400, 21.7, TRUE),
  (15, 3, 5, 4, NOW() - INTERVAL '24 hours', 11.8, 850, 21.5, FALSE),
  (16, 3, 5, 4, NOW() - INTERVAL '23 hours', 11.5, 870, 21.8, FALSE),
  (17, 3, 5, 4, NOW() - INTERVAL '22 hours', 11.9, 880, 21.6, FALSE);

-- Insertar alertas
INSERT INTO alertas (id, animal_id, dispositivo_id, tipo_alerta, severidad, timestamp_alerta, descripcion, datos_contextuales, estado, usuario_responsable_id)
VALUES 
  (1, 5, NULL, 'bajo_consumo', 'alta', NOW() - INTERVAL '6 hours', 'Animal consume menos de lo esperado en últimas 24 horas', 
    '{"consumo_esperado": 12.0, "consumo_actual": 6.8, "diferencia": -44.2, "promedio_7_dias": 12.5}', 'abierta', 4),
  (2, 5, NULL, 'consumo_atipico', 'critica', NOW() - INTERVAL '5 hours', 'Consumo anómalo detectado automáticamente', 
    '{"valor_medido": 6.1, "puntuacion_anomalia": 0.87, "timestamp_evento": "' || (NOW() - INTERVAL '5 hours')::TEXT || '"}', 'en_progreso', 4),
  (3, NULL, 2, 'falla_sensor', 'media', NOW() - INTERVAL '2 hours', 'Sensor de bebedero no reporta datos', 
    '{"sensor_id": 4, "dispositivo_id": 2, "ultima_lectura": "' || (NOW() - INTERVAL '6 hours')::TEXT || '"}', 'abierta', 2);

-- Datos de ejemplo completados
-- Total: 2 estancias, 5 usuarios, 5 ubicaciones, 5 dispositivos, 9 sensores, 6 animales, 17 mediciones, 3 alertas