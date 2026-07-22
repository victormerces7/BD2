-- =====================================================================
-- 06_indexes.sql
-- Índices criados a partir da análise das consultas lentas
-- (ver queries/lentas_originais.sql e docs/metricas_comparativas.md)
-- =====================================================================

-- ---------------------------------------------------------------------
-- IDX 1 — suporta a Consulta 1 (pedidos por status + período)
-- Índice composto: a ordem (status, data_pedido) permite ao otimizador
-- primeiro filtrar por status (igualdade) e depois percorrer o intervalo
-- de datas já ordenado, evitando o filesort do ORDER BY data_pedido.
-- ---------------------------------------------------------------------
CREATE INDEX idx_pedidos_status_data ON pedidos (status, data_pedido);

-- ---------------------------------------------------------------------
-- IDX 2 — suporta a Consulta 3 (relatório anual) e outras buscas por
-- intervalo de datas em pedidos, quando o filtro de status não é usado.
-- ---------------------------------------------------------------------
CREATE INDEX idx_pedidos_data ON pedidos (data_pedido);

-- ---------------------------------------------------------------------
-- IDX 3 — suporta a Consulta 4 (busca de cliente por nome).
-- Índice FULLTEXT: como a busca real do CRM é "nome começa com" /
-- "contém a palavra", um índice B-Tree comum não ajuda em LIKE '%x%'.
-- O FULLTEXT permite busca por palavra (inclusive prefixo) em tempo
-- praticamente constante, ao custo de não suportar substring arbitrária
-- no meio da palavra (trade-off explicado na apresentação).
-- ---------------------------------------------------------------------
CREATE FULLTEXT INDEX idx_clientes_nome_ft ON clientes (nome);

-- ---------------------------------------------------------------------
-- IDX 4 — suporta a Consulta 5 (top produtos mais vendidos).
-- Índice composto e "covering" para a agregação SUM(quantidade)
-- agrupada por id_produto: o otimizador consegue calcular a soma
-- lendo somente o índice, sem tocar nas linhas da tabela.
-- ---------------------------------------------------------------------
CREATE INDEX idx_itens_pedido_produto_qtd ON itens_pedido (id_produto, quantidade);

-- ---------------------------------------------------------------------
-- IDX 5 (extra) — apoio a relatórios financeiros por forma/status de
-- pagamento, usados nas Views/Procedures da seção seguinte.
-- ---------------------------------------------------------------------
CREATE INDEX idx_pagamentos_status_forma ON pagamentos (status_pagamento, forma_pagamento);

-- ---------------------------------------------------------------------
-- IDX 6 (extra) — apoio ao filtro de avaliações por nota, usado em
-- Views de reputação de produto/vendedor.
-- ---------------------------------------------------------------------
CREATE INDEX idx_avaliacoes_produto_nota ON avaliacoes (id_produto, nota_produto);

-- Conferir os índices criados:
-- SHOW INDEX FROM pedidos;
-- SHOW INDEX FROM clientes;
-- SHOW INDEX FROM itens_pedido;
