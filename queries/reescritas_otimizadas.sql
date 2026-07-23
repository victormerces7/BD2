-- =====================================================================
-- reescritas_otimizadas.sql
-- Versões otimizadas das 5 consultas de queries/lentas_originais.sql
-- Pré-requisito: aplicar scripts/06_indexes.sql
-- =====================================================================

-- ---------------------------------------------------------------------
-- CONSULTA 1 (otimizada): pedidos entregues em um período
-- Mudança: nenhuma reescrita de SQL foi necessária — o ganho vem 100%
-- do índice composto idx_pedidos_status_data (status, data_pedido),
-- que transforma o full scan em um range scan já ordenado.
-- ---------------------------------------------------------------------
SELECT id_pedido, id_cliente, data_pedido, valor_total, status
FROM pedidos
WHERE status = 'ENTREGUE'
  AND data_pedido BETWEEN '2024-01-01' AND '2024-06-30'
ORDER BY data_pedido DESC;

--correção: CRIAÇÃO DE INDEX IDX_PEDIDOS_STATUS_DATA (status, data_pedido)
-- ---------------------------------------------------------------------
-- CONSULTA 2 (otimizada): faturamento total por vendedor
-- Mudança: as 2 subconsultas correlacionadas (executadas 1x por
-- vendedor) foram substituídas por um único JOIN + GROUP BY,
-- processado em uma única passada pelas tabelas.
-- ---------------------------------------------------------------------
SELECT
    v.id_vendedor,
    v.nome_loja,
    SUM(ip.quantidade * ip.preco_unitario) AS faturamento_total,
    COUNT(DISTINCT ip.id_pedido) AS total_pedidos
FROM vendedores v
JOIN produtos p ON p.id_vendedor = v.id_vendedor
JOIN itens_pedido ip ON ip.id_produto = p.id_produto
GROUP BY v.id_vendedor, v.nome_loja
ORDER BY faturamento_total DESC
LIMIT 20;

--NÃO HOUVE CORREÇÃO
-- ---------------------------------------------------------------------
-- CONSULTA 3 (otimizada): pedidos realizados em um determinado ano
-- Mudança: a condição YEAR(data_pedido) = 2024 (não-sargável) foi
-- reescrita como um intervalo de datas — permitindo o uso do índice
-- idx_pedidos_data. A lógica de negócio é idêntica.
-- ---------------------------------------------------------------------
SELECT COUNT(*) AS total_pedidos, SUM(valor_total) AS receita
FROM pedidos
WHERE data_pedido >= '2024-01-01'
  AND data_pedido <  '2025-01-01';

-- CORREÇÃO: NÃO HOUVE
-- ---------------------------------------------------------------------
-- CONSULTA 4 (otimizada): busca de cliente por nome
-- Mudança: LIKE '%Silva%' foi substituído por busca FULLTEXT em modo
-- booleano com prefixo (Silva*), usando o índice idx_clientes_nome_ft.
-- Observação (trade-off): esta forma localiza nomes que CONTENHAM a
-- palavra "Silva" (ex.: "Maria Silva", "Silva Pereira"), mas não um
-- trecho no MEIO de uma palavra (ex.: "Silvano" não seria igual a
-- LIKE '%Silva%', embora "Silva*" em boolean mode capture prefixos
-- como "Silvano" também). Para os casos de uso reais de um CRM
-- (buscar pelo nome/sobrenome do cliente) o FULLTEXT atende plenamente
-- e é ordens de magnitude mais rápido que o full scan.
-- ---------------------------------------------------------------------
SELECT id_cliente, nome, email, telefone, status_conta
FROM clientes
WHERE nome LIKE '%Silva%';


--CORREÇÃO
SELECT id_cliente, nome, email, telefone, status_conta
FROM clientes
WHERE MATCH(nome) AGAINST('Silva*' IN BOOLEAN MODE);


-- ---------------------------------------------------------------------
-- CONSULTA 5 (otimizada): top 10 produtos mais vendidos
-- Mudança: a agregação SUM(quantidade)/GROUP BY passou a ser feita
-- primeiro (usando o índice covering idx_itens_pedido_produto_qtd),
-- limitada a 10 linhas, e SÓ DEPOIS há o JOIN com produtos — em vez de
-- juntar as ~660 mil linhas de itens_pedido com produtos antes de
-- agregar e ordenar 120 mil produtos.
-- ---------------------------------------------------------------------
SELECT p.*, SUM(ip.quantidade) AS total_vendido
FROM itens_pedido ip
JOIN produtos p ON p.id_produto = ip.id_produto
GROUP BY p.id_produto
ORDER BY total_vendido DESC
LIMIT 10;


--correção
SELECT p.id_produto, p.nome, p.preco_original, p.preco_desconto, top.total_vendido
FROM (
    SELECT id_produto, SUM(quantidade) AS total_vendido
    FROM itens_pedido
    GROUP BY id_produto
    ORDER BY total_vendido DESC
    LIMIT 10
) top
JOIN produtos p ON p.id_produto = top.id_produto
ORDER BY top.total_vendido DESC;


-- =====================================================================
-- OTIMIZAÇÃO AVANÇADA (Consultas 2 e 5): tabela-resumo + trigger
-- =====================================================================
-- Ao medir a Consulta 2 reescrita como JOIN, o resultado foi PIOR que a
-- versão original com subconsultas correlacionadas (ver
-- docs/metricas_comparativas.md). Motivo: o JOIN obriga o MySQL a
-- percorrer as ~660 mil linhas de itens_pedido inteiras para agregar,
-- enquanto as subconsultas correlacionadas, por serem bem indexadas
-- (id_vendedor, id_produto), acessavam só as linhas de cada vendedor.
--
-- A lição: nem toda reescrita de JOIN é mais rápida — depende de quão
-- seletivos são os índices disponíveis. Quando o gargalo real é agregar
-- uma tabela fato inteira em toda consulta, a solução correta não é
-- reescrever a consulta, e sim PARAR de agregar em tempo de consulta.
--
-- Por isso criamos a tabela resumo_vendas_produto (scripts/05_triggers.sql),
-- mantida sempre atualizada por triggers em itens_pedido. As Consultas 2
-- e 5 passam a ler dados já agregados, ao custo de um pequeno overhead
-- em cada INSERT/UPDATE/DELETE de item de pedido (trade-off leitura x
-- escrita, típico de sistemas com muito mais leituras de relatório do
-- que escritas de pedidos).
-- ---------------------------------------------------------------------

-- CONSULTA 5 (avançada): top 10 produtos mais vendidos via tabela-resumo
SELECT p.id_produto, p.nome, p.preco_original, p.preco_desconto,
       r.total_quantidade, r.faturamento_total
FROM resumo_vendas_produto r
JOIN produtos p ON p.id_produto = r.id_produto
ORDER BY r.total_quantidade DESC
LIMIT 10;

-- CONSULTA 2 (avançada): faturamento por vendedor via tabela-resumo
-- (agrega ~120 mil linhas já prontas de resumo_vendas_produto, em vez
-- de ~660 mil linhas cruas de itens_pedido)
SELECT v.id_vendedor, v.nome_loja,
       SUM(r.faturamento_total) AS faturamento_total,
       SUM(r.total_quantidade)  AS itens_vendidos
FROM vendedores v
JOIN produtos p ON p.id_vendedor = v.id_vendedor
JOIN resumo_vendas_produto r ON r.id_produto = p.id_produto
GROUP BY v.id_vendedor, v.nome_loja
ORDER BY faturamento_total DESC
LIMIT 20;
