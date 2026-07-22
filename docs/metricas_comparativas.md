# Métricas Comparativas — Antes x Depois da Otimização

**Ambiente:** MySQL/MariaDB, banco `marketplace_db` populado com ~1,6 milhão
de linhas (300 mil pedidos, 660 mil itens de pedido, 120 mil produtos, 60 mil
clientes, 150 mil avaliações — ver `data/dados_mockados.csv` e
`scripts/02_dml_populacao.sql`).

**Metodologia:** cada consulta foi executada 8 vezes (2 de aquecimento
descartadas + 6 medidas), reportando a **mediana** do tempo de execução em
milissegundos, para reduzir ruído de cache/SO. Planos de execução obtidos via
`EXPLAIN` (arquivos completos em `docs/planos_de_execucao/`).

| # | Consulta | Antes (mediana) | Depois (mediana) | Ganho |
|---|----------|-----------------:|-------------------:|------:|
| 1 | Pedidos por status + período | 182,8 ms | 124,7 ms | **1,5x** |
| 2 | Faturamento por vendedor (JOIN reescrito) | 2.165,5 ms | 2.569,2 ms | **0,8x (piorou)** |
| 2b| Faturamento por vendedor (tabela-resumo) | 2.165,5 ms | 327,3 ms | **6,6x** |
| 3 | Pedidos por ano (função YEAR) | 67,3 ms | 69,7 ms | ≈ igual* |
| 4 | Busca de cliente por nome (LIKE → FULLTEXT) | 29,4 ms | 6,4 ms | **4,6x** |
| 5 | Top 10 produtos mais vendidos (reescrita) | 613,0 ms | 1.666,2 ms | **0,4x (piorou)** |
| 5b| Top 10 produtos mais vendidos (tabela-resumo) | 613,0 ms | 0,5 ms | **~1.200x** |

\* Consulta 3 é dominada pelo `COUNT`/`SUM` sobre ~300 mil linhas; o índice em
`data_pedido` não ajuda porque a query não tem seletividade (traz quase todas
as linhas do ano). Ver análise abaixo.

---

## Consulta 1 — Pedidos por status + período

**Diagnóstico:** `EXPLAIN` mostrava `type=ALL`, 298.674 linhas varridas,
`Using where; Using filesort` — nenhum índice suportava o filtro composto
nem a ordenação por `data_pedido`.

**Otimização:** índice composto `idx_pedidos_status_data (status, data_pedido)`.
Depois, `EXPLAIN` passa a mostrar `type=range`, `rows=20022` (estimativa,
muito menor que 298 mil) e a cláusula `Using filesort` desaparece — o índice
já entrega os dados ordenados.

## Consulta 2 — Faturamento por vendedor

**Diagnóstico:** duas subconsultas correlacionadas (uma para soma, uma para
contagem), executadas uma vez por vendedor (~3.000 vezes cada).

**Tentativa 1 (reescrita para JOIN + GROUP BY):** pioga o tempo (2.569 ms vs
2.165 ms). Motivo: como `id_vendedor` e `id_produto` já tinham índice (criado
automaticamente pelas FKs), as subconsultas correlacionadas acessavam, para
cada vendedor, só as linhas daquele vendedor via índice (`ref`) — um acesso
seletivo. Já o `JOIN` obriga o otimizador a percorrer as ~660 mil linhas de
`itens_pedido` inteiras antes de agrupar. **Lição:** reescrever subquery
correlacionada em JOIN nem sempre é mais rápido — depende da seletividade
dos índices disponíveis.

**Tentativa 2 (tabela-resumo + trigger) — a que resolveu de verdade:** como o
gargalo real era agregar a tabela fato inteira a cada consulta, a solução foi
parar de agregar em tempo de consulta. Criamos `resumo_vendas_produto`,
mantida sempre atualizada por 3 triggers em `itens_pedido`
(`scripts/05_triggers.sql`). A consulta de faturamento por vendedor passou a
agregar ~120 mil linhas já prontas em vez de ~660 mil linhas cruas:
**2.165 ms → 327 ms (6,6x mais rápido)**.

## Consulta 3 — Pedidos por ano

**Diagnóstico:** `WHERE YEAR(data_pedido) = 2024` é *non-sargable*: a função
aplicada à coluna impede o uso de qualquer índice em `data_pedido`, mesmo que
ele exista.

**Otimização:** reescrita para intervalo (`data_pedido >= '2024-01-01' AND
data_pedido < '2025-01-01'`), semanticamente idêntica, porém sargável.
Mesmo assim o tempo não melhorou, porque ~1/6 de todas as 300 mil linhas
pertence a 2024 — o otimizador corretamente decide que um *full scan* é mais
barato que usar o índice e depois buscar as linhas uma a uma (baixa
seletividade). É um exemplo real de quando *criar* um índice não ajuda: a
reescrita ainda vale a pena por correção/clareza e por deixar a consulta
pronta para cenários mais seletivos (ex.: filtrar por mês), mas o ganho de
performance aqui é nulo — e está documentado para não gerar expectativa
falsa na apresentação.

## Consulta 4 — Busca de cliente por nome

**Diagnóstico:** `LIKE '%Silva%'` (wildcard à esquerda) impede o uso de
índice B-Tree — *full scan* em 59.628 linhas.

**Otimização:** índice `FULLTEXT` em `clientes.nome` + reescrita para
`MATCH(nome) AGAINST('Silva*' IN BOOLEAN MODE)`. **29,4 ms → 6,4 ms (4,6x)**.
**Trade-off importante:** FULLTEXT busca por *palavra* (com suporte a
prefixo), não por substring arbitrária no meio de uma palavra — para o caso
de uso real (CRM buscando por nome/sobrenome) isso é suficiente e muito mais
rápido; não seria uma substituição correta para "encontrar qualquer trecho
em qualquer posição do texto".

## Consulta 5 — Top 10 produtos mais vendidos

**Diagnóstico:** agregação de ~660 mil linhas de `itens_pedido` + `JOIN` com
120 mil produtos + `GROUP BY`/`ORDER BY` sem índice de apoio —
`Using temporary; Using filesort`.

**Tentativa 1 (subquery agregando antes do JOIN):** piorou (1.666 ms vs
613 ms), pelo mesmo motivo da Consulta 2 — o plano escolhido pelo otimizador
(`LATERAL DERIVED`) acabou sendo pior que o plano original nesta base.

**Tentativa 2 (tabela-resumo + trigger):** a consulta passa a ler direto de
`resumo_vendas_produto` (indexada por `total_quantidade`), sem agregar nada
em tempo de consulta: **613 ms → 0,5 ms (~1.200x mais rápido)**.

---

## Conclusão geral

* Índices simples/compostos resolveram bem os casos de filtro seletivo
  (Consultas 1 e 4).
* Reescrever subquery→JOIN **não é uma regra geral de otimização** — só
  ajuda quando o JOIN reduz o volume de dados processado; testamos e
  medimos antes de assumir isso (Consultas 2 e 5).
* Quando o gargalo é agregar uma tabela fato inteira em toda consulta de
  relatório, a solução mais robusta é **parar de agregar em tempo de
  consulta**: uma tabela-resumo mantida por trigger entrega leituras O(1)
  ao custo de um pequeno overhead de escrita — trade-off adequado para um
  marketplace, onde relatórios são lidos com muito mais frequência do que
  itens de pedido são inseridos.
* Nem toda consulta lenta tem solução via índice (Consulta 3): quando a
  seletividade é baixa, o *full scan* pode ser genuinamente o plano ótimo.
