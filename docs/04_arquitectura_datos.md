# ARQUITECTURA DE DATOS: de la lectura del sensor a la alerta

## 1. Por qué una arquitectura simple y no un Data Lake / Lakehouse

El caso de uso tiene tres características que empujan hacia una arquitectura simple de una
sola base operacional (PostgreSQL + pgvector), en vez de una arquitectura por capas con Data
Lake/Warehouse/Lakehouse:

- **El dato no es tan variado como para justificar un lago de datos**: prácticamente todo lo
  que produce el sistema son mediciones numéricas estructuradas y algo de JSON de
  configuración/contexto — no hay imágenes, video, ni grandes volúmenes de texto libre que
  requieran almacenamiento en crudo desacoplado del motor transaccional.
- **El consumo es mayormente operacional, no analítico masivo**: las consultas que importan
  (alertas sin resolver, consumo de los últimos 7 días, similitud de patrones) necesitan
  responder en segundos sobre datos recientes, no procesar años de historia en un batch
  nocturno. Eso es el terreno de una base transaccional bien indexada, no el de un Data
  Warehouse separado.
- **El equipo y el volumen actual no justifican la complejidad operativa** de mantener
  ingesta, un lago de datos y un warehouse como sistemas separados — eso es una decisión de
  escalar *cuando* el volumen o el tipo de análisis lo exijan, no de entrada (ver
  `arquitectura/escalabilidad.md` para el punto en el que esta decisión debería revisarse).

Lo que sí se adopta, dentro de esa base única, es una **separación lógica por capas de
procesamiento** (cruda → validada → preparada para IA), descripta en la sección 3.

## 2. Flujo de datos de punta a punta

```
┌──────────────┐     ┌───────────────┐     ┌─────────────────────────────────────┐
│   Sensores   │     │   Gateway /   │     │        PostgreSQL + pgvector          │
│  RFID/pesaje │────▶│  Firmware del │────▶│  (almacenamiento operacional único)   │
│  (comederos) │     │  dispositivo  │     │                                        │
└──────────────┘     └───────┬───────┘     │  ┌──────────┐  ┌───────────────────┐  │
                              │             │  │mediciones│─▶│ triggers:          │  │
                      INSERT por evento     │  │(cruda)   │  │ - detectar_anomalia│  │
                      (ver 3.1)             │  └──────────┘  │ - generar_alerta   │  │
                              └────────────▶│                │ - actualizar       │  │
                                             │                │   desnormalizados  │  │
                                             │                └─────────┬──────────┘  │
                                             │                          ▼             │
                                             │              ┌──────────────────┐      │
                                             │              │ alertas          │      │
                                             │              │ (procesada)      │      │
                                             │              └──────────────────┘      │
                                             │  ┌────────────────────────────────┐    │
                                             │  │ embedding_patron (preparado    │    │
                                             │  │ para IA, ver vectorial/)       │    │
                                             │  └────────────────────────────────┘    │
                                             └───────────────────┬────────────────────┘
                                                                  │
                                              RLS (app.estancia_id) filtra cada consulta
                                                                  │
                              ┌───────────────────────────────────┼───────────────────────────┐
                              ▼                                   ▼                            ▼
                    ┌──────────────────┐              ┌────────────────────┐        ┌──────────────────┐
                    │ App operativa     │              │ Dashboard /        │        │ Veterinario /     │
                    │ (peones, alertas  │              │ vistas ejecutivas  │        │ análisis puntual   │
                    │  en tiempo real)  │              │ (admin plataforma) │        │ (consultas 5, 6, 8)│
                    └──────────────────┘              └────────────────────┘        └──────────────────┘
```

## 3. Componentes

### 3.1 Fuentes de datos e ingesta

Los comederos/bebederos inteligentes emiten un evento por cada visita de un animal (lectura
RFID + peso consumido + duración). El firmware del dispositivo hace un `INSERT` directo (o vía
una API delgada que lo traduce a `INSERT`) sobre `mediciones`. No hay un paso de "staging"
intermedio: el volumen por evento es chico y la latencia esperada es baja (el caso de uso pide
detectar problemas rápido), así que agregar una cola/broker de ingesta (Kafka, mencionado en
el informe como extensión futura) solo se justifica cuando el volumen por estancia supere lo
que una escritura directa puede sostener — ver `arquitectura/escalabilidad.md`.

### 3.2 Almacenamiento operacional (capa "cruda" y "procesada")

Es la misma base PostgreSQL, con una separación lógica por trigger en vez de por sistema:

- **Cruda**: la fila tal como llega del sensor (`valor_medido`, `duracion_evento_segundos`,
  `datos_crudos` JSONB con información de diagnóstico del propio sensor como RSSI o nivel de
  batería).
- **Procesada**: generada por los triggers en el mismo `INSERT` — `es_anomalia` y
  `puntuacion_anomalia` (trigger `detectar_anomalia`), la fila de `alertas` correspondiente
  (trigger `generar_alerta_anomalia`), y los campos desnormalizados de `estancias.
  cantidad_animales_actual` / `animales.ubicacion_actual_id`.

No hay un ETL nocturno separado: el procesamiento ocurre en el momento de la escritura porque
el caso de uso necesita que la alerta exista *apenas* se detecta la anomalía, no al día
siguiente.

### 3.3 Datos preparados para IA

El vector `embedding_patron` (ver `vectorial/modelo_vectorial.md`) es el dato "preparado para
IA" del sistema: no viene directamente del sensor, sino de un proceso de featurización sobre
la secuencia de mediciones de un animal/día. En esta entrega ese proceso está simulado en los
datos de ejemplo; en producción sería un job (batch diario o un microservicio) que lee las
mediciones del día, genera el vector con un modelo entrenado, y hace `UPDATE` sobre la fila
representativa del día.

### 3.4 Componentes de consulta y consumidores

Todos los consumidores leen la misma base, pero con distinto nivel de acceso vía RLS:

- **App operativa** (peones/encargados/veterinarios): conectan como `app_user`, con
  `app.estancia_id` fijado a su propia estancia — solo ven y pueden alertar sobre su propia
  operación (consultas representativas 1, 2, 4, 6, 8).
- **Vistas ejecutivas / administración de plataforma**: el único consumidor que
  intencionalmente cruza estancias (consulta 7, `alertas_activas_por_estancia`) — pensado
  para quien opera la plataforma, no para un usuario de una estancia particular.
- **Análisis exploratorio** (consulta 3, comparación entre corrales; consulta 5, similitud
  vectorial): mismo motor, mismas políticas RLS, sin infraestructura analítica separada.

## 4. Qué falta para escalar esta arquitectura

Esta arquitectura de "una base bien diseñada" es la elección correcta para el volumen actual
(ver `arquitectura/escalabilidad.md`), pero tiene un techo. Los puntos donde se volvería a
evaluar el enfoque (por ejemplo, separar lectura/escritura, introducir una cola de ingesta, o
mover el histórico frío a almacenamiento analítico aparte) se desarrollan en ese documento en
vez de anticiparse acá sin evidencia de que hagan falta.
