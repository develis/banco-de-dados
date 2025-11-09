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