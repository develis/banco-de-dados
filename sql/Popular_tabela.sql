-- SCRIPT DE POPULAÇÃO V6

TRUNCATE TABLE TB_Pagamento, TB_Certificado, TB_Inscricao, TB_Registro, TB_Usuario RESTART IDENTITY CASCADE;

DO $$
DECLARE
    -- Variáveis de LOOP
    v_user_record RECORD;
    v_activity_record RECORD;
    v_event_id INT;
    v_num_events_user INT;
    v_num_activities_user INT;
    
    -- Arrays para consulta rápida
    v_all_event_ids INT[];
BEGIN

    -- 1. POPULAR TB_Usuario (5.000 REGISTROS)
    -- -----------------------------------------------------------------
    RAISE NOTICE '1. Criando 5.000 usuários...';
    INSERT INTO TB_Usuario (
        CD_CPF, DS_Email, DS_Nome, DS_Instituicao, DS_Escolaridade
    )
    SELECT
        LPAD(s::text, 11, '0'),
        'usuario' || s || '@exemplo.com',
        'Nome ' || (ARRAY['Ana', 'Bruno', 'Carla', 'Diego', 'Elisa', 'Fábio', 'Gabriela'])[1 + floor(random() * 7)] || ' ' || (ARRAY['Silva', 'Souza', 'Pereira', 'Costa', 'Alves', 'Lima', 'Santos'])[1 + floor(random() * 7)] || ' ' || s,
        CASE 
            WHEN random() < 0.45 THEN 'Universidade Federal da Bahia'
            WHEN random() < 0.75 THEN 'Instituto Federal da Bahia'
            WHEN random() < 0.90 THEN 'Universidade Católica'
            ELSE 'Universidade Estuadual da Bahia'
        END,
        CASE 
            WHEN random() < 0.40 THEN 'Superior Incompleto'
            WHEN random() < 0.75 THEN 'Superior Completo'
            WHEN random() < 0.95 THEN 'Mestrado'
            ELSE 'Doutorado'
        END
    FROM generate_series(1, 5000) s;


    -- 2. POPULAR TB_Registro (5 Eventos e Atividades 0-10)
    -- -----------------------------------------------------------------
    RAISE NOTICE '2. Criando 5 Eventos e Atividades variáveis (0-10)...';
    
    -- AJUSTE: Coluna ST_Submissao e seus valores foram removidos daqui
    INSERT INTO TB_Registro (ID_EventoPai, TP_Registro, DS_Titulo, DS_Descricao, DS_Local, DH_Inicio, DH_Fim, TP_Area)
    VALUES 
        (NULL, 'Evento', 'Congresso de Tecnologia 2025', '...', 'Centro de Convenções A', '2025-10-20 09:00:00', '2025-10-22 18:00:00', 'TI'),
        (NULL, 'Evento', 'Semana Acadêmica de IA', '...', 'Auditório Reitoria', '2025-11-05 08:00:00', '2025-11-07 17:00:00', 'IA'),
        (NULL, 'Evento', 'Simpósio de Redes e Segurança', '...', 'Prédio de Engenharia', '2025-11-10 09:00:00', '2025-11-11 18:00:00', 'Redes'),
        (NULL, 'Evento', 'Feira de Hardware e Robótica', '...', 'Ginásio de Esportes', '2025-11-15 10:00:00', '2025-11-16 17:00:00', 'Hardware'),
        (NULL, 'Evento', 'Workshop de Lógica de Programação', '...', 'Laboratório 301', '2025-11-20 08:00:00', '2025-11-20 17:00:00', 'TI');

    v_all_event_ids := ARRAY(SELECT ID_Registro FROM TB_Registro WHERE TP_Registro = 'Evento');

    FOR v_event_id IN SELECT * FROM unnest(v_all_event_ids) LOOP
        v_num_activities_user := floor(random() * 11)::INT;
        IF v_num_activities_user > 0 THEN
            INSERT INTO TB_Registro (ID_EventoPai, TP_Registro, DS_Titulo, DS_Descricao, DS_Local, DH_Inicio, DH_Fim, TP_Area)
            SELECT 
                v_event_id, 'Atividade', 'Atividade Tópico ' || s, '...', 'Sala ' || (100 + s),
                (SELECT DH_Inicio FROM TB_Registro WHERE ID_Registro = v_event_id) + (s * '1 hour'::interval),
                (SELECT DH_Inicio FROM TB_Registro WHERE ID_Registro = v_event_id) + ((s + 1) * '1 hour'::interval),
                (SELECT TP_Area FROM TB_Registro WHERE ID_Registro = v_event_id)
            FROM generate_series(1, v_num_activities_user) s;
        END IF;
    END LOOP;


    -- 3. POPULAR TB_Inscricao (LÓGICA DINÂMICA)
    -- -----------------------------------------------------------------
    RAISE NOTICE '3. Inscrevendo usuários dinamicamente...';
    
    FOR v_user_record IN SELECT ID_Usuario FROM TB_Usuario LOOP
    
        v_num_events_user := floor(random() * 4)::INT;
        IF v_num_events_user > 0 THEN
            FOR i IN 1..v_num_events_user LOOP
                v_event_id := v_all_event_ids[1 + floor(random() * 5)];
                
                INSERT INTO TB_Inscricao (
                    ID_Registro, ID_Usuario, DH_DataInscricao, TP_Inscricao, 
                    ST_Pagamento, VL_CustoInscricao, ST_Presente
                )
                VALUES (
                    v_event_id, v_user_record.ID_Usuario, NOW() - (random()*30 + 1) * '1 day'::interval, 
                    (ARRAY['Online', 'Presencial'])[1 + floor(random()*2)],
                    CASE WHEN random() < 0.6 THEN 'Pago' WHEN random() < 0.85 THEN 'Pendente' ELSE 'Isento' END,
                    100 + (random()*100),
                    random() < 0.65
                )
                ON CONFLICT (id_registro, id_usuario) DO NOTHING;

                v_num_activities_user := floor(random() * 3)::INT;
                IF v_num_activities_user > 0 THEN
                    FOR v_activity_record IN 
                        SELECT ID_Registro FROM TB_Registro 
                        WHERE ID_EventoPai = v_event_id 
                        ORDER BY random() 
                        LIMIT v_num_activities_user 
                    LOOP
                        INSERT INTO TB_Inscricao (
                            ID_Registro, ID_Usuario, DH_DataInscricao, TP_Inscricao, 
                            ST_Pagamento, VL_CustoInscricao, ST_Presente
                        )
                        VALUES (
                            v_activity_record.ID_Registro, v_user_record.ID_Usuario, NOW() - (random()*30 + 1) * '1 day'::interval,
                            (ARRAY['Online', 'Presencial'])[1 + floor(random()*2)],
                            'Isento', 
                            0.00, -- Custo da Atividade é SEMPRE ZERO
                            random() < 0.8
                        )
                        ON CONFLICT (id_registro, id_usuario) DO NOTHING;
                    END LOOP;
                END IF;
            END LOOP;
        END IF;
    END LOOP;


    -- 4. POPULAR TB_Pagamento (COM LÓGICA DE DESCONTO)
    -- -----------------------------------------------------------------
    RAISE NOTICE '4. Gerando pagamentos (com descontos)...';
    INSERT INTO TB_Pagamento (
        ID_Inscricao, DH_DataPagamento, VL_ValorPago, TP_MetodoPagamento, CD_Transacao
    )
    SELECT 
        I.ID_Inscricao, 
        I.DH_DataInscricao + (random() * 3 + 1) * '1 hour'::interval, 
        (CASE 
            WHEN random() < 0.7 THEN I.VL_CustoInscricao
            WHEN random() < 0.9 THEN I.VL_CustoInscricao * 0.5
            ELSE I.VL_CustoInscricao * 0.75
        END)::DECIMAL(10,2) AS VL_ValorPago,
        CASE         
            WHEN random() < 0.5 THEN 'PIX' 
            WHEN random() < 0.85 THEN 'Cartão de Crédito' 
            ELSE 'Boleto' 
        END,
        'TRX_' || MD5(I.ID_Inscricao::text || NOW()::text)
    FROM TB_Inscricao I
    WHERE I.ST_Pagamento = 'Pago';


    -- 5. POPULAR TB_Certificado
    -- -----------------------------------------------------------------
    RAISE NOTICE '5. Gerando certificados...';
    INSERT INTO TB_Certificado (
        ID_Inscricao, CD_Validacao, DH_Emissao
    )
    SELECT
        I.ID_Inscricao,
        MD5(I.ID_Usuario::text || I.ID_Registro::text || R.DH_Fim::text),
        R.DH_Fim + '1 day'::interval
    FROM TB_Inscricao I
    JOIN TB_Registro R ON I.ID_Registro = R.ID_Registro
    WHERE I.ST_Presente = true;

    RAISE NOTICE 'População de dados (v6) concluída com sucesso!';
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