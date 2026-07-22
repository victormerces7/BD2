-- =====================================================================
-- 03_views.sql — Views do projeto Marketplace
-- =====================================================================

-- VIEW 1: catálogo público de produtos ativos (esconde colunas internas
-- e já resolve nome do vendedor/categoria — usada pela página de busca)
CREATE OR REPLACE VIEW vw_catalogo_produtos AS
SELECT pr.id_produto, pr.nome AS produto, pr.preco_original, pr.preco_desconto,
       COALESCE(pr.preco_desconto, pr.preco_original) AS preco_final,
       pr.estoque, v.nome_loja AS vendedor, c.nome AS categoria
FROM produtos pr
JOIN vendedores v ON v.id_vendedor = pr.id_vendedor
JOIN categorias c ON c.id_categoria = pr.id_categoria
WHERE pr.ativo = 1;

-- VIEW 2: pedidos "explodidos" com dados do cliente e pagamento —
-- usada pelo painel de atendimento ao cliente
CREATE OR REPLACE VIEW vw_pedidos_detalhados AS
SELECT pe.id_pedido, pe.data_pedido, pe.status, pe.valor_total,
       cl.id_cliente, cl.nome AS cliente, cl.email AS email_cliente,
       pg.forma_pagamento, pg.status_pagamento
FROM pedidos pe
JOIN clientes cl ON cl.id_cliente = pe.id_cliente
LEFT JOIN pagamentos pg ON pg.id_pedido = pe.id_pedido;

-- VIEW 3: reputação consolidada do vendedor (nota média, total de
-- avaliações) — usada na página de perfil da loja
CREATE OR REPLACE VIEW vw_reputacao_vendedor AS
SELECT v.id_vendedor, v.nome_loja,
       ROUND(AVG(a.nota_vendedor), 2) AS nota_media,
       COUNT(a.id_avaliacao) AS total_avaliacoes
FROM vendedores v
JOIN produtos p ON p.id_vendedor = v.id_vendedor
JOIN avaliacoes a ON a.id_produto = p.id_produto
GROUP BY v.id_vendedor, v.nome_loja;

-- VIEW 4: ranking de produtos mais vendidos, já usando a tabela-resumo
-- mantida por trigger (ver scripts/05_triggers.sql) — O(1) em vez de
-- agregar itens_pedido a cada consulta
CREATE OR REPLACE VIEW vw_top_produtos AS
SELECT p.id_produto, p.nome, v.nome_loja AS vendedor,
       r.total_quantidade, r.faturamento_total
FROM resumo_vendas_produto r
JOIN produtos p ON p.id_produto = r.id_produto
JOIN vendedores v ON v.id_vendedor = p.id_vendedor
ORDER BY r.total_quantidade DESC;
