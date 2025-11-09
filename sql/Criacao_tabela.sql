-- TABELA PAGAMENTO
CREATE TABLE TB_Pagamento (
    ID_Pagamento INTEGER GENERATED ALWAYS AS IDENTITY,
    ID_Inscricao INTEGER,
    DH_DataPagamento TIMESTAMP,
    VL_ValorPago DECIMAL,
    TP_MetodoPagamento VARCHAR,
    CD_Transacao VARCHAR,

	-- PRIMARY KEY
	CONSTRAINT PK_Pagamento PRIMARY KEY (ID_Pagamento);
);

-- TABELA CERTIFICADO
CREATE TABLE TB_Certificado (
    ID_Certificado INTEGER GENERATED ALWAYS AS IDENTITY,
    ID_Inscricao INTEGER,
    CD_Validacao VARCHAR,
    DH_Emissao TIMESTAMP,
	
	-- PRIMARY KEY
	CONSTRAINT PK_Certificado PRIMARY KEY (ID_Certificado);
);

-- TABELA USUARIO
CREATE TABLE TB_Usuario (
    ID_Usuario INTEGER GENERATED ALWAYS AS IDENTITY,
    CD_CPF VARCHAR,
    DS_Email VARCHAR,
    DS_Nome VARCHAR,
    DS_Instituicao VARCHAR,
    DS_Escolaridade VARCHAR,
	
	-- PRIMARY KEY
	CONSTRAINT PK_Usuario PRIMARY KEY (ID_Usuario);
);

-- TABELA REGISTRO
CREATE TABLE TB_Registro (
    ID_Registro INTEGER GENERATED ALWAYS AS IDENTITY,
    ID_EventoPai INTEGER,
    TP_Registro VARCHAR,
    DS_Titulo VARCHAR,
    DS_Descricao VARCHAR,
    DS_Local VARCHAR,
    DH_Inicio TIMESTAMP,
    DH_Fim TIMESTAMP,
    TP_Area VARCHAR,
	
	-- PRIMARY KEY
	CONSTRAINT PK_Registro PRIMARY KEY (ID_Registro);
);

-- TABELA INSCRICAO
CREATE TABLE TB_Inscricao (
    ID_Inscricao INTEGER GENERATED ALWAYS AS IDENTITY,
    ID_Registro INTEGER,
    ID_Usuario INTEGER,
    DH_DataInscricao TIMESTAMP,
    TP_Inscricao VARCHAR,
    ST_Pagamento VARCHAR,
    VL_CustoInscricao DECIMAL,
    ST_Presente BOOLEAN
	
	-- PRIMARY KEY
	CONSTRAINT PK_Inscricao PRIMARY KEY (ID_Inscricao);
);

-- DEFINIÇÃO DAS CONSTRAINTS
-- FOREIGN KEY PAGAMENTO/INSCRICAO
ALTER TABLE TB_Pagamento ADD CONSTRAINT FK_Pagamento_Inscricao
    FOREIGN KEY (ID_Inscricao)
    REFERENCES TB_Inscricao (ID_Inscricao);

-- FOREIGN KEY CERTIFICADO/INSCRICAO
ALTER TABLE TB_Certificado ADD CONSTRAINT FK_Certificado_Inscricao
    FOREIGN KEY (ID_Inscricao)
    REFERENCES TB_Inscricao (ID_Inscricao);

-- UNIQUE KEY USUARIO/CPF
ALTER TABLE TB_Usuario ADD CONSTRAINT UK_Usuario_CPF UNIQUE (CD_CPF);
-- UNIQUE KEY USUARIO/EMAIL
ALTER TABLE TB_Usuario ADD CONSTRAINT UK_Usuario_Email UNIQUE (DS_Email);

-- FOREIGN KEY ATIVIDADE/EVENTO
ALTER TABLE TB_Registro ADD CONSTRAINT FK_Registro_EventoPai
    FOREIGN KEY (ID_EventoPai)
    REFERENCES TB_Registro (ID_Registro);

-- UNIQUE KEY INSCRICAO (USUARIO,REGISTRO)
ALTER TABLE TB_Inscricao ADD CONSTRAINT UK_Usuario_Registro UNIQUE (ID_Registro, ID_Usuario);
-- FOREIGN KEY INSCRICAO_USUARIO
ALTER TABLE TB_Inscricao ADD CONSTRAINT FK_Inscricao_Usuario
    FOREIGN KEY (ID_Usuario)
    REFERENCES TB_Usuario (ID_Usuario);
-- FOREIGN KEY INSCRICAO_REGISTRO
ALTER TABLE TB_Inscricao ADD CONSTRAINT FK_Inscricao_Registro
    FOREIGN KEY (ID_Registro)
    REFERENCES TB_Registro (ID_Registro);

-- FUNÇÃO DO TRIGGER (Implementação PL/pgSQL)
-- Garante a regra de negócios onde um usuário só pode se inscrever em uma atividade que pertence a um evento ao qual ele já está inscrito
CREATE FUNCTION fn_VerificarInscricaoAtividade()
RETURNS TRIGGER AS $$
DECLARE
    -- Variáveis para armazenar os dados do registro (evento ou atividade)
    v_TipoRegistro VARCHAR;
    v_ID_Evento_Pai INT;
    v_InscricaoPaiCount INT;
BEGIN
    
    -- 1. Buscar o tipo e o pai do registro que está sendo inscrito
    SELECT 
        TP_Registro,
        ID_EventoPai
    INTO 
        v_TipoRegistro,
        v_ID_Evento_Pai
    FROM 
        TB_Registro
    WHERE 
        ID_Registro = NEW.ID_Registro; -- 'NEW.ID_Registro' é o ID do registro da nova inscrição

-- CRIACAO DO TRIGGER
CREATE TRIGGER trg_AntesDeInserirInscricao
BEFORE INSERT ON TB_Inscricao
FOR EACH ROW
EXECUTE FUNCTION fn_VerificarInscricaoAtividade();
    -- 2. Verificar o tipo. A regra só se aplica a 'Atividade'
    IF v_TipoRegistro = 'Atividade' THEN
        
        -- 3. (Boa prática) Garantir que a atividade tem um evento pai associado
        IF v_ID_Evento_Pai IS NULL THEN
            RAISE EXCEPTION 'Erro de integridade de dados: A Atividade (ID: %) não possui um Evento pai (ID_EventoPai) associado.', NEW.ID_Registro;
        END IF;

        -- 4. Contar quantas inscrições o usuário (NEW.ID_Usuario) tem no evento pai (v_ID_Evento_Pai)
        SELECT 
            COUNT(*)
        INTO
            v_InscricaoPaiCount
        FROM 
            TB_Inscricao
        WHERE 
            ID_Usuario = NEW.ID_Usuario      -- O mesmo usuário
            AND ID_Registro = v_ID_Evento_Pai; -- O evento pai da atividade

        -- 5. Se a contagem for 0, o usuário NÃO está inscrito no evento pai.
        IF v_InscricaoPaiCount = 0 THEN
            -- BLOQUEIA A INSERÇÃO e retorna um erro claro
            RAISE EXCEPTION 'Inscrição bloqueada: O usuário (ID: %) deve estar inscrito no Evento principal (ID: %) antes de se inscrever na Atividade (ID: %).',
            NEW.ID_Usuario, v_ID_Evento_Pai, NEW.ID_Registro;
        END IF;
        
    END IF;

    -- 6. Se a regra passou (ou se era um 'Evento'), permite a inserção
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- CRIAÇÃO DO TRIGGER
CREATE TRIGGER trg_AntesDeInserirInscricao
BEFORE INSERT ON TB_Inscricao
FOR EACH ROW
EXECUTE FUNCTION fn_VerificarInscricaoAtividade();