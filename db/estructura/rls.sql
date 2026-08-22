-- rls.sql
-- Row-Level Security (RLS) para garantizar aislamiento de datos por estancia

-- Nota: RLS en PostgreSQL requiere que exista una forma de identificar al usuario actual.
-- Esta implementación asume que existe un variable de sesión o columna que indica
-- a qué estancia pertenece el usuario conectado.

-- Para propósitos de demostración, usaremos: current_setting('app.estancia_id')
-- que debe ser establecido por la aplicación así:
-- SET app.estancia_id = 1;  (al conectarse)

-- Habilitar RLS en tablas de datos
ALTER TABLE usuarios ENABLE ROW LEVEL SECURITY;
ALTER TABLE ubicaciones ENABLE ROW LEVEL SECURITY;
ALTER TABLE dispositivos ENABLE ROW LEVEL SECURITY;
ALTER TABLE sensores ENABLE ROW LEVEL SECURITY;
ALTER TABLE animales ENABLE ROW LEVEL SECURITY;
ALTER TABLE mediciones ENABLE ROW LEVEL SECURITY;
ALTER TABLE alertas ENABLE ROW LEVEL SECURITY;

-- Política RLS en USUARIOS: cada usuario ve solo usuarios de su estancia
CREATE POLICY usuarios_own_estancia ON usuarios
  FOR SELECT
  USING (estancia_id = current_setting('app.estancia_id')::BIGINT);

CREATE POLICY usuarios_insert_own_estancia ON usuarios
  FOR INSERT
  WITH CHECK (estancia_id = current_setting('app.estancia_id')::BIGINT);

CREATE POLICY usuarios_update_own_estancia ON usuarios
  FOR UPDATE
  USING (estancia_id = current_setting('app.estancia_id')::BIGINT);

-- Política RLS en UBICACIONES: acceso solo a ubicaciones de la estancia
CREATE POLICY ubicaciones_own_estancia ON ubicaciones
  FOR SELECT
  USING (estancia_id = current_setting('app.estancia_id')::BIGINT);

CREATE POLICY ubicaciones_insert_own_estancia ON ubicaciones
  FOR INSERT
  WITH CHECK (estancia_id = current_setting('app.estancia_id')::BIGINT);

CREATE POLICY ubicaciones_update_own_estancia ON ubicaciones
  FOR UPDATE
  USING (estancia_id = current_setting('app.estancia_id')::BIGINT);

-- Política RLS en DISPOSITIVOS: acceso mediante cadena FK
CREATE POLICY dispositivos_own_estancia ON dispositivos
  FOR SELECT
  USING (ubicacion_id IN (
    SELECT id FROM ubicaciones 
    WHERE estancia_id = current_setting('app.estancia_id')::BIGINT
  ));

CREATE POLICY dispositivos_insert_own_estancia ON dispositivos
  FOR INSERT
  WITH CHECK (ubicacion_id IN (
    SELECT id FROM ubicaciones 
    WHERE estancia_id = current_setting('app.estancia_id')::BIGINT
  ));

CREATE POLICY dispositivos_update_own_estancia ON dispositivos
  FOR UPDATE
  USING (ubicacion_id IN (
    SELECT id FROM ubicaciones 
    WHERE estancia_id = current_setting('app.estancia_id')::BIGINT
  ));

-- Política RLS en SENSORES: acceso mediante cadena FK (dispositivo -> ubicación -> estancia)
CREATE POLICY sensores_own_estancia ON sensores
  FOR SELECT
  USING (dispositivo_id IN (
    SELECT d.id FROM dispositivos d
    WHERE d.ubicacion_id IN (
      SELECT id FROM ubicaciones 
      WHERE estancia_id = current_setting('app.estancia_id')::BIGINT
    )
  ));

-- Política RLS en ANIMALES: acceso solo a animales de su estancia
CREATE POLICY animales_own_estancia ON animales
  FOR SELECT
  USING (estancia_id = current_setting('app.estancia_id')::BIGINT);

CREATE POLICY animales_insert_own_estancia ON animales
  FOR INSERT
  WITH CHECK (estancia_id = current_setting('app.estancia_id')::BIGINT);

CREATE POLICY animales_update_own_estancia ON animales
  FOR UPDATE
  USING (estancia_id = current_setting('app.estancia_id')::BIGINT);

-- Política RLS en MEDICIONES: acceso solo a mediciones de su estancia
CREATE POLICY mediciones_own_estancia ON mediciones
  FOR SELECT
  USING (dispositivo_id IN (
    SELECT d.id FROM dispositivos d
    WHERE d.ubicacion_id IN (
      SELECT id FROM ubicaciones 
      WHERE estancia_id = current_setting('app.estancia_id')::BIGINT
    )
  ));

CREATE POLICY mediciones_insert_own_estancia ON mediciones
  FOR INSERT
  WITH CHECK (dispositivo_id IN (
    SELECT d.id FROM dispositivos d
    WHERE d.ubicacion_id IN (
      SELECT id FROM ubicaciones 
      WHERE estancia_id = current_setting('app.estancia_id')::BIGINT
    )
  ));

-- Política RLS en ALERTAS: acceso solo a alertas de su estancia
CREATE POLICY alertas_own_estancia ON alertas
  FOR SELECT
  USING (
    animal_id IN (
      SELECT id FROM animales 
      WHERE estancia_id = current_setting('app.estancia_id')::BIGINT
    )
    OR dispositivo_id IN (
      SELECT d.id FROM dispositivos d
      WHERE d.ubicacion_id IN (
        SELECT id FROM ubicaciones 
        WHERE estancia_id = current_setting('app.estancia_id')::BIGINT
      )
    )
  );

CREATE POLICY alertas_insert_own_estancia ON alertas
  FOR INSERT
  WITH CHECK (
    animal_id IN (
      SELECT id FROM animales 
      WHERE estancia_id = current_setting('app.estancia_id')::BIGINT
    )
    OR dispositivo_id IN (
      SELECT d.id FROM dispositivos d
      WHERE d.ubicacion_id IN (
        SELECT id FROM ubicaciones 
        WHERE estancia_id = current_setting('app.estancia_id')::BIGINT
      )
    )
  );