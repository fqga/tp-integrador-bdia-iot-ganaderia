# Modelo lógico: normalización y diseño relacional

## 1. Transición del modelo conceptual al lógico

El **modelo conceptual** describe qué datos existen y cómo se relacionan en el dominio (sin preocuparse por tecnología). El **modelo lógico** traduce esto a una estructura relacional normalizada, considerando:

- Tablas explícitas y claves primarias
- Claves foráneas y sus restricciones
- Normalización según niveles (1NF, 2NF, 3NF, BCNF)
- Trade-offs entre integridad y performance

---

## 2. Formas normales y cumplimiento

### 2.1 Primera forma normal (1NF)

**Definición**: Cada atributo contiene un único valor (no listas o conjuntos).

**Violación de 1NF**:
```sql
CREATE TABLE animales_incorrecto (
  id SERIAL PRIMARY KEY,
  nombre VARCHAR(100),
  tags_rfid TEXT[], -- Viola 1NF: atributo multivaluado
  ubicaciones TEXT[] -- Viola 1NF
);
```

**Aplicación correcta**:
```sql
CREATE TABLE animales (
  id SERIAL PRIMARY KEY,
  tag_rfid VARCHAR(50) NOT NULL UNIQUE, -- Un solo valor
  nombre VARCHAR(100)
);
```

**Cumplimiento**: Todos los atributos en el modelo propuesto son atómicos. El esquema cumple con 1NF.

---

### 2.2 Segunda forma normal (2NF)

**Definición**: Está en 1NF Y cada atributo no-clave depende completamente de toda la clave primaria (no solo de parte de ella).

**Violación de 2NF**:
```sql
CREATE TABLE mediciones_incorrecto (
  dispositivo_id BIGINT,
  sensor_id BIGINT,
  timestamp TIMESTAMP,
  valor_medido DECIMAL(10,3),
  
  -- Estos dependen solo de dispositivo_id, no de toda la PK
  tipo_dispositivo VARCHAR(50),
  ubicacion_dispositivo VARCHAR(100),
  
  PRIMARY KEY (dispositivo_id, sensor_id, timestamp)
);
```

**Aplicación correcta**:
```sql
CREATE TABLE mediciones (
  id SERIAL PRIMARY KEY, -- Clave simple
  dispositivo_id BIGINT NOT NULL,
  sensor_id BIGINT NOT NULL,
  timestamp TIMESTAMP NOT NULL,
  valor_medido DECIMAL(10,3) NOT NULL,
  FOREIGN KEY (dispositivo_id) REFERENCES dispositivos(id),
  FOREIGN KEY (sensor_id) REFERENCES sensores(id)
);

-- tipo_dispositivo y ubicación están en tabla DISPOSITIVOS
```

**Cumplimiento**: Cada tabla utiliza una clave primaria simple, y todos los atributos dependen completamente de ella. El esquema cumple con 2NF.

---

### 2.3 Tercera forma normal (3NF)

**Definición**: Está en 2NF Y ningún atributo no-clave depende transitivamente de la clave primaria.

**Violación de 3NF**:
```sql
CREATE TABLE dispositivos_incorrecto (
  id SERIAL PRIMARY KEY,
  ubicacion_id BIGINT,
  tipo_dispositivo VARCHAR(50),
  ubicacion_nombre VARCHAR(150), -- Depende de ubicacion_id, NO de id
  ubicacion_tipo VARCHAR(50)     -- Depende transitivamente
);
```

**Aplicación correcta**:
```sql
CREATE TABLE dispositivos (
  id SERIAL PRIMARY KEY,
  ubicacion_id BIGINT NOT NULL,
  tipo_dispositivo VARCHAR(50),
  FOREIGN KEY (ubicacion_id) REFERENCES ubicaciones(id)
);

CREATE TABLE ubicaciones (
  id SERIAL PRIMARY KEY,
  nombre VARCHAR(150),
  tipo VARCHAR(50)
);
```

**Cumplimiento**: Las dependencias transitivas se eliminan mediante claves foráneas explícitas. El esquema cumple con 3NF.

---

## 3. Esquema relacional normalizado (3NF)

### 3.1 Tablas finales

#### USUARIOS
```sql
CREATE TABLE usuarios (
  id SERIAL PRIMARY KEY,
  estancia_id BIGINT NOT NULL,
  nombre VARCHAR(100) NOT NULL,
  email VARCHAR(255) NOT NULL,
  contraseña_hash VARCHAR(255) NOT NULL,
  rol VARCHAR(50) NOT NULL,
  activo BOOLEAN DEFAULT TRUE,
  fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  FOREIGN KEY (estancia_id) REFERENCES estancias(id),
  UNIQUE (estancia_id, email),
  CHECK (rol IN ('peón', 'encargado', 'veterinario', 'admin'))
);
```

**Justificación 3NF**: La clave primaria es `id`. Todos los atributos dependen directamente de la clave primaria. No existen dependencias transitivas.

---

#### ESTANCIAS
```sql
CREATE TABLE estancias (
  id BIGINT PRIMARY KEY,
  nombre VARCHAR(200) NOT NULL UNIQUE,
  descripcion TEXT,
  ubicacion_ciudad VARCHAR(100),
  ubicacion_provincia VARCHAR(100),
  tipo_produccion VARCHAR(50) NOT NULL,
  cantidad_animales_actual INTEGER DEFAULT 0,
  contacto_responsable VARCHAR(255),
  activa BOOLEAN DEFAULT TRUE,
  fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  CHECK (tipo_produccion IN ('engorde', 'cría', 'lechería', 'mixto')),
  CHECK (cantidad_animales_actual >= 0)
);
```

**Justificación 3NF**: La clave primaria es `id`. Todos los campos son propiedades descriptivas de la estancia sin dependencias transitivas.

---

#### UBICACIONES
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
  activa BOOLEAN DEFAULT TRUE,
  fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  FOREIGN KEY (estancia_id) REFERENCES estancias(id) ON DELETE CASCADE,
  FOREIGN KEY (responsable_usuario_id) REFERENCES usuarios(id) ON DELETE SET NULL,
  UNIQUE (estancia_id, nombre),
  CHECK (capacidad_animales > 0),
  CHECK (tipo IN ('corral', 'encierre', 'peseada', 'galpón'))
);
```

**Justificación 3NF**: La clave primaria es `id`. Las dependencias a otras entidades se expresan mediante claves foráneas explícitas. No hay atributos que dependan transitivamente de `id`.

---

#### DISPOSITIVOS
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
  estado VARCHAR(50) DEFAULT 'operacional',
  configuracion JSONB DEFAULT '{}',
  firmware_version VARCHAR(50),
  fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  FOREIGN KEY (ubicacion_id) REFERENCES ubicaciones(id) ON DELETE CASCADE,
  CHECK (fecha_retiro IS NULL OR fecha_retiro >= fecha_instalacion),
  CHECK (tipo_dispositivo IN ('comedero', 'bebedero')),
  CHECK (estado IN ('operacional', 'mantenimiento', 'falla'))
);
```

**Justificación 3NF**: La clave primaria es `id`. La dependencia a `ubicacion_id` es expresada mediante clave foránea. El campo `configuracion` en formato JSONB permite flexibilidad sin introducir dependencias transitivas.

---

#### SENSORES
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
  estado VARCHAR(50) DEFAULT 'operacional',
  activo BOOLEAN DEFAULT TRUE,
  fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  FOREIGN KEY (dispositivo_id) REFERENCES dispositivos(id) ON DELETE CASCADE,
  CHECK (tipo_sensor IN ('rfid', 'pesaje', 'temperatura', 'humedad')),
  CHECK (rango_minimo < rango_maximo),
  CHECK (precision_declarada > 0)
);
```

**Justificación 3NF**: La clave primaria es `id`. Todos los atributos describen características del sensor. La dependencia a `dispositivo_id` es expresada mediante clave foránea.

---

#### ANIMALES
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
  estado_salud VARCHAR(50) DEFAULT 'sano',
  ubicacion_actual_id BIGINT,
  fecha_ingreso_estancia DATE NOT NULL,
  fecha_egreso_estancia DATE,
  motivo_egreso VARCHAR(255),
  fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  FOREIGN KEY (estancia_id) REFERENCES estancias(id) ON DELETE CASCADE,
  FOREIGN KEY (ubicacion_actual_id) REFERENCES ubicaciones(id) ON DELETE SET NULL,
  UNIQUE (estancia_id, tag_rfid),
  CHECK (fecha_egreso_estancia IS NULL OR fecha_egreso_estancia >= fecha_ingreso_estancia),
  CHECK (sexo IN ('macho', 'hembra', 'indefinido')),
  CHECK (estado_salud IN ('sano', 'enfermo', 'en_tratamiento', 'descarte'))
);
```

**Justificación 3NF**: La clave primaria es `id`. Las dependencias se expresan mediante claves foráneas. Todos los atributos describen propiedades del animal sin dependencias transitivas.

---

#### MEDICIONES
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
  es_anomalia BOOLEAN DEFAULT FALSE,
  puntuacion_anomalia DECIMAL(5,3),
  embedding_patron vector(768),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  FOREIGN KEY (dispositivo_id) REFERENCES dispositivos(id),
  FOREIGN KEY (sensor_id) REFERENCES sensores(id),
  FOREIGN KEY (animal_id) REFERENCES animales(id) ON DELETE SET NULL,
  CHECK (valor_medido >= 0),
  CHECK (duracion_evento_segundos > 0 OR duracion_evento_segundos IS NULL),
  CHECK (temperatura_ambiental_celsius BETWEEN -40 AND 50),
  CHECK (humedad_ambiental_pct BETWEEN 0 AND 100),
  CHECK (puntuacion_anomalia BETWEEN 0 AND 1 OR puntuacion_anomalia IS NULL)
);
```

**Justificación 3NF**: La clave primaria es `id`. Las dependencias a otras entidades se expresan mediante claves foráneas. Todos los atributos describen una medición específica sin transitividades. El campo `datos_crudos` en formato JSONB permite capturar información variable sin afectar la normalización.

**Nota sobre particionamiento**: Esta tabla será particionada por timestamp en la implementación física, pero a nivel lógico se trata de una tabla única.

---

#### ALERTAS
```sql
CREATE TABLE alertas (
  id BIGINT PRIMARY KEY,
  animal_id BIGINT,
  dispositivo_id BIGINT,
  tipo_alerta VARCHAR(50) NOT NULL,
  severidad VARCHAR(50) NOT NULL,
  timestamp_alerta TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  descripcion TEXT NOT NULL,
  datos_contextuales JSONB,
  estado VARCHAR(50) DEFAULT 'abierta',
  usuario_responsable_id BIGINT,
  timestamp_resolucion TIMESTAMP,
  notas_resolucion TEXT,
  fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  FOREIGN KEY (animal_id) REFERENCES animales(id) ON DELETE SET NULL,
  FOREIGN KEY (dispositivo_id) REFERENCES dispositivos(id) ON DELETE SET NULL,
  FOREIGN KEY (usuario_responsable_id) REFERENCES usuarios(id) ON DELETE SET NULL,
  CHECK ((animal_id IS NOT NULL) OR (dispositivo_id IS NOT NULL)),
  CHECK (tipo_alerta IN ('bajo_consumo', 'no_presencia', 'falla_sensor', 'consumo_atipico')),
  CHECK (severidad IN ('baja', 'media', 'alta', 'critica')),
  CHECK (estado IN ('abierta', 'en_progreso', 'resuelta')),
  CHECK (timestamp_resolucion IS NULL OR timestamp_resolucion >= timestamp_alerta)
);
```

**Justificación 3NF**: La clave primaria es `id`. Las dependencias se expresan mediante claves foráneas. Todos los atributos describen una alerta específica. El campo `datos_contextuales` en formato JSONB permite capturar información contextual sin afectar la normalización.

---

## 4. Decisiones de desnormalización controlada

### 4.1 Campo `cantidad_animales_actual` en ESTANCIAS

**Ubicación**: Tabla ESTANCIAS

**Análisis de la desnormalización**:

Si se mantuviera la normalización estricta, la cantidad de animales activos en una estancia debería calcularse mediante:
```sql
SELECT COUNT(*) FROM animales 
WHERE estancia_id = X AND fecha_egreso_estancia IS NULL
```

En un sistema de producción con millones de animales, esta consulta se ejecutaría miles de veces. Implicaciones de performance:
- Escaneo de tabla completa O(n)
- Múltiples índices necesarios
- Latencia inaceptable en dashboards

**Solución implementada**: Campo desnormalizado `cantidad_animales_actual` en tabla ESTANCIAS.

**Trade-offs**:
- Ventaja: Consulta O(1) - lectura directa sin cálculo
- Desventaja: Overhead de mantenimiento mediante trigger o batch job

**Estrategia de consistencia** (implementada mediante trigger, ver `db/estructura/triggers.sql`):
```sql
CREATE OR REPLACE FUNCTION actualizar_cantidad_animales()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE estancias 
  SET cantidad_animales_actual = (
    SELECT COUNT(*) FROM animales 
    WHERE estancia_id = NEW.estancia_id AND fecha_egreso_estancia IS NULL
  )
  WHERE id = NEW.estancia_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_cantidad_animales
AFTER INSERT OR UPDATE ON animales
FOR EACH ROW
EXECUTE FUNCTION actualizar_cantidad_animales();
```

**Decisión**: La desnormalización se justifica porque consultas de resumen son muy frecuentes y la consistencia se garantiza mediante trigger.

---

### 4.2 Campo `ubicacion_actual_id` en ANIMALES

**Ubicación**: Tabla ANIMALES

**Análisis de la desnormalización**:

Sin desnormalización, la ubicación actual de un animal requeriría consulta compleja:
```sql
SELECT ubicacion_id FROM ubicaciones 
WHERE id IN (SELECT ubicacion_id FROM dispositivos 
  WHERE id IN (SELECT dispositivo_id FROM mediciones 
    WHERE animal_id = X ORDER BY timestamp DESC LIMIT 1))
```

Esta consulta es muy costosa (múltiples joins con tabla MEDICIONES de millones de registros).

**Solución implementada**: Campo desnormalizado `ubicacion_actual_id` en tabla ANIMALES.

**Trade-offs**:
- Ventaja: Consulta directa "¿dónde está el animal ahora?" en O(1)
- Desventaja: Requiere sincronización cuando animal se mueve entre ubicaciones

**Decisión**: La desnormalización se justifica porque "ubicación actual" es consulta muy frecuente en operaciones ganaderas.

---

### 4.3 Almacenamiento JSONB en lugar de tablas separadas

#### 4.3.1 DISPOSITIVOS.configuracion
```json
{
  "calibracion_pesaje": 0.98,
  "umbral_presencia_kg": 100,
  "umbral_alerta_bajo_stock": 5,
  "intervalo_reporte": 60,
  "sensibilidad_rfid": "alta"
}
```

**Justificación**:
- Configuración varía significativamente entre modelos de dispositivos
- No se requiere filtrado frecuente por parámetros específicos
- Flexibilidad necesaria para evolucionar sin cambios de schema
- Evita fragmentación en 10+ tablas de configuración por tipo de dispositivo

**Alternativa rechazada**: Tabla separada `configuraciones_dispositivos` sería justificada solo si se requirieran queries como "encontrar dispositivos con calibración < 0.95".

#### 4.3.2 MEDICIONES.datos_crudos
```json
{
  "rssi_rfid": -65,
  "numero_intentos_lectura": 2,
  "latencia_ms": 34,
  "nivel_bateria_sensor": 87
}
```

**Justificación**:
- Información adicional que no siempre se captura
- Varía por tipo de sensor
- No se filtra en queries principales
- Facilita auditoría y debugging

#### 4.3.3 ALERTAS.datos_contextuales
```json
{
  "promedio_7_dias_kg": 15.5,
  "consumo_actual_kg": 8.2,
  "desviacion_estandar": 1.2,
  "percentil_consumo": 15,
  "temperatura_correlacion": 22.5
}
```

**Justificación**:
- Contexto que motivó la alerta puede cambiar según lógica de detección
- Permite auditoría de qué datos influyeron en qué decisión
- No requiere normalización

---

## 5. Análisis de anomalías de base de datos

### 5.1 Anomalía de actualización

**Escenario**: Cambiar nombre de ubicación de "Corral A" a "Corral Norte Nueva".

**Problema en diseño incorrecto** (si ubicacion_nombre estuviera en DISPOSITIVOS):
```sql
UPDATE dispositivos SET ubicacion_nombre = 'Corral Norte Nueva'
WHERE ubicacion_id = 5;
```
Requeriría actualizar 1000 filas si hay 1000 dispositivos en esa ubicación. Riesgo de inconsistencia.

**Solución en diseño propuesto**:
```sql
UPDATE ubicaciones SET nombre = 'Corral Norte Nueva' WHERE id = 5;
```
Actualización única. DISPOSITIVOS mantiene referencia via FK.

**Resultado**: Libre de anomalía de actualización.

---

### 5.2 Anomalía de inserción

**Escenario**: Registrar una nueva estancia sin animales inicialmente.

**Problema en diseño incorrecto** (tabla conjunta estancia-animal):
```sql
INSERT INTO estancia_animales (estancia_id, animal_id, tag_rfid, raza, nombre_estancia)
VALUES (10, NULL, NULL, NULL, 'Nueva Estancia');
-- Imposible: animal_id no puede ser NULL en relación de composición
```

**Solución en diseño propuesto**:
```sql
INSERT INTO estancias (id, nombre, tipo_produccion) 
VALUES (10, 'Nueva Estancia', 'engorde');
-- Funciona sin necesidad de animales existentes
```

**Resultado**: Libre de anomalía de inserción.

---

### 5.3 Anomalía de eliminación

**Escenario**: Borrar el único animal en una ubicación.

**Problema en diseño incorrecto** (si ubicacion_tipo estuviera en ANIMALES):
```sql
DELETE FROM animales WHERE id = 999;
-- Se pierden datos sobre la ubicación (ubicacion_tipo, etc)
```

**Solución en diseño propuesto**:
```sql
DELETE FROM animales WHERE id = 999;
-- La ubicación persiste en tabla UBICACIONES
```

**Resultado**: Libre de anomalía de eliminación.

---

## 6. Integridad referencial y política de cascadas

### 6.1 Restricciones ON DELETE

```sql
-- ON DELETE CASCADE: borrar estancia → elimina datos dependientes en cascada
FOREIGN KEY (estancia_id) REFERENCES estancias(id) ON DELETE CASCADE
-- Afecta: ubicaciones, dispositivos, sensores, animales, mediciones, alertas

-- ON DELETE SET NULL: borrar usuario responsable → alerta queda sin responsable
FOREIGN KEY (usuario_responsable_id) REFERENCES usuarios(id) ON DELETE SET NULL

-- ON DELETE SET NULL: borrar animal → mediciones conservan histórico con animal_id = NULL
FOREIGN KEY (animal_id) REFERENCES animales(id) ON DELETE SET NULL
```

**Justificación de políticas**:
- CASCADE en estancia: relación de composición completa (tabla existe solo si estancia existe)
- SET NULL en usuario: relación débil (alerta puede quedar sin responsable sin perder integridad)
- SET NULL en animal: preserva histórico de mediciones aunque animal sea eliminado

---

## 7. Resumen de decisiones de normalización

| Tabla | Forma Normal | Desviaciones | Justificación |
|---|---|---|---|
| USUARIOS | 3NF | Ninguna | Totalmente normalizado |
| ESTANCIAS | 3NF-0.5 | Campo `cantidad_animales_actual` desnormalizado | Performance en conteos frecuentes |
| UBICACIONES | 3NF | Ninguna | Totalmente normalizado |
| DISPOSITIVOS | 3NF-0.5 | Atributo JSONB `configuracion` | Flexibilidad de parámetros por modelo |
| SENSORES | 3NF | Ninguna | Totalmente normalizado |
| ANIMALES | 3NF-0.5 | Campo `ubicacion_actual_id` desnormalizado | Ubicación actual es consulta frecuente |
| MEDICIONES | 3NF-0.5 | Atributos JSONB `datos_crudos` y vectorial `embedding_patron` | Información variable y vectores de similitud |
| ALERTAS | 3NF-0.5 | Atributo JSONB `datos_contextuales` | Contexto de generación de alerta |

**Conclusión**: El esquema general cumple con 3NF con 3 desnormalizaciones controladas y justificadas por requerimientos de performance.

---

## 8. Comparación: alternativas tecnológicas consideradas

### 8.1 PostgreSQL (relacional) vs MongoDB (NoSQL)

**Ventajas de MongoDB**:
- Flexibilidad en schema de documentos
- Bueno para datos semi-estructurados
- Escalabilidad horizontal nativa

**Desventajas de MongoDB para este caso**:
- Carencia de transacciones ACID (relaciones entre mediciones y alertas deben ser consistentes)
- Falta de integridad referencial nativa (¿qué ocurre si se elimina un dispositivo con millones de mediciones?)
- Multi-tenancy requiere lógica de aplicación más compleja
- Row-Level Security no existe de forma nativa

**Decisión**: PostgreSQL es más apropiado debido a requerimientos de relaciones complejas y garantías ACID.

---

### 8.2 Una tabla MEDICIONES vs subtablas por tipo de sensor

**Alternativa**: Crear tablas separadas:
```sql
CREATE TABLE mediciones_pesaje (...)
CREATE TABLE mediciones_rfid (...)
CREATE TABLE mediciones_temperatura (...)
```

**Desventajas**:
- Consultas requieren UNION ALL de múltiples tablas
- Lógica de inserción más compleja
- Mantenimiento más costoso

**Ventajas de tabla única**:
- PostgreSQL maneja millones de registros eficientemente
- Queries simples en una tabla
- Particionamiento temporal simplificado
- Índices más eficientes

**Decisión**: Una tabla MEDICIONES con campo `sensor_id` para identificar tipo.

---

## 9. Diagrama lógico (representación textual)

```
ESTANCIAS
   |
   +-- UBICACIONES
   |      |
   |      +-- DISPOSITIVOS
   |             |
   |             +-- SENSORES
   |
   +-- USUARIOS
          |
          +-- ALERTAS
                |
                +-- ANIMALES
                     |
                     +-- MEDICIONES

Relaciones clave:
- MEDICIONES referencia: dispositivo_id, sensor_id, animal_id
- ALERTAS referencia: animal_id, dispositivo_id, usuario_responsable_id
- DISPOSITIVOS referencia: ubicacion_id
- UBICACIONES referencia: estancia_id
- USUARIOS referencia: estancia_id
- SENSORES referencia: dispositivo_id
- ANIMALES referencia: estancia_id, ubicacion_actual_id
```

---

## 10. Conclusión

Se ha transformado exitosamente el modelo conceptual en un **esquema relacional normalizado a 3NF** con **3 desnormalizaciones controladas y justificadas** por requerimientos de performance:

1. Campo `cantidad_animales_actual` en ESTANCIAS
2. Campo `ubicacion_actual_id` en ANIMALES
3. Atributos JSONB en DISPOSITIVOS, MEDICIONES y ALERTAS

El modelo final es:
- Libre de anomalías de actualización, inserción y eliminación
- Preparado para multi-tenancy mediante FK a ESTANCIAS
- ACID-compliant para garantizar consistencia
- Escalable mediante particionamiento temporal (ver `db/estructura/particiones.sql`)
- Flexible mediante JSONB para configuraciones variables

La siguiente fase implementará este modelo lógico como SQL físico en PostgreSQL, incluyendo índices, particionamiento y seguridad.