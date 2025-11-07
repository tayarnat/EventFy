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

-- ============================================
-- RPC: Relatório por período para empresa
-- ============================================
CREATE OR REPLACE FUNCTION public.get_company_period_report(
  p_company_id uuid,
  p_start timestamptz,
  p_end timestamptz
)
RETURNS TABLE (
  total_events integer,
  events_active integer,
  events_finalized integer,
  events_cancelled integer,
  total_confirmed integer,
  total_attended integer,
  average_rating numeric(3,2),
  total_reviews integer
)
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  -- Restrição: só a própria empresa (usuário autenticado) pode consultar
  IF p_company_id <> auth.uid() THEN
    RAISE EXCEPTION 'permission denied' USING ERRCODE = '28000';
  END IF;
  RETURN QUERY
  WITH events_in_period AS (
    SELECT e.*
    FROM events e
    WHERE e.company_id = p_company_id
      AND e.data_inicio >= p_start
      AND e.data_inicio <= p_end
  )
  SELECT
    -- Total de eventos no período
    (SELECT COUNT(*) FROM events_in_period)::integer AS total_events,
    -- Contagem por status
    (SELECT COUNT(*) FROM events_in_period WHERE status = 'ativo')::integer AS events_active,
    (SELECT COUNT(*) FROM events_in_period WHERE status = 'finalizado')::integer AS events_finalized,
    (SELECT COUNT(*) FROM events_in_period WHERE status = 'cancelado')::integer AS events_cancelled,
    -- Confirmados e compareceram no período (considerando data do evento)
    COALESCE((
      SELECT COUNT(*)
      FROM event_attendances ea
      JOIN events_in_period e ON e.id = ea.event_id
      WHERE ea.status = 'confirmado'
    ), 0)::integer AS total_confirmed,
    COALESCE((
      SELECT COUNT(*)
      FROM event_attendances ea
      JOIN events_in_period e ON e.id = ea.event_id
      WHERE ea.status = 'compareceu'
    ), 0)::integer AS total_attended,
    -- Média e total de avaliações no período (considerando data de criação da avaliação)
    COALESCE((
      SELECT AVG(er.rating)
      FROM event_reviews er
      JOIN events e ON e.id = er.event_id
      WHERE e.company_id = p_company_id
        AND er.created_at >= p_start AND er.created_at <= p_end
    ), 0)::numeric(3,2) AS average_rating,
    COALESCE((
      SELECT COUNT(*)
      FROM event_reviews er
      JOIN events e ON e.id = er.event_id
      WHERE e.company_id = p_company_id
        AND er.created_at >= p_start AND er.created_at <= p_end
    ), 0)::integer AS total_reviews;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_company_period_report(uuid, timestamptz, timestamptz) TO authenticated;

-- ============================================
-- RPC: Estatísticas mensais (últimos N meses) para empresa
-- ============================================
CREATE OR REPLACE FUNCTION public.get_company_monthly_stats(
  p_company_id uuid,
  p_months integer DEFAULT 6
)
RETURNS TABLE (
  month_start timestamptz,
  month_label text,
  events_count integer,
  confirmed_count integer,
  attended_count integer,
  reviews_count integer,
  average_rating numeric(3,2)
)
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  -- Restrição: só a própria empresa (usuário autenticado) pode consultar
  IF p_company_id <> auth.uid() THEN
    RAISE EXCEPTION 'permission denied' USING ERRCODE = '28000';
  END IF;
  RETURN QUERY
  WITH months AS (
    SELECT date_trunc('month', NOW()) - (make_interval(months => s)) AS month_start
    FROM generate_series(0, GREATEST(p_months, 1) - 1) AS s
  ),
  events_in_month AS (
    SELECT m.month_start,
           COUNT(*) AS events_count
    FROM months m
    LEFT JOIN events e
      ON e.company_id = p_company_id
     AND e.data_inicio >= m.month_start
     AND e.data_inicio < (m.month_start + INTERVAL '1 month')
    GROUP BY m.month_start
  ),
  confirmed_in_month AS (
    SELECT m.month_start,
           COUNT(ea.*) AS confirmed_count
    FROM months m
    LEFT JOIN events e
      ON e.company_id = p_company_id
     AND e.data_inicio >= m.month_start
     AND e.data_inicio < (m.month_start + INTERVAL '1 month')
    LEFT JOIN event_attendances ea ON ea.event_id = e.id AND ea.status = 'confirmado'
    GROUP BY m.month_start
  ),
  attended_in_month AS (
    SELECT m.month_start,
           COUNT(ea.*) AS attended_count
    FROM months m
    LEFT JOIN events e
      ON e.company_id = p_company_id
     AND e.data_inicio >= m.month_start
     AND e.data_inicio < (m.month_start + INTERVAL '1 month')
    LEFT JOIN event_attendances ea ON ea.event_id = e.id AND ea.status = 'compareceu'
    GROUP BY m.month_start
  ),
  reviews_in_month AS (
    SELECT m.month_start,
           COUNT(er.*) FILTER (WHERE e.id IS NOT NULL) AS reviews_count,
           COALESCE(AVG(er.rating) FILTER (WHERE e.id IS NOT NULL), 0) AS average_rating
    FROM months m
    LEFT JOIN event_reviews er
      ON er.created_at >= m.month_start
     AND er.created_at < (m.month_start + INTERVAL '1 month')
    LEFT JOIN events e ON e.id = er.event_id AND e.company_id = p_company_id
    GROUP BY m.month_start
  )
  SELECT 
    m.month_start,
    to_char(m.month_start, 'YYYY-MM') AS month_label,
    COALESCE(eim.events_count, 0)::integer AS events_count,
    COALESCE(cm.confirmed_count, 0)::integer AS confirmed_count,
    COALESCE(am.attended_count, 0)::integer AS attended_count,
    COALESCE(rm.reviews_count, 0)::integer AS reviews_count,
    COALESCE(rm.average_rating, 0)::numeric(3,2) AS average_rating
  FROM months m
  LEFT JOIN events_in_month eim ON eim.month_start = m.month_start
  LEFT JOIN confirmed_in_month cm ON cm.month_start = m.month_start
  LEFT JOIN attended_in_month am ON am.month_start = m.month_start
  LEFT JOIN reviews_in_month rm ON rm.month_start = m.month_start
  ORDER BY m.month_start ASC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_company_monthly_stats(uuid, integer) TO authenticated;

-- Monthly progress (cumulative) for a company
-- Ensure no ambiguous overload remains (removes legacy 3-arg version)
DROP FUNCTION IF EXISTS public.get_company_monthly_progress(uuid, integer, boolean);
CREATE OR REPLACE FUNCTION public.get_company_monthly_progress(
  p_company_id uuid,
  p_start_month timestamptz DEFAULT NULL,
  p_end_month timestamptz DEFAULT NULL,
  p_months integer DEFAULT 6,
  p_from_first_event boolean DEFAULT true
)
RETURNS TABLE (
  month_start timestamptz,
  month_label text,
  events_month integer,
  events_prev_month integer,
  events_delta integer,
  events_cumulative integer,
  confirmed_month integer,
  confirmed_prev_month integer,
  confirmed_delta integer,
  confirmed_cumulative integer,
  attended_month integer,
  attended_prev_month integer,
  attended_delta integer,
  attended_cumulative integer,
  reviews_month integer,
  reviews_prev_month integer,
  reviews_delta integer,
  reviews_cumulative integer,
  average_rating_month numeric(3,2),
  average_rating_prev numeric(3,2),
  average_rating_delta numeric(3,2)
)
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  -- Restrição: só a própria empresa (usuário autenticado) pode consultar
  IF p_company_id <> auth.uid() THEN
    RAISE EXCEPTION 'permission denied' USING ERRCODE = '28000';
  END IF;
  RETURN QUERY
  WITH first_event AS (
    SELECT date_trunc('month', MIN(e.data_inicio)) AS first_month
    FROM events e
    WHERE e.company_id = p_company_id
  ),
  start_end AS (
    SELECT 
      CASE 
        WHEN p_start_month IS NOT NULL THEN date_trunc('month', p_start_month)
        WHEN p_from_first_event AND fe.first_month IS NOT NULL THEN fe.first_month
        ELSE date_trunc('month', NOW()) - (INTERVAL '1 month' * (GREATEST(p_months, 1) - 1))
      END AS start_month,
      CASE
        WHEN p_end_month IS NOT NULL THEN date_trunc('month', p_end_month)
        ELSE date_trunc('month', NOW())
      END AS end_month
    FROM first_event fe
  ),
  months AS (
    SELECT date_trunc('month', g) AS month_start
    FROM start_end se,
         generate_series(se.start_month, se.end_month, INTERVAL '1 month') AS g
  ),
  events_in_month AS (
    SELECT m.month_start,
           COUNT(*) AS events_count
    FROM months m
    LEFT JOIN events e
      ON e.company_id = p_company_id
     AND e.data_inicio >= m.month_start
     AND e.data_inicio < (m.month_start + INTERVAL '1 month')
    GROUP BY m.month_start
  ),
  confirmed_in_month AS (
    SELECT m.month_start,
           COUNT(ea.*) AS confirmed_count
    FROM months m
    LEFT JOIN events e
      ON e.company_id = p_company_id
     AND e.data_inicio >= m.month_start
     AND e.data_inicio < (m.month_start + INTERVAL '1 month')
    LEFT JOIN event_attendances ea ON ea.event_id = e.id AND ea.status = 'confirmado'
    GROUP BY m.month_start
  ),
  attended_in_month AS (
    SELECT m.month_start,
           COUNT(ea.*) AS attended_count
    FROM months m
    LEFT JOIN events e
      ON e.company_id = p_company_id
     AND e.data_inicio >= m.month_start
     AND e.data_inicio < (m.month_start + INTERVAL '1 month')
    LEFT JOIN event_attendances ea ON ea.event_id = e.id AND ea.status = 'compareceu'
    GROUP BY m.month_start
  ),
  reviews_in_month AS (
    SELECT m.month_start,
           COUNT(er.*) FILTER (WHERE e.id IS NOT NULL) AS reviews_count,
           COALESCE(AVG(er.rating) FILTER (WHERE e.id IS NOT NULL), 0) AS average_rating
    FROM months m
    LEFT JOIN event_reviews er
      ON er.created_at >= m.month_start
     AND er.created_at < (m.month_start + INTERVAL '1 month')
    LEFT JOIN events e ON e.id = er.event_id AND e.company_id = p_company_id
    GROUP BY m.month_start
  ),
  aggregated AS (
    SELECT m.month_start,
           COALESCE(eim.events_count, 0)::integer AS events_month,
           COALESCE(cm.confirmed_count, 0)::integer AS confirmed_month,
           COALESCE(am.attended_count, 0)::integer AS attended_month,
           COALESCE(rm.reviews_count, 0)::integer AS reviews_month,
           COALESCE(rm.average_rating, 0)::numeric(3,2) AS average_rating_month
    FROM months m
    LEFT JOIN events_in_month eim ON eim.month_start = m.month_start
    LEFT JOIN confirmed_in_month cm ON cm.month_start = m.month_start
    LEFT JOIN attended_in_month am ON am.month_start = m.month_start
    LEFT JOIN reviews_in_month rm ON rm.month_start = m.month_start
  )
  SELECT 
    a.month_start,
    to_char(a.month_start, 'YYYY-MM') AS month_label,
    a.events_month,
    LAG(a.events_month) OVER (ORDER BY a.month_start ASC) AS events_prev_month,
    (a.events_month - COALESCE(LAG(a.events_month) OVER (ORDER BY a.month_start ASC), 0))::integer AS events_delta,
    (SUM(a.events_month) OVER (ORDER BY a.month_start ASC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW))::integer AS events_cumulative,
    a.confirmed_month,
    LAG(a.confirmed_month) OVER (ORDER BY a.month_start ASC) AS confirmed_prev_month,
    (a.confirmed_month - COALESCE(LAG(a.confirmed_month) OVER (ORDER BY a.month_start ASC), 0))::integer AS confirmed_delta,
    (SUM(a.confirmed_month) OVER (ORDER BY a.month_start ASC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW))::integer AS confirmed_cumulative,
    a.attended_month,
    LAG(a.attended_month) OVER (ORDER BY a.month_start ASC) AS attended_prev_month,
    (a.attended_month - COALESCE(LAG(a.attended_month) OVER (ORDER BY a.month_start ASC), 0))::integer AS attended_delta,
    (SUM(a.attended_month) OVER (ORDER BY a.month_start ASC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW))::integer AS attended_cumulative,
    a.reviews_month,
    LAG(a.reviews_month) OVER (ORDER BY a.month_start ASC) AS reviews_prev_month,
    (a.reviews_month - COALESCE(LAG(a.reviews_month) OVER (ORDER BY a.month_start ASC), 0))::integer AS reviews_delta,
    (SUM(a.reviews_month) OVER (ORDER BY a.month_start ASC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW))::integer AS reviews_cumulative,
    a.average_rating_month,
    LAG(a.average_rating_month) OVER (ORDER BY a.month_start ASC) AS average_rating_prev,
    (a.average_rating_month - COALESCE(LAG(a.average_rating_month) OVER (ORDER BY a.month_start ASC), 0))::numeric(3,2) AS average_rating_delta
  FROM aggregated a
  ORDER BY a.month_start ASC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_company_monthly_progress(uuid, timestamptz, timestamptz, integer, boolean) TO authenticated;