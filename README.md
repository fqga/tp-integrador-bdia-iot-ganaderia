# Sistema de Monitoreo IoT con Análisis Predictivo para Ganadería
 
## Información del Proyecto
 
**Trabajo Práctico Integrador**  
Carrera de Especialización en Inteligencia Artificial  
Asignatura: Bases de Datos para Inteligencia Artificial  
Docente: Martín Lacheski  
Año: 2026
 
---
 
## Resumen Ejecutivo
 
Este proyecto presenta el diseño de una **solución de datos para un sistema de monitoreo IoT en ganadería**. El sistema captura mediciones de consumo individual de animales mediante sensores RFID instalados en comederos inteligentes, permitiendo detectar anomalías, generar alertas predictivas y realizar análisis sobre patrones de consumo.
 
El enfoque está en el **diseño de la capa de datos** que sustenta una aplicación de IA, no en el entrenamiento de modelos ni en la aplicación completa. Se priorizan aspectos de almacenamiento, consulta, gobernanza, seguridad y escalabilidad.
 
---
 
## Caso de Uso Seleccionado
 
**Monitoreo IoT con análisis predictivo**
 
### Descripción del Contexto
 
Una organización ganadera posee comederos inteligentes instalados en diferentes ubicaciones (corrales, encierre, peseada, galpones). Cada comedero está equipado con:
- **Sensor RFID**: identifica el animal mediante tag único
- **Sensor de pesaje**: registra cantidad consumida
- **Sensores ambientales**: temperatura, humedad
### Problema a Resolver
 
1. **Detección de anomalías**: identificar cambios en patrones de consumo que indiquen enfermedad o malestar
2. **Alertas predictivas**: anticipar problemas de suministro o salud animal
3. **Análisis histórico**: consultas sobre tendencias de consumo por animal
4. **Escalabilidad**: manejar millones de registros de mediciones sin degradación de performance
---
 
## Datos Identificados
 
### Datos Principales (Estructurados)
 
- **Usuarios**: peones, encargados, veterinarios, administradores
- **Estancias**: unidades ganaderas (multi-tenancy)
- **Ubicaciones**: corrales, encierre, peseada, galpones
- **Dispositivos**: comederos y bebederos inteligentes
- **Sensores**: componentes de medición (RFID, pesaje, temperatura)
- **Animales**: entidades ganaderas con tags únicos
- **Mediciones**: registros periódicos de consumo individual
- **Alertas**: eventos detectados automáticamente
### Datos para Análisis Predictivo (Vectoriales)
 
- Embeddings de patrones de consumo: representaciones vectoriales de secuencias temporales
- Búsqueda de similitud para detectar comportamientos atípicos
---
 
## Tecnologías Propuestas
 
### Base de Datos Principal
- **PostgreSQL 15+**
  - Modelo relacional normalizado
  - Particionamiento temporal por mediciones
  - Row-Level Security (RLS) para multi-tenancy
  - JSONB para configuraciones flexibles
### Búsqueda Vectorial
- **pgvector**: extensión de PostgreSQL para embeddings
  - Almacenamiento de vectores de patrones de consumo
  - Búsqueda por similitud para detectar anomalías
  - Integración nativa con la base relacional
### Justificación de Elección
 
PostgreSQL fue seleccionado porque:
1. Maneja transacciones ACID para garantizar consistencia
2. Soporta particionamiento temporal eficiente (mediciones > 10M registros/año)
3. RLS nativa para multi-tenancy sin lógica en aplicación
4. pgvector integrado para análisis predictivo sin BD separada
5. Herramienta estándar industrial para este tipo de sistemas
---