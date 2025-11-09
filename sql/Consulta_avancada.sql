-- CONSULTAS Avançadas (20 CONSULTAS)
-- Consultas avançadas envolvem no mínimo 3 tabelas E devem utilizar pelo menos 3 das seguintes funções: SUB-CONSULTAS, JOIN, GROUP BY, WINDOW e COUNT.

ANALYZE;
-- 1) Ranking de usuários por número de inscrições em eventos
SELECT
  u.ds_nome AS nome_usuario,
  COUNT(i.id_inscricao) FILTER (WHERE r.tp_registro = 'Evento') AS total_inscricoes,
  DENSE_RANK() OVER (ORDER BY COUNT(i.id_inscricao) FILTER (WHERE r.tp_registro = 'Evento') DESC)
     AS posicao_no_ranking
FROM tb_usuario u
LEFT JOIN tb_inscricao i ON i.id_usuario = u.id_usuario
LEFT JOIN tb_registro  r ON r.id_registro = i.id_registro
GROUP BY u.ds_nome
ORDER BY posicao_no_ranking, nome_usuario;

-- 2) Ranking de usuários por valor total pago (JOIN + GROUP BY + WINDOW)
SELECT
  u.ds_nome,
  SUM(p.vl_valorpago) AS total_pago,
  DENSE_RANK() OVER (ORDER BY SUM(p.vl_valorpago) DESC) AS posicao
FROM tb_usuario u
JOIN tb_inscricao i ON i.id_usuario = u.id_usuario
JOIN tb_pagamento p ON p.id_inscricao = i.id_inscricao
GROUP BY u.ds_nome
ORDER BY posicao, u.ds_nome;

-- 3) Participação de cada método de pagamento dentro de cada evento (JOIN + GROUP BY + WINDOW)
SELECT
  r.ds_titulo AS evento,
  p.tp_metodopagamento AS metodo,
  COUNT(*) AS qtd,
  ROUND(100.0 * COUNT(*) / NULLIF(SUM(COUNT(*)) OVER (PARTITION BY r.id_registro),0), 2) AS pct_no_evento
FROM tb_registro r
JOIN tb_inscricao i ON i.id_registro = r.id_registro
JOIN tb_pagamento p ON p.id_inscricao = i.id_inscricao
WHERE r.tp_registro = 'Evento'
GROUP BY r.id_registro, r.ds_titulo, p.tp_metodopagamento
ORDER BY evento, pct_no_evento DESC, metodo;

-- 4) Top 3 atividades mais populares em cada evento (self-JOIN + LEFT JOIN + GROUP BY + WINDOW)
WITH atividades AS (
  SELECT e.id_registro AS id_evento, e.ds_titulo AS evento, a.id_registro AS id_atividade, a.ds_titulo AS atividade
  FROM tb_registro e
  JOIN tb_registro a ON a.id_eventopai = e.id_registro
  WHERE e.tp_registro = 'Evento' AND a.tp_registro = 'Atividade'
),
cont AS (
  SELECT
    x.evento, x.atividade, COUNT(i.id_inscricao) AS inscritos,
    ROW_NUMBER() OVER (PARTITION BY x.evento ORDER BY COUNT(i.id_inscricao) DESC) AS pos_no_evento
  FROM atividades x
  LEFT JOIN tb_inscricao i ON i.id_registro = x.id_atividade
  GROUP BY x.evento, x.atividade
)
SELECT * FROM cont WHERE pos_no_evento <= 3 ORDER BY evento, pos_no_evento, atividade;

-- 5) Receita acumulada por dia (CTE + GROUP BY + WINDOW)
WITH por_dia AS (
  SELECT CAST(p.dh_datapagamento AS DATE) AS dia, SUM(p.vl_valorpago) AS total_dia
  FROM tb_pagamento p
  GROUP BY CAST(p.dh_datapagamento AS DATE)
)
SELECT
  dia, total_dia,
  SUM(total_dia) OVER (ORDER BY dia) AS receita_acumulada
FROM por_dia
ORDER BY dia;

-- 6) Usuários presentes em TODOS os eventos em que se inscreveram (JOIN + GROUP BY + HAVING)
SELECT u.ds_nome
FROM tb_usuario u
JOIN tb_inscricao i ON i.id_usuario = u.id_usuario
JOIN tb_registro r ON r.id_registro = i.id_registro AND r.tp_registro = 'Evento'
GROUP BY u.ds_nome
HAVING COUNT(*) = COUNT(*) FILTER (WHERE i.st_presente);

-- 7) Tempo médio (em horas) entre inscrição e pagamento por evento + ranking (JOIN + GROUP BY + WINDOW)
SELECT
  r.ds_titulo AS evento,
  AVG(EXTRACT(EPOCH FROM (p.dh_datapagamento - i.dh_datainscricao))/3600.0) AS horas_media,
  RANK() OVER (ORDER BY AVG(p.dh_datapagamento - i.dh_datainscricao)) AS posicao
FROM tb_registro r
JOIN tb_inscricao i ON i.id_registro = r.id_registro
JOIN tb_pagamento p ON p.id_inscricao = i.id_inscricao
WHERE r.tp_registro = 'Evento'
GROUP BY r.ds_titulo
ORDER BY posicao, evento;

-- 8) Certificados emitidos por dia com média móvel entre os dias (GROUP BY + WINDOW)
WITH por_dia AS (
  SELECT CAST(c.dh_emissao AS DATE) AS dia, COUNT(*) AS qtd
  FROM tb_certificado c
  GROUP BY CAST(c.dh_emissao AS DATE)
)
SELECT
  dia, qtd,
  AVG(qtd) OVER (ORDER BY dia ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS media_movel
FROM por_dia
ORDER BY dia;

-- 9) Percentil 90 do valor pago por evento (JOIN + GROUP BY + SUBCONSULTA com PERCENTILE_CONT)
SELECT
  r.ds_titulo AS evento,
  PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY p.vl_valorpago) AS p90_valor
FROM tb_registro r
JOIN tb_inscricao i ON i.id_registro = r.id_registro
JOIN tb_pagamento p ON p.id_inscricao = i.id_inscricao
WHERE r.tp_registro = 'Evento'
GROUP BY r.ds_titulo
ORDER BY p90_valor DESC;

-- 10) Funil por evento: inscritos, pagos, presentes + ranking por conversão (JOIN + GROUP BY + WINDOW)
SELECT
  r.ds_titulo AS evento,
  COUNT(*) AS inscritos,
  COUNT(*) FILTER (WHERE i.st_pagamento = 'Pago') AS pagos,
  COUNT(*) FILTER (WHERE i.st_presente) AS presentes,
  ROUND(100.0 * COUNT(*) FILTER (WHERE i.st_presente) / NULLIF(COUNT(*),0), 2) AS taxa_presenca_pct,
  RANK() OVER (ORDER BY 1.0 * COUNT(*) FILTER (WHERE i.st_presente) / NULLIF(COUNT(*),0) DESC) AS ranking
FROM tb_registro r
JOIN tb_inscricao i ON i.id_registro = r.id_registro
WHERE r.tp_registro = 'Evento'
GROUP BY r.ds_titulo
ORDER BY ranking, evento;

-- 11) Usuários com soma paga acima da média global (SUBCONSULTA + JOIN + GROUP BY)
WITH pag_por_user AS (
  SELECT u.id_usuario, u.ds_nome, SUM(p.vl_valorpago) AS total_user
  FROM tb_usuario u
  JOIN tb_inscricao i ON i.id_usuario = u.id_usuario
  JOIN tb_pagamento p ON p.id_inscricao = i.id_inscricao
  GROUP BY u.id_usuario, u.ds_nome
),
media_geral AS (
  SELECT AVG(total_user) AS media_total FROM pag_por_user
)
SELECT pu.ds_nome, pu.total_user
FROM pag_por_user pu, media_geral mg
WHERE pu.total_user > mg.media_total
ORDER BY pu.total_user DESC;

-- 12) Dia da semana com mais inscrições + ranking (GROUP BY + WINDOW + SUBCONSULTA para nome do dia)
WITH por_dia AS (
  SELECT DATE_TRUNC('day', dh_datainscricao)::date AS dia, COUNT(*) AS qtd
  FROM tb_inscricao
  GROUP BY DATE_TRUNC('day', dh_datainscricao)
),
por_dow AS (
  SELECT EXTRACT(DOW FROM dia)::int AS dow, SUM(qtd) AS total
  FROM por_dia
  GROUP BY EXTRACT(DOW FROM dia)
)
SELECT
  CASE dow
    WHEN 0 THEN 'Domingo' WHEN 1 THEN 'Segunda' WHEN 2 THEN 'Terça'
    WHEN 3 THEN 'Quarta' WHEN 4 THEN 'Quinta' WHEN 5 THEN 'Sexta' ELSE 'Sábado' END AS dia_semana,
  total,
  RANK() OVER (ORDER BY total DESC) AS ranking
FROM por_dow
ORDER BY ranking;

-- 13) Eventos com arrecadação acima da média global (JOIN + GROUP BY + SUBCONSULTA)
WITH arrec AS (
  SELECT r.id_registro, r.ds_titulo, SUM(p.vl_valorpago) AS total_evento
  FROM tb_registro r
  JOIN tb_inscricao i ON i.id_registro = r.id_registro
  JOIN tb_pagamento p ON p.id_inscricao = i.id_inscricao
  WHERE r.tp_registro = 'Evento'
  GROUP BY r.id_registro, r.ds_titulo
),
media AS (SELECT AVG(total_evento) AS media FROM arrec)
SELECT a.ds_titulo AS evento, a.total_evento
FROM arrec a, media m
WHERE a.total_evento > m.media
ORDER BY a.total_evento DESC;

-- 14) Usuários "multievento" (>=2 eventos) e valor médio por evento (JOIN + GROUP BY + HAVING + WINDOW)
WITH por_user_evento AS (
  SELECT u.id_usuario, u.ds_nome, r.id_registro, COALESCE(SUM(p.vl_valorpago),0) AS pago_no_evento
  FROM tb_usuario u
  JOIN tb_inscricao i ON i.id_usuario = u.id_usuario
  JOIN tb_registro r ON r.id_registro = i.id_registro AND r.tp_registro = 'Evento'
  LEFT JOIN tb_pagamento p ON p.id_inscricao = i.id_inscricao
  GROUP BY u.id_usuario, u.ds_nome, r.id_registro
),
agregado AS (
  SELECT ds_nome,
         COUNT(*) AS eventos_distintos,
         AVG(pago_no_evento) AS media_pago_por_evento
  FROM por_user_evento
  GROUP BY ds_nome
  HAVING COUNT(*) >= 2
)
SELECT
  ds_nome, eventos_distintos, media_pago_por_evento,
  DENSE_RANK() OVER (ORDER BY eventos_distintos DESC, media_pago_por_evento DESC) AS posicao
FROM agregado
ORDER BY posicao, ds_nome;

-- 15) Mapa hora-do-dia de pagamentos (GROUP BY + WINDOW)
SELECT
  EXTRACT(HOUR FROM dh_datapagamento)::int AS hora,
  COUNT(*) AS qtd,
  RANK() OVER (ORDER BY COUNT(*) DESC) AS ranking_hora
FROM tb_pagamento
GROUP BY EXTRACT(HOUR FROM dh_datapagamento)
ORDER BY hora;

-- 16) Usuários com mais certificados (JOIN + GROUP BY + WINDOW)
SELECT
  u.ds_nome,
  COUNT(c.id_certificado) AS total_certificados,
  DENSE_RANK() OVER (ORDER BY COUNT(c.id_certificado) DESC) AS posicao
FROM tb_usuario u
JOIN tb_inscricao i ON i.id_usuario = u.id_usuario
JOIN tb_certificado c ON c.id_inscricao = i.id_inscricao
GROUP BY u.ds_nome
ORDER BY posicao, u.ds_nome;

-- 17) Presentes sem pagamento confirmado  
SELECT
  r.ds_titulo AS evento,
  COUNT(*) AS presentes_sem_pagamento
FROM tb_registro r
JOIN tb_inscricao i ON i.id_registro = r.id_registro
WHERE r.tp_registro = 'Evento'
  AND i.st_presente = TRUE
  AND NOT EXISTS (
    SELECT 1
    FROM tb_pagamento p
    WHERE p.id_inscricao = i.id_inscricao
  )
GROUP BY r.ds_titulo
HAVING COUNT(*) > 0
ORDER BY presentes_sem_pagamento DESC, evento;

-- 18) Arrecadação por instituição + participação no total  
SELECT
  u.ds_instituicao,
  SUM(p.vl_valorpago) AS arrecadacao_total,
  ROUND(
    100.0 * SUM(p.vl_valorpago)
    / NULLIF(SUM(SUM(p.vl_valorpago)) OVER (), 0)
  , 2) AS participacao_pct
FROM tb_usuario u
JOIN tb_inscricao i ON i.id_usuario = u.id_usuario
JOIN tb_pagamento p ON p.id_inscricao = i.id_inscricao
GROUP BY u.ds_instituicao
ORDER BY arrecadacao_total DESC, u.ds_instituicao;

-- 19) Escolaridade por área 
SELECT
    r.tp_area,
    u.ds_escolaridade,
    COUNT(DISTINCT u.id_usuario) AS total_usuarios
FROM
    tb_inscricao i
JOIN
    tb_usuario u ON i.id_usuario = u.id_usuario
JOIN
    tb_registro r ON i.id_registro = r.id_registro
WHERE
    r.tp_registro = 'Evento'
GROUP BY
    r.tp_area, u.ds_escolaridade
ORDER BY
    r.tp_area, total_usuarios DESC;

-- 20) Top 3 eventos com mais certificados emitidos 
SELECT
    r.ds_titulo AS evento,
    COUNT(c.id_certificado) AS total_certificados
FROM
    tb_certificado c
JOIN
    tb_inscricao i ON i.id_inscricao = c.id_inscricao
JOIN
    tb_registro r ON i.id_registro = r.id_registro
WHERE
	r.tp_registro = 'Evento'
GROUP BY
    r.ds_titulo
ORDER BY
    total_certificados DESC
LIMIT 3;


