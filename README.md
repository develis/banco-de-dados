## Repositório - Banco de Dados (Trabalho de Disciplina)

## Requisitos

- PostgreSQL (testado em versões modernas; usar >= 10 recomendado).
- Cliente `psql` disponível no PATH para execução via terminal/PowerShell.
- usuário do banco com privilégios de criação de objetos e inserção (CREATE, INSERT, REFERENCES, etc.).

## Ordem de execução recomendada (passo a passo)

1) Criar o banco (opcional) e conectar-se com o usuário adequado.

2) Rodar o script de criação (tabelas, constraints, função trigger):

```powershell
psql -h localhost -p 5432 -U seu_usuario -d seu_banco -f .\sql\Criacao_tabela.sql
```

Notas:
- `Criacao_tabela.sql` contém as tabelas (`TB_Usuario`, `TB_Registro`, `TB_Inscricao`, `TB_Pagamento`, `TB_Certificado`) e as constraints (PKs, FKs, UNIQUEs) além da implementação da função trigger em PL/pgSQL.
- Se preferir usar a versão ANSI/PSM da trigger (para outro SGBD), veja `sql/trigger_definicao_ansi-sql.sql`.

3) Popular os dados (script de população automatizada):

```powershell
psql -h localhost -p 5432 -U seu_usuario -d seu_banco -f .\sql\Popular_tabela.sql
```

Observações:
- `Popular_tabela.sql` faz um `TRUNCATE ... RESTART IDENTITY CASCADE` no início — portanto é seguro reexecutar o script para resetar os dados.
- Ao final do script há seleção das contagens por tabela; use-a para validar rapidamente se a população foi aplicada (ex.: `TB_Usuario` deverá ter ~5000 registros, dependendo da versão do script).

4) (Opcional) Aplicar planos de indexação — escolha um dos planos:

- Plano simples:

```powershell
psql -h localhost -U seu_usuario -d seu_banco -f .\sql\plano_indexacao_1.sql
```

- Plano intermediário:

```powershell
psql -h localhost -U seu_usuario -d seu_banco -f .\sql\plano_indexacao_2.sql
```

- Plano avançado:

```powershell
psql -h localhost -U seu_usuario -d seu_banco -f .\sql\plano_indexacao_3.sql
```

Recomenda-se rodar `ANALYZE` após aplicar índices para atualizar estatísticas.

5) Executar consultas para avaliação

- Consultas intermediárias (arquivo com 10 queries):

```powershell
psql -h localhost -U seu_usuario -d seu_banco -f .\sql\Consulta_intermediaria.sql
```

- Consultas avançadas (arquivo com 20 queries):

```powershell
psql -h localhost -U seu_usuario -d seu_banco -f .\sql\Consulta_avancada.sql
```

Estas consultas incluem JOINs, GROUP BY, WINDOW FUNCTIONS, filtros e agregações. O professor pode avaliar corretude dos resultados, custos e planos (EXPLAIN ANALYZE) quando desejar.

## Como executar via pgAdmin (GUI)

1. Abra o `pgAdmin` e conecte-se ao servidor PostgreSQL apropriado com o usuário desejado.
2. (Opcional) Crie um banco de dados novo: clique com o botão direito em "Databases" → "Create" → "Database..." e informe o nome.
3. Selecione o banco de dados alvo no painel da esquerda e abra o "Query Tool" (ícone de consulta ou botão direito → "Query Tool"). Confirme que o banco selecionado no canto superior direito é o correto.
4. Para rodar um arquivo SQL inteiro, vá em `File` → `Open` no Query Tool e selecione o arquivo do repositório (p.ex. `sql/Criacao_tabela.sql`).
5. Execute o script clicando em "Execute/Run" (▶) ou pressionando F5. Observe a aba "Messages" para erros, avisos e `RAISE NOTICE` emitidos pelos scripts.
6. Ordem recomendada para execução dos arquivos (via pgAdmin):

   Sequência de Execução dos arquivos SQL para criar e popular as tabelas:
   1. `sql/Criacao_tabela.sql`
   2. `sql/Popular_tabela.sql`

   Arquivos com Consultas (para avaliar resultados):
   1. `sql/Consulta_intermediaria.sql`
   2. `sql/Consulta_avancada.sql`

   Planos de Indexacao para testes (execute quando quiser testar impacto em performance):
   1. `sql/plano_indexacao_1.sql`
   2. `sql/plano_indexacao_2.sql`
   3. `sql/plano_indexacao_3.sql`

7. Para comparar planos de execução no pgAdmin: copie a query para o Query Tool e rode `EXPLAIN (ANALYZE, BUFFERS) <sua_query>`; o resultado aparecerá na aba de saída.
8. Se precisar reexecutar o script de criação e evitar erro por objetos já existentes (trigger/função), drope objetos conforme instruções em "Problemas conhecidos" antes de reexecutar.

## Como testar regras de negócio (trigger)

Teste rápido (esperado: erro quando tentar inscrever um usuário em uma Atividade sem inscrição prévia no Evento pai):

1) Criar um usuário temporário e anotar o `id` retornado:

```sql
INSERT INTO TB_Usuario (CD_CPF, DS_Email, DS_Nome, DS_Instituicao, DS_Escolaridade)
VALUES ('00000000000','teste-trigger@exemplo.com','Aluno Trigger','Universidade X','Superior')
RETURNING id_usuario;
```

2) Identificar uma `Atividade` (registro com `tp_registro = 'Atividade'`):

```sql
SELECT id_registro FROM tb_registro WHERE tp_registro = 'Atividade' LIMIT 1;
```

3) Tentar inserir uma inscrição nessa atividade com o usuário criado (deve levantar exceção):

```sql
INSERT INTO TB_Inscricao (ID_Registro, ID_Usuario, DH_DataInscricao, TP_Inscricao, ST_Pagamento, VL_CustoInscricao, ST_Presente)
VALUES (<atividade_id>, <novo_id_usuario>, NOW(), 'Presencial', 'Isento', 0.00, false);
```

Se a trigger PL/pgSQL estiver ativa, a inserção será bloqueada com mensagem informando que o usuário precisa estar inscrito no evento pai.

Se não quiser o comportamento de trigger durante alguns testes, desative-a com:

```sql
DROP TRIGGER IF EXISTS trg_AntesDeInserirInscricao ON TB_Inscricao;
DROP FUNCTION IF EXISTS fn_VerificarInscricaoAtividade();
-- ou comentar/alterar a criação no arquivo de criação
```

## Como remover/limpar (devolver ao estado inicial)

- Limpar todas as tabelas (dropar tudo):

```sql
-- Atenção: apaga todos os dados e objetos relacionados
DROP TABLE IF EXISTS TB_Pagamento, TB_Certificado, TB_Inscricao, TB_Registro, TB_Usuario CASCADE;
```

- Remover índices criados pelos planos (exemplos):

```sql
DROP INDEX IF EXISTS idx_simples_reg_tipo;
DROP INDEX IF EXISTS idx_inter_inscricao_usuario, idx_inter_inscricao_registro, idx_inter_pagamento_inscricao, idx_inter_certificado_inscricao, idx_inter_registro_eventopai;
DROP INDEX IF EXISTS idx_avanc_inscricao_funil, idx_avanc_inscricao_usuario, idx_avanc_registro_pai_tipo, idx_avanc_registro_APENAS_EVENTOS, idx_avanc_inscricao_APENAS_PRESENTES;
```
