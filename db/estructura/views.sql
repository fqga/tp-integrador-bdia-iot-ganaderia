-- views.sql
-- Vistas para consultas frecuentes. Se crean con el propietario 'postgres' (superusuario),
-- pero como las políticas RLS evalúan current_setting('app.estancia_id') en tiempo de consulta
-- (no el rol dueño de la vista), igual filtran correctamente cuando se consultan como
-- app_user. alertas_activas_por_estancia es la excepción intencional: es un panorama
-- multi-estancia pensado para un rol admin de plataforma, por eso se consulta como postgres.

-- Vista: consumo de cada animal en los últimos 7 días
CREATE OR REPLACE VIEW animales_consumo_7_dias AS
SELECT
  a.id,
  a.estancia_id,
  a.nombre_alias,
  a.tag_rfid,
  COALESCE(SUM(m.valor_medido), 0) AS consumo_total_7_dias,
  COUNT(m.id) AS numero_eventos,
  ROUND(AVG(m.valor_medido), 2) AS consumo_promedio,
  ROUND(STDDEV(m.valor_medido), 2) AS desviacion_estandar
FROM animales a
LEFT JOIN mediciones m ON a.id = m.animal_id
  AND m.timestamp > CURRENT_TIMESTAMP - INTERVAL '7 days'
GROUP BY a.id, a.estancia_id, a.nombre_alias, a.tag_rfid;

-- Vista auxiliar: cada alerta con la estancia a la que pertenece (vía animal_id o, si es una
-- alerta de hardware sin animal asociado, vía dispositivo_id -> ubicacion_id).
CREATE OR REPLACE VIEW alertas_con_estancia AS
SELECT
  al.*,
  COALESCE(a.estancia_id, u.estancia_id) AS estancia_id
FROM alertas al
LEFT JOIN animales a ON a.id = al.animal_id
LEFT JOIN dispositivos d ON d.id = al.dispositivo_id
LEFT JOIN ubicaciones u ON u.id = d.ubicacion_id;

-- Vista: alertas activas por estancia (panorama multi-tenant para administración de plataforma)
CREATE OR REPLACE VIEW alertas_activas_por_estancia AS
SELECT
  e.id AS estancia_id,
  e.nombre AS estancia_nombre,
  COUNT(*) AS cantidad_alertas,
  COUNT(*) FILTER (WHERE ac.severidad = 'critica') AS criticas,
  COUNT(*) FILTER (WHERE ac.severidad = 'alta') AS altas,
  COUNT(*) FILTER (WHERE ac.estado IN ('abierta', 'en_progreso')) AS sin_resolver
FROM alertas_con_estancia ac
JOIN estancias e ON e.id = ac.estancia_id
GROUP BY e.id, e.nombre;

-- Vista: cantidad de dispositivos por ubicación y estado operativo (mantenimiento/monitoreo)
CREATE OR REPLACE VIEW dispositivos_por_estado AS
SELECT
  u.estancia_id,
  d.ubicacion_id,
  d.estado,
  COUNT(*) AS cantidad
FROM dispositivos d
JOIN ubicaciones u ON u.id = d.ubicacion_id
GROUP BY u.estancia_id, d.ubicacion_id, d.estado;

GRANT SELECT ON
  animales_consumo_7_dias, alertas_con_estancia, alertas_activas_por_estancia, dispositivos_por_estado
  TO app_user;
