# Sistema de monitoreo IoT con análisis predictivo para ganadería

## Información del proyecto

**Trabajo práctico integrador**  

Carrera de Especialización en Inteligencia Artificial  

Cátedra: Bases de Datos para Inteligencia Artificial  

Alumno: Facundo Manuel Quiroga

Nro de SIU: a2305

Docente: Martín Lacheski  

Año: 2026

---

## Resumen ejecutivo

Este proyecto presenta el diseño de una **solución de datos para un sistema de monitoreo IoT en ganadería**. El sistema captura mediciones de consumo individual de animales mediante sensores RFID instalados en comederos inteligentes, permitiendo detectar anomalías, generar alertas predictivas y realizar análisis sobre patrones de consumo.

El enfoque está en el **diseño de la capa de datos** que sustenta una aplicación de IA, no en el entrenamiento de modelos ni en la aplicación completa. Se priorizan aspectos de almacenamiento, consulta, gobernanza, seguridad y escalabilidad.

---

## Caso de uso seleccionado

**Monitoreo IoT con análisis predictivo**

### Descripción del contexto

Una organización ganadera posee comederos inteligentes instalados en diferentes ubicaciones (corrales, encierre, peseada, galpones). Cada comedero está equipado con:
- **Sensor RFID**: identifica el animal mediante tag único
- **Sensor de pesaje**: registra cantidad consumida
- **Sensores ambientales**: temperatura, humedad (opcionales)

### Problema a resolver

1. **Detección de anomalías**: identificar cambios en patrones de consumo que indiquen enfermedad o malestar
2. **Alertas predictivas**: anticipar problemas de suministro o salud animal
3. **Análisis histórico**: consultas sobre tendencias de consumo por animal
4. **Escalabilidad**: manejar millones de registros de mediciones sin degradación de performance

---

## Datos identificados

### Datos principales (estructurados)

- **Usuarios**: peones, encargados, veterinarios, administradores
- **Estancias**: unidades ganaderas (multi-tenancy)
- **Ubicaciones**: corrales, encierre, galpones
- **Dispositivos**: comederos y bebederos inteligentes
- **Sensores**: componentes de medición (RFID, pesaje, temperatura)
- **Animales**: entidades ganaderas con tags únicos
- **Mediciones**: registros periódicos de consumo individual
- **Alertas**: eventos detectados automáticamente

### Datos para análisis predictivo (vectoriales)

- Embeddings de patrones de consumo: representaciones vectoriales de secuencias temporales
- Búsqueda de similitud para detectar comportamientos atípicos

---

## Tecnologías propuestas

### Base de datos principal
- **PostgreSQL 15+**
  - Modelo relacional normalizado
  - Particionamiento temporal por mediciones
  - Row-Level Security (RLS) para multi-tenancy
  - JSONB para configuraciones flexibles

### Búsqueda vectorial
- **pgvector**: extensión de PostgreSQL para embeddings
  - Almacenamiento de vectores de patrones de consumo
  - Búsqueda por similitud para detectar anomalías
  - Integración nativa con la base relacional

### Justificación de elección

PostgreSQL fue seleccionado porque:
1. Maneja transacciones ACID para garantizar consistencia
2. Soporta particionamiento temporal eficiente (mediciones > 10M registros/año)
3. RLS nativa para multi-tenancy sin lógica en aplicación
4. pgvector integrado para análisis predictivo sin BD separada
5. Herramienta estándar industrial para este tipo de sistemas

---

## Estructura del repositorio

```
tp-integrador-bdia-iot-ganaderia/
├── README.md                          # Este archivo
├── docker-compose.yml                 # Levanta PostgreSQL + pgvector y corre todo el init
├── docs/
│   ├── informe_tecnico.md            # Informe completo (15 secciones)
│   ├── 01_modelo_conceptual.md       # ER y entidades
│   ├── 02_modelo_logico.md           # Normalización y modelo lógico
│   ├── 03_modelo_fisico.md           # SQL físico, particionamiento, RLS, triggers
│   └── 04_arquitectura_datos.md      # Flujo de datos y componentes
├── data/
│   └── ejemplos/
│       └── datos_simulados.sql       # Catálogo + 353 mediciones + embeddings de ejemplo
├── db/
│   ├── estructura/
│   │   ├── schema.sql                # CREATE TABLE + constraints (mediciones particionada)
│   │   ├── particiones.sql           # Particiones mensuales de mediciones
│   │   ├── indexes.sql                # Índices optimizados (incluye ivfflat vectorial)
│   │   ├── triggers.sql              # Desnormalización + detección de anomalías + alertas
│   │   ├── rls.sql                   # Rol app_user + políticas RLS multi-tenant
│   │   └── views.sql                 # Vistas para consultas frecuentes
│   ├── consultas/
│   │   └── queries_representativas.sql # 8 consultas representativas, probadas
│   └── vectorial/
│       └── embeddings.sql            # Función animales_similares() (búsqueda por similitud)
├── vectorial/
│   └── modelo_vectorial.md           # Qué se vectoriza, metadatos, aislamiento RLS
├── arquitectura/
│   └── escalabilidad.md              # Particiones, índices, qué separar al crecer
└── .gitignore
```

---

## Instrucciones de uso

### Requisitos
- Docker y Docker Compose instalados
  - Descargar desde: https://www.docker.com/products/docker-desktop/

### Instalación (solo 3 pasos)

**1. Clonar repositorio**
```bash
git clone https://github.com/tu-usuario/tp-integrador-bdia-iot-ganaderia.git
cd tp-integrador-bdia-iot-ganaderia
```

**2. Levantar contenedor PostgreSQL**
```bash
docker-compose up -d
```

Espera 10 segundos a que la base de datos esté lista.

**3. Verificar que funciona**
```bash
docker-compose exec postgres psql -U postgres -d monitoreo_iot_ganaderia -c "\dt"
```

Deberías ver las 8 tablas del modelo (`estancias`, `usuarios`, `ubicaciones`, `dispositivos`,
`sensores`, `animales`, `alertas`, y `mediciones` como tabla particionada) más sus 13
particiones (`mediciones_2026_01` … `mediciones_2026_12` y `mediciones_default`) — 21 filas en
total en el listado.

### Conectarse a la base de datos

**Opción A: Desde terminal (usuario administrador, sin RLS)**
```bash
docker-compose exec postgres psql -U postgres -d monitoreo_iot_ganaderia
```

### Probar el aislamiento multi-tenant (RLS)

`postgres` es superusuario, y PostgreSQL **bypassea RLS para superusuarios** aunque las
políticas existan y estén habilitadas. Para probar el aislamiento de verdad hay que conectarse
con el rol de aplicación que crea `db/estructura/rls.sql` (`app_user`), y fijar la estancia
activa con `SET app.estancia_id` antes de consultar — sin ese SET, las consultas fallan
(fail-closed) en lugar de devolver datos de todas las estancias:

```bash
docker-compose exec postgres psql -U app_user -d monitoreo_iot_ganaderia
# password: app_user_password
```
```sql
SET app.estancia_id = 2;
SELECT id, nombre_alias FROM animales;  -- solo animales de la Estancia 2
```

### Detener la base de datos
```bash
docker-compose down
```

### Eliminar todo (datos + contenedor)
```bash
docker-compose down -v
```

### Reiniciar desde cero
```bash
docker-compose down -v
docker-compose up -d
```

---

## Decisiones de diseño principales

### 1. Multi-tenancy con Row-Level Security
Se implementa mediante RLS nativa de PostgreSQL. Cada usuario solo ve datos de su estancia.
- Ventaja: seguridad en base de datos, no en aplicación
- Desventaja: overhead mínimo en performance

### 2. Particionamiento temporal de mediciones
Tabla `mediciones` particionada por rango de fecha (mensual).
- Ventaja: escalabilidad, queries más rápidas, mantenimiento eficiente
- Desventaja: complejidad en operaciones administrativas

### 3. Normalización 3NF
El schema está en 3NF. Se mantiene disciplina de normalización para evitar anomalías.

### 4. JSONB para configuración flexible
Dispositivos y sensores almacenan configuración en JSONB.
- Ventaja: flexibilidad sin migración de schema
- Desventaja: queries menos eficientes en búsquedas de JSON

### 5. Sin auditoría centralizada
Se decide no incluir tabla de auditoría para simplificar scope. Focus en datos operativos.

---

## Consultas representativas incluidas

Las 8 consultas de `db/consultas/queries_representativas.sql`, probadas contra los datos de
ejemplo (detalle y por qué es útil cada una en `docs/informe_tecnico.md`, sección 10):

1. **Consumo total y promedio por animal (7 días)**: tendencias individuales
2. **Animales por debajo de su propio histórico**: detección de problemas de salud sin umbral fijo
3. **Consumo promedio por ubicación**: comparación entre corrales
4. **Alertas sin resolver, priorizadas**: bandeja de trabajo operativa
5. **Búsqueda por similitud vectorial**: animales con patrón de consumo parecido (pgvector)
6. **Promedio móvil por animal (función de ventana)**: vista de detalle para veterinario
7. **Alertas activas por estancia**: panorama ejecutivo multi-tenant
8. **Trazabilidad de un caso**: historial completo de mediciones y alertas de un animal

---

## Propuestas de extensión

### Búsqueda vectorial
Se utiliza pgvector para crear embeddings de secuencias de consumo. Permite detectar animales con patrones anómalos comparando con el centroide del rebaño.

### Escalabilidad futura
- Replicación read-only para reportes analíticos
- Sharding horizontal si traspasa 100M mediciones/año
- Data lake para histórico comprimido (parquet en S3)
- Kafka para streaming de mediciones en tiempo real

### Limitaciones actuales
- No se implementa cache en memoria (Redis)
- No incluye API REST (solo SQL puro)
- No modela predicción de fallas (ML está fuera de scope)
- RLS aísla por **estancia**, no por **rol dentro de la estancia**: un peón y un admin de la
  misma estancia tienen hoy los mismos permisos de fila (detalle y extensión propuesta en
  `docs/informe_tecnico.md`, sección 13)
- La creación de particiones futuras de `mediciones` es manual (no hay un job automático que
  cree la partición del mes siguiente con anticipación — ver `arquitectura/escalabilidad.md`, sección 6)
- No hay tabla de auditoría centralizada (decisión de scope, ver sección de decisiones de diseño)

---

## Autor

**Facundo Manuel Quiroga**  
Especialización en Inteligencia Artificial - UBA FIUBA  
Agosto 2026
