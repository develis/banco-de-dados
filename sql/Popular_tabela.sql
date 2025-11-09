-- Limpa as tabelas na ordem correta para evitar conflitos de FK
-- CASCADE remove os registros dependentes (Pagamento/Certificado dependem de Inscricao, etc.)
TRUNCATE TABLE TB_Pagamento, TB_Certificado, TB_Inscricao, TB_Registro, TB_Usuario RESTART IDENTITY CASCADE;

-- Usamos um bloco anônimo (DO) para declarar variáveis e executar a lógica
DO $$
DECLARE
    -- Variáveis para guardar os IDs dos eventos principais
    v_evento_id_1 INT;
    v_evento_id_2 INT;
    
    -- Arrays para guardar os IDs das atividades de cada evento
    v_atividades_e1 INT[];
    v_atividades_e2 INT[];
BEGIN

    -- 1. POPULAR TB_Usuario (5.000 REGISTROS)
    -- -----------------------------------------------------------------
    INSERT INTO TB_Usuario (
        CD_CPF, 
        DS_Email, 
        DS_Nome, 
        DS_Instituicao, 
        DS_Escolaridade
    )
    SELECT
        LPAD(s::text, 11, '0'), -- Gera CPFs únicos (ex: '00000000001')
        'usuario' || s || '@exemplo.com', -- Gera emails únicos
        'Nome Completo do Usuário ' || s,
        -- Distribui usuários entre 4 instituições/escolaridades
        (ARRAY['Universidade Federal da Bahia', 'Instituto Federal da Bahia', 'Universidade Católica', 'Universidade Estuadual da Bahia'])[1 + (s % 4)],
        (ARRAY['Superior Incompleto', 'Superior Completo', 'Mestrado', 'Doutorado'])[1 + (s % 4)]
    FROM generate_series(1, 5000) s; -- Gera 5.000 linhas


    -- 2. POPULAR TB_Registro (Eventos e Atividades)
    -- -----------------------------------------------------------------
    
    -- Inserir Eventos Principais PRIMEIRO (ID_EventoPai = NULL)
    INSERT INTO TB_Registro (ID_EventoPai, TP_Registro, DS_Titulo, DS_Descricao, DS_Local, DH_Inicio, DH_Fim, TP_Area, ST_Submissao)
    VALUES (NULL, 'Evento', 'Congresso de Tecnologia 2025', 'Evento principal sobre inovação e TI.', 'Centro de Convenções A', '2025-10-20 09:00:00', '2025-10-22 18:00:00', 'TI', 'Fechado')
    RETURNING ID_Registro INTO v_evento_id_1; -- Salva o ID gerado

    INSERT INTO TB_Registro (ID_EventoPai, TP_Registro, DS_Titulo, DS_Descricao, DS_Local, DH_Inicio, DH_Fim, TP_Area, ST_Submissao)
    VALUES (NULL, 'Evento', 'Semana Acadêmica de IA', 'Evento focado em Inteligência Artificial e Machine Learning.', 'Auditório Principal Reitoria', '2025-11-05 08:00:00', '2025-11-07 17:00:00', 'IA', 'Aberto')
    RETURNING ID_Registro INTO v_evento_id_2; -- Salva o ID gerado

    -- Inserir Atividades (filhas dos eventos)
    -- 10 Atividades para o Evento 1
    INSERT INTO TB_Registro (ID_EventoPai, TP_Registro, DS_Titulo, DS_Descricao, DS_Local, DH_Inicio, DH_Fim, TP_Area)
    SELECT 
        v_evento_id_1,
        'Atividade',
        'Palestra E1 - Tópico ' || s,
        'Descrição detalhada da atividade ' || s || ' do evento 1.',
        'Sala ' || (100 + s),
        '2025-10-20 10:00:00'::timestamp + (s * '1 hour'::interval),
        '2025-10-20 11:00:00'::timestamp + (s * '1 hour'::interval),
        'TI'
    FROM generate_series(1, 10) s;

    -- 10 Atividades para o Evento 2
    INSERT INTO TB_Registro (ID_EventoPai, TP_Registro, DS_Titulo, DS_Descricao, DS_Local, DH_Inicio, DH_Fim, TP_Area)
    SELECT 
        v_evento_id_2,
        'Atividade',
        'Workshop E2 - Tópico ' || s,
        'Descrição detalhada da atividade ' || s || ' do evento 2.',
        'Sala ' || (200 + s),
        '2025-11-05 09:00:00'::timestamp + (s * '2 hours'::interval),
        '2025-11-05 11:00:00'::timestamp + (s * '2 hours'::interval),
        'IA'
    FROM generate_series(1, 10) s;
    
    -- Guarda os IDs das atividades recém-criadas nos arrays
    v_atividades_e1 := ARRAY(SELECT ID_Registro FROM TB_Registro WHERE ID_EventoPai = v_evento_id_1);
    v_atividades_e2 := ARRAY(SELECT ID_Registro FROM TB_Registro WHERE ID_EventoPai = v_evento_id_2);


    -- 3. POPULAR TB_Inscricao (5.000 REGISTROS)
    -- -----------------------------------------------------------------
    -- Aqui, vamos criar 5.000 inscrições TOTAIS, respeitando a regra de negócio.
    
    -- Bloco 1: 1.500 usuários (1 a 1500) inscritos no Evento 1
    INSERT INTO TB_Inscricao (ID_Registro, ID_Usuario, DH_DataInscricao, TP_Inscricao, ST_Pagamento, VL_CustoInscricao, ST_Presente)
    SELECT 
        v_evento_id_1,
        s, -- ID_Usuario
        NOW() - (s * '1 day'::interval), -- Datas de inscrição variadas
        'Online',
        (ARRAY['Pago', 'Pendente', 'Isento'])[1 + (s % 3)],
        150.00,
        (ARRAY[true, false])[1 + (s % 2)] -- Metade presente, metade ausente
    FROM generate_series(1, 1500) s;

    -- Bloco 2: 1.000 usuários (1 a 1000) inscritos em UMA atividade do Evento 1
    -- (REGRA OK: Todos do Bloco 1 já estão no Evento 1)
    INSERT INTO TB_Inscricao (ID_Registro, ID_Usuario, DH_DataInscricao, TP_Inscricao, ST_Pagamento, VL_CustoInscricao, ST_Presente)
    SELECT 
        v_atividades_e1[1 + (s % ARRAY_LENGTH(v_atividades_e1, 1))], -- Pega uma atividade aleatória (round-robin)
        s, -- ID_Usuario
        NOW() - (s * '1 day'::interval) + '1 hour'::interval, -- 1h depois da inscrição no evento
        'Online',
        'Isento', -- Atividades geralmente são isentas se o evento é pago
        0.00,
        (ARRAY[true, false])[1 + (s % 2)]
    FROM generate_series(1, 1000) s;

    -- Bloco 3: 1.500 usuários (1501 a 3000) inscritos no Evento 2
    INSERT INTO TB_Inscricao (ID_Registro, ID_Usuario, DH_DataInscricao, TP_Inscricao, ST_Pagamento, VL_CustoInscricao, ST_Presente)
    SELECT 
        v_evento_id_2,
        s, -- ID_Usuario
        NOW() - (s * '1 day'::interval),
        'Presencial',
        (ARRAY['Pago', 'Pendente'])[1 + (s % 2)],
        200.00,
        (ARRAY[true, false, true])[1 + (s % 3)] -- 2/3 presentes
    FROM generate_series(1501, 3000) s;

    -- Bloco 4: 1.000 usuários (1501 a 2500) inscritos em UMA atividade do Evento 2
    -- (REGRA OK: Todos do Bloco 3 já estão no Evento 2)
    INSERT INTO TB_Inscricao (ID_Registro, ID_Usuario, DH_DataInscricao, TP_Inscricao, ST_Pagamento, VL_CustoInscricao, ST_Presente)
    SELECT 
        v_atividades_e2[1 + (s % ARRAY_LENGTH(v_atividades_e2, 1))],
        s, -- ID_Usuario
        NOW() - (s * '1 day'::interval) + '1 hour'::interval,
        'Presencial',
        'Isento',
        0.00,
        (ARRAY[true, false])[1 + (s % 2)]
    FROM generate_series(1501, 2500) s;
    
    -- TOTAL: 1500 (E1) + 1000 (Ativ E1) + 1500 (E2) + 1000 (Ativ E2) = 5.000 Inscrições


    -- Bloco 5 (NOVO): Criar interseção — usuários do Evento 1 também inscritos no Evento 2
    -- 400 usuários: 201..600 também no Evento 2 (sem violar UK (ID_Registro, ID_Usuario))
    INSERT INTO TB_Inscricao (ID_Registro, ID_Usuario, DH_DataInscricao, TP_Inscricao, ST_Pagamento, VL_CustoInscricao, ST_Presente)
    SELECT
        v_evento_id_2,
        s,
        NOW() - (s * '1 day'::interval) + '30 minutes'::interval,
        'Online',
        (ARRAY['Pago','Pendente'])[1 + (s % 2)],
        200.00,
        (ARRAY[true,false])[1 + (s % 2)]
    FROM generate_series(201, 600) s;

    -- Bloco 6 (NOVO): Criar interseção — usuários do Evento 2 também inscritos no Evento 1
    -- 300 usuários: 1601..1900 também no Evento 1
    INSERT INTO TB_Inscricao (ID_Registro, ID_Usuario, DH_DataInscricao, TP_Inscricao, ST_Pagamento, VL_CustoInscricao, ST_Presente)
    SELECT
        v_evento_id_1,
        s,
        NOW() - (s * '1 day'::interval) + '45 minutes'::interval,
        'Presencial',
        (ARRAY['Pago','Pendente'])[1 + (s % 2)],
        150.00,
        (ARRAY[true,false,true])[1 + (s % 3)]
    FROM generate_series(1601, 1900) s;

    -- Observação: As inserções de Pagamento (etapa 4) e Certificado (etapa 5) consideram TODAS as inscrições 'Pago' e 'ST_Presente = true',
    -- portanto os registros novos acima já serão contemplados automaticamente.


    -- 4. POPULAR TB_Pagamento
    -- -----------------------------------------------------------------
    -- Insere um pagamento para CADA inscrição que está com status 'Pago'
    INSERT INTO TB_Pagamento (
        ID_Inscricao, 
        DH_DataPagamento, 
        VL_ValorPago, 
        TP_MetodoPagamento, 
        CD_Transacao
    )
    SELECT 
        ID_Inscricao,
        DH_DataInscricao + '2 hours'::interval, -- Pagou 2h depois de inscrever
        VL_CustoInscricao,
        (ARRAY['Cartão de Crédito', 'PIX', 'Boleto'])[1 + (ID_Usuario % 3)],
        'TRX_' || MD5(ID_Inscricao::text || NOW()::text) -- Gera um código de transação
    FROM 
        TB_Inscricao
    WHERE 
        ST_Pagamento = 'Pago';


    -- 5. POPULAR TB_Certificado
    -- -----------------------------------------------------------------
    -- Gera um certificado para CADA inscrição onde ST_Presente = true
    INSERT INTO TB_Certificado (
        ID_Inscricao,
        CD_Validacao,
        DH_Emissao
    )
    SELECT
        I.ID_Inscricao,
        MD5(I.ID_Usuario::text || I.ID_Registro::text || R.DH_Fim::text), -- Gera código de validação
        R.DH_Fim + '1 day'::interval -- Emite o certificado 1 dia após o fim do registro
    FROM 
        TB_Inscricao I
    JOIN 
        TB_Registro R ON I.ID_Registro = R.ID_Registro
    WHERE 
        I.ST_Presente = true;

    RAISE NOTICE 'População de dados sintéticos concluída com sucesso!';
END $$;

-- Verifica a contagem
SELECT 'TB_Usuario' as Tabela, COUNT(*) FROM TB_Usuario
UNION ALL
SELECT 'TB_Registro', COUNT(*) FROM TB_Registro
UNION ALL
SELECT 'TB_Inscricao', COUNT(*) FROM TB_Inscricao
UNION ALL
SELECT 'TB_Pagamento', COUNT(*) FROM TB_Pagamento
UNION ALL
SELECT 'TB_Certificado', COUNT(*) FROM TB_Certificado;