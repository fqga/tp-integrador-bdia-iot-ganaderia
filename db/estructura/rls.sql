-- rls.sql
-- Row-Level Security (RLS) para garantizar aislamiento de datos por estancia

-- Nota: RLS en PostgreSQL requiere que exista una forma de identificar al usuario actual.
-- Esta implementación asume que existe un variable de sesión o columna que indica
-- a qué estancia pertenece el usuario conectado.

-- Para propósitos de demostración, usaremos: current_setting('app.estancia_id')
-- que debe ser establecido por la aplicación así:
-- SET app.estancia_id = 1;  (al conectarse)

-- IMPORTANTE: RLS no se aplica a superusuarios ni al dueño de la tabla (a menos que la tabla
-- tenga FORCE ROW LEVEL SECURITY, y aun así un superusuario la sigue bypasseando). El usuario
-- 'postgres' de docker-compose.yml es superusuario: conectarse con él para probar RLS no sirve,
-- SIEMPRE va a ver todas las filas. Por eso se crea acá un rol de aplicación sin ese privilegio,
-- que es con el que hay que conectarse para validar el aislamiento (ver README.md).
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'app_user') THEN
    CREATE ROLE app_user LOGIN PASSWORD 'app_user_password' NOSUPERUSER NOBYPASSRLS;
  END IF;
END $$;

GRANT CONNECT ON DATABASE monitoreo_iot_ganaderia TO app_user;
GRANT USAGE ON SCHEMA public TO app_user;
GRANT SELECT, INSERT, UPDATE ON
  estancias, usuarios, ubicaciones, dispositivos, sensores, animales, mediciones, alertas
  TO app_user;

-- Habilitar RLS en tablas de datos (incluye ESTANCIAS: sin esto, cualquier usuario autenticado
-- podría listar los nombres y datos de contacto de estancias que no son la suya).
ALTER TABLE estancias ENABLE ROW LEVEL SECURITY;
ALTER TABLE usuarios ENABLE ROW LEVEL SECURITY;
ALTER TABLE ubicaciones ENABLE ROW LEVEL SECURITY;
ALTER TABLE dispositivos ENABLE ROW LEVEL SECURITY;
ALTER TABLE sensores ENABLE ROW LEVEL SECURITY;
ALTER TABLE animales ENABLE ROW LEVEL SECURITY;
ALTER TABLE mediciones ENABLE ROW LEVEL SECURITY;
ALTER TABLE alertas ENABLE ROW LEVEL SECURITY;

-- Política RLS en ESTANCIAS: cada usuario ve solo el registro de su propia estancia
CREATE POLICY estancias_own ON estancias
  FOR SELECT
  USING (id = current_setting('app.estancia_id')::BIGINT);

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