-- Plano Simples: Indexar a coluna de filtro mais usada no banco
CREATE INDEX idx_simples_reg_tipo
  ON TB_Registro (tp_registro);