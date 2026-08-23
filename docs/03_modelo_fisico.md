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
CREATE EXTENSION IF NOT EXISTS vector;
```

El nombre de la extensión en PostgreSQL es `vector` (el proyecto se llama "pgvector", pero
`CREATE EXTENSION pgvector` falla — es un error común). Permite almacenar y consultar vectores
de dimensionalidad alta (embeddings de 768 dimensiones para patrones de consumo).

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

### 3.7 MEDICIONES (particionada por rango de `timestamp`)

```sql
-- PARTITION BY exige que toda PK/UNIQUE incluya la columna de partición: por eso la PK es
-- (id, timestamp) y no id simple. La unicidad de id la sigue garantizando el generador
-- (seq_mediciones); ver particiones.sql para las particiones reales.
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

`mediciones` ya se crea `PARTITION BY RANGE (timestamp)` en `schema.sql` (sección 3.7); este
archivo (`db/estructura/particiones.sql`) solo agrega las particiones concretas — una por mes
de 2026 más una partición `DEFAULT` que evita que un `INSERT` falle si su timestamp cae fuera
de los rangos explícitos (por ejemplo, datos de prueba fechados en 2025):

```sql
CREATE TABLE mediciones_2026_01 PARTITION OF mediciones
  FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');

CREATE TABLE mediciones_2026_02 PARTITION OF mediciones
  FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');

-- ... una partición por cada mes de 2026 (ver particiones.sql para las 12 completas)

CREATE TABLE mediciones_2026_12 PARTITION OF mediciones
  FOR VALUES FROM ('2026-12-01') TO ('2027-01-01');

-- Partición de respaldo: cualquier timestamp fuera de los rangos mensuales explícitos
CREATE TABLE mediciones_default PARTITION OF mediciones DEFAULT;
```

Los índices de `indexes.sql` (sección 5) se crean **después** de este script, sobre la tabla
particionada `mediciones`: PostgreSQL propaga automáticamente cada `CREATE INDEX` a todas las
particiones existentes, y a cualquier partición que se agregue después. Lo mismo aplica a los
triggers (sección 7) y a las políticas RLS (sección 6): se definen una sola vez sobre la tabla
particionada y valen para todas sus particiones sin repetir la definición.

**Ventajas del particionamiento temporal**:
- Queries por rango de fecha son más rápidas (escanea solo particiones relevantes — partition
  pruning, aprovechado por las consultas representativas 1 y 2)
- Mantenimiento: eliminar datos antiguos es `DROP TABLE mediciones_2024_01` en vez de un
  `DELETE` masivo
- Escalabilidad: agregar nuevas particiones mensualmente (tarea operativa recurrente, no
  automática — ver `arquitectura/escalabilidad.md`, sección 2, para el trade-off)

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

La estrategia real (implementada en `db/estructura/rls.sql`) usa una variable de sesión
(`app.estancia_id`) fijada por la aplicación al conectar, en vez de resolver la estancia con
una subconsulta a `usuarios` en cada política — es más simple y evita una vuelta extra a la
base en cada fila evaluada. Es la misma técnica que se muestra en el ejemplo simplificado del
informe técnico.

**Importante — un superusuario bypassea RLS**: PostgreSQL ignora las políticas RLS para
superusuarios y para el dueño de la tabla, sin importar cuántas políticas existan. El
contenedor de `docker-compose.yml` crea al usuario `postgres` como superusuario (necesario
para que `docker-entrypoint-initdb.d` pueda crear tablas, roles y extensiones), así que
**conectarse como `postgres` para "probar" RLS siempre va a mostrar todas las filas** — no es
que las políticas fallen, es que no aplican. Por eso `rls.sql` crea además un rol de
aplicación sin ese privilegio:

```sql
-- Rol de aplicación: NOSUPERUSER + NOBYPASSRLS (el valor por defecto de un rol nuevo ya es
-- NOBYPASSRLS; se lo deja explícito para que la intención quede clara en el script)
CREATE ROLE app_user LOGIN PASSWORD 'app_user_password' NOSUPERUSER NOBYPASSRLS;

GRANT CONNECT ON DATABASE monitoreo_iot_ganaderia TO app_user;
GRANT USAGE ON SCHEMA public TO app_user;
GRANT SELECT, INSERT, UPDATE ON
  estancias, usuarios, ubicaciones, dispositivos, sensores, animales, mediciones, alertas
  TO app_user;

-- Habilitar RLS en tablas de datos (incluida ESTANCIAS: sin esto, cualquier usuario
-- autenticado podría listar estancias que no son la suya)
ALTER TABLE estancias ENABLE ROW LEVEL SECURITY;
ALTER TABLE usuarios ENABLE ROW LEVEL SECURITY;
ALTER TABLE ubicaciones ENABLE ROW LEVEL SECURITY;
ALTER TABLE dispositivos ENABLE ROW LEVEL SECURITY;
ALTER TABLE sensores ENABLE ROW LEVEL SECURITY;
ALTER TABLE animales ENABLE ROW LEVEL SECURITY;
ALTER TABLE mediciones ENABLE ROW LEVEL SECURITY;
ALTER TABLE alertas ENABLE ROW LEVEL SECURITY;

-- Política RLS en ESTANCIAS: cada usuario ve solo el registro de su propia estancia
CREATE POLICY estancias_own ON estancias
  FOR SELECT
  USING (id = current_setting('app.estancia_id')::BIGINT);

-- Política RLS en USUARIOS: cada usuario ve solo usuarios de su estancia
CREATE POLICY usuarios_own_estancia ON usuarios
  FOR SELECT
  USING (estancia_id = current_setting('app.estancia_id')::BIGINT);
-- + políticas INSERT/UPDATE equivalentes con WITH CHECK (misma condición)

-- Política RLS en ANIMALES: acceso solo a animales de su estancia
CREATE POLICY animales_own_estancia ON animales
  FOR SELECT
  USING (estancia_id = current_setting('app.estancia_id')::BIGINT);

-- Política RLS en MEDICIONES: acceso vía la cadena dispositivo -> ubicación -> estancia
CREATE POLICY mediciones_own_estancia ON mediciones
  FOR SELECT
  USING (dispositivo_id IN (
    SELECT d.id FROM dispositivos d
    WHERE d.ubicacion_id IN (
      SELECT id FROM ubicaciones WHERE estancia_id = current_setting('app.estancia_id')::BIGINT
    )
  ));

-- Política RLS en ALERTAS: acceso vía animal_id o vía dispositivo_id (alertas de hardware
-- pueden no tener animal asociado)
CREATE POLICY alertas_own_estancia ON alertas
  FOR SELECT
  USING (
    animal_id IN (SELECT id FROM animales WHERE estancia_id = current_setting('app.estancia_id')::BIGINT)
    OR dispositivo_id IN (
      SELECT d.id FROM dispositivos d
      WHERE d.ubicacion_id IN (
        SELECT id FROM ubicaciones WHERE estancia_id = current_setting('app.estancia_id')::BIGINT
      )
    )
  );
```

Ver `db/estructura/rls.sql` para el listado completo (incluye las políticas `INSERT`/`UPDATE`
de cada tabla, omitidas acá por espacio) y `README.md`, sección "Probar el aislamiento
multi-tenant (RLS)", para el procedimiento de verificación con `app_user`.

**Fail-closed por diseño**: si una sesión de `app_user` no ejecuta `SET app.estancia_id` antes
de consultar, `current_setting('app.estancia_id')` lanza un error (`unrecognized configuration
parameter`) en vez de devolver `NULL` o todas las filas — un bug de la aplicación que se
olvida de fijar la estancia falla ruidosamente, no filtra datos en silencio.

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
WHEN (NEW.animal_id IS NOT NULL)
EXECUTE FUNCTION actualizar_ubicacion_animal();
```

### 7.3 Trigger: detección automática de anomalías

`BEFORE INSERT OR UPDATE` sobre `mediciones`: compara el nuevo valor contra el promedio ±2
desviaciones estándar de las mediciones previas del mismo animal en los últimos 7 días.

**Corrección aplicada sobre la primera versión**: con menos de ~5 mediciones previas, la
desviación estándar de la muestra es 0 (con 1 dato) o un valor muy inestable, así que
*cualquier* variación normal de un animal sano quedaba marcada como anomalía — se detectó
este falso positivo al cargar los primeros datos de ejemplo (6 de 17 mediciones marcadas como
"crítica" incluyendo animales sanos). La versión final exige un mínimo de 5 mediciones previas
antes de evaluar, y aplica un piso de desviación (5% del promedio) para evitar límites de
ancho cero cuando el historial fue casi constante:

```sql
CREATE OR REPLACE FUNCTION detectar_anomalia()
RETURNS TRIGGER AS $$
DECLARE
  v_cantidad_previa INTEGER;
  v_promedio_7_dias DECIMAL(10,3);
  v_desviacion DECIMAL(10,3);
  v_limite_superior DECIMAL(10,3);
  v_limite_inferior DECIMAL(10,3);
BEGIN
  SELECT COUNT(*), COALESCE(AVG(valor_medido), 0), COALESCE(STDDEV(valor_medido), 0)
  INTO v_cantidad_previa, v_promedio_7_dias, v_desviacion
  FROM mediciones
  WHERE animal_id = NEW.animal_id
    AND timestamp > NEW.timestamp - INTERVAL '7 days'
    AND timestamp < NEW.timestamp
    AND id != NEW.id;

  IF NEW.animal_id IS NULL OR v_cantidad_previa < 5 THEN
    NEW.es_anomalia := FALSE;
    NEW.puntuacion_anomalia := NULL;
    RETURN NEW;
  END IF;

  v_desviacion := GREATEST(v_desviacion, v_promedio_7_dias * 0.05);
  v_limite_superior := v_promedio_7_dias + (2 * v_desviacion);
  v_limite_inferior := GREATEST(0, v_promedio_7_dias - (2 * v_desviacion));

  IF NEW.valor_medido > v_limite_superior OR NEW.valor_medido < v_limite_inferior THEN
    NEW.es_anomalia := TRUE;
    NEW.puntuacion_anomalia := LEAST(1.0, ABS(NEW.valor_medido - v_promedio_7_dias) / GREATEST(v_desviacion, 0.1));
  ELSE
    NEW.es_anomalia := FALSE;
    NEW.puntuacion_anomalia := 0.0;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tg_detectar_anomalia
BEFORE INSERT OR UPDATE ON mediciones
FOR EACH ROW
EXECUTE FUNCTION detectar_anomalia();
```

### 7.4 Trigger: generación automática de alerta ante una anomalía

`AFTER INSERT` sobre `mediciones`, condicionado a `NEW.es_anomalia = TRUE` (ya calculado por
el trigger anterior, que corre antes por ser `BEFORE INSERT`): inserta una fila en `alertas`
con severidad proporcional a `puntuacion_anomalia`. Ver `db/estructura/triggers.sql` para la
función completa (`generar_alerta_anomalia`).

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

Implementadas en `db/estructura/views.sql`: `animales_consumo_7_dias`,
`alertas_con_estancia` (vista auxiliar que resuelve la estancia de una alerta tanto por
`animal_id` como por `dispositivo_id`, para cubrir alertas de hardware sin animal asociado),
`alertas_activas_por_estancia` y `dispositivos_por_estado`. La consulta representativa #7
(`db/consultas/queries_representativas.sql`) usa `alertas_activas_por_estancia` como panorama
ejecutivo multi-estancia.

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

El orden real (el que ejecuta `docker-compose.yml` vía `docker-entrypoint-initdb.d`, en orden
alfabético por el prefijo numérico del nombre de archivo montado):

```bash
# 01: db/estructura/schema.sql       -> CREATE TABLE, CONSTRAINTS, COMMENTS (mediciones ya
#                                        declarada PARTITION BY RANGE)
# 02: db/estructura/particiones.sql  -> CREATE TABLE ... PARTITION OF (particiones mensuales)
# 03: db/estructura/indexes.sql      -> CREATE INDEX (se propaga a todas las particiones)
# 04: db/estructura/triggers.sql     -> CREATE FUNCTION, CREATE TRIGGER
# 05: db/estructura/rls.sql          -> CREATE ROLE app_user, ENABLE RLS, CREATE POLICY
# 06: db/estructura/views.sql        -> CREATE VIEW
# 07: db/vectorial/embeddings.sql    -> CREATE FUNCTION animales_similares()
# 08: data/ejemplos/datos_simulados.sql -> INSERT de datos de ejemplo

# Particiones e índices van antes que triggers/RLS porque son propiedades estructurales de la
# tabla; triggers y políticas, al definirse sobre la tabla particionada (no sobre cada
# partición), no dependen de ese orden pero se agrupan después por claridad.

# Ejecución manual (fuera de docker-compose):
psql -d monitoreo_iot_ganaderia -f db/estructura/schema.sql
psql -d monitoreo_iot_ganaderia -f db/estructura/particiones.sql
psql -d monitoreo_iot_ganaderia -f db/estructura/indexes.sql
psql -d monitoreo_iot_ganaderia -f db/estructura/triggers.sql
psql -d monitoreo_iot_ganaderia -f db/estructura/rls.sql
psql -d monitoreo_iot_ganaderia -f db/estructura/views.sql
psql -d monitoreo_iot_ganaderia -f db/vectorial/embeddings.sql
psql -d monitoreo_iot_ganaderia -f data/ejemplos/datos_simulados.sql
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