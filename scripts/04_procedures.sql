-- =====================================================================
-- 04_procedures.sql — Stored Procedures do projeto Marketplace
-- =====================================================================
DELIMITER $$

-- PROC 1: fecha um pedido — cria o pagamento e (se aprovado) atualiza
-- o status, tudo em uma transação, validado pelo trigger de negócio.
CREATE PROCEDURE sp_fechar_pedido(
    IN p_id_pedido INT,
    IN p_forma_pagamento VARCHAR(50),
    IN p_gateway VARCHAR(50)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    INSERT INTO pagamentos (id_pedido, forma_pagamento, gateway_pagamento,
                             status_pagamento, id_transacao_gateway, data_processamento)
    VALUES (p_id_pedido, p_forma_pagamento, p_gateway, 'APROVADO',
            UUID(), NOW());

    UPDATE pedidos SET status = 'ENTREGUE' WHERE id_pedido = p_id_pedido;

    COMMIT;
END$$

-- PROC 2: relatório de faturamento por vendedor em um período,
-- usando a tabela-resumo (rápido) filtrada por data via itens_pedido
-- apenas quando necessário.
CREATE PROCEDURE sp_relatorio_faturamento_vendedor(IN p_top_n INT)
BEGIN
    SELECT v.id_vendedor, v.nome_loja,
           SUM(r.faturamento_total) AS faturamento_total,
           SUM(r.total_quantidade)  AS itens_vendidos
    FROM vendedores v
    JOIN produtos p ON p.id_vendedor = v.id_vendedor
    JOIN resumo_vendas_produto r ON r.id_produto = p.id_produto
    GROUP BY v.id_vendedor, v.nome_loja
    ORDER BY faturamento_total DESC
    LIMIT p_top_n;
END$$

-- PROC 3: reprocessa do zero a tabela-resumo (manutenção/correção,
-- caso seja necessário recalcular após uma migração de dados em massa)
CREATE PROCEDURE sp_reprocessar_resumo_vendas()
BEGIN
    TRUNCATE TABLE resumo_vendas_produto;
    INSERT INTO resumo_vendas_produto (id_produto, total_quantidade, faturamento_total)
    SELECT id_produto, SUM(quantidade), SUM(quantidade*preco_unitario)
    FROM itens_pedido
    GROUP BY id_produto;
END$$

DELIMITER ;
