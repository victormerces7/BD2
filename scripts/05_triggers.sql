-- =====================================================================
-- 05_triggers.sql
-- Triggers do projeto Marketplace
-- =====================================================================

DELIMITER $$

-- ---------------------------------------------------------------------
-- TRIGGER 1, 2 e 3 — mantêm a tabela resumo_vendas_produto sincronizada
-- com itens_pedido. Essa tabela é a base da otimização "avançada" das
-- Consultas 2 e 5 (ver docs/metricas_comparativas.md): em vez de agregar
-- ~660 mil linhas em tempo de consulta, o resumo é mantido incrementalmente
-- a cada operação, e as consultas de relatório passam a ler poucas linhas
-- já prontas.
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_itens_pedido_after_insert
AFTER INSERT ON itens_pedido
FOR EACH ROW
BEGIN
    INSERT INTO resumo_vendas_produto (id_produto, total_quantidade, faturamento_total)
    VALUES (NEW.id_produto, NEW.quantidade, NEW.quantidade * NEW.preco_unitario)
    ON DUPLICATE KEY UPDATE
        total_quantidade = total_quantidade + NEW.quantidade,
        faturamento_total = faturamento_total + (NEW.quantidade * NEW.preco_unitario);
END$$

CREATE TRIGGER trg_itens_pedido_after_update
AFTER UPDATE ON itens_pedido
FOR EACH ROW
BEGIN
    UPDATE resumo_vendas_produto
       SET total_quantidade  = total_quantidade  - OLD.quantidade + NEW.quantidade,
           faturamento_total = faturamento_total - (OLD.quantidade * OLD.preco_unitario)
                                                  + (NEW.quantidade * NEW.preco_unitario)
     WHERE id_produto = NEW.id_produto;
END$$

CREATE TRIGGER trg_itens_pedido_after_delete
AFTER DELETE ON itens_pedido
FOR EACH ROW
BEGIN
    UPDATE resumo_vendas_produto
       SET total_quantidade  = total_quantidade  - OLD.quantidade,
           faturamento_total = faturamento_total - (OLD.quantidade * OLD.preco_unitario)
     WHERE id_produto = OLD.id_produto;
END$$

-- ---------------------------------------------------------------------
-- TRIGGER 4 — trava de integridade de negócio: impede que um pedido
-- seja marcado como 'ENTREGUE' se ainda não existe um pagamento
-- 'APROVADO' associado a ele. Evita inconsistência operacional.
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_pedidos_valida_entrega
BEFORE UPDATE ON pedidos
FOR EACH ROW
BEGIN
    IF NEW.status = 'ENTREGUE' AND OLD.status <> 'ENTREGUE' THEN
        IF NOT EXISTS (
            SELECT 1 FROM pagamentos
             WHERE id_pedido = NEW.id_pedido
               AND status_pagamento = 'APROVADO'
        ) THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Não é possível marcar como ENTREGUE um pedido sem pagamento APROVADO.';
        END IF;
    END IF;
END$$

-- ---------------------------------------------------------------------
-- TRIGGER 5 — recalcula automaticamente o valor_total do pedido sempre
-- que valor_produtos, valor_frete ou valor_desconto forem alterados,
-- evitando que a aplicação precise repetir essa regra de negócio.
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_pedidos_recalcula_total
BEFORE UPDATE ON pedidos
FOR EACH ROW
BEGIN
    IF NEW.valor_produtos <> OLD.valor_produtos
       OR NEW.valor_frete <> OLD.valor_frete
       OR NEW.valor_desconto <> OLD.valor_desconto THEN
        SET NEW.valor_total = NEW.valor_produtos + NEW.valor_frete - NEW.valor_desconto;
    END IF;
END$$

DELIMITER ;
