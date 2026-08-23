-- schema.sql
-- Creación de todas las tablas del modelo físico

CREATE EXTENSION IF NOT EXISTS vector;

-- Tabla ESTANCIAS
CREATE TABLE estancias (
  id BIGINT PRIMARY KEY,
  nombre VARCHAR(200) NOT NULL UNIQUE,
  descripcion TEXT,
  ubicacion_ciudad VARCHAR(100),
  ubicacion_provincia VARCHAR(100),
  tipo_produccion VARCHAR(50) NOT NULL,
  cantidad_animales_actual INTEGER NOT NULL DEFAULT 0,
  contacto_responsable VARCHAR(255),
  activa BOOLEAN NOT NULL DEFAULT TRUE,
  fecha_creacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  
  CONSTRAINT chk_tipo_produccion CHECK (tipo_produccion IN ('engorde', 'cría', 'lechería', 'mixto')),
  CONSTRAINT chk_cantidad_animales CHECK (cantidad_animales_actual >= 0)
);

COMMENT ON TABLE estancias IS 'Unidades ganaderas independientes (multi-tenancy)';
COMMENT ON COLUMN estancias.cantidad_animales_actual IS 'Desnormalizado: calculado mediante trigger';

-- Tabla USUARIOS
CREATE TABLE usuarios (
  id SERIAL PRIMARY KEY,
  estancia_id BIGINT NOT NULL,
  nombre VARCHAR(100) NOT NULL,
  email VARCHAR(255) NOT NULL,
  contraseña_hash VARCHAR(255) NOT NULL,
  rol VARCHAR(50) NOT NULL,
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  fecha_creacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  
  CONSTRAINT fk_usuarios_estancia FOREIGN KEY (estancia_id) REFERENCES estancias(id) ON DELETE CASCADE,
  CONSTRAINT uq_email_por_estancia UNIQUE (estancia_id, email),
  CONSTRAINT chk_rol CHECK (rol IN ('peón', 'encargado', 'veterinario', 'admin'))
);

COMMENT ON TABLE usuarios IS 'Personas que interactúan con el sistema';
COMMENT ON COLUMN usuarios.rol IS 'Determina permisos y filtrado en RLS';

-- Tabla UBICACIONES
CREATE TABLE ubicaciones (
  id BIGINT PRIMARY KEY,
  estancia_id BIGINT NOT NULL,
  nombre VARCHAR(150) NOT NULL,
  tipo VARCHAR(50) NOT NULL,
  descripcion TEXT,
  capacidad_animales INTEGER NOT NULL,
  area_metros_cuadrados DECIMAL(10,2),
  responsable_usuario_id BIGINT,
  activa BOOLEAN NOT NULL DEFAULT TRUE,
  fecha_creacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  
  CONSTRAINT fk_ubicaciones_estancia FOREIGN KEY (estancia_id) REFERENCES estancias(id) ON DELETE CASCADE,
  CONSTRAINT fk_ubicaciones_usuario FOREIGN KEY (responsable_usuario_id) REFERENCES usuarios(id) ON DELETE SET NULL,
  CONSTRAINT uq_ubicacion_nombre UNIQUE (estancia_id, nombre),
  CONSTRAINT chk_capacidad CHECK (capacidad_animales > 0),
  CONSTRAINT chk_tipo CHECK (tipo IN ('corral', 'encierre', 'peseada', 'galpón'))
);

COMMENT ON TABLE ubicaciones IS 'Sectores físicos donde se instalan dispositivos';

-- Tabla DISPOSITIVOS
CREATE TABLE dispositivos (
  id BIGINT PRIMARY KEY,
  serial_hardware VARCHAR(100) NOT NULL UNIQUE,
  ubicacion_id BIGINT NOT NULL,
  tipo_dispositivo VARCHAR(50) NOT NULL,
  modelo VARCHAR(100) NOT NULL,
  fabricante VARCHAR(100),
  fecha_instalacion DATE NOT NULL,
  fecha_retiro DATE,
  estado VARCHAR(50) NOT NULL DEFAULT 'operacional',
  configuracion JSONB NOT NULL DEFAULT '{}',
  firmware_version VARCHAR(50),
  fecha_creacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  
  CONSTRAINT fk_dispositivos_ubicacion FOREIGN KEY (ubicacion_id) REFERENCES ubicaciones(id) ON DELETE CASCADE,
  CONSTRAINT chk_fechas_dispositivo CHECK (fecha_retiro IS NULL OR fecha_retiro >= fecha_instalacion),
  CONSTRAINT chk_tipo_dispositivo CHECK (tipo_dispositivo IN ('comedero', 'bebedero')),
  CONSTRAINT chk_estado_dispositivo CHECK (estado IN ('operacional', 'mantenimiento', 'falla'))
);

COMMENT ON TABLE dispositivos IS 'Comederos y bebederos inteligentes instalados';
COMMENT ON COLUMN dispositivos.configuracion IS 'Parámetros específicos del modelo en formato JSONB';

-- Tabla SENSORES
CREATE TABLE sensores (
  id BIGINT PRIMARY KEY,
  dispositivo_id BIGINT NOT NULL,
  tipo_sensor VARCHAR(50) NOT NULL,
  unidad_medida VARCHAR(20) NOT NULL,
  rango_minimo DECIMAL(10,2) NOT NULL,
  rango_maximo DECIMAL(10,2) NOT NULL,
  precision_declarada DECIMAL(5,3) NOT NULL,
  fecha_ultima_calibracion DATE,
  estado VARCHAR(50) NOT NULL DEFAULT 'operacional',
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  fecha_creacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  
  CONSTRAINT fk_sensores_dispositivo FOREIGN KEY (dispositivo_id) REFERENCES dispositivos(id) ON DELETE CASCADE,
  CONSTRAINT chk_tipo_sensor CHECK (tipo_sensor IN ('rfid', 'pesaje', 'temperatura', 'humedad')),
  CONSTRAINT chk_rango CHECK (rango_minimo < rango_maximo),
  CONSTRAINT chk_precision CHECK (precision_declarada > 0)
);

COMMENT ON TABLE sensores IS 'Componentes de medición dentro de dispositivos';

-- Tabla ANIMALES
CREATE TABLE animales (
  id BIGINT PRIMARY KEY,
  estancia_id BIGINT NOT NULL,
  tag_rfid VARCHAR(50) NOT NULL,
  nombre_alias VARCHAR(100),
  raza VARCHAR(100) NOT NULL,
  sexo VARCHAR(50) NOT NULL,
  fecha_nacimiento DATE NOT NULL,
  peso_actual_kg DECIMAL(8,2),
  fecha_ultimo_peso TIMESTAMP,
  estado_salud VARCHAR(50) NOT NULL DEFAULT 'sano',
  ubicacion_actual_id BIGINT,
  fecha_ingreso_estancia DATE NOT NULL,
  fecha_egreso_estancia DATE,
  motivo_egreso VARCHAR(255),
  fecha_creacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  
  CONSTRAINT fk_animales_estancia FOREIGN KEY (estancia_id) REFERENCES estancias(id) ON DELETE CASCADE,
  CONSTRAINT fk_animales_ubicacion FOREIGN KEY (ubicacion_actual_id) REFERENCES ubicaciones(id) ON DELETE SET NULL,
  CONSTRAINT uq_tag_rfid UNIQUE (estancia_id, tag_rfid),
  CONSTRAINT chk_fechas_egreso CHECK (fecha_egreso_estancia IS NULL OR fecha_egreso_estancia >= fecha_ingreso_estancia),
  CONSTRAINT chk_sexo CHECK (sexo IN ('macho', 'hembra', 'indefinido')),
  CONSTRAINT chk_estado_salud CHECK (estado_salud IN ('sano', 'enfermo', 'en_tratamiento', 'descarte'))
);

COMMENT ON TABLE animales IS 'Entidades ganaderas individuales con identificación RFID';
COMMENT ON COLUMN animales.ubicacion_actual_id IS 'Desnormalizado: ubicación actual para queries rápidas';

-- Tabla MEDICIONES
-- Particionada por rango de timestamp (ver particiones.sql). El particionamiento exige que
-- toda clave primaria/unique incluya la columna de partición: por eso la PK es (id, timestamp)
-- en lugar de id simple. La unicidad de id sigue garantizada por el generador (seq_mediciones).
CREATE TABLE mediciones (
  id BIGINT NOT NULL,
  dispositivo_id BIGINT NOT NULL,
  sensor_id BIGINT NOT NULL,
  animal_id BIGINT,
  timestamp TIMESTAMP NOT NULL,
  valor_medido DECIMAL(10,3) NOT NULL,
  duracion_evento_segundos INTEGER,
  temperatura_ambiental_celsius DECIMAL(5,2),
  humedad_ambiental_pct DECIMAL(5,2),
  datos_crudos JSONB,
  es_anomalia BOOLEAN NOT NULL DEFAULT FALSE,
  puntuacion_anomalia DECIMAL(5,3),
  embedding_patron vector(768),
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT pk_mediciones PRIMARY KEY (id, timestamp),
  CONSTRAINT fk_mediciones_dispositivo FOREIGN KEY (dispositivo_id) REFERENCES dispositivos(id),
  CONSTRAINT fk_mediciones_sensor FOREIGN KEY (sensor_id) REFERENCES sensores(id),
  CONSTRAINT fk_mediciones_animal FOREIGN KEY (animal_id) REFERENCES animales(id) ON DELETE SET NULL,
  CONSTRAINT chk_valor_medido CHECK (valor_medido >= 0),
  CONSTRAINT chk_duracion_evento CHECK (duracion_evento_segundos > 0 OR duracion_evento_segundos IS NULL),
  CONSTRAINT chk_temperatura CHECK (temperatura_ambiental_celsius BETWEEN -40 AND 50),
  CONSTRAINT chk_humedad CHECK (humedad_ambiental_pct BETWEEN 0 AND 100),
  CONSTRAINT chk_puntuacion_anomalia CHECK (puntuacion_anomalia BETWEEN 0 AND 1 OR puntuacion_anomalia IS NULL)
) PARTITION BY RANGE (timestamp);

COMMENT ON TABLE mediciones IS 'Registros de consumo individual - tabla principal de hechos, particionada por mes';
COMMENT ON COLUMN mediciones.embedding_patron IS 'Vector de similitud generado por modelo de embeddings';

-- Tabla ALERTAS
CREATE TABLE alertas (
  id BIGINT PRIMARY KEY,
  animal_id BIGINT,
  dispositivo_id BIGINT,
  tipo_alerta VARCHAR(50) NOT NULL,
  severidad VARCHAR(50) NOT NULL,
  timestamp_alerta TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  descripcion TEXT NOT NULL,
  datos_contextuales JSONB,
  estado VARCHAR(50) NOT NULL DEFAULT 'abierta',
  usuario_responsable_id BIGINT,
  timestamp_resolucion TIMESTAMP,
  notas_resolucion TEXT,
  fecha_creacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  
  CONSTRAINT fk_alertas_animal FOREIGN KEY (animal_id) REFERENCES animales(id) ON DELETE SET NULL,
  CONSTRAINT fk_alertas_dispositivo FOREIGN KEY (dispositivo_id) REFERENCES dispositivos(id) ON DELETE SET NULL,
  CONSTRAINT fk_alertas_usuario FOREIGN KEY (usuario_responsable_id) REFERENCES usuarios(id) ON DELETE SET NULL,
  CONSTRAINT chk_alerta_referencia CHECK ((animal_id IS NOT NULL) OR (dispositivo_id IS NOT NULL)),
  CONSTRAINT chk_tipo_alerta CHECK (tipo_alerta IN ('bajo_consumo', 'no_presencia', 'falla_sensor', 'consumo_atipico')),
  CONSTRAINT chk_severidad CHECK (severidad IN ('baja', 'media', 'alta', 'critica')),
  CONSTRAINT chk_estado_alerta CHECK (estado IN ('abierta', 'en_progreso', 'resuelta')),
  CONSTRAINT chk_timestamp_resolucion CHECK (timestamp_resolucion IS NULL OR timestamp_resolucion >= timestamp_alerta)
);

COMMENT ON TABLE alertas IS 'Eventos detectados automáticamente por lógica de reglas';
COMMENT ON COLUMN alertas.datos_contextuales IS 'Contexto que generó la alerta en formato JSONB';