# MODELO CONCEPTUAL: Entidades, Atributos y Relaciones

## 1. Diagrama ER (Representación Textual)

```
┌─────────────────────┐         ┌──────────────────┐
│      USUARIOS       │         │    ESTANCIAS     │
├─────────────────────┤         ├──────────────────┤
│ PK: id              │◄────────│ PK: id           │
│ nombre              │ N    1  │ nombre           │
│ email               │         │ ubicacion        │
│ rol                 │         │ tipo_produccion  │
│ estancia_id (FK)    │         │ contacto         │
│ activo              │         └──────────────────┘
└─────────────────────┘

         │
         │ 1:N
         ▼
┌──────────────────────┐
│   UBICACIONES        │
├──────────────────────┤
│ PK: id               │
│ FK: estancia_id      │
│ nombre               │
│ tipo                 │
│ capacidad_animales   │
│ responsable          │
└──────────────────────┘
         │
         │ 1:N
         ▼
┌──────────────────────┐      ┌──────────────────┐
│   DISPOSITIVOS       │      │    SENSORES      │
├──────────────────────┤      ├──────────────────┤
│ PK: id               │◄─────│ PK: id           │
│ FK: ubicacion_id     │ 1   N│ FK: dispositivo  │
│ tipo_dispositivo     │      │ tipo_sensor      │
│ modelo               │      │ unidad_medida    │
│ serial               │      │ rango_min/max    │
│ fecha_instalacion    │      │ precisión        │
│ estado               │      │ estado           │
│ configuracion (JSON) │      └──────────────────┘
└──────────────────────┘
         │
         │ 1:N
         ▼
┌──────────────────────────────────────┐
│        MEDICIONES                    │
│      (Tabla Principal - Histórica)   │
├──────────────────────────────────────┤
│ PK: id                               │
│ FK: dispositivo_id                   │
│ FK: sensor_id                        │
│ FK: animal_id (puede ser NULL)       │
│ timestamp                            │
│ valor_medido (cantidad en kg/ml)     │
│ duracion_evento (segundos)           │
│ temperatura_ambiental                │
│ humedad_ambiental                    │
│ datos_crudos (JSON)                  │
│ es_anomalia (boolean)                │
│ embedding_vector (pgvector 768D)     │
└──────────────────────────────────────┘
         ▲
         │ N:1
         │
┌──────────────────────┐
│      ANIMALES        │
├──────────────────────┤
│ PK: id               │
│ FK: estancia_id      │
│ tag_id (UNIQUE)      │
│ nombre_alias         │
│ raza                 │
│ sexo                 │
│ fecha_nacimiento     │
│ peso_actual          │
│ estado_salud         │
│ fecha_ingreso        │
│ fecha_egreso         │
└──────────────────────┘
         │
         │ 1:N
         ▼
┌──────────────────────┐
│      ALERTAS         │
├──────────────────────┤
│ PK: id               │
│ FK: animal_id        │
│ FK: dispositivo_id   │
│ tipo_alerta          │
│ severidad            │
│ timestamp_alerta     │
│ descripcion          │
│ estado               │
│ FK: usuario_responsable_id │
│ timestamp_resolucion │
└──────────────────────┘
         │
         └──────────────────────┐
                                │ N:1
                                ▼
                        ┌──────────────────┐
                        │   USUARIOS       │
                        │ (Resolución)     │
                        └──────────────────┘
```

---

## 2. Descripción Detallada de Entidades

### 2.1 USUARIOS

**Propósito**: Registrar personas que interactúan con el sistema.

**Atributos**:

| Atributo | Tipo | Constraints | Descripción |
|----------|------|-------------|-------------|
| id | SERIAL | PK, NOT NULL | Identificador único |
| nombre | VARCHAR(100) | NOT NULL | Nombre completo |
| email | VARCHAR(255) | NOT NULL, UNIQUE | Email único por estancia |
| contraseña_hash | VARCHAR(255) | NOT NULL | Hash bcrypt |
| rol | ENUM | NOT NULL | {peón, encargado, veterinario, admin} |
| estancia_id | BIGINT | FK, NOT NULL | A qué estancia pertenece |
| telefono | VARCHAR(20) | NULL | Contacto |
| activo | BOOLEAN | DEFAULT true | Si puede acceder |
| fecha_creacion | TIMESTAMP | DEFAULT NOW() | Auditoría |

**Restricciones**:
- PK: id
- FK: estancia_id → ESTANCIAS(id)
- UNIQUE: (email, estancia_id)
- CHECK: rol IN ('peón', 'encargado', 'veterinario', 'admin')

**Notas**:
- La combinación (email, estancia_id) es UNIQUE porque permite que el mismo email exista en diferentes estancias
- Rol determina qué ve en RLS (Row-Level Security)

---

### 2.2 ESTANCIAS

**Propósito**: Modelar unidades ganaderas independientes (multi-tenancy).

**Atributos**:

| Atributo | Tipo | Constraints | Descripción |
|----------|------|-------------|-------------|
| id | BIGINT | PK | Identificador único |
| nombre | VARCHAR(200) | NOT NULL, UNIQUE | Nombre del predio |
| descripcion | TEXT | NULL | Detalles |
| ubicacion_ciudad | VARCHAR(100) | NULL | Ciudad |
| ubicacion_provincia | VARCHAR(100) | NULL | Provincia |
| tipo_produccion | ENUM | NOT NULL | {engorde, cría, lechería, mixto} |
| cantidad_animales_actual | INT | DEFAULT 0 | Estimativo dinámico |
| contacto_responsable | VARCHAR(255) | NULL | Persona a contactar |
| activa | BOOLEAN | DEFAULT true | Si sigue operando |
| fecha_creacion | TIMESTAMP | DEFAULT NOW() | Auditoría |

**Restricciones**:
- PK: id
- UNIQUE: nombre
- CHECK: tipo_produccion IN ('engorde', 'cría', 'lechería', 'mixto')
- CHECK: cantidad_animales_actual >= 0

**Notas**:
- Esta es la tabla de "tenants" en la arquitectura multi-tenant
- RLS en PostgreSQL filtra por estancia_id del usuario conectado

---

### 2.3 UBICACIONES

**Propósito**: Modelar sectores físicos donde se instalan dispositivos.

**Atributos**:

| Atributo | Tipo | Constraints | Descripción |
|----------|------|-------------|-------------|
| id | BIGINT | PK | Identificador único |
| estancia_id | BIGINT | FK, NOT NULL | A qué estancia pertenece |
| nombre | VARCHAR(150) | NOT NULL | "Corral A", "Encierre 1" |
| tipo | ENUM | NOT NULL | {corral, encierre, peseada, galpón} |
| descripcion | TEXT | NULL | Notas adicionales |
| capacidad_animales | INT | NOT NULL | Máximo de animales |
| area_metros_cuadrados | DECIMAL(10,2) | NULL | Tamaño físico |
| responsable_usuario_id | BIGINT | FK, NULL | Quién supervisa |
| activa | BOOLEAN | DEFAULT true | Si se usa actualmente |
| fecha_creacion | TIMESTAMP | DEFAULT NOW() | Auditoría |

**Restricciones**:
- PK: id
- FK: estancia_id → ESTANCIAS(id) [CASCADE]
- FK: responsable_usuario_id → USUARIOS(id) [SET NULL]
- UNIQUE: (estancia_id, nombre)
- CHECK: capacidad_animales > 0
- CHECK: tipo IN ('corral', 'encierre', 'peseada', 'galpón')

**Notas**:
- Un usuario responsable puede abandonar el sistema; por eso FK es SET NULL
- El nombre es único dentro de estancia, pero puede repetirse entre estancias

---

### 2.4 DISPOSITIVOS

**Propósito**: Representar equipos físicos (comederos, bebederos) instalados.

**Atributos**:

| Atributo | Tipo | Constraints | Descripción |
|----------|------|-------------|-------------|
| id | BIGINT | PK | ID lógico en BD |
| serial_hardware | VARCHAR(100) | NOT NULL, UNIQUE | Número de serie |
| ubicacion_id | BIGINT | FK, NOT NULL | Dónde está instalado |
| tipo_dispositivo | ENUM | NOT NULL | {comedero, bebedero} |
| modelo | VARCHAR(100) | NOT NULL | "FeedTrack Pro v2" |
| fabricante | VARCHAR(100) | NULL | Empresa fabricante |
| fecha_instalacion | DATE | NOT NULL | Cuándo se puso en servicio |
| fecha_retiro | DATE | NULL | Si fue retirado |
| estado | ENUM | DEFAULT 'operacional' | {operacional, mantenimiento, falla} |
| configuracion | JSONB | DEFAULT '{}' | Parámetros específicos |
| firmware_version | VARCHAR(50) | NULL | Versión de software |
| fecha_creacion | TIMESTAMP | DEFAULT NOW() | Auditoría |

**Restricciones**:
- PK: id
- FK: ubicacion_id → UBICACIONES(id) [CASCADE]
- UNIQUE: serial_hardware
- CHECK: fecha_retiro IS NULL OR fecha_retiro >= fecha_instalacion
- CHECK: tipo_dispositivo IN ('comedero', 'bebedero')
- CHECK: estado IN ('operacional', 'mantenimiento', 'falla')

**Ejemplos de CONFIGURACION (JSONB)**:
```json
{
  "calibracion_pesaje": 0.98,
  "umbral_presencia_kg": 100,
  "umbral_alerta_bajo_stock": 5,
  "intervalo_reporte_segundos": 60,
  "sensibilidad_rfid": "alta"
}
```

---

### 2.5 SENSORES

**Propósito**: Modelar componentes de medición dentro de dispositivos.

**Atributos**:

| Atributo | Tipo | Constraints | Descripción |
|----------|------|-------------|-------------|
| id | BIGINT | PK | ID único |
| dispositivo_id | BIGINT | FK, NOT NULL | A qué dispositivo pertenece |
| tipo_sensor | ENUM | NOT NULL | {rfid, pesaje, temperatura, humedad} |
| unidad_medida | VARCHAR(20) | NOT NULL | "kg", "°C", "%" |
| rango_minimo | DECIMAL(10,2) | NOT NULL | Valor mínimo esperado |
| rango_maximo | DECIMAL(10,2) | NOT NULL | Valor máximo esperado |
| precision_declarada | DECIMAL(5,3) | NOT NULL | Ej: ±0.05 |
| fecha_ultima_calibracion | DATE | NULL | Auditoría de validez |
| estado | ENUM | DEFAULT 'operacional' | {operacional, descalibrado, falla} |
| activo | BOOLEAN | DEFAULT true | Si se usa en cálculos |
| fecha_creacion | TIMESTAMP | DEFAULT NOW() | Auditoría |

**Restricciones**:
- PK: id
- FK: dispositivo_id → DISPOSITIVOS(id) [CASCADE]
- CHECK: tipo_sensor IN ('rfid', 'pesaje', 'temperatura', 'humedad')
- CHECK: rango_minimo < rango_maximo
- CHECK: precision_declarada > 0

**Notas**:
- Un dispositivo típicamente tiene 2-4 sensores (pesaje, RFID, temperatura, humedad)
- La combinación (dispositivo_id, tipo_sensor) suele ser UNIQUE

---

### 2.6 ANIMALES

**Propósito**: Modelar entidades ganaderas individuales.

**Atributos**:

| Atributo | Tipo | Constraints | Descripción |
|----------|------|-------------|-------------|
| id | BIGINT | PK | ID único interno |
| estancia_id | BIGINT | FK, NOT NULL | A qué estancia pertenece |
| tag_rfid | VARCHAR(50) | NOT NULL | Identificador hardware |
| nombre_alias | VARCHAR(100) | NULL | "Blanca", "Negra 42" |
| raza | VARCHAR(100) | NOT NULL | "Aberdeen Angus", "Hereford" |
| sexo | ENUM | NOT NULL | {macho, hembra, indefinido} |
| fecha_nacimiento | DATE | NOT NULL | Edad calculable desde aquí |
| peso_actual_kg | DECIMAL(8,2) | NULL | Último peso registrado |
| fecha_ultimo_peso | TIMESTAMP | NULL | Cuándo se pesó |
| estado_salud | ENUM | DEFAULT 'sano' | {sano, enfermo, en_tratamiento, descarte} |
| ubicacion_actual_id | BIGINT | FK, NULL | Dónde está ahora |
| fecha_ingreso_estancia | DATE | NOT NULL | Cuándo llegó |
| fecha_egreso_estancia | DATE | NULL | Cuándo salió (NULL si sigue) |
| motivo_egreso | VARCHAR(255) | NULL | "Venta", "Faena", "Muerte" |
| fecha_creacion | TIMESTAMP | DEFAULT NOW() | Auditoría |

**Restricciones**:
- PK: id
- FK: estancia_id → ESTANCIAS(id) [CASCADE]
- FK: ubicacion_actual_id → UBICACIONES(id) [SET NULL]
- UNIQUE: (estancia_id, tag_rfid)
- CHECK: fecha_egreso_estancia IS NULL OR fecha_egreso_estancia >= fecha_ingreso_estancia
- CHECK: sexo IN ('macho', 'hembra', 'indefinido')
- CHECK: estado_salud IN ('sano', 'enfermo', 'en_tratamiento', 'descarte')

**Notas**:
- `tag_rfid` es el ID que lee el sensor RFID en el comedero
- Formato típico: hexadecimal (ej: "9E-54-3F-AB-CD-EF")

---

### 2.7 MEDICIONES

**Propósito**: Tabla de hechos principal. Registra eventos de consumo individual.
**Esta es la tabla más crítica y más grande.**

**Atributos**:

| Atributo | Tipo | Constraints | Descripción |
|----------|------|-------------|-------------|
| id | BIGINT | PK | ID único |
| dispositivo_id | BIGINT | FK, NOT NULL | Qué dispositivo registró |
| sensor_id | BIGINT | FK, NOT NULL | Qué sensor capturó |
| animal_id | BIGINT | FK, NULL | Qué animal (puede fallar lectura RFID) |
| timestamp | TIMESTAMP | NOT NULL | Cuándo ocurrió |
| valor_medido | DECIMAL(10,3) | NOT NULL | Cantidad consumida (kg o ml) |
| duracion_evento_segundos | INT | NULL | Cuánto tiempo comió |
| temperatura_ambiental_celsius | DECIMAL(5,2) | NULL | °C en el dispositivo |
| humedad_ambiental_pct | DECIMAL(5,2) | NULL | % humedad |
| datos_crudos | JSONB | NULL | Información adicional |
| es_anomalia | BOOLEAN | DEFAULT false | Flag calculado |
| puntuacion_anomalia | DECIMAL(5,3) | NULL | Score 0-1 de anomalía |
| embedding_patron | vector(768) | NULL | Vector pgvector |
| created_at | TIMESTAMP | DEFAULT NOW() | Auditoría |

**Restricciones**:
- PK: id
- FK: dispositivo_id → DISPOSITIVOS(id)
- FK: sensor_id → SENSORES(id)
- FK: animal_id → ANIMALES(id) [SET NULL]
- CHECK: valor_medido >= 0
- CHECK: duracion_evento_segundos > 0 OR duracion_evento_segundos IS NULL
- CHECK: temperatura_ambiental_celsius BETWEEN -40 AND 50
- CHECK: humedad_ambiental_pct BETWEEN 0 AND 100
- CHECK: puntuacion_anomalia BETWEEN 0 AND 1 OR puntuacion_anomalia IS NULL

**Índices Críticos**:
```sql
INDEX: (timestamp DESC)                    
INDEX: (animal_id, timestamp DESC)         
INDEX: (dispositivo_id, timestamp DESC)    
INDEX: (es_anomalia, timestamp DESC)       
INDEX: (animal_id) WHERE es_anomalia=true  
VECTOR INDEX: embedding_patron             
```

**Particionamiento**:
```sql
PARTITION BY RANGE (timestamp) monthly
```

**Notas**:
- `animal_id` puede ser NULL si falla lectura RFID
- `es_anomalia` se calcula mediante trigger después de inserción
- Volumen esperado: 10-100 registros/segundo = 864M-8.64B registros/año

---

### 2.8 ALERTAS

**Propósito**: Registrar eventos detectados automáticamente.

**Atributos**:

| Atributo | Tipo | Constraints | Descripción |
|----------|------|-------------|-------------|
| id | BIGINT | PK | ID único |
| animal_id | BIGINT | FK, NULL | Animal asociado |
| dispositivo_id | BIGINT | FK, NULL | Dispositivo asociado |
| tipo_alerta | ENUM | NOT NULL | {bajo_consumo, no_presencia, falla_sensor, consumo_atipico} |
| severidad | ENUM | NOT NULL | {baja, media, alta, critica} |
| timestamp_alerta | TIMESTAMP | DEFAULT NOW() | Cuándo se generó |
| descripcion | TEXT | NOT NULL | Texto explicativo |
| datos_contextuales | JSONB | NULL | Datos que motivaron alerta |
| estado | ENUM | DEFAULT 'abierta' | {abierta, en_progreso, resuelta} |
| usuario_responsable_id | BIGINT | FK, NULL | Quién la resuelve |
| timestamp_resolucion | TIMESTAMP | NULL | Cuándo se cerró |
| notas_resolucion | TEXT | NULL | Comentario de cierre |
| fecha_creacion | TIMESTAMP | DEFAULT NOW() | Auditoría |

**Restricciones**:
- PK: id
- FK: animal_id → ANIMALES(id) [SET NULL]
- FK: dispositivo_id → DISPOSITIVOS(id) [SET NULL]
- FK: usuario_responsable_id → USUARIOS(id) [SET NULL]
- CHECK: (animal_id IS NOT NULL) OR (dispositivo_id IS NOT NULL)
- CHECK: tipo_alerta IN ('bajo_consumo', 'no_presencia', 'falla_sensor', 'consumo_atipico')
- CHECK: severidad IN ('baja', 'media', 'alta', 'critica')
- CHECK: estado IN ('abierta', 'en_progreso', 'resuelta')
- CHECK: timestamp_resolucion IS NULL OR timestamp_resolucion >= timestamp_alerta

**Ejemplos de DATOS_CONTEXTUALES**:
```json
{
  "promedio_consumo_7_dias_kg": 15.5,
  "consumo_actual_kg": 8.2,
  "desviacion_estandar": 1.2,
  "percentil_consumo": 15
}
```

**Notas**:
- Una alerta debe tener animal_id O dispositivo_id
- Índice sobre (estado, timestamp_alerta DESC) para queries rápidas

---

## 3. Relaciones y Cardinalidades

### 3.1 Matriz de Relaciones

```
ORIGEN              →  DESTINO              TIPO  CARDINALIDAD  
──────────────────────────────────────────────────────────────
USUARIOS            →  ESTANCIAS            FK    N:1           
UBICACIONES         →  ESTANCIAS            FK    N:1           
DISPOSITIVOS        →  UBICACIONES          FK    N:1           
SENSORES            →  DISPOSITIVOS         FK    N:1           
MEDICIONES          →  DISPOSITIVOS         FK    N:1           
MEDICIONES          →  SENSORES             FK    N:1           
MEDICIONES          →  ANIMALES             FK    N:1           
ALERTAS             →  ANIMALES             FK    N:1           
ALERTAS             →  DISPOSITIVOS         FK    0:N           
ALERTAS             →  USUARIOS             FK    N:1           
ANIMALES            →  ESTANCIAS            FK    N:1           
ANIMALES            →  UBICACIONES (actual) FK    N:1           
```

### 3.2 Cardinalidades Específicas

| Relación | Cantidad | Ejemplo |
|---|---|---|
| ESTANCIA → UBICACIONES | 1:N | 1 estancia tiene 5-20 ubicaciones |
| UBICACION → DISPOSITIVOS | 1:N | 1 corral tiene 2-4 comederos |
| DISPOSITIVO → SENSORES | 1:N | 1 comedero tiene 2-3 sensores |
| DISPOSITIVO → MEDICIONES | 1:N | 1 dispositivo genera 100-1000 mediciones/hora |
| ANIMAL → MEDICIONES | 1:N | 1 animal tiene 5-20 mediciones/día |
| ESTANCIA → USUARIOS | 1:N | 1 estancia tiene 5-50 usuarios |
| ANIMAL → ALERTAS | 1:N | 1 animal puede generar 0-100 alertas/año |

---

## 4. Restricciones de Integridad

### 4.1 Restricciones de Dominio (CHECK)

```sql
-- USUARIOS
CHECK (rol IN ('peón', 'encargado', 'veterinario', 'admin'))

-- ESTANCIAS
CHECK (tipo_produccion IN ('engorde', 'cría', 'lechería', 'mixto'))

-- DISPOSITIVOS
CHECK (fecha_retiro IS NULL OR fecha_retiro >= fecha_instalacion)
CHECK (estado IN ('operacional', 'mantenimiento', 'falla'))

-- MEDICIONES
CHECK (valor_medido >= 0)
CHECK (temperatura_ambiental_celsius BETWEEN -40 AND 50)
CHECK (humedad_ambiental_pct BETWEEN 0 AND 100)

-- ALERTAS
CHECK ((animal_id IS NOT NULL) OR (dispositivo_id IS NOT NULL))
CHECK (severidad IN ('baja', 'media', 'alta', 'critica'))
CHECK (estado IN ('abierta', 'en_progreso', 'resuelta'))

-- ANIMALES
CHECK (fecha_egreso_estancia IS NULL OR fecha_egreso_estancia >= fecha_ingreso_estancia)
CHECK (estado_salud IN ('sano', 'enfermo', 'en_tratamiento', 'descarte'))
```

### 4.2 Restricciones de Unicidad

```sql
-- Global unique
UNIQUE (serial_hardware)

-- Per-tenant unique
UNIQUE (estancia_id, nombre)           -- UBICACIONES
UNIQUE (estancia_id, tag_rfid)         -- ANIMALES
UNIQUE (estancia_id, email)            -- USUARIOS

-- Overall
UNIQUE (nombre)                        -- ESTANCIAS
```

---

## 5. Conclusión del Modelo Conceptual

El modelo consta de **8 entidades principales** con **10 relaciones clave**, almacenando datos de **4 tipos diferentes**. Está **normalizado en 3NF**, soporta **multi-tenancy** mediante FK en ESTANCIAS y **RLS** en PostgreSQL.

La **tabla MEDICIONES** es el corazón del sistema y requiere **particionamiento temporal**, **índices especializados** y **vectorización** para análisis predictivo.