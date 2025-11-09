                                   -- CONSULTAS INTERMEDIÁRIAS (10 CONSULTAS)
-- Consultas intermediárias envolvem no mínimo 3 tabelas E devem utilizar pelo menos 2 das seguintes funções: JOIN, GROUP BY, WINDOW e COUNT.

-- 1) Total de inscrições por usuário (apenas Eventos)
SELECT
  u.ds_nome AS nome_usuario,
  COUNT(i.id_inscricao) AS total_inscricoes_evento
FROM tb_usuario u
JOIN tb_inscricao i ON i.id_usuario = u.id_usuario
JOIN tb_registro r ON r.id_registro = i.id_registro
WHERE r.tp_registro = 'Evento'
GROUP BY u.ds_nome
ORDER BY total_inscricoes_evento DESC, nome_usuario;

-- 2) Arrecadação por evento
SELECT
  r.id_registro,
  r.ds_titulo AS titulo_evento,
  COUNT(p.id_pagamento) AS qtd_pagamentos,
  SUM(p.vl_valorpago) AS total_arrecadado
FROM tb_registro r
JOIN tb_inscricao i ON i.id_registro = r.id_registro
JOIN tb_pagamento p ON p.id_inscricao = i.id_inscricao
WHERE r.tp_registro = 'Evento'
GROUP BY r.id_registro, r.ds_titulo
ORDER BY total_arrecadado DESC;

-- 3) Certificados emitidos por evento
SELECT
  r.id_registro,
  r.ds_titulo AS titulo_evento,
  COUNT(c.id_certificado) AS certificados_emitidos
FROM tb_registro r
JOIN tb_inscricao i ON i.id_registro = r.id_registro
JOIN tb_certificado c ON c.id_inscricao = i.id_inscricao
WHERE r.tp_registro = 'Evento'
GROUP BY r.id_registro, r.ds_titulo
ORDER BY certificados_emitidos DESC;

-- 4) Participantes por instituição em cada evento
SELECT
  r.ds_titulo AS evento,
  u.ds_instituicao,
  COUNT(DISTINCT u.id_usuario) AS participantes
FROM tb_usuario u
JOIN tb_inscricao i ON i.id_usuario = u.id_usuario
JOIN tb_registro r ON r.id_registro = i.id_registro
WHERE r.tp_registro = 'Evento'
GROUP BY r.ds_titulo, u.ds_instituicao
ORDER BY evento, participantes DESC;

-- 5) Método de pagamento por evento
SELECT
  r.ds_titulo AS evento,
  p.tp_metodopagamento AS metodo,
  COUNT(*) AS qtd
FROM tb_registro r
JOIN tb_inscricao i ON i.id_registro = r.id_registro
JOIN tb_pagamento p ON p.id_inscricao = i.id_inscricao
WHERE r.tp_registro = 'Evento'
GROUP BY r.ds_titulo, p.tp_metodopagamento
ORDER BY evento, qtd DESC;

-- 6) Presença por evento
SELECT
	r.ds_titulo AS evento,
	u.ds_instituicao,
	i.st_presente,
	COUNT(i.id_inscricao) AS total_participantes
FROM
    tb_registro r
JOIN
    tb_inscricao i ON i.id_registro = r.id_registro
JOIN
    tb_usuario u ON i.id_usuario = u.id_usuario
WHERE
    r.tp_registro = 'Evento'
GROUP BY 
    r.ds_titulo,
    u.ds_instituicao,
    i.st_presente
ORDER BY
    evento,
    u.ds_instituicao,
    i.st_presente DESC;

-- 7) Inscritos por atividade dentro de cada evento
SELECT
  rp.ds_titulo AS evento_pai,
  rf.ds_titulo AS atividade,
  COUNT(i.id_inscricao) AS inscritos
FROM tb_registro rp
JOIN tb_registro rf ON rf.id_eventopai = rp.id_registro
LEFT JOIN tb_inscricao i ON i.id_registro = rf.id_registro
WHERE rp.tp_registro = 'Evento'
  AND rf.tp_registro = 'Atividade'
GROUP BY rp.ds_titulo, rf.ds_titulo
ORDER BY evento_pai, inscritos DESC, atividade;

-- 8) Média e desvio do valor pago por tipo de inscrição em cada evento
SELECT
  r.ds_titulo AS evento,
  i.tp_inscricao,
  AVG(p.vl_valorpago) AS media_pago,
  STDDEV_POP(p.vl_valorpago) AS desvio_pago
FROM tb_registro r
JOIN tb_inscricao i ON i.id_registro = r.id_registro
JOIN tb_pagamento p ON p.id_inscricao = i.id_inscricao
WHERE r.tp_registro = 'Evento'
GROUP BY r.ds_titulo, i.tp_inscricao
ORDER BY evento, media_pago DESC;

-- 9) Distribuição diária de pagamentos por evento
SELECT
  r.ds_titulo AS evento,
  CAST(p.dh_datapagamento AS DATE) AS dia,
  COUNT(*) AS qtd_pagamentos,
  SUM(p.vl_valorpago) AS total_dia
FROM tb_registro r
JOIN tb_inscricao i ON i.id_registro = r.id_registro
JOIN tb_pagamento p ON p.id_inscricao = i.id_inscricao
WHERE r.tp_registro = 'Evento'
GROUP BY r.ds_titulo, CAST(p.dh_datapagamento AS DATE)
ORDER BY evento, dia;

-- 10) Taxa de presença por evento com ranking simples
WITH base AS (
  SELECT
    r.id_registro,
    r.ds_titulo AS evento,
    COUNT(*) FILTER (WHERE i.st_presente) AS presentes,
    COUNT(*) AS total
  FROM tb_registro r
  JOIN tb_inscricao i ON i.id_registro = r.id_registro
  WHERE r.tp_registro = 'Evento'
  GROUP BY r.id_registro, r.ds_titulo
)
SELECT
  evento,
  presentes,
  total,
  ROUND(100.0 * presentes / NULLIF(total,0), 2) AS taxa_presenca_pct,
  RANK() OVER (ORDER BY 1.0 * presentes/NULLIF(total,0) DESC) AS posicao
FROM base
ORDER BY posicao, evento;

