-- =====================================================================
-- lentas_originais.sql
-- 5 consultas problemáticas identificadas no sistema de marketplace,
-- executadas sobre a base já populada (~1,6 milhão de linhas).
-- Banco: marketplace_db (MySQL/MariaDB)
-- =====================================================================

-- ---------------------------------------------------------------------
-- CONSULTA 1: Dashboard de vendas — pedidos entregues em um período
-- Problema: filtro por status + intervalo de datas sem índice composto.
-- Faz FULL TABLE SCAN em 300.000 linhas de "pedidos".
-- ---------------------------------------------------------------------
SELECT id_pedido, id_cliente, data_pedido, valor_total, status
FROM pedidos
WHERE status = 'ENTREGUE'
  AND data_pedido BETWEEN '2024-01-01' AND '2024-06-30'
ORDER BY data_pedido DESC;


-- ---------------------------------------------------------------------
-- CONSULTA 2: Faturamento total por vendedor (relatório gerencial)
-- Problema: subconsulta correlacionada — recalcula a soma para CADA
-- vendedor, executando a subquery ~3.000 vezes (padrão N+1 em SQL).
-- ---------------------------------------------------------------------
SELECT
    v.id_vendedor,
    v.nome_loja,
    (SELECT SUM(ip.quantidade * ip.preco_unitario)
       FROM itens_pedido ip
       JOIN produtos p ON p.id_produto = ip.id_produto
      WHERE p.id_vendedor = v.id_vendedor) AS faturamento_total,
    (SELECT COUNT(DISTINCT ip.id_pedido)
       FROM itens_pedido ip
       JOIN produtos p ON p.id_produto = ip.id_produto
      WHERE p.id_vendedor = v.id_vendedor) AS total_pedidos
FROM vendedores v
ORDER BY faturamento_total DESC
LIMIT 20;


-- ---------------------------------------------------------------------
-- CONSULTA 3: Pedidos realizados em um determinado ano
-- Problema: função YEAR() aplicada à coluna na cláusula WHERE torna a
-- condição "non-sargable" — impede o uso de qualquer índice em data_pedido,
-- mesmo que ele exista.
-- ---------------------------------------------------------------------
SELECT COUNT(*) AS total_pedidos, SUM(valor_total) AS receita
FROM pedidos
WHERE YEAR(data_pedido) = 2024;


-- ---------------------------------------------------------------------
-- CONSULTA 4: Busca de cliente por nome (tela de atendimento / CRM)
-- Problema: LIKE com wildcard à esquerda ('%termo%') não pode usar
-- índice B-Tree tradicional — obriga varredura completa de 60.000 linhas.
-- ---------------------------------------------------------------------
SELECT id_cliente, nome, email, telefone, status_conta
FROM clientes
WHERE nome LIKE '%Silva%';


-- ---------------------------------------------------------------------
-- CONSULTA 5: Top 10 produtos mais vendidos (página inicial / destaques)
-- Problema: agrega ~660.000 linhas de itens_pedido fazendo JOIN com
-- produtos sem nenhum índice de apoio para o GROUP BY / ORDER BY,
-- além de trazer SELECT * desnecessário de produtos.
-- ---------------------------------------------------------------------
SELECT p.*, SUM(ip.quantidade) AS total_vendido
FROM itens_pedido ip
JOIN produtos p ON p.id_produto = ip.id_produto
GROUP BY p.id_produto
ORDER BY total_vendido DESC
LIMIT 10;
