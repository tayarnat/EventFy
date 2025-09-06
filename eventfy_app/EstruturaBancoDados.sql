-- ============================================
-- SCHEMA COMPLETO - MAPA DE EVENTOS
-- ============================================

-- Extensões necessárias
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS postgis; -- Para coordenadas geográficas

-- ============================================
-- TABELAS PRINCIPAIS
-- ============================================

-- Tipos de usuário (ENUM)
CREATE TYPE user_type AS ENUM ('user', 'company');
CREATE TYPE gender_type AS ENUM ('masculino', 'feminino', 'outro', 'nao_informar');
CREATE TYPE event_status AS ENUM ('ativo', 'cancelado', 'finalizado', 'rascunho');
CREATE TYPE attendance_status AS ENUM ('interessado', 'confirmado', 'compareceu', 'nao_compareceu');

-- ============================================
-- USUÁRIOS BASE
-- ============================================
CREATE TABLE users_base (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email VARCHAR(150) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL, -- hash da senha
  user_type user_type NOT NULL,
  is_active BOOLEAN DEFAULT TRUE,
  email_verified BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  last_login TIMESTAMP WITH TIME ZONE
);

-- ============================================
-- USUÁRIOS PESSOA FÍSICA
-- ============================================
CREATE TABLE users (
  id UUID PRIMARY KEY REFERENCES users_base(id) ON DELETE CASCADE,
  nome VARCHAR(150) NOT NULL,
  telefone VARCHAR(20),
  endereco VARCHAR(200),
  data_nascimento DATE,
  cpf VARCHAR(11) UNIQUE,
  genero gender_type,
  range_distancia INTEGER DEFAULT 10000, -- em metros
  avatar_url TEXT,
  -- Coordenadas geográficas
  location GEOGRAPHY(POINT, 4326), -- PostGIS para coordenadas
  -- Configurações de privacidade
  profile_public BOOLEAN DEFAULT TRUE,
  location_sharing BOOLEAN DEFAULT TRUE,
  -- Estatísticas do usuário
  total_events_attended INTEGER DEFAULT 0,
  total_reviews INTEGER DEFAULT 0,
  average_rating_given DECIMAL(3,2) DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- EMPRESAS
-- ============================================
CREATE TABLE companies (
  id UUID PRIMARY KEY REFERENCES users_base(id) ON DELETE CASCADE,
  cnpj VARCHAR(14) UNIQUE NOT NULL,
  nome_fantasia VARCHAR(150) NOT NULL,
  razao_social VARCHAR(150),
  telefone VARCHAR(20),
  endereco VARCHAR(200),
  location GEOGRAPHY(POINT, 4326), -- Localização da empresa
  logo_url TEXT,
  website TEXT,
  instagram VARCHAR(100),
  facebook VARCHAR(100),
  -- Dados do responsável
  responsavel_nome VARCHAR(150),
  responsavel_cpf VARCHAR(11),
  responsavel_telefone VARCHAR(20),
  responsavel_email VARCHAR(150),
  -- Status da empresa
  verificada BOOLEAN DEFAULT FALSE,
  verificada_em TIMESTAMP WITH TIME ZONE,
  -- Estatísticas da empresa
  total_events_created INTEGER DEFAULT 0,
  average_rating DECIMAL(3,2) DEFAULT 0,
  total_followers INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- CATEGORIAS/TAGS
-- ============================================
CREATE TABLE categories (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  codigo_interno VARCHAR(50) UNIQUE NOT NULL,
  nome VARCHAR(100) NOT NULL,
  descricao TEXT,
  cor_hex VARCHAR(7), -- #FF5733
  icone VARCHAR(50), -- nome do ícone
  categoria_pai UUID REFERENCES categories(id), -- para subcategorias
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- EVENTOS
-- ============================================
CREATE TABLE events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  titulo VARCHAR(200) NOT NULL,
  descricao TEXT,
  endereco VARCHAR(200) NOT NULL,
  location GEOGRAPHY(POINT, 4326) NOT NULL, -- Coordenadas do evento
  data_inicio TIMESTAMP WITH TIME ZONE NOT NULL,
  data_fim TIMESTAMP WITH TIME ZONE NOT NULL,
  valor DECIMAL(10,2) DEFAULT 0,
  is_gratuito BOOLEAN DEFAULT TRUE,
  capacidade INTEGER,
  capacidade_atual INTEGER DEFAULT 0,
  idade_minima INTEGER DEFAULT 0,
  -- URLs e mídias
  foto_principal_url TEXT,
  link_externo TEXT, -- link para compra de ingressos
  link_streaming TEXT, -- para eventos online/híbridos
  -- Status e configurações
  status event_status DEFAULT 'ativo',
  is_online BOOLEAN DEFAULT FALSE,
  is_presencial BOOLEAN DEFAULT TRUE,
  requires_approval BOOLEAN DEFAULT FALSE, -- empresa precisa aprovar presença
  -- Estatísticas do evento
  total_views INTEGER DEFAULT 0,
  total_interested INTEGER DEFAULT 0,
  total_confirmed INTEGER DEFAULT 0,
  total_attended INTEGER DEFAULT 0,
  average_rating DECIMAL(3,2) DEFAULT 0,
  total_reviews INTEGER DEFAULT 0,
  -- Metadados
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- TABELAS RELACIONAIS
-- ============================================

-- Evento-Categoria (Many-to-Many)
CREATE TABLE event_categories (
  event_id UUID REFERENCES events(id) ON DELETE CASCADE,
  category_id UUID REFERENCES categories(id) ON DELETE CASCADE,
  PRIMARY KEY (event_id, category_id)
);

-- Preferências do usuário por categoria
CREATE TABLE user_preferences (
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  category_id UUID REFERENCES categories(id) ON DELETE CASCADE,
  preference_score DECIMAL(3,2) DEFAULT 0.5, -- 0.0 a 1.0
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  PRIMARY KEY (user_id, category_id)
);

-- Usuários seguindo empresas
CREATE TABLE user_company_follows (
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
  notification_enabled BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  PRIMARY KEY (user_id, company_id)
);

-- Presença/Interesse em eventos
CREATE TABLE event_attendances (
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  event_id UUID REFERENCES events(id) ON DELETE CASCADE,
  status attendance_status DEFAULT 'interessado',
  approved_by_company BOOLEAN DEFAULT NULL, -- null se não precisa aprovação
  checked_in_at TIMESTAMP WITH TIME ZONE, -- quando fez check-in no evento
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  PRIMARY KEY (user_id, event_id)
);

-- Eventos favoritados
CREATE TABLE user_favorite_events (
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  event_id UUID REFERENCES events(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  PRIMARY KEY (user_id, event_id)
);

-- Empresas favoritadas
CREATE TABLE user_favorite_companies (
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  PRIMARY KEY (user_id, company_id)
);

-- ============================================
-- AVALIAÇÕES E COMENTÁRIOS
-- ============================================

-- Avaliações de eventos
CREATE TABLE event_reviews (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  rating INTEGER CHECK (rating >= 1 AND rating <= 5),
  titulo VARCHAR(150),
  comentario TEXT,
  is_anonymous BOOLEAN DEFAULT FALSE,
  helpful_votes INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, event_id)
);

-- Comentários em eventos (diferentes de avaliações)
CREATE TABLE event_comments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  parent_comment_id UUID REFERENCES event_comments(id), -- para respostas
  comentario TEXT NOT NULL,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- SISTEMA DE INTERAÇÕES (PARA IA/ML)
-- ============================================
CREATE TABLE user_interactions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  event_id UUID REFERENCES events(id) ON DELETE CASCADE,
  company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
  interaction_type VARCHAR(50) NOT NULL, -- 'view', 'like', 'share', 'search', 'filter'
  interaction_duration INTEGER, -- tempo em segundos (para views)
  interaction_value DECIMAL(3,2), -- score da interação (0-1)
  device_info JSONB, -- informações do dispositivo
  location_at_interaction GEOGRAPHY(POINT, 4326), -- onde estava quando interagiu
  metadata JSONB, -- dados adicionais específicos da interação
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- NOTIFICAÇÕES
-- ============================================
CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  titulo VARCHAR(150) NOT NULL,
  mensagem TEXT NOT NULL,
  tipo VARCHAR(50) NOT NULL, -- 'event_reminder', 'new_event', 'recommendation', 'company_update'
  related_event_id UUID REFERENCES events(id),
  related_company_id UUID REFERENCES companies(id),
  is_read BOOLEAN DEFAULT FALSE,
  sent_at TIMESTAMP WITH TIME ZONE,
  expires_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- MÍDIA E ARQUIVOS
-- ============================================
CREATE TABLE event_media (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  tipo VARCHAR(20) NOT NULL, -- 'image', 'video'
  url TEXT NOT NULL,
  is_main BOOLEAN DEFAULT FALSE, -- foto principal
  ordem INTEGER DEFAULT 0,
  alt_text VARCHAR(200),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- SISTEMA DE BUSCA E FILTROS
-- ============================================
CREATE TABLE user_searches (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  search_query VARCHAR(200),
  filters_applied JSONB, -- filtros usados na busca
  results_count INTEGER,
  location_searched GEOGRAPHY(POINT, 4326),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- ÍNDICES PARA PERFORMANCE
-- ============================================

-- Índices geográficos
CREATE INDEX idx_events_location ON events USING GIST (location);
CREATE INDEX idx_users_location ON users USING GIST (location);
CREATE INDEX idx_companies_location ON companies USING GIST (location);

-- Índices temporais
CREATE INDEX idx_events_data_inicio ON events (data_inicio);
CREATE INDEX idx_events_data_fim ON events (data_fim);
CREATE INDEX idx_events_status ON events (status);

-- Índices para relacionamentos
CREATE INDEX idx_events_company ON events (company_id);
CREATE INDEX idx_user_interactions_user ON user_interactions (user_id);
CREATE INDEX idx_user_interactions_event ON user_interactions (event_id);
CREATE INDEX idx_user_interactions_type ON user_interactions (interaction_type);
CREATE INDEX idx_notifications_user_unread ON notifications (user_id, is_read);

-- Índices compostos para queries complexas
CREATE INDEX idx_events_active_future ON events (data_inicio, status) WHERE status = 'ativo';
CREATE INDEX idx_events_location_active ON events USING GIST (location) WHERE status = 'ativo';
CREATE INDEX idx_user_interactions_ml ON user_interactions (user_id, interaction_type, created_at);

-- ============================================
-- TRIGGERS E FUNÇÕES
-- ============================================

-- Função para atualizar timestamps
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers para updated_at
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_companies_updated_at BEFORE UPDATE ON companies FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_events_updated_at BEFORE UPDATE ON events FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Função para atualizar estatísticas de empresa
CREATE OR REPLACE FUNCTION update_company_stats()
RETURNS TRIGGER AS $$
BEGIN
    -- Atualizar total de eventos
    UPDATE companies SET 
        total_events_created = (
            SELECT COUNT(*) FROM events WHERE company_id = NEW.company_id
        ),
        -- Atualizar rating médio baseado nas avaliações dos eventos
        average_rating = (
            SELECT COALESCE(AVG(er.rating), 0)
            FROM event_reviews er
            JOIN events e ON er.event_id = e.id
            WHERE e.company_id = NEW.company_id
        )
    WHERE id = NEW.company_id;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger para atualizar stats da empresa quando evento é avaliado
CREATE TRIGGER update_company_stats_on_review 
    AFTER INSERT OR UPDATE OR DELETE ON event_reviews 
    FOR EACH ROW EXECUTE FUNCTION update_company_stats();

-- Função para atualizar capacidade atual do evento
CREATE OR REPLACE FUNCTION update_event_capacity()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE events SET 
        capacidade_atual = (
            SELECT COUNT(*) 
            FROM event_attendances 
            WHERE event_id = COALESCE(NEW.event_id, OLD.event_id) 
            AND status IN ('confirmado', 'compareceu')
        )
    WHERE id = COALESCE(NEW.event_id, OLD.event_id);
    RETURN COALESCE(NEW, OLD);
END;
$$ language 'plpgsql';

-- Trigger para atualizar capacidade
CREATE TRIGGER update_event_capacity_trigger
    AFTER INSERT OR UPDATE OR DELETE ON event_attendances
    FOR EACH ROW EXECUTE FUNCTION update_event_capacity();

-- ============================================
-- VIEWS ÚTEIS
-- ============================================

-- View para eventos com informações completas
CREATE VIEW events_complete AS
SELECT 
    e.*,
    c.nome_fantasia as empresa_nome,
    c.logo_url as empresa_logo,
    c.average_rating as empresa_rating,
    -- Agregação das categorias
    array_agg(cat.nome) as categorias,
    -- Distância será calculada dinamicamente na aplicação
    ST_X(e.location::geometry) as longitude,
    ST_Y(e.location::geometry) as latitude
FROM events e
JOIN companies c ON e.company_id = c.id
LEFT JOIN event_categories ec ON e.id = ec.event_id
LEFT JOIN categories cat ON ec.category_id = cat.id
WHERE e.status = 'ativo'
GROUP BY e.id, c.nome_fantasia, c.logo_url, c.average_rating;

-- View para perfil completo do usuário
CREATE VIEW user_profile_complete AS
SELECT 
    u.*,
    ub.email,
    ub.created_at as account_created_at,
    ST_X(u.location::geometry) as longitude,
    ST_Y(u.location::geometry) as latitude,
    -- Estatísticas de preferências
    array_agg(DISTINCT cat.nome) as preferred_categories
FROM users u
JOIN users_base ub ON u.id = ub.id
LEFT JOIN user_preferences up ON u.id = up.user_id
LEFT JOIN categories cat ON up.category_id = cat.id AND up.preference_score > 0.6
GROUP BY u.id, ub.email, ub.created_at;

-- ============================================
-- DADOS INICIAIS
-- ============================================

-- Inserir categorias principais
INSERT INTO categories (codigo_interno, nome, descricao, cor_hex) VALUES
('musica', 'Música', 'Eventos musicais de todos os gêneros', '#FF6B6B'),
('gastronomia', 'Gastronomia', 'Eventos gastronômicos e culinários', '#4ECDC4'),
('esporte', 'Esporte', 'Eventos esportivos e atividades físicas', '#45B7D1'),
('cultura', 'Cultura', 'Eventos culturais, arte e entretenimento', '#96CEB4'),
('negocios', 'Negócios', 'Eventos corporativos e networking', '#FECA57'),
('tecnologia', 'Tecnologia', 'Eventos de tecnologia e inovação', '#FF9FF3'),
('educacao', 'Educação', 'Cursos, palestras e workshops', '#54A0FF'),
('vida_noturna', 'Vida Noturna', 'Bares, baladas e eventos noturnos', '#5F27CD'),
('familia', 'Família', 'Eventos para toda a família', '#00D2D3'),
('saude', 'Saúde e Bem-estar', 'Eventos relacionados à saúde', '#FF6348');

-- ============================================
-- FUNÇÕES PARA RECOMENDAÇÕES
-- ============================================

-- Função para calcular distância entre pontos
CREATE OR REPLACE FUNCTION calculate_distance(
    user_location GEOGRAPHY,
    event_location GEOGRAPHY
) RETURNS INTEGER AS $$
BEGIN
    RETURN ST_Distance(user_location, event_location)::INTEGER;
END;
$$ LANGUAGE plpgsql;

-- Função para buscar eventos próximos e futuros
CREATE OR REPLACE FUNCTION get_nearby_events(
    user_lat DECIMAL,
    user_lng DECIMAL,
    radius_meters INTEGER DEFAULT 10000,
    limit_count INTEGER DEFAULT 20
)
RETURNS TABLE (
    event_id UUID,
    titulo VARCHAR,
    distance_meters INTEGER,
    data_inicio TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        e.id,
        e.titulo,
        ST_Distance(
            ST_SetSRID(ST_MakePoint(user_lng, user_lat), 4326)::geography,
            e.location
        )::INTEGER as distance_meters,
        e.data_inicio
    FROM events e
    WHERE e.status = 'ativo'
    AND e.data_inicio > CURRENT_TIMESTAMP
    AND ST_DWithin(
        ST_SetSRID(ST_MakePoint(user_lng, user_lat), 4326)::geography,
        e.location,
        radius_meters
    )
    ORDER BY distance_meters, e.data_inicio
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- POLÍTICAS RLS (ROW LEVEL SECURITY)
-- ============================================

-- Habilitar RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE companies ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_interactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Políticas básicas (ajustar conforme autenticação)
CREATE POLICY "Users can view own data" ON users FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update own data" ON users FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Companies can view own data" ON companies FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Companies can update own data" ON companies FOR UPDATE USING (auth.uid() = id);

-- Eventos são públicos para leitura, mas só empresa dona pode editar
CREATE POLICY "Events are publicly readable" ON events FOR SELECT USING (true);
CREATE POLICY "Companies can manage their events" ON events 
    FOR ALL USING (company_id IN (SELECT id FROM companies WHERE id = auth.uid()));

-- ALTER TABLE EXECUTADO POSTERIORMENTE 01

-- Política para permitir inserção de dados na tabela users durante o registro
CREATE POLICY "Allow service role to insert user data" 
ON users 
FOR INSERT 
TO authenticated, anon 
WITH CHECK (true);

-- Política para permitir inserção de dados na tabela companies durante o registro
CREATE POLICY "Allow service role to insert company data" 
ON companies 
FOR INSERT 
TO authenticated, anon 
WITH CHECK (true);


-- ============================================
-- COMENTÁRIOS E OBSERVAÇÕES
-- ============================================

/*
MELHORIAS IMPLEMENTADAS:

1. **Herança corrigida**: users_base como tabela principal, users e companies herdam dela
2. **Geolocalização com PostGIS**: Coordenadas geográficas adequadas com funções nativas
3. **Estatísticas automáticas**: Triggers que mantém contadores atualizados
4. **Sistema de notificações completo**: Com tipos, expiração e status de leitura
5. **Mídia dos eventos**: Tabela separada para múltiplas fotos/vídeos
6. **Sistema de busca**: Histórico de buscas para melhorar recomendações
7. **Interações detalhadas**: Para alimentar algoritmos de ML
8. **Views otimizadas**: Consultas complexas pré-definidas
9. **Funções úteis**: Para cálculos geográficos e buscas
10. **Segurança**: RLS básico implementado

PRÓXIMOS PASSOS:
- Implementar autenticação (Supabase Auth)
- Criar API Python para recomendações ML
- Configurar integração com mapas no Flutter
- Implementar sistema de notificações push
*/