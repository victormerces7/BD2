#!/usr/bin/env python3
import csv, pymysql, sys, time

conn = pymysql.connect(host="127.0.0.1", user="root", password="senha123", database="marketplace_db", charset="utf8mb4", autocommit=False)
cur = conn.cursor()
cur.execute("SET FOREIGN_KEY_CHECKS=0")
cur.execute("SET UNIQUE_CHECKS=0")
conn.commit()

def nz(v):
    return None if v == "\\N" else v

def load(csvfile, table, cols, batch=200):
    t0 = time.time()
    placeholders = ",".join(["%s"] * len(cols))
    sql = f"INSERT INTO {table} ({','.join(cols)}) VALUES ({placeholders})"
    rows = []
    total = 0
    with open(csvfile, encoding="utf-8") as f:
        reader = csv.reader(f)
        for row in reader:
            rows.append([nz(v) for v in row])
            if len(rows) >= batch:
                cur.executemany(sql, rows)
                conn.commit()
                total += len(rows)
                rows = []
        if rows:
            cur.executemany(sql, rows)
            conn.commit()
            total += len(rows)
    print(f"  {table}: {total} linhas em {time.time()-t0:.1f}s")

load("C:/Users/Victo/Downloads/csv/categorias.csv", "categorias",
     ["id_categoria","id_categoria_pai","nome","slug","descricao"])

load("C:/Users/Victo/Downloads/csv/vendedores.csv", "vendedores",
     ["id_vendedor","nome_loja","razao_social","cnpj","email","telefone",
      "categoria_principal","data_adesao","status_verificacao"])

load("C:/Users/Victo/Downloads/csv/clientes.csv", "clientes",
     ["id_cliente","nome","email","cpf","telefone","genero","data_nascimento",
      "data_cadastro","status_conta"])

load("C:/Users/Victo/Downloads/csv/enderecos.csv", "enderecos",
     ["id_endereco","id_cliente","id_vendedor","tipo_endereco","rua","numero",
      "complemento","bairro","cidade","estado","cep","principal"])

load("C:/Users/Victo/Downloads/csv/produtos.csv", "produtos",
     ["id_produto","id_vendedor","id_categoria","nome","descricao","preco_original",
      "preco_desconto","estoque","sku","ativo","data_cadastro"])

load("C:/Users/Victo/Downloads/csv/pedidos.csv", "pedidos",
     ["id_pedido","id_cliente","id_endereco_entrega","data_pedido","status",
      "valor_produtos","valor_frete","valor_desconto","valor_total","cupom_aplicado"])

load("C:/Users/Victo/Downloads/csv/itens_pedido.csv", "itens_pedido",
     ["id_item_pedido","id_pedido","id_produto","quantidade","preco_unitario","comissao_marketplace"])

load("C:/Users/Victo/Downloads/csv/pagamentos.csv", "pagamentos",
     ["id_pagamento","id_pedido","forma_pagamento","gateway_pagamento","status_pagamento",
      "id_transacao_gateway","parcelas","data_processamento"])

load("C:/Users/Victo/Downloads/csv/avaliacoes.csv", "avaliacoes",
     ["id_avaliacao","id_produto","id_cliente","id_pedido","nota_produto","nota_vendedor",
      "comentario","sentimento_analisado","data_avaliacao"])

cur.execute("SET FOREIGN_KEY_CHECKS=1")
cur.execute("SET UNIQUE_CHECKS=1")
conn.commit()
cur.close()
conn.close()
print("Carga concluída.")
