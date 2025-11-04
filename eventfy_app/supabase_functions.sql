-- Função para buscar eventos próximos usando PostGIS
-- Execute este SQL no Supabase SQL Editor

CREATE OR REPLACE FUNCTION get_nearby_events(
  user_lat DOUBLE PRECISION,
  user_lng DOUBLE PRECISION,
  radius_km DOUBLE PRECISION DEFAULT 10.0
)
RETURNS TABLE (
  id UUID,
  company_id UUID,
  titulo VARCHAR(200),
  descricao TEXT,
  endereco VARCHAR(200),
  data_inicio TIMESTAMP WITH TIME ZONE,
  data_fim TIMESTAMP WITH TIME ZONE,
  valor DECIMAL(10,2),
  is_gratuito BOOLEAN,
  capacidade INTEGER,
  capacidade_atual INTEGER,
  idade_minima INTEGER,
  foto_principal_url TEXT,
  link_externo TEXT,
  link_streaming TEXT,
  status event_status,
  is_online BOOLEAN,
  is_presencial BOOLEAN,
  requires_approval BOOLEAN,
  total_views INTEGER,
  total_interested INTEGER,
  total_confirmed INTEGER,
  total_attended INTEGER,
  average_rating DECIMAL(3,2),
  total_reviews INTEGER,
  created_at TIMESTAMP WITH TIME ZONE,
  updated_at TIMESTAMP WITH TIME ZONE,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  empresa_nome TEXT,
  empresa_logo TEXT,
  empresa_rating NUMERIC(3,2),
  distance_km DOUBLE PRECISION
)
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    e.id,
    e.company_id,
    e.titulo,
    e.descricao,
    e.endereco,
    e.data_inicio,
    e.data_fim,
    e.valor,
    e.is_gratuito,
    e.capacidade,
    e.capacidade_atual,
    e.idade_minima,
    e.foto_principal_url,
    e.link_externo,
    e.link_streaming,
    e.status,
    e.is_online,
    e.is_presencial,
    e.requires_approval,
    e.total_views,
    e.total_interested,
    e.total_confirmed,
    e.total_attended,
    e.average_rating,
    e.total_reviews,
    e.created_at,
    e.updated_at,
    ST_Y(e.location::geometry) AS latitude,
    ST_X(e.location::geometry) AS longitude,
    c.nome_fantasia::text AS empresa_nome,
    c.logo_url::text AS empresa_logo,
    c.average_rating AS empresa_rating,
    ST_Distance(
      e.location::geography,
      ST_SetSRID(ST_MakePoint(user_lng, user_lat), 4326)::geography
    ) / 1000 AS distance_km
  FROM events e
  INNER JOIN companies c ON e.company_id = c.id
  WHERE 
    e.status = 'ativo'
    AND e.data_fim >= NOW()
    AND ST_DWithin(
      e.location::geography,
      ST_SetSRID(ST_MakePoint(user_lng, user_lat), 4326)::geography,
      radius_km * 1000
    )
  ORDER BY distance_km ASC;
END;
$$;

-- Dar permissões para usuários autenticados
GRANT EXECUTE ON FUNCTION get_nearby_events(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION) TO authenticated;
GRANT EXECUTE ON FUNCTION get_nearby_events(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION) TO anon;

-- ============================================
-- Atualização automática de status dos eventos
-- ============================================

-- Função que finaliza eventos expirados com base no horário do servidor
CREATE OR REPLACE FUNCTION finalize_expired_events()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE events
  SET status = 'finalizado',
      updated_at = NOW()
  WHERE status = 'ativo'
    AND data_fim < NOW();
END;
$$;

-- Trigger para garantir que ao inserir/atualizar um evento, se a data_fim já passou,
-- o status não fique como 'ativo'
CREATE OR REPLACE FUNCTION enforce_event_status_on_write()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.data_fim < NOW() THEN
    NEW.status := 'finalizado';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS enforce_event_status_on_write_trigger ON events;
CREATE TRIGGER enforce_event_status_on_write_trigger
BEFORE INSERT OR UPDATE ON events
FOR EACH ROW
EXECUTE FUNCTION enforce_event_status_on_write();

-- Habilitar extensão pg_cron (se ainda não estiver habilitada)
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Agendar tarefa periódica para finalizar eventos expirados usando horário do servidor
-- Executa a cada 15 minutos
SELECT cron.schedule(
  'finalize_expired_events_job',
  '*/15 * * * *',
  $$SELECT finalize_expired_events();$$
);

-- Permissões (opcional): permitir execução manual da função via RPC se necessário
GRANT EXECUTE ON FUNCTION finalize_expired_events() TO authenticated;
GRANT EXECUTE ON FUNCTION finalize_expired_events() TO anon;

-- ============================================
-- RPC: Eventos completos (com empresa e categorias)
-- ============================================
CREATE OR REPLACE FUNCTION public.get_events_complete(
  p_limit integer DEFAULT 200,
  p_offset integer DEFAULT 0
)
RETURNS TABLE (
  id uuid,
  company_id uuid,
  titulo varchar(200),
  descricao text,
  endereco varchar(200),
  data_inicio timestamptz,
  data_fim timestamptz,
  valor numeric(10,2),
  is_gratuito boolean,
  capacidade integer,
  capacidade_atual integer,
  idade_minima integer,
  foto_principal_url text,
  link_externo text,
  link_streaming text,
  status event_status,
  is_online boolean,
  is_presencial boolean,
  requires_approval boolean,
  total_views integer,
  total_interested integer,
  total_confirmed integer,
  total_attended integer,
  average_rating numeric(3,2),
  total_reviews integer,
  created_at timestamptz,
  updated_at timestamptz,
  latitude double precision,
  longitude double precision,
  empresa_nome text,
  empresa_logo text,
  empresa_rating numeric(3,2),
  categorias text[]
)
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    e.id,
    e.company_id,
    e.titulo,
    e.descricao,
    e.endereco,
    e.data_inicio,
    e.data_fim,
    e.valor,
    e.is_gratuito,
    e.capacidade,
    e.capacidade_atual,
    e.idade_minima,
    e.foto_principal_url,
    e.link_externo,
    e.link_streaming,
    e.status,
    e.is_online,
    e.is_presencial,
    e.requires_approval,
    e.total_views,
    e.total_interested,
    e.total_confirmed,
    e.total_attended,
    e.average_rating,
    e.total_reviews,
    e.created_at,
    e.updated_at,
    ST_Y(e.location::geometry) as latitude,
    ST_X(e.location::geometry) as longitude,
    c.nome_fantasia::text as empresa_nome,
    c.logo_url::text as empresa_logo,
    c.average_rating as empresa_rating,
    COALESCE(array_agg(cat.nome::text ORDER BY cat.nome) FILTER (WHERE cat.nome IS NOT NULL), ARRAY[]::text[]) as categorias
  FROM events e
  JOIN companies c ON c.id = e.company_id
  LEFT JOIN event_categories ec ON ec.event_id = e.id
  LEFT JOIN categories cat ON cat.id = ec.category_id
  WHERE e.status = 'ativo' AND e.data_fim >= NOW()
  GROUP BY e.id, c.nome_fantasia, c.logo_url, c.average_rating
  ORDER BY e.data_inicio ASC
  LIMIT p_limit OFFSET p_offset;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_events_complete(integer, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_events_complete(integer, integer) TO anon;

-- ============================================
-- RPC: Eventos por empresa
-- ============================================
CREATE OR REPLACE FUNCTION public.get_company_events(
  p_company_id uuid,
  p_limit integer DEFAULT 200,
  p_offset integer DEFAULT 0
)
RETURNS TABLE (
  id uuid,
  company_id uuid,
  titulo varchar(200),
  descricao text,
  endereco varchar(200),
  data_inicio timestamptz,
  data_fim timestamptz,
  valor numeric(10,2),
  is_gratuito boolean,
  capacidade integer,
  capacidade_atual integer,
  idade_minima integer,
  foto_principal_url text,
  link_externo text,
  link_streaming text,
  status event_status,
  is_online boolean,
  is_presencial boolean,
  requires_approval boolean,
  total_views integer,
  total_interested integer,
  total_confirmed integer,
  total_attended integer,
  average_rating numeric(3,2),
  total_reviews integer,
  created_at timestamptz,
  updated_at timestamptz,
  latitude double precision,
  longitude double precision,
  empresa_nome text,
  empresa_logo text,
  empresa_rating numeric(3,2),
  categorias text[]
)
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    e.id,
    e.company_id,
    e.titulo,
    e.descricao,
    e.endereco,
    e.data_inicio,
    e.data_fim,
    e.valor,
    e.is_gratuito,
    e.capacidade,
    e.capacidade_atual,
    e.idade_minima,
    e.foto_principal_url,
    e.link_externo,
    e.link_streaming,
    e.status,
    e.is_online,
    e.is_presencial,
    e.requires_approval,
    e.total_views,
    e.total_interested,
    e.total_confirmed,
    e.total_attended,
    e.average_rating,
    e.total_reviews,
    e.created_at,
    e.updated_at,
    ST_Y(e.location::geometry) as latitude,
    ST_X(e.location::geometry) as longitude,
    c.nome_fantasia::text as empresa_nome,
    c.logo_url::text as empresa_logo,
    c.average_rating as empresa_rating,
    COALESCE(array_agg(cat.nome::text ORDER BY cat.nome) FILTER (WHERE cat.nome IS NOT NULL), ARRAY[]::text[]) as categorias
  FROM events e
  JOIN companies c ON c.id = e.company_id
  LEFT JOIN event_categories ec ON ec.event_id = e.id
  LEFT JOIN categories cat ON cat.id = ec.category_id
  WHERE e.company_id = p_company_id AND e.status = 'ativo' AND e.data_fim >= NOW()
  GROUP BY e.id, c.nome_fantasia, c.logo_url, c.average_rating
  ORDER BY e.data_inicio ASC
  LIMIT p_limit OFFSET p_offset;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_company_events(uuid, integer, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_company_events(uuid, integer, integer) TO anon;

-- ============================================
-- RPC: Eventos por lista de IDs
-- ============================================
CREATE OR REPLACE FUNCTION public.get_events_by_ids(
  p_ids uuid[]
)
RETURNS TABLE (
  id uuid,
  company_id uuid,
  titulo varchar(200),
  descricao text,
  endereco varchar(200),
  data_inicio timestamptz,
  data_fim timestamptz,
  valor numeric(10,2),
  is_gratuito boolean,
  capacidade integer,
  capacidade_atual integer,
  idade_minima integer,
  foto_principal_url text,
  link_externo text,
  link_streaming text,
  status event_status,
  is_online boolean,
  is_presencial boolean,
  requires_approval boolean,
  total_views integer,
  total_interested integer,
  total_confirmed integer,
  total_attended integer,
  average_rating numeric(3,2),
  total_reviews integer,
  created_at timestamptz,
  updated_at timestamptz,
  latitude double precision,
  longitude double precision,
  empresa_nome text,
  empresa_logo text,
  empresa_rating numeric(3,2),
  categorias text[]
)
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    e.id,
    e.company_id,
    e.titulo,
    e.descricao,
    e.endereco,
    e.data_inicio,
    e.data_fim,
    e.valor,
    e.is_gratuito,
    e.capacidade,
    e.capacidade_atual,
    e.idade_minima,
    e.foto_principal_url,
    e.link_externo,
    e.link_streaming,
    e.status,
    e.is_online,
    e.is_presencial,
    e.requires_approval,
    e.total_views,
    e.total_interested,
    e.total_confirmed,
    e.total_attended,
    e.average_rating,
    e.total_reviews,
    e.created_at,
    e.updated_at,
    ST_Y(e.location::geometry) as latitude,
    ST_X(e.location::geometry) as longitude,
    c.nome_fantasia::text as empresa_nome,
    c.logo_url::text as empresa_logo,
    c.average_rating as empresa_rating,
    COALESCE(array_agg(cat.nome::text ORDER BY cat.nome) FILTER (WHERE cat.nome IS NOT NULL), ARRAY[]::text[]) as categorias
  FROM events e
  JOIN companies c ON c.id = e.company_id
  LEFT JOIN event_categories ec ON ec.event_id = e.id
  LEFT JOIN categories cat ON cat.id = ec.category_id
  WHERE e.id = ANY(p_ids) AND e.status = 'ativo' AND e.data_fim >= NOW()
  GROUP BY e.id, c.nome_fantasia, c.logo_url, c.average_rating
  ORDER BY e.data_inicio DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_events_by_ids(uuid[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_events_by_ids(uuid[]) TO anon;