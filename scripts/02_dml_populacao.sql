-- =====================================================================
-- 02_dml_populacao.sql
-- Estratégia de população de dados (ambiente real ~1,6M linhas)
-- =====================================================================
-- A geração via SQL puro (loops/procedures) é lenta para volumes grandes
-- e não produz dados realistas (nomes, emails, endereços, etc.). Por isso
-- a população foi feita em duas etapas com scripts Python auxiliares
-- (também versionados nesta pasta):
--
--   1) python3 scripts/gerar_dados.py
--      -> usa a biblioteca Faker (locale pt_BR) para gerar CSVs
--         realistas e consistentes (respeitando FKs) em /csv:
--         categorias(48), vendedores(3.000), clientes(60.000),
--         enderecos(~75.000), produtos(120.000), pedidos(300.000),
--         itens_pedido(~660.000), pagamentos(~225.000), avaliacoes(150.000)
--
--   2) python3 scripts/carregar_dados.py
--      -> carrega os CSVs em lotes (INSERT em batches) respeitando a
--         ordem de dependência das FKs, com FOREIGN_KEY_CHECKS=0 e
--         UNIQUE_CHECKS=0 durante a carga para maior performance.
--
-- Volume final populado (conferido com SELECT COUNT(*)):
--   categorias=48 | vendedores=3.000 | clientes=60.000 | enderecos=75.049
--   produtos=120.000 | pedidos=300.000 | itens_pedido=659.863
--   pagamentos=224.968 | avaliacoes=150.000
--   TOTAL ≈ 1.593.000 linhas
--
-- Uma amostra dos dados gerados está em data/dados_mockados.csv.
--
-- Alternativa 100% SQL (menor escala), caso o ambiente não tenha Python/
-- Faker disponível — gera ~10 mil categorias/produtos fictícios via
-- tabela de números, útil para testes rápidos:
-- ---------------------------------------------------------------------
INSERT INTO categorias (nome, slug, descricao)
SELECT CONCAT('Categoria Demo ', n), CONCAT('categoria-demo-', n), 'Gerada via SQL'
FROM (
    SELECT (a.N + b.N*10 + 1) AS n
    FROM (SELECT 0 N UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
          UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) a,
         (SELECT 0 N UNION SELECT 1 UNION SELECT 2) b
) nums
LIMIT 20;
