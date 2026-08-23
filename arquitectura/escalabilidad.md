# ESCALABILIDAD Y RENDIMIENTO

## 1. Qué tabla crece más, y por cuánto

`mediciones` domina el crecimiento por un orden de magnitud sobre cualquier otra tabla: cada
evento de consumo es una fila, mientras que `animales`, `dispositivos`, `usuarios`, etc.
crecen con el tamaño del rodeo/infraestructura, no con el tiempo.

Con el volumen estimado en `docs/informe_tecnico.md` (10-100 mediciones/segundo por
estancia en operación a escala), una sola estancia grande puede generar entre 315M y 3.150M
de filas por año. `alertas` crece proporcional a la tasa de anomalías detectadas — mucho
menor, pero no despreciable si el umbral del trigger es sensible (ver la corrección del
trigger `detectar_anomalia` en `db/estructura/triggers.sql`, que exige un mínimo de 5
mediciones previas antes de evaluar, justamente para no inundar `alertas` de falsos
positivos).

## 2. Particionamiento de `mediciones`

**Implementado en esta entrega** (`db/estructura/particiones.sql`): `mediciones` está
declarada `PARTITION BY RANGE (timestamp)` con una partición por mes de 2026 más una
partición `DEFAULT` de resguardo. Esto habilita:

- **Poda de particiones (partition pruning)**: una consulta con `WHERE timestamp > NOW() -
  INTERVAL '7 days'` (como las consultas representativas 1 y 2) solo escanea 1-2 particiones
  en vez de la tabla completa, sin importar cuántos años de historia acumule el sistema.
- **Purga barata de historia vieja**: borrar datos de hace 2+ años es un `DROP TABLE
  mediciones_2024_01` (instantáneo, sin `VACUUM` posterior) en vez de un `DELETE` masivo que
  bloquea la tabla y genera tuplas muertas.
- **Mantenimiento independiente por partición**: `REINDEX`/`VACUUM` de un mes puntual sin
  afectar el resto.

**Costo asumido**: hay que crear la partición del mes siguiente con anticipación (un job
mensual con `pg_cron` o un cron externo que ejecute el `CREATE TABLE ... PARTITION OF`
correspondiente). Mientras esa partición no exista, las filas caen en la partición `DEFAULT`,
que no tiene el beneficio de poda — es una red de seguridad para no perder escrituras, no una
solución de régimen permanente. Este es el trade-off central del particionamiento manual:
gana rendimiento de consulta y mantenimiento a cambio de una tarea operativa recurrente.

## 3. Índices: cuáles importan y por qué

Los índices ya creados (`db/estructura/indexes.sql`) están elegidos en función de los
patrones de consulta reales del caso de uso, no de forma genérica:

| Índice | Consulta que optimiza | Por qué importa a escala |
|---|---|---|
| `idx_mediciones_animal_timestamp` | Historial de un animal (consultas 1, 6, 8) | Sin él, cada consulta de "consumo del animal X" escanea toda la partición |
| `idx_mediciones_anomalia_parcial` (parcial, `WHERE es_anomalia`) | Detección de anomalías | Las anomalías son <2% de las filas: un índice parcial pesa una fracción de uno completo y solo indexa lo que realmente se busca |
| `idx_alertas_estado_timestamp` (parcial, `WHERE estado IN (...)`) | Bandeja de alertas sin resolver (consulta 4) | Las alertas resueltas se acumulan indefinidamente; sin el filtro parcial, el índice crecería con todo el historial en vez de solo los casos activos |
| `idx_mediciones_embedding` (ivfflat, coseno) | Similitud vectorial (consulta 5) | Sin índice, una búsqueda de similitud es `O(n)` sobre todas las mediciones con vector; ivfflat la vuelve aproximada pero sub-lineal |

**Compromiso**: cada índice nuevo acelera lecturas pero ralentiza cada `INSERT` (hay que
mantenerlo). Con `mediciones` siendo la tabla de mayor volumen de escritura, no se agregaron
índices "por si acaso" — cada uno tiene una consulta representativa concreta detrás.

## 4. Qué se precalcula (y qué no)

Ya implementado como desnormalización con triggers (ver `docs/02_modelo_logico.md`, sección
4): `estancias.cantidad_animales_actual` y `animales.ubicacion_actual_id`. Ambos evitan un
`COUNT`/subconsulta contra `mediciones` en cada lectura de un dato que se pide todo el tiempo
(dashboard) pero cambia con poca frecuencia relativa.

Las vistas `animales_consumo_7_dias` y `alertas_activas_por_estancia`
(`db/estructura/views.sql`) **no** son vistas materializadas: se recalculan en cada consulta.
Es la decisión correcta al volumen actual (siguen siendo rápidas gracias a los índices de la
sección 3) pero es el primer punto a revisar si el dashboard ejecutivo empieza a sentirse
lento: convertirlas en vistas materializadas con refresco periódico (`REFRESH MATERIALIZED
VIEW CONCURRENTLY`, cada 5-15 minutos) cambia el costo de cálculo por segundos de
desactualización — aceptable para un panorama ejecutivo, no para la bandeja de alertas activas
que sí necesita ser en tiempo real.

## 5. Qué se separaría si el sistema creciera un orden de magnitud

- **Réplica de solo lectura** para las consultas analíticas/ejecutivas (3, 5, 7), de forma que
  no compitan por recursos con los `INSERT` de alta frecuencia de los sensores.
- **Cola de ingesta** (Kafka/similar) entre los dispositivos y la base si la tasa de escritura
  supera lo que `INSERT`s directos pueden sostener con los triggers síncronos activos —
  permite desacoplar la escritura del cálculo de anomalías (moverlo a un consumer asíncrono)
  a costa de que la alerta ya no sea instantánea.
- **Sharding por estancia**: dado que el aislamiento ya es por `estancia_id` (vía RLS), es la
  clave natural de partición horizontal si una sola instancia de PostgreSQL deja de alcanzar
  — cada estancia grande podría vivir en su propia instancia sin cambiar el modelo de datos.
- **Almacenamiento frío separado** para mediciones de más de ~1 año (Parquet en object
  storage), si aparece una necesidad analítica de largo plazo que no justifique mantener años
  de historia en la base operacional. Hasta que esa necesidad exista, es complejidad que no
  se justifica (ver `docs/04_arquitectura_datos.md`, sección 1).

## 6. Qué no se resuelve en esta entrega (limitación reconocida)

No hay un mecanismo automático de rotación de particiones (crear la del mes siguiente, migrar
filas fuera de `DEFAULT`, purgar particiones viejas): quedó como tarea operativa manual/cron
descripta pero no implementada, consistente con el alcance de "prueba mínima" pedido por la
consigna y no de un sistema productivo completo.
