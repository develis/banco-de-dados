-- Plano Avançado: Índices Compostos e Parciais para consultas específicas

-- 1. Índice Composto para o "Funil por Evento"
CREATE INDEX idx_avanc_inscricao_funil
  ON TB_Inscricao (id_registro, st_presente, st_pagamento);

-- 2. Índice Composto para consultas focadas no Usuário
CREATE INDEX idx_avanc_inscricao_usuario
  ON TB_Inscricao (id_usuario, id_registro);

-- 3. Índice Composto para a auto-relação
CREATE INDEX idx_avanc_registro_pai_tipo
  ON TB_Registro (id_eventopai, tp_registro);

-- 4. Índice PARCIAL
CREATE INDEX idx_avanc_registro_APENAS_EVENTOS
  ON TB_Registro (id_registro)
  WHERE tp_registro = 'Evento';

-- 5. Índice PARCIAL para presentes
CREATE INDEX idx_avanc_inscricao_APENAS_PRESENTES
  ON TB_Inscricao (id_registro)
  WHERE st_presente = TRUE;