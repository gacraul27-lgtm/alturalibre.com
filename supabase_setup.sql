-- ══════════════════════════════════════════════
--  ALTURA LIBRE · Supabase Setup
--  Copia y pega este SQL en:
--  supabase.com → tu proyecto → SQL Editor → Run
-- ══════════════════════════════════════════════

-- 1. Tabla de perfiles (extiende auth.users)
CREATE TABLE IF NOT EXISTS public.profiles (
  id                  UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  nombre_completo     TEXT NOT NULL,
  telefono            TEXT,
  celular             TEXT,
  fecha_nacimiento    DATE,
  contacto_emergencia TEXT,
  tipo_sangre         TEXT,
  created_at          TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Tabla de reservaciones
CREATE TABLE IF NOT EXISTS public.reservaciones (
  id               UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id          UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  actividad_nombre TEXT NOT NULL,
  tipo_actividad   TEXT,
  fecha_evento     DATE,
  precio           DECIMAL(10,2),
  estado           TEXT DEFAULT 'pendiente' CHECK (estado IN ('pendiente','confirmada','cancelada')),
  asistio          BOOLEAN DEFAULT FALSE,
  created_at       TIMESTAMPTZ DEFAULT NOW()
);

-- Migración (si la tabla ya existe):
-- ALTER TABLE public.reservaciones ADD COLUMN IF NOT EXISTS asistio BOOLEAN DEFAULT FALSE;

-- 3. Row Level Security (RLS)
ALTER TABLE public.profiles      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reservaciones ENABLE ROW LEVEL SECURITY;

-- Perfiles: cada usuario ve/edita solo el suyo
CREATE POLICY "profiles_own" ON public.profiles
  FOR ALL USING (auth.uid() = id);

-- Reservaciones: cada usuario ve/crea solo las suyas
CREATE POLICY "reservaciones_own" ON public.reservaciones
  FOR ALL USING (auth.uid() = user_id);

-- 4. Trigger: crea perfil automáticamente al registrarse
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.profiles (
    id, nombre_completo, telefono, celular,
    fecha_nacimiento, contacto_emergencia, tipo_sangre
  ) VALUES (
    NEW.id,
    NEW.raw_user_meta_data->>'nombre_completo',
    NEW.raw_user_meta_data->>'telefono',
    NEW.raw_user_meta_data->>'celular',
    NULLIF(NEW.raw_user_meta_data->>'fecha_nacimiento','')::DATE,
    NEW.raw_user_meta_data->>'contacto_emergencia',
    NEW.raw_user_meta_data->>'tipo_sangre'
  );
  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
