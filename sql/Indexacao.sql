CREATE INDEX idx_simples_reg_tipo
  ON TB_Registro (tp_registro);

-- Plano Intermediário: Indexar todas as FKs + Filtros Comuns

-- 1. Indexar TODAS as colunas de Chave Estrangeira (FK)
CREATE INDEX idx_inter_inscricao_usuario ON TB_Inscricao (id_usuario);
CREATE INDEX idx_inter_inscricao_registro ON TB_Inscricao (id_registro);
CREATE INDEX idx_inter_pagamento_inscricao ON TB_Pagamento (id_inscricao);
CREATE INDEX idx_inter_certificado_inscricao ON TB_Certificado (id_inscricao);
CREATE INDEX idx_inter_registro_eventopai ON TB_Registro (id_eventopai);

-- 2. Indexar as colunas de FILTRO (WHERE) mais comuns
CREATE INDEX idx_inter_registro_tipo ON TB_Registro (tp_registro);
CREATE INDEX idx_inter_inscricao_presente ON TB_Inscricao (st_presente);
CREATE INDEX idx_inter_inscricao_pagamento ON TB_Inscricao (st_pagamento);

-- Plano Avançado: Índices Compostos e Parciais para consultas específicas

-- 1. Índice Composto para o "Funil por Evento" (Consultas 10-av, 17-av, 6-int)
--    Cobre JOIN, WHERE e FILTER de uma só vez
CREATE INDEX idx_avanc_inscricao_funil
  ON TB_Inscricao (id_registro, st_presente, st_pagamento);

-- 2. Índice Composto para consultas focadas no Usuário (1-av, 2-av, 14-av, 16-av)
--    Cobre o JOIN por usuário e já agiliza a busca por registro
CREATE INDEX idx_avanc_inscricao_usuario
  ON TB_Inscricao (id_usuario, id_registro);

-- 3. Índice Composto para a auto-relação (7-int, 4-av)
--    Acelera a busca de Atividades (rf) que pertencem a um Evento (rp)
CREATE INDEX idx_avanc_registro_pai_tipo
  ON TB_Registro (id_eventopai, tp_registro);

-- 4. Índice PARCIAL (A técnica mais avançada)
--    Um índice pequeno e ultra-rápido que SÓ contém os eventos
--    Usado por 90% das suas consultas
CREATE INDEX idx_avanc_registro_APENAS_EVENTOS
  ON TB_Registro (id_registro)
  WHERE tp_registro = 'Evento';

-- 5. Índice PARCIAL para presentes (acelera 6-int, 10-av, 6-av)
CREATE INDEX idx_avanc_inscricao_APENAS_PRESENTES
  ON TB_Inscricao (id_registro)
  WHERE st_presente = TRUE;