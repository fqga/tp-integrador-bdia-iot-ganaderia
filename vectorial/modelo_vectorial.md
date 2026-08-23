# MODELO VECTORIAL: Búsqueda por similitud de patrones de consumo

## 1. Qué se vectoriza

La unidad vectorizada es el **patrón diario de consumo de un animal**: la secuencia de
mediciones de un animal a lo largo de un día (cantidad consumida, horarios, duración de cada
evento) se resume en un vector de 768 dimensiones que captura la "forma" de cómo comió ese
animal ese día — no el valor de una medición puntual.

Se vectoriza a nivel diario y no a nivel de medición individual por dos razones:

- Una medición aislada (un evento de 30 segundos en el comedero) no tiene información
  suficiente para caracterizar un comportamiento; el patrón emerge de la secuencia.
- Vectorizar cada medición multiplicaría el volumen de vectores por el número de eventos/día
  (5-20 según el animal) sin agregar valor: lo que se quiere comparar es "¿este animal comió
  hoy como come habitualmente?", no "¿este evento puntual es raro?" (eso ya lo resuelve el
  trigger `detectar_anomalia`, que trabaja sobre valores escalares, no sobre embeddings).

En una implementación de producción, el vector se generaría con un modelo entrenado sobre
secuencias de mediciones (por ejemplo, un autoencoder o embeddings de series temporales). En
esta entrega, `data/ejemplos/datos_simulados.sql` genera vectores **sintéticos**: valores
aleatorios bajos y homogéneos para animales sanos, y valores desplazados hacia arriba en un
subconjunto de dimensiones para el animal en tratamiento durante su semana de caída de
consumo — alcanza para demostrar que la consulta de similitud agrupa correctamente a los
animales sanos entre sí y separa al que tiene un patrón distinto (ver consulta
representativa #5 en `db/consultas/queries_representativas.sql`).

## 2. Dónde se almacena y qué metadatos lo acompañan

El vector vive **en la misma fila** de la tabla `mediciones` (columna `embedding_patron
vector(768)`), no en una base vectorial separada. Se decidió así porque:

- El vector siempre se consulta junto con sus metadatos relacionales (`animal_id`,
  `timestamp`, `es_anomalia`, la ubicación/dispositivo vía joins) — mantenerlo co-ubicado
  evita una segunda consulta a otro sistema y un segundo punto de fallo/consistencia.
- pgvector permite crear un índice (`ivfflat`, distancia coseno) sobre la misma tabla sin
  duplicar infraestructura.
- El volumen es manejable (~1 vector/animal/día, no uno por evento): con cientos de miles de
  animales seguiría siendo una fracción pequeña de la tabla `mediciones`.

Los metadatos que acompañan a cada vector son los que ya tiene la fila de `mediciones`:
`animal_id` (a qué animal pertenece), `timestamp` (a qué día/momento corresponde),
`dispositivo_id`/`sensor_id` (con qué equipo se registró), `es_anomalia` (si esa fila puntual
ya fue marcada como anómala por el trigger escalar). No hace falta una tabla de metadatos
separada porque el vector no vive de forma independiente: es una columna más de un hecho que
ya está completamente descripto por el resto de la fila.

## 3. Vínculo con los datos originales

El vector **no reemplaza** las mediciones crudas: la fila que lo contiene sigue teniendo
`valor_medido`, `duracion_evento_segundos`, etc. El vínculo es directo y no requiere
resolución adicional: `embedding_patron` es una columna de `mediciones`, así que cualquier
resultado de una búsqueda por similitud ya trae consigo, en la misma fila, el animal, el
momento y el valor medido que motivaron ese vector. Esto es deliberado: en un sistema donde
la trazabilidad importa (¿por qué el sistema recomendó atender a este animal?), nunca hay que
"volver" a otra tabla para justificar un resultado de similitud — la fila devuelta ya es la
evidencia.

## 4. Consultas por similitud que resuelve

- **Encontrar animales de referencia comparables**: dado un animal sano, encontrar otros con
  patrón de consumo parecido (para benchmarking dentro del mismo lote/corral).
- **Detectar si una anomalía es aislada o generalizada**: si el patrón "atípico" de un animal
  empieza a parecerse al de *varios* animales del mismo corral, es indicio de un problema del
  comedero/agua/alimento (foco sanitario) y no de un animal individual — un caso que la
  detección escalar por animal (trigger `detectar_anomalia`) no puede ver porque analiza cada
  animal de forma aislada.
- **Priorizar revisión veterinaria**: ordenar animales por distancia a un "patrón sano" de
  referencia (ver `animales_similares()` en `db/vectorial/embeddings.sql`), en vez de esperar
  a que un umbral escalar dispare una alerta.

Ver consulta representativa #5 y la función `animales_similares(animal_id, limite)` para la
implementación concreta con el operador `<=>` (distancia coseno) sobre el índice
`idx_mediciones_embedding` (ivfflat).

## 5. Restricciones de acceso

El vector hereda **exactamente las mismas políticas RLS** que el resto de `mediciones`, porque
es una columna de la misma tabla, no un almacén aparte con su propio control de acceso: un
usuario de la Estancia 2 no puede ejecutar una búsqueda de similitud que le devuelva
mediciones (ni sus vectores) de la Estancia 1, sin necesidad de duplicar la lógica de
aislamiento (ver `db/estructura/rls.sql`, política `mediciones_own_estancia`).

Riesgo específico a mitigar: una búsqueda de similitud, a diferencia de un filtro exacto,
siempre devuelve *algo* — el vecino más cercano existe aunque sea poco parecido. Sin RLS, una
consulta de similitud mal acotada podría devolver el animal "más similar" de **otra estancia**,
filtrando indirectamente que ese animal existe y cuál es su patrón de consumo. Al aplicarse
RLS sobre la tabla base antes de calcular la distancia, ese resultado directamente no está
disponible para comparar: el filtro de similitud opera solo dentro del subconjunto de filas
ya autorizado para la estancia activa.

## 6. Por qué no una base vectorial separada

Se evaluó y descartó una base vectorial dedicada (Pinecone, Milvus, Qdrant) para esta entrega:

| Criterio | pgvector (elegido) | Base vectorial dedicada |
|---|---|---|
| Volumen de vectores | Bajo (~1/animal/día) | Pensadas para millones-billones |
| Consistencia con datos relacionales | Nativa (misma transacción) | Requiere sincronización externa |
| Aislamiento multi-tenant | RLS ya existente, sin duplicar lógica | Hay que reimplementar el filtro por tenant |
| Complejidad operativa | Un solo motor (PostgreSQL) | Un segundo sistema a operar y monitorear |

Si el volumen de vectores creciera varios órdenes de magnitud (por ejemplo, si se decidiera
vectorizar cada medición individual en vez de un patrón diario, o vectorizar además texto
libre de notas veterinarias con embeddings de lenguaje), migrar esa porción a una base
vectorial dedicada sería razonable — ver `docs/04_arquitectura_datos.md`, sección de
escalabilidad, para esa discusión.
