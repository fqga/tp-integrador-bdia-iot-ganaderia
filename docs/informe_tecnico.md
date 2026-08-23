# INFORME TÉCNICO: Sistema de Monitoreo IoT con Análisis Predictivo para Ganadería

## 1. Descripción del Caso de Uso

### 1.1 Contexto y Problemática

En operaciones ganaderas modernas, la salud y el bienestar animal son críticos para la rentabilidad. Tradicionalmente, el monitoreo del consumo de alimento se realiza de manera manual: observación visual, pesajes puntuales, registros en papel. Este enfoque presenta limitaciones:

- **Falta de detección temprana**: cambios sutiles en consumo pueden indicar enfermedad, pero pasan desapercibidos
- **Ineficiencia operativa**: peones deben realizar inspecciones periódicas manuales
- **Imposibilidad de análisis**: sin datos históricos granulares, no se pueden identificar tendencias
- **Imposibilidad de comparación**: cada animal en su contexto, sin benchmark

### 1.2 Solución Propuesta

Se diseña un **sistema de datos** que sustenta una aplicación IoT para monitoreo continuo de consumo individual mediante:

1. **Comederos y bebederos inteligentes** equipados con sensores RFID y pesaje
2. **Captura automática** de mediciones: qué animal comió, cuánto, cuándo
3. **Almacenamiento centralizado** de millones de registros históricos
4. **Detección de anomalías** mediante análisis de patrones de consumo
5. **Generación de alertas** automáticas ante cambios relevantes

### 1.3 Actores del Sistema

- **Peones**: operarios que revisan corrales, resuelven alertas
- **Encargado de producción**: supervisa múltiples ubicaciones, analiza tendencias
- **Veterinario**: accede a datos para diagnóstico y tratamiento
- **Administrador**: gestiona dispositivos, usuarios, configuraciones

### 1.4 Objetivos de la Solución

**Objetivos Técnicos de Datos:**
1. Almacenar mediciones de forma eficiente (10-100 registros/segundo por estancia)
2. Consultar históricos completos con latencia aceptable (<1 segundo)
3. Detectar eventos anómalos en tiempo real
4. Generar alertas automáticas según reglas configurables
5. Escalar sin degradación de performance ante crecimiento de datos

**Objetivos Empresariales:**
1. Anticipar problemas de salud animal
2. Optimizar consumo de alimento
3. Reducir mortalidad y morbilidad
4. Mejorar eficiencia operativa
5. Facilitar toma de decisiones basada en datos

---

## 2. Relevamiento de Datos Necesarios

### 2.1 Entidades Principales del Dominio

#### USUARIOS
Personas que interactúan con el sistema.
- Identificador único
- Nombre, email, teléfono
- Rol: determina permisos (peón, encargado, veterinario, admin)
- Estancia asociada: cada usuario pertenece a una estancia (multi-tenancy)
- Fecha de activación/desactivación

#### ESTANCIAS
Unidades ganaderas (empresas/predios).
- Identificador único
- Nombre, descripción
- Ubicación geográfica
- Tipo de producción: engorde, cría, lechería
- Cantidad de animales actual
- Contacto responsable

#### UBICACIONES
Sectores físicos donde se instalan dispositivos (corrales, encierre, peseada, galpones).
- Identificador único
- Estancia a la que pertenece
- Nombre descriptivo
- Tipo: corral, encierre, peseada, galpón
- Capacidad máxima de animales
- Responsable designado

#### DISPOSITIVOS
Comederos y bebederos inteligentes instalados en ubicaciones.
- Identificador único (serial del dispositivo)
- Ubicación donde está instalado
- Tipo: comedero, bebedero
- Modelo y fabricante
- Fecha de instalación/retiro
- Estado: operacional, en mantenimiento, falla
- Configuración en JSON: umbrales, parámetros de calibración

#### SENSORES
Componentes de medición dentro de los dispositivos.
- Identificador único
- Dispositivo al que pertenece
- Tipo: RFID, pesaje, temperatura, humedad
- Unidad de medida
- Rango operativo
- Precisión declarada
- Estado: operacional, descalibrado, falla

#### ANIMALES
Entidades ganaderas individuales.
- Identificador único (ID interno)
- Tag RFID único: identificador que lee el sensor
- Estancia a la que pertenece
- Nombre o alias
- Raza, sexo
- Fecha de nacimiento / ingreso a estancia
- Peso actual
- Estado de salud: sano, enfermo, en tratamiento, descarte
- Fecha de egreso (NULL si sigue en predios)

#### MEDICIONES
Registros de eventos de consumo. **Esta es la tabla más crítica y grande.**
- Identificador único
- Timestamp exacto del evento
- Dispositivo que registró
- Sensor que capturó
- Animal identificado (puede ser NULL si falla RFID)
- Valor medido: cantidad consumida en kg
- Duración del evento en segundos
- Temperatura y humedad ambiental (opcional)
- Flag: `es_anomalia` (calculado posteriormente)

#### ALERTAS
Eventos detectados por lógica de reglas.
- Identificador único
- Animal asociado (o dispositivo si es alert de hardware)
- Tipo de alerta: bajo_consumo, no_presencia, falla_sensor, consumo_atípico
- Severidad: baja, media, alta, crítica
- Timestamp de generación
- Descripción explicativa
- Estado: abierta, en_progreso, resuelta
- Usuario responsable (quién la resuelve)
- Timestamp de resolución (NULL si no resuelta)

---

### 2.2 Relaciones Principales

| Origen | Destino | Tipo | Cardinalidad | Justificación |
|--------|---------|------|--------------|---------------|
| USUARIOS | ESTANCIAS | FK | N:1 | Un usuario pertenece a una estancia (multi-tenancy) |
| ESTANCIAS | UBICACIONES | FK | 1:N | Una estancia tiene múltiples corrales/sectores |
| UBICACIONES | DISPOSITIVOS | FK | 1:N | Una ubicación tiene comederos/bebederos |
| DISPOSITIVOS | SENSORES | FK | 1:N | Un dispositivo tiene múltiples sensores |
| SENSORES | MEDICIONES | FK | 1:N | Un sensor genera millones de mediciones |
| DISPOSITIVOS | MEDICIONES | FK | 1:N | Un dispositivo registra todas sus mediciones |
| ANIMALES | MEDICIONES | FK | N:1 | Un animal tiene múltiples registros de consumo |
| ANIMALES | ALERTAS | FK | 1:N | Un animal puede generar múltiples alertas |
| DISPOSITIVOS | ALERTAS | FK | 0:N | Un dispositivo puede generar alertas (falla) |
| USUARIOS | ALERTAS | FK | 0:N | Un usuario resuelve alertas |

---

### 2.3 Restricciones de Integridad

**Restricciones de Unicidad:**
- `tag_id` en ANIMALES: identificador RFID único en estancia
- `serial` en DISPOSITIVOS: identificador de hardware único globalmente
- Email en USUARIOS: email único por estancia

**Restricciones de Formato:**
- Tag RFID: formato hexadecimal, longitud fija
- Email: formato válido
- Temperaturas: rango -40°C a +50°C
- Consumo: valores positivos

**Restricciones Temporales:**
- Mediciones deben estar ordenadas temporalmente
- Alertas resueltas tienen timestamp de resolución > timestamp de alerta

---

### 2.4 Flujos de Datos Principales

**Flujo 1: Captura de Medición**
```
Dispositivo RFID → Lee tag animal
         ↓
    Sensor pesaje → Registra peso consumido
         ↓
Base de datos MEDICIONES ← timestamp, animal_id, cantidad
         ↓
Trigger calcula promedio → Evalúa anomalía
         ↓
Si anomalía → Crea registro en ALERTAS
```

**Flujo 2: Resolución de Alerta**
```
Peón ve alerta → Inspecciona animal
         ↓
Diagnóstico (sano/enfermo)
         ↓
Peón resuelve alerta en sistema
         ↓
Sistema registra resolución: timestamp, usuario_id
```

---

## 3. Clasificación de los Datos Según su Tipo

### 3.1 Datos Estructurados (80% del volumen)

Son datos que responden a un esquema riguroso, almacenables en tablas relacionales.

**Entidades Core:**
- USUARIOS, ESTANCIAS, UBICACIONES
- DISPOSITIVOS, SENSORES
- ANIMALES
- MEDICIONES (la mayor parte: timestamp, valor numérico, IDs)
- ALERTAS

**Características:**
- Esquema fijo predefinido
- Relaciones claras
- Queryables mediante SQL standard
- Altos requerimientos de integridad referencial
- Transacciones ACID

**Volumen Estimado:**
- MEDICIONES: 10-100 registros/segundo por estancia
- En 1 año: 315M a 3.15B registros
- Tamaño: 30-300 GB/año por estancia

### 3.2 Datos Semi-Estructurados (15% del volumen)

Datos que varían en estructura, almacenados en JSONB.

**Ejemplos:**
- `DISPOSITIVOS.configuracion`: parámetros específicos del modelo
  ```json
  {
    "calibracion_pesaje": 0.98,
    "umbral_presencia": 100,
    "intervalo_reporte": 60
  }
  ```

- `MEDICIONES.datos_crudos`: información adicional del evento
  ```json
  {
    "rssi_rfid": -65,
    "calidad_lectura": 95,
    "numero_intentos_lectura": 2
  }
  ```

**Características:**
- Estructura variable según contexto
- Queryable parcialmente en SQL (operadores JSONB)
- Permite evolución sin migración

**Volumen Estimado:**
- ~200 bytes por medición: 60-600 GB/año

### 3.3 Datos No Estructurados (5% del volumen)

Datos libres de formato, generalmente texto.

**Ejemplos:**
- Notas de resolución de alertas: texto libre
- Observaciones de veterinario: notas médicas

**Características:**
- Sin esquema predefinido
- Almacenables en columnas TEXT
- Indexables mediante full-text search

**Volumen Estimado:**
- ~100 bytes por alerta de texto

### 3.4 Datos Vectoriales (1% del volumen, pero crítico para IA)

Representaciones numéricas multidimensionales para búsqueda por similitud.

**Ejemplos:**
- **Embedding de patrón de consumo**: vector de 768D que representa "firma" de cómo come un animal
  - Entrenado sobre secuencias de 30 mediciones consecutivas
  - Permite encontrar animales "similares" en comportamiento

**Casos de Uso:**
1. **Detección de anomalías**: comparar embedding actual contra histórico
2. **Detección de epidemias**: encontrar múltiples animales con patrones anómalos similares
3. **Predicción de problemas**: clusters de animales con riesgo similar

**Características:**
- Generados por modelos de embedding
- Almacenados en columnas vectoriales (pgvector)
- Queryables mediante búsqueda de similitud

**Volumen Estimado:**
- 768 dimensiones × 4 bytes = ~3KB por vector
- Si se genera 1 vector por animal/día: 3KB × 10K animales × 365 días = ~11 GB/año

---

### 3.5 Matriz de Almacenamiento Recomendado

| Tipo de Dato | Dónde Almacenar | Tecnología | Justificación |
|---|---|---|---|
| **Estructurados** | PostgreSQL (tablas normalizadas) | SQL relacional | ACID, integridad, queries complejas |
| **Semi-estructurados** | PostgreSQL (JSONB) | Column type JSONB | Flexibilidad sin migración |
| **No estructurados (texto)** | PostgreSQL (TEXT) | Text column | Indexable con full-text search |
| **Vectoriales** | PostgreSQL (pgvector) | Vector type + índices | Co-ubicado con datos relacionales |

---

## Conclusión de Fase 1-3

Se han identificado **8 entidades principales** con **10 relaciones clave**, almacenando datos de **4 tipos diferentes** (estructurados, semi, no estructurados, vectoriales). El volumen estimado es de **30-600 GB/año** en mediciones estructuradas.

Las siguientes fases detallarán el modelo lógico normalizado y la implementación física en PostgreSQL.