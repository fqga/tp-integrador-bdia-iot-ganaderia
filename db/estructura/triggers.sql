-- triggers.sql
-- Triggers para mantener consistencia de campos desnormalizados

-- Trigger 1: Actualizar cantidad_animales_actual en ESTANCIAS
CREATE OR REPLACE FUNCTION actualizar_cantidad_animales()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
    UPDATE estancias 
    SET cantidad_animales_actual = (
      SELECT COUNT(*) FROM animales 
      WHERE estancia_id = NEW.estancia_id AND fecha_egreso_estancia IS NULL
    )
    WHERE id = NEW.estancia_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE estancias 
    SET cantidad_animales_actual = (
      SELECT COUNT(*) FROM animales 
      WHERE estancia_id = OLD.estancia_id AND fecha_egreso_estancia IS NULL
    )
    WHERE id = OLD.estancia_id;
    RETURN OLD;
  END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tg_actualizar_cantidad_animales
AFTER INSERT OR UPDATE OR DELETE ON animales
FOR EACH ROW
EXECUTE FUNCTION actualizar_cantidad_animales();

-- Trigger 2: Actualizar ubicacion_actual_id en ANIMALES
CREATE OR REPLACE FUNCTION actualizar_ubicacion_animal()
RETURNS TRIGGER AS $$
DECLARE
  v_ubicacion_id BIGINT;
BEGIN
  -- Obtener ubicación del último dispositivo donde comió el animal
  SELECT ubicacion_id INTO v_ubicacion_id
  FROM dispositivos
  WHERE id = (
    SELECT dispositivo_id FROM mediciones
    WHERE animal_id = NEW.animal_id
    ORDER BY timestamp DESC
    LIMIT 1
  );
  
  IF v_ubicacion_id IS NOT NULL THEN
    UPDATE animales SET ubicacion_actual_id = v_ubicacion_id
    WHERE id = NEW.animal_id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tg_actualizar_ubicacion_animal
AFTER INSERT ON mediciones
FOR EACH ROW
WHEN (NEW.animal_id IS NOT NULL)
EXECUTE FUNCTION actualizar_ubicacion_animal();

-- Trigger 3: Detección automática de anomalías (versión simplificada)
-- Marca como anomalía si consumo está fuera de rango esperado
CREATE OR REPLACE FUNCTION detectar_anomalia()
RETURNS TRIGGER AS $$
DECLARE
  v_promedio_7_dias DECIMAL(10,3);
  v_desviacion DECIMAL(10,3);
  v_limite_superior DECIMAL(10,3);
  v_limite_inferior DECIMAL(10,3);
BEGIN
  -- Calcular promedio y desviación estándar de últimos 7 días
  SELECT 
    COALESCE(AVG(valor_medido), 0),
    COALESCE(STDDEV(valor_medido), 0)
  INTO v_promedio_7_dias, v_desviacion
  FROM mediciones
  WHERE animal_id = NEW.animal_id
    AND timestamp > NEW.timestamp - INTERVAL '7 days'
    AND id != NEW.id;
  
  -- Si no hay datos previos, no marcar como anomalía
  IF v_promedio_7_dias = 0 THEN
    RETURN NEW;
  END IF;
  
  -- Establecer límites: promedio ± 2 desviaciones
  v_limite_superior := v_promedio_7_dias + (2 * v_desviacion);
  v_limite_inferior := GREATEST(0, v_promedio_7_dias - (2 * v_desviacion));
  
  -- Marcar como anomalía si está fuera de rango
  IF NEW.valor_medido > v_limite_superior OR NEW.valor_medido < v_limite_inferior THEN
    NEW.es_anomalia := TRUE;
    NEW.puntuacion_anomalia := LEAST(1.0, ABS(NEW.valor_medido - v_promedio_7_dias) / GREATEST(v_desviacion, 0.1));
  ELSE
    NEW.es_anomalia := FALSE;
    NEW.puntuacion_anomalia := 0.0;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tg_detectar_anomalia
BEFORE INSERT OR UPDATE ON mediciones
FOR EACH ROW
EXECUTE FUNCTION detectar_anomalia();

-- Trigger 4: Generar alerta automáticamente si es anomalía
CREATE OR REPLACE FUNCTION generar_alerta_anomalia()
RETURNS TRIGGER AS $$
DECLARE
  v_proxima_alerta_id BIGINT;
BEGIN
  IF NEW.es_anomalia = TRUE THEN
    -- Obtener siguiente ID de alerta
    SELECT COALESCE(MAX(id), 0) + 1 INTO v_proxima_alerta_id FROM alertas;
    
    -- Insertar alerta
    INSERT INTO alertas (
      id,
      animal_id,
      tipo_alerta,
      severidad,
      timestamp_alerta,
      descripcion,
      datos_contextuales,
      estado
    ) VALUES (
      v_proxima_alerta_id,
      NEW.animal_id,
      'consumo_atipico',
      CASE 
        WHEN NEW.puntuacion_anomalia > 0.8 THEN 'critica'
        WHEN NEW.puntuacion_anomalia > 0.6 THEN 'alta'
        WHEN NEW.puntuacion_anomalia > 0.4 THEN 'media'
        ELSE 'baja'
      END,
      NEW.timestamp,
      'Consumo anómalo detectado: ' || NEW.valor_medido || ' kg (esperado diferente)',
      jsonb_build_object(
        'valor_medido', NEW.valor_medido,
        'puntuacion_anomalia', NEW.puntuacion_anomalia,
        'timestamp_evento', NEW.timestamp
      ),
      'abierta'
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tg_generar_alerta_anomalia
AFTER INSERT ON mediciones
FOR EACH ROW
WHEN (NEW.es_anomalia = TRUE AND NEW.animal_id IS NOT NULL)
EXECUTE FUNCTION generar_alerta_anomalia();