Informe tecnico v2 · MD
# INFORME TÉCNICO: Sistema de monitoreo IoT con análisis predictivo para ganadería
 
## 1. Descripción del caso de uso
 
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