-- IMPLEMENTACAO TRIGGER (Padrão ANSI-SQL/PSM)

CREATE TRIGGER trg_VerificarInscricaoAtividade_ANSI
    BEFORE INSERT ON TB_Inscricao
    REFERENCING NEW AS N -- Define 'N' como o alias para a nova linha (NEW)
    FOR EACH ROW
BEGIN
    -- Declaração de variáveis
    DECLARE v_TipoRegistro VARCHAR(100);
    DECLARE v_ID_Evento_Pai INT;
    DECLARE v_InscricaoPaiCount INT;

    -- 1. Buscar o tipo e o pai do registro
    --    (Usando o alias 'N' definido no 'REFERENCING')
    SELECT
        TP_Registro,
        ID_EventoPai
    INTO
        v_TipoRegistro,
        v_ID_Evento_Pai
    FROM
        TB_Registro
    WHERE
        ID_Registro = N.ID_Registro;

    -- 2. Verificar o tipo
    IF v_TipoRegistro = 'Atividade' THEN

        -- 3. Garantir que a atividade tem um pai
        IF v_ID_Evento_Pai IS NULL THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Erro de integridade: A Atividade (ID) não possui um Evento pai (ID_EventoPai) associado.';
        END IF;

        -- 4. Contar a inscrição no evento pai
        SELECT
            COUNT(*)
        INTO
            v_InscricaoPaiCount
        FROM
            TB_Inscricao
        WHERE
            ID_Usuario = N.ID_Usuario
            AND ID_Registro = v_ID_Evento_Pai;

        -- 5. Se a contagem for 0, bloquear
        IF v_InscricaoPaiCount = 0 THEN
            -- Lança o erro padrão ANSI
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Inscrição bloqueada: O usuário deve estar inscrito no Evento principal antes de se inscrever na Atividade.';
        END IF;

    END IF;
END;