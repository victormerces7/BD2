#!/usr/bin/env python3
"""
Gerador de massa de dados para o projeto BD2 - Marketplace.
Gera arquivos CSV em /home/claude/csv/ para posterior LOAD DATA INFILE.

Volumes definidos para simular um ambiente real, mas ainda executável
em máquina local em poucos minutos:

    categorias      ~        60
    vendedores      ~     3.000
    clientes        ~    60.000
    enderecos       ~    85.000
    produtos        ~   20.000
    pedidos         ~   30.000
    itens_pedido    ~   75.000
    pagamentos      ~   30.000
    avaliacoes      ~   15.000
    -----------------------------
    TOTAL           ~ 1.768.000 linhas
"""
import csv
import random
from datetime import datetime, timedelta
from faker import Faker

fake = Faker("pt_BR")
Faker.seed(42)
random.seed(42)

OUT = "/home/claude/csv"
import os
os.makedirs(OUT, exist_ok=True)

N_CLIENTES = 60_000
N_VENDEDORES = 3_000
N_PRODUTOS = 120_000
N_PEDIDOS = 300_000
N_AVALIACOES = 150_000

ESTADOS = ["SP","RJ","MG","BA","PR","RS","PE","CE","SC","GO","DF","AM","PA","ES","MA"]
STATUS_CONTA = ["ATIVO","ATIVO","ATIVO","ATIVO","INATIVO","BLOQUEADO"]
STATUS_PEDIDO = ["ENTREGUE","ENTREGUE","ENTREGUE","ENTREGUE","ENVIADO","PROCESSANDO","CANCELADO","PENDENTE"]
FORMAS_PGTO = ["CARTAO_CREDITO","CARTAO_DEBITO","PIX","BOLETO"]
STATUS_PGTO = ["APROVADO","APROVADO","APROVADO","APROVADO","RECUSADO","PROCESSANDO","ESTORNADO"]

CATEGORIAS_PAI = ["Eletrônicos","Moda","Casa e Decoração","Esporte e Lazer","Beleza e Saúde",
                  "Livros","Brinquedos","Automotivo","Alimentos e Bebidas","Pet Shop"]
SUBCATEGORIAS = {
    "Eletrônicos": ["Smartphones","Notebooks","TVs","Fones de Ouvido","Câmeras"],
    "Moda": ["Roupas Femininas","Roupas Masculinas","Calçados","Acessórios","Bolsas"],
    "Casa e Decoração": ["Móveis","Utensílios de Cozinha","Cama Mesa e Banho","Iluminação"],
    "Esporte e Lazer": ["Fitness","Ciclismo","Camping","Suplementos"],
    "Beleza e Saúde": ["Maquiagem","Perfumaria","Cuidados com a Pele","Higiene"],
    "Livros": ["Ficção","Não-Ficção","Didáticos","HQs e Mangás"],
    "Brinquedos": ["Educativos","Bonecas e Bonecos","Jogos de Tabuleiro"],
    "Automotivo": ["Acessórios para Carro","Peças","Som Automotivo"],
    "Alimentos e Bebidas": ["Mercearia","Bebidas","Snacks"],
    "Pet Shop": ["Ração","Acessórios para Pets","Higiene Pet"],
}

def fake_cpf(i):
    d = f"{i:09d}"
    return f"{d[0:3]}.{d[3:6]}.{d[6:9]}-{i%100:02d}"

def fake_cnpj(i):
    d = f"{i:08d}"
    return f"{d[0:2]}.{d[2:5]}.{d[5:8]}/0001-{i%100:02d}"

def slugify(s):
    import unicodedata
    s = unicodedata.normalize("NFKD", s).encode("ascii","ignore").decode()
    return s.lower().replace(" ", "-")

def rand_date(start_year=2019, end_year=2026):
    start = datetime(start_year,1,1)
    end = datetime(end_year,7,20)
    delta = end - start
    return start + timedelta(seconds=random.randint(0, int(delta.total_seconds())))

# ---------------------------------------------------------------
# 1. CATEGORIAS
# ---------------------------------------------------------------
print("Gerando categorias...")
categorias = []  # (id, id_pai, nome, slug, descricao)
cid = 1
pai_ids = {}
for pai in CATEGORIAS_PAI:
    categorias.append((cid, "\\N", pai, slugify(pai), f"Produtos da categoria {pai}"))
    pai_ids[pai] = cid
    cid += 1
for pai, subs in SUBCATEGORIAS.items():
    for sub in subs:
        nome_completo = f"{sub}"
        categorias.append((cid, pai_ids[pai], nome_completo, slugify(f"{pai}-{sub}"), f"{sub} - subcategoria de {pai}"))
        cid += 1

with open(f"{OUT}/categorias.csv","w",newline="",encoding="utf-8") as f:
    w = csv.writer(f)
    w.writerows(categorias)

n_categorias = len(categorias)
categoria_ids = [c[0] for c in categorias]
print(f"  -> {n_categorias} categorias")

# ---------------------------------------------------------------
# 2. VENDEDORES
# ---------------------------------------------------------------
print("Gerando vendedores...")
with open(f"{OUT}/vendedores.csv","w",newline="",encoding="utf-8") as f:
    w = csv.writer(f)
    for i in range(1, N_VENDEDORES+1):
        nome_loja = fake.company()
        w.writerow([
            i, nome_loja[:150], fake.company_suffix() and f"{nome_loja} LTDA"[:150],
            fake_cnpj(i), f"vendedor{i}@{fake.free_email_domain()}",
            fake.phone_number()[:20], random.choice(CATEGORIAS_PAI),
            rand_date(2018,2025).strftime("%Y-%m-%d %H:%M:%S"),
            random.choice(["VERIFICADO","VERIFICADO","VERIFICADO","PENDENTE"])
        ])
print(f"  -> {N_VENDEDORES} vendedores")

# ---------------------------------------------------------------
# 3. CLIENTES
# ---------------------------------------------------------------
print("Gerando clientes...")
with open(f"{OUT}/clientes.csv","w",newline="",encoding="utf-8") as f:
    w = csv.writer(f)
    for i in range(1, N_CLIENTES+1):
        genero = random.choice(["M","F","OUTRO"])
        nome = fake.name_male() if genero == "M" else (fake.name_female() if genero == "F" else fake.name())
        w.writerow([
            i, nome[:150], f"cliente{i}@{fake.free_email_domain()}",
            fake_cpf(i), fake.phone_number()[:20], genero,
            fake.date_of_birth(minimum_age=16, maximum_age=85).strftime("%Y-%m-%d"),
            rand_date(2019,2026).strftime("%Y-%m-%d %H:%M:%S"),
            random.choice(STATUS_CONTA)
        ])
print(f"  -> {N_CLIENTES} clientes")

# ---------------------------------------------------------------
# 4. ENDERECOS (para clientes e vendedores)
# ---------------------------------------------------------------
print("Gerando enderecos...")
eid = 1
enderecos_rows = []
with open(f"{OUT}/enderecos.csv","w",newline="",encoding="utf-8") as f:
    w = csv.writer(f)
    for c in range(1, N_CLIENTES+1):
        # a maioria dos clientes tem 1 endereço, alguns tem 2
        n_end = 1 if random.random() < 0.8 else 2
        for k in range(n_end):
            w.writerow([
                eid, c, "\\N", random.choice(["RESIDENCIAL","COMERCIAL"]),
                fake.street_name()[:150], str(random.randint(1,2000)),
                (f"Apto {random.randint(1,300)}") if random.random()<0.3 else "\\N",
                fake.bairro()[:100], fake.city()[:100], random.choice(ESTADOS),
                fake.postcode(), 1 if k==0 else 0
            ])
            eid += 1
    for v in range(1, N_VENDEDORES+1):
        w.writerow([
            eid, "\\N", v, "COMERCIAL",
            fake.street_name()[:150], str(random.randint(1,2000)), "\\N",
            fake.bairro()[:100], fake.city()[:100], random.choice(ESTADOS),
            fake.postcode(), 1
        ])
        eid += 1
n_enderecos = eid - 1
print(f"  -> {n_enderecos} enderecos")

# ids de endereco por cliente (para usar em pedidos)
# recarrega rapidamente do csv para mapear cliente -> lista de enderecos
cliente_enderecos = {}
with open(f"{OUT}/enderecos.csv", encoding="utf-8") as f:
    r = csv.reader(f)
    for row in r:
        if row[1] != "\\N":
            cliente_enderecos.setdefault(int(row[1]), []).append(int(row[0]))

# ---------------------------------------------------------------
# 5. PRODUTOS
# ---------------------------------------------------------------
print("Gerando produtos...")
ADJETIVOS = ["Premium","Compacto","Profissional","Portátil","Clássico","Moderno","Essencial","Deluxe"]
with open(f"{OUT}/produtos.csv","w",newline="",encoding="utf-8") as f:
    w = csv.writer(f)
    for i in range(1, N_PRODUTOS+1):
        vendedor = random.randint(1, N_VENDEDORES)
        categoria = random.choice(categoria_ids)
        preco = round(random.uniform(15, 5000), 2)
        tem_desconto = random.random() < 0.35
        preco_desconto = round(preco * random.uniform(0.5, 0.9), 2) if tem_desconto else "\\N"
        nome_produto = f"{random.choice(ADJETIVOS)} {fake.word().capitalize()} {fake.word().capitalize()}"
        w.writerow([
            i, vendedor, categoria, nome_produto[:150],
            fake.text(max_nb_chars=200).replace("\n"," "),
            preco, preco_desconto, random.randint(0, 500),
            f"SKU-{i:08d}", 1 if random.random() < 0.92 else 0,
            rand_date(2019,2026).strftime("%Y-%m-%d %H:%M:%S")
        ])
print(f"  -> {N_PRODUTOS} produtos")

# ---------------------------------------------------------------
# 6. PEDIDOS + ITENS_PEDIDO + PAGAMENTOS
# ---------------------------------------------------------------
print("Gerando pedidos, itens_pedido e pagamentos...")
CUPONS = ["\\N","\\N","\\N","\\N","\\N","BEMVINDO10","FRETEGRATIS","BLACKFRIDAY","NATAL15"]

f_ped = open(f"{OUT}/pedidos.csv","w",newline="",encoding="utf-8")
f_item = open(f"{OUT}/itens_pedido.csv","w",newline="",encoding="utf-8")
f_pag = open(f"{OUT}/pagamentos.csv","w",newline="",encoding="utf-8")
w_ped, w_item, w_pag = csv.writer(f_ped), csv.writer(f_item), csv.writer(f_pag)

item_id = 1
clientes_com_endereco = list(cliente_enderecos.keys())

pedidos_ids_validos = []  # para avaliacoes depois: (id_pedido, id_cliente, lista_produtos)
pedido_produto_cliente = []

for pid in range(1, N_PEDIDOS+1):
    cliente = random.choice(clientes_com_endereco)
    endereco = random.choice(cliente_enderecos[cliente])
    data_pedido = rand_date(2019, 2026)
    status = random.choice(STATUS_PEDIDO)

    n_itens = random.choices([1,2,3,4,5], weights=[35,30,20,10,5])[0]
    produtos_pedido = random.sample(range(1, N_PRODUTOS+1), n_itens)
    valor_produtos = 0
    for prod in produtos_pedido:
        qtd = random.randint(1,3)
        preco_unit = round(random.uniform(15,5000),2)
        comissao = round(preco_unit * qtd * 0.12, 2)
        valor_produtos += preco_unit * qtd
        w_item.writerow([item_id, pid, prod, qtd, preco_unit, comissao])
        item_id += 1

    frete = round(random.uniform(0, 60), 2)
    desconto = round(valor_produtos * random.choice([0,0,0,0.05,0.1]), 2)
    total = round(valor_produtos + frete - desconto, 2)

    w_ped.writerow([pid, cliente, endereco, data_pedido.strftime("%Y-%m-%d %H:%M:%S"),
                     status, round(valor_produtos,2), frete, desconto, total, random.choice(CUPONS)])

    if status not in ("CANCELADO","PENDENTE"):
        data_proc = (data_pedido + timedelta(minutes=random.randint(1,120)))
        w_pag.writerow([pid, pid, random.choice(FORMAS_PGTO), random.choice(["GATEWAY_A","GATEWAY_B","GATEWAY_C"]),
                         random.choice(STATUS_PGTO), fake.uuid4(), random.choice([1,1,2,3,6,10,12]),
                         data_proc.strftime("%Y-%m-%d %H:%M:%S")])

    if status == "ENTREGUE":
        pedido_produto_cliente.append((pid, cliente, produtos_pedido))

    if pid % 50000 == 0:
        print(f"  ... {pid} pedidos gerados")

f_ped.close(); f_item.close(); f_pag.close()
print(f"  -> {N_PEDIDOS} pedidos, {item_id-1} itens_pedido")

# ---------------------------------------------------------------
# 7. AVALIACOES (apenas pedidos ENTREGUES)
# ---------------------------------------------------------------
print("Gerando avaliacoes...")
COMENTARIOS_POS = ["Produto excelente, superou expectativas!","Ótima qualidade e entrega rápida.",
                    "Recomendo, chegou antes do prazo.","Muito satisfeito com a compra."]
COMENTARIOS_NEU = ["Produto ok, dentro do esperado.","Cumpre o que promete.","Nada excepcional, mas funcional."]
COMENTARIOS_NEG = ["Veio com defeito, não recomendo.","Demorou muito para chegar.","Qualidade abaixo do esperado."]

with open(f"{OUT}/avaliacoes.csv","w",newline="",encoding="utf-8") as f:
    w = csv.writer(f)
    aval_id = 1
    amostras = random.sample(pedido_produto_cliente, min(N_AVALIACOES, len(pedido_produto_cliente)))
    for pid, cliente, produtos_pedido in amostras:
        prod = random.choice(produtos_pedido)
        nota = random.choices([5,4,3,2,1], weights=[40,30,15,10,5])[0]
        if nota >= 4:
            coment, sent = random.choice(COMENTARIOS_POS), "POSITIVO"
        elif nota == 3:
            coment, sent = random.choice(COMENTARIOS_NEU), "NEUTRO"
        else:
            coment, sent = random.choice(COMENTARIOS_NEG), "NEGATIVO"
        nota_vendedor = max(1, min(5, nota + random.choice([-1,0,0,1])))
        w.writerow([aval_id, prod, cliente, pid, nota, nota_vendedor, coment, sent,
                    rand_date(2019,2026).strftime("%Y-%m-%d %H:%M:%S")])
        aval_id += 1
print(f"  -> {aval_id-1} avaliacoes")

print("\nCSV gerados em", OUT)
