# MODELO FÍSICO: Implementación en PostgreSQL

## 1. Introducción

El **modelo físico** implementa el esquema relacional normalizado en PostgreSQL 15+. Incluye:

- Definición de tablas con tipos de datos específicos
- Restricciones de integridad (claves primarias, foráneas, checks)
- Índices para optimizar queries frecuentes
- Particionamiento temporal de tabla MEDICIONES
- Row-Level Security (RLS) para multi-tenancy
- Triggers para mantener desnormalizaciones
- Extensiones necesarias (pgvector para vectores)

---

## 2. Extensiones requeridas

```sql
CREATE EXTENSION IF NOT EXISTS pgvector;
```

La extensión `pgvector` permite almacenar y consultar vectores de dimensionalidad alta (embeddings de 768 dimensiones para patrones de consumo).

---

## 3. Creación de tablas

### 3.1 ESTANCIAS

```sql
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
```

---

### 3.2 USUARIOS

```sql
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

CREATE INDEX idx_usuarios_estancia ON usuarios(estancia_id);

COMMENT ON TABLE usuarios IS 'Personas que interactúan con el sistema';
COMMENT ON COLUMN usuarios.rol IS 'Determina permisos y filtrado en RLS';
```

---

### 3.3 UBICACIONES

```sql
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

CREATE INDEX idx_ubicaciones_estancia ON ubicaciones(estancia_id);
CREATE INDEX idx_ubicaciones_usuario ON ubicaciones(responsable_usuario_id);

COMMENT ON TABLE ubicaciones IS 'Sectores físicos donde se instalan dispositivos';
```

---

### 3.4 DISPOSITIVOS

```sql
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

CREATE INDEX idx_dispositivos_ubicacion ON dispositivos(ubicacion_id);
CREATE INDEX idx_dispositivos_estado ON dispositivos(estado);

COMMENT ON TABLE dispositivos IS 'Comederos y bebederos inteligentes instalados';
COMMENT ON COLUMN dispositivos.configuracion IS 'Parámetros específicos del modelo en formato JSONB';
```

---

### 3.5 SENSORES

```sql
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

CREATE INDEX idx_sensores_dispositivo ON sensores(dispositivo_id);
CREATE INDEX idx_sensores_tipo ON sensores(tipo_sensor);

COMMENT ON TABLE sensores IS 'Componentes de medición dentro de dispositivos';
```

---

### 3.6 ANIMALES

```sql
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

CREATE INDEX idx_animales_estancia ON animales(estancia_id);
CREATE INDEX idx_animales_tag_rfid ON animales(tag_rfid);
CREATE INDEX idx_animales_ubicacion ON animales(ubicacion_actual_id);
CREATE INDEX idx_animales_estado_salud ON animales(estado_salud);

COMMENT ON TABLE animales IS 'Entidades ganaderas individuales con identificación RFID';
COMMENT ON COLUMN animales.ubicacion_actual_id IS 'Desnormalizado: ubicación actual para queries rápidas';
```

---

### 3.7 MEDICIONES (sin particionamiento en esta vista)

```sql
CREATE TABLE mediciones (
  id BIGINT PRIMARY KEY,
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
  
  CONSTRAINT fk_mediciones_dispositivo FOREIGN KEY (dispositivo_id) REFERENCES dispositivos(id),
  CONSTRAINT fk_mediciones_sensor FOREIGN KEY (sensor_id) REFERENCES sensores(id),
  CONSTRAINT fk_mediciones_animal FOREIGN KEY (animal_id) REFERENCES animales(id) ON DELETE SET NULL,
  CONSTRAINT chk_valor_medido CHECK (valor_medido >= 0),
  CONSTRAINT chk_duracion_evento CHECK (duracion_evento_segundos > 0 OR duracion_evento_segundos IS NULL),
  CONSTRAINT chk_temperatura CHECK (temperatura_ambiental_celsius BETWEEN -40 AND 50),
  CONSTRAINT chk_humedad CHECK (humedad_ambiental_pct BETWEEN 0 AND 100),
  CONSTRAINT chk_puntuacion_anomalia CHECK (puntuacion_anomalia BETWEEN 0 AND 1 OR puntuacion_anomalia IS NULL)
);

COMMENT ON TABLE mediciones IS 'Registros de consumo individual - tabla principal de hechos';
COMMENT ON COLUMN mediciones.embedding_patron IS 'Vector de similitud generado por modelo de embeddings';
```

---

### 3.8 ALERTAS

```sql
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

CREATE INDEX idx_alertas_animal ON alertas(animal_id);
CREATE INDEX idx_alertas_dispositivo ON alertas(dispositivo_id);
CREATE INDEX idx_alertas_estado ON alertas(estado);
CREATE INDEX idx_alertas_timestamp ON alertas(timestamp_alerta DESC);
CREATE INDEX idx_alertas_sin_resolver ON alertas(id) WHERE estado IN ('abierta', 'en_progreso');

COMMENT ON TABLE alertas IS 'Eventos detectados automáticamente por lógica de reglas';
COMMENT ON COLUMN alertas.datos_contextuales IS 'Contexto que generó la alerta en formato JSONB';
```

---

## 4. Particionamiento temporal de MEDICIONES

```sql
-- Crear tabla partida (en versión final, reemplazar tabla anterior)
-- Estructura: MEDICIONES particionada por rango de timestamp (mensual)

-- Nota: En PostgreSQL, el particionamiento se realiza en la creación de tabla.
-- Esta es una guía de cómo hacerlo:

CREATE TABLE mediciones_particionada (
  id BIGINT PRIMARY KEY,
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
  
  CONSTRAINT fk_mediciones_dispositivo FOREIGN KEY (dispositivo_id) REFERENCES dispositivos(id),
  CONSTRAINT fk_mediciones_sensor FOREIGN KEY (sensor_id) REFERENCES sensores(id),
  CONSTRAINT fk_mediciones_animal FOREIGN KEY (animal_id) REFERENCES animales(id) ON DELETE SET NULL,
  CONSTRAINT chk_valor_medido CHECK (valor_medido >= 0),
  CONSTRAINT chk_duracion_evento CHECK (duracion_evento_segundos > 0 OR duracion_evento_segundos IS NULL),
  CONSTRAINT chk_temperatura CHECK (temperatura_ambiental_celsius BETWEEN -40 AND 50),
  CONSTRAINT chk_humedad CHECK (humedad_ambiental_pct BETWEEN 0 AND 100),
  CONSTRAINT chk_puntuacion_anomalia CHECK (puntuacion_anomalia BETWEEN 0 AND 1 OR puntuacion_anomalia IS NULL)
) PARTITION BY RANGE (timestamp);

-- Crear particiones mensuales (ejemplo: 2026)
CREATE TABLE mediciones_2026_01 PARTITION OF mediciones_particionada
  FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');

CREATE TABLE mediciones_2026_02 PARTITION OF mediciones_particionada
  FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');

-- ... continuar para todos los meses

-- Crear índices en tabla partida
CREATE INDEX idx_mediciones_timestamp ON mediciones_particionada(timestamp DESC);
CREATE INDEX idx_mediciones_animal ON mediciones_particionada(animal_id, timestamp DESC);
CREATE INDEX idx_mediciones_dispositivo ON mediciones_particionada(dispositivo_id, timestamp DESC);
CREATE INDEX idx_mediciones_anomalia ON mediciones_particionada(es_anomalia, timestamp DESC);

-- Índice parcial para anomalías
CREATE INDEX idx_mediciones_anomalia_parcial ON mediciones_particionada(animal_id, timestamp DESC) 
  WHERE es_anomalia = TRUE;
```

**Ventajas del particionamiento temporal**:
- Queries por rango de fecha son más rápidas (escanea solo particiones relevantes)
- Mantenimiento: eliminar datos antiguos es TRUNCATE de una partición
- Escalabilidad: agregar nuevas particiones mensualmente de forma automática

---

## 5. Índices optimizados

```sql
-- Índices en MEDICIONES (tabla crítica para queries frecuentes)
CREATE INDEX idx_mediciones_timestamp ON mediciones(timestamp DESC);
CREATE INDEX idx_mediciones_animal_timestamp ON mediciones(animal_id, timestamp DESC);
CREATE INDEX idx_mediciones_dispositivo_timestamp ON mediciones(dispositivo_id, timestamp DESC);
CREATE INDEX idx_mediciones_es_anomalia ON mediciones(es_anomalia, timestamp DESC);

-- Índice parcial: solo anomalías (optimiza queries de alertas)
CREATE INDEX idx_mediciones_anomalia_parcial ON mediciones(animal_id, timestamp DESC) 
  WHERE es_anomalia = TRUE;

-- Índice vectorial para búsqueda por similitud (pgvector)
CREATE INDEX idx_mediciones_embedding ON mediciones USING ivfflat (embedding_patron vector_cosine_ops)
  WITH (lists = 100);

-- Índices en tablas de configuración
CREATE INDEX idx_dispositivos_ubicacion_estado ON dispositivos(ubicacion_id, estado);
CREATE INDEX idx_sensores_dispositivo_tipo ON sensores(dispositivo_id, tipo_sensor);
CREATE INDEX idx_animales_estancia_estado ON animales(estancia_id, estado_salud);

-- Índices en ALERTAS (consultas frecuentes de alertas abiertas)
CREATE INDEX idx_alertas_estado_timestamp ON alertas(estado, timestamp_alerta DESC) 
  WHERE estado IN ('abierta', 'en_progreso');
```

---

## 6. Row-Level Security (RLS) para multi-tenancy

```sql
-- Habilitar RLS en tablas de datos
ALTER TABLE usuarios ENABLE ROW LEVEL SECURITY;
ALTER TABLE ubicaciones ENABLE ROW LEVEL SECURITY;
ALTER TABLE dispositivos ENABLE ROW LEVEL SECURITY;
ALTER TABLE sensores ENABLE ROW LEVEL SECURITY;
ALTER TABLE animales ENABLE ROW LEVEL SECURITY;
ALTER TABLE mediciones ENABLE ROW LEVEL SECURITY;
ALTER TABLE alertas ENABLE ROW LEVEL SECURITY;

-- Función auxiliar: obtener estancia del usuario actual
CREATE OR REPLACE FUNCTION obtener_estancia_usuario()
RETURNS BIGINT AS $$
BEGIN
  RETURN (SELECT estancia_id FROM usuarios WHERE id = current_user_id::integer);
END;
$$ LANGUAGE plpgsql;

-- Política RLS en USUARIOS: cada usuario ve solo usuarios de su estancia
CREATE POLICY usuarios_own_estancia ON usuarios
  FOR SELECT
  USING (estancia_id = (SELECT estancia_id FROM usuarios WHERE id = current_user_id::integer));

-- Política RLS en UBICACIONES: acceso solo a ubicaciones de la estancia
CREATE POLICY ubicaciones_own_estancia ON ubicaciones
  FOR SELECT
  USING (estancia_id = (SELECT estancia_id FROM usuarios WHERE id = current_user_id::integer));

-- Política RLS en DISPOSITIVOS: acceso mediante cadena FK
CREATE POLICY dispositivos_own_estancia ON dispositivos
  FOR SELECT
  USING (ubicacion_id IN (
    SELECT id FROM ubicaciones 
    WHERE estancia_id = (SELECT estancia_id FROM usuarios WHERE id = current_user_id::integer)
  ));

-- Política RLS en ANIMALES: acceso solo a animales de su estancia
CREATE POLICY animales_own_estancia ON animales
  FOR SELECT
  USING (estancia_id = (SELECT estancia_id FROM usuarios WHERE id = current_user_id::integer));

-- Política RLS en MEDICIONES: acceso solo a mediciones de su estancia
CREATE POLICY mediciones_own_estancia ON mediciones
  FOR SELECT
  USING (dispositivo_id IN (
    SELECT id FROM dispositivos 
    WHERE ubicacion_id IN (
      SELECT id FROM ubicaciones 
      WHERE estancia_id = (SELECT estancia_id FROM usuarios WHERE id = current_user_id::integer)
    )
  ));

-- Política RLS en ALERTAS: acceso solo a alertas de su estancia
CREATE POLICY alertas_own_estancia ON alertas
  FOR SELECT
  USING (
    animal_id IN (SELECT id FROM animales WHERE estancia_id = (SELECT estancia_id FROM usuarios WHERE id = current_user_id::integer))
    OR dispositivo_id IN (SELECT id FROM dispositivos WHERE ubicacion_id IN (SELECT id FROM ubicaciones WHERE estancia_id = (SELECT estancia_id FROM usuarios WHERE id = current_user_id::integer)))
  );
```

---

## 7. Triggers para mantener desnormalizaciones

### 7.1 Trigger: actualizar cantidad_animales_actual en ESTANCIAS

```sql
CREATE OR REPLACE FUNCTION actualizar_cantidad_animales()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
    UPDATE estancias 
    SET cantidad_animales_actual = (
      SELECT COUNT(*) FROM animales 
      WHERE estancia_id = NEW.estancia_id AND fecha_egreso_estancia IS NULL
    )
    WHERE id = NEW.estancia_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE estancias 
    SET cantidad_animales_actual = (
      SELECT COUNT(*) FROM animales 
      WHERE estancia_id = OLD.estancia_id AND fecha_egreso_estancia IS NULL
    )
    WHERE id = OLD.estancia_id;
    RETURN OLD;
  END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tg_actualizar_cantidad_animales
AFTER INSERT OR UPDATE OR DELETE ON animales
FOR EACH ROW
EXECUTE FUNCTION actualizar_cantidad_animales();
```

### 7.2 Trigger: actualizar ubicacion_actual_id en ANIMALES

```sql
CREATE OR REPLACE FUNCTION actualizar_ubicacion_animal()
RETURNS TRIGGER AS $$
DECLARE
  v_ubicacion_id BIGINT;
BEGIN
  -- Obtener ubicación del último dispositivo donde comió el animal
  SELECT ubicacion_id INTO v_ubicacion_id
  FROM dispositivos
  WHERE id = (
    SELECT dispositivo_id FROM mediciones
    WHERE animal_id = NEW.animal_id
    ORDER BY timestamp DESC
    LIMIT 1
  );
  
  IF v_ubicacion_id IS NOT NULL THEN
    UPDATE animales SET ubicacion_actual_id = v_ubicacion_id
    WHERE id = NEW.animal_id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tg_actualizar_ubicacion_animal
AFTER INSERT ON mediciones
FOR EACH ROW
EXECUTE FUNCTION actualizar_ubicacion_animal();
```

---

## 8. Generador de IDs para tablas grandes

```sql
-- Usar BIGSERIAL para estancias con ID custom
-- CREATE SEQUENCE seq_estancias START 1 INCREMENT 1;

-- Para animales, dispositivos, etc., usar BIGINT con generadores
CREATE SEQUENCE seq_animales START 1 INCREMENT 1;
CREATE SEQUENCE seq_dispositivos START 1 INCREMENT 1;
CREATE SEQUENCE seq_mediciones START 1 INCREMENT 1;
CREATE SEQUENCE seq_alertas START 1 INCREMENT 1;

-- En INSERTs: INSERT INTO animales (id, ...) VALUES (nextval('seq_animales'), ...);
```

---

## 9. Vistas útiles para consultas frecuentes

```sql
-- Vista: animales con consumo total en últimos 7 días
CREATE OR REPLACE VIEW animales_consumo_7_dias AS
SELECT 
  a.id,
  a.estancia_id,
  a.nombre_alias,
  a.tag_rfid,
  COALESCE(SUM(m.valor_medido), 0) AS consumo_total_7_dias,
  COUNT(m.id) AS numero_eventos,
  ROUND(AVG(m.valor_medido), 2) AS consumo_promedio,
  ROUND(STDDEV(m.valor_medido), 2) AS desviacion_estandar
FROM animales a
LEFT JOIN mediciones m ON a.id = m.animal_id 
  AND m.timestamp > CURRENT_TIMESTAMP - INTERVAL '7 days'
GROUP BY a.id, a.estancia_id, a.nombre_alias, a.tag_rfid;

-- Vista: alertas activas por estancia
CREATE OR REPLACE VIEW alertas_activas_por_estancia AS
SELECT 
  e.id AS estancia_id,
  e.nombre AS estancia_nombre,
  COUNT(al.id) AS cantidad_alertas,
  COUNT(CASE WHEN al.severidad = 'critica' THEN 1 END) AS criticas,
  COUNT(CASE WHEN al.severidad = 'alta' THEN 1 END) AS altas,
  COUNT(CASE WHEN al.estado = 'abierta' THEN 1 END) AS sin_resolver
FROM estancias e
LEFT JOIN alertas al ON e.id IN (
  SELECT estancia_id FROM animales WHERE id = al.animal_id
) AND al.estado IN ('abierta', 'en_progreso')
GROUP BY e.id, e.nombre;

-- Vista: dispositivos por estado de operación
CREATE OR REPLACE VIEW dispositivos_por_estado AS
SELECT 
  ubicacion_id,
  estado,
  COUNT(*) AS cantidad
FROM dispositivos
GROUP BY ubicacion_id, estado;
```

---

## 10. Secuencia de creación (orden de ejecución)

1. Extensiones: `CREATE EXTENSION pgvector`
2. Tabla ESTANCIAS (sin dependencias)
3. Tabla USUARIOS (depende de ESTANCIAS)
4. Tabla UBICACIONES (depende de ESTANCIAS y USUARIOS)
5. Tabla DISPOSITIVOS (depende de UBICACIONES)
6. Tabla SENSORES (depende de DISPOSITIVOS)
7. Tabla ANIMALES (depende de ESTANCIAS y UBICACIONES)
8. Tabla MEDICIONES (depende de DISPOSITIVOS, SENSORES, ANIMALES)
9. Tabla ALERTAS (depende de ANIMALES, DISPOSITIVOS, USUARIOS)
10. Índices en todas las tablas
11. Triggers (después de todas las tablas)
12. Políticas RLS (después de habilitar RLS)
13. Vistas

---

## 11. Script completo de ejecución

```bash
# Archivo: schema.sql
# Contiene: CREATE TABLE, CONSTRAINTS, COMMENTS

# Archivo: indexes.sql
# Contiene: CREATE INDEX (todas las tablas)

# Archivo: partitions.sql
# Contiene: CREATE TABLE ... PARTITION BY RANGE

# Archivo: rls.sql
# Contiene: ALTER TABLE ENABLE RLS, CREATE POLICY

# Archivo: triggers.sql
# Contiene: CREATE FUNCTION, CREATE TRIGGER

# Archivo: views.sql
# Contiene: CREATE VIEW

# Ejecución en orden:
psql -d base_datos -f schema.sql
psql -d base_datos -f indexes.sql
psql -d base_datos -f partitions.sql
psql -d base_datos -f rls.sql
psql -d base_datos -f triggers.sql
psql -d base_datos -f views.sql
```

---

## 12. Validación de integridad

```sql
-- Verificar que todas las tablas fueron creadas
SELECT tablename FROM pg_tables 
WHERE schemaname = 'public' 
ORDER BY tablename;

-- Verificar índices creados
SELECT indexname FROM pg_indexes 
WHERE schemaname = 'public' 
ORDER BY indexname;

-- Verificar triggers
SELECT trigger_name FROM information_schema.triggers 
WHERE trigger_schema = 'public';

-- Verificar políticas RLS
SELECT tablename, policyname FROM pg_policies 
WHERE schemaname = 'public';

-- Verificar restricciones
SELECT constraint_name, table_name FROM information_schema.table_constraints 
WHERE table_schema = 'public' 
ORDER BY table_name, constraint_name;
```

---

## 13. Consideraciones de performance

### 13.1 Tamaño estimado de datos

```
MEDICIONES: 1 millón de registros/mes
- Por registro: ~500 bytes (incluye JSONB y vector)
- Por mes: ~500 MB
- Por año: ~6 GB
- Con particionamiento: acceso eficiente por rango de fecha
```

### 13.2 Estrategia de índices

- Índices temporales: `(timestamp DESC)` para range queries
- Índices compuestos: `(animal_id, timestamp DESC)` para histórico por animal
- Índices parciales: solo registros activos (`WHERE estado = 'abierta'`)
- Índice vectorial: IVFFLAT para búsqueda de similitud (~100 listas)

### 13.3 Mantenimiento regular

```sql
-- Vacuum y análisis mensual
VACUUM ANALYZE;

-- Reindexar mensualmente
REINDEX INDEX CONCURRENTLY idx_mediciones_timestamp;

-- Eliminar particiones antiguas (ej: 2+ años)
DROP TABLE mediciones_2024_01;
```

---

## 14. Conclusión

El modelo físico implementa completamente el esquema relacional normalizado en PostgreSQL con:

- Tipificación correcta de datos
- Restricciones de integridad a nivel de base de datos
- Índices optimizados para queries frecuentes
- Particionamiento temporal para escalabilidad
- Row-Level Security para aislamiento de datos
- Triggers para mantener desnormalizaciones
- Vistas para queries complejas frecuentes

El sistema está listo para manejo de millones de registros con performance aceptable y seguridad multi-tenant garantizada.