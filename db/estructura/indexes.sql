-- indexes.sql
-- Creación de índices optimizados para queries frecuentes

-- Índices en USUARIOS
CREATE INDEX idx_usuarios_estancia ON usuarios(estancia_id);

-- Índices en UBICACIONES
CREATE INDEX idx_ubicaciones_estancia ON ubicaciones(estancia_id);
CREATE INDEX idx_ubicaciones_usuario ON ubicaciones(responsable_usuario_id);

-- Índices en DISPOSITIVOS
CREATE INDEX idx_dispositivos_ubicacion ON dispositivos(ubicacion_id);
CREATE INDEX idx_dispositivos_estado ON dispositivos(estado);
CREATE INDEX idx_dispositivos_ubicacion_estado ON dispositivos(ubicacion_id, estado);

-- Índices en SENSORES
CREATE INDEX idx_sensores_dispositivo ON sensores(dispositivo_id);
CREATE INDEX idx_sensores_tipo ON sensores(tipo_sensor);
CREATE INDEX idx_sensores_dispositivo_tipo ON sensores(dispositivo_id, tipo_sensor);

-- Índices en ANIMALES
CREATE INDEX idx_animales_estancia ON animales(estancia_id);
CREATE INDEX idx_animales_tag_rfid ON animales(tag_rfid);
CREATE INDEX idx_animales_ubicacion ON animales(ubicacion_actual_id);
CREATE INDEX idx_animales_estado_salud ON animales(estado_salud);
CREATE INDEX idx_animales_estancia_estado ON animales(estancia_id, estado_salud);

-- Índices en MEDICIONES (tabla crítica para queries frecuentes)
CREATE INDEX idx_mediciones_timestamp ON mediciones(timestamp DESC);
CREATE INDEX idx_mediciones_animal_timestamp ON mediciones(animal_id, timestamp DESC);
CREATE INDEX idx_mediciones_dispositivo_timestamp ON mediciones(dispositivo_id, timestamp DESC);
CREATE INDEX idx_mediciones_es_anomalia ON mediciones(es_anomalia, timestamp DESC);
CREATE INDEX idx_mediciones_sensor ON mediciones(sensor_id);

-- Índice parcial: solo anomalías (optimiza queries de alertas)
CREATE INDEX idx_mediciones_anomalia_parcial ON mediciones(animal_id, timestamp DESC) 
  WHERE es_anomalia = TRUE;

-- Índice vectorial para búsqueda por similitud (pgvector)
CREATE INDEX idx_mediciones_embedding ON mediciones USING ivfflat (embedding_patron vector_cosine_ops)
  WITH (lists = 100);

-- Índices en ALERTAS (consultas frecuentes de alertas activas)
CREATE INDEX idx_alertas_animal ON alertas(animal_id);
CREATE INDEX idx_alertas_dispositivo ON alertas(dispositivo_id);
CREATE INDEX idx_alertas_estado ON alertas(estado);
CREATE INDEX idx_alertas_timestamp ON alertas(timestamp_alerta DESC);
CREATE INDEX idx_alertas_usuario ON alertas(usuario_responsable_id);

-- Índice parcial: alertas sin resolver (query muy frecuente)
CREATE INDEX idx_alertas_sin_resolver ON alertas(id) 
  WHERE estado IN ('abierta', 'en_progreso');

-- Índice compuesto para queries de alertas por estado y tiempo
CREATE INDEX idx_alertas_estado_timestamp ON alertas(estado, timestamp_alerta DESC) 
  WHERE estado IN ('abierta', 'en_progreso');