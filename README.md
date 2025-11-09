## Repositório - Banco de Dados (Trabalho de Disciplina)

## Requisitos

- PostgreSQL (testado em versões modernas; usar >= 10 recomendado).
- Cliente `psql` disponível no PATH para execução via terminal/PowerShell.
- usuário do banco com privilégios de criação de objetos e inserção (CREATE, INSERT, REFERENCES, etc.).

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
