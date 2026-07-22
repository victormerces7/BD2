-- =====================================================================
-- 01_ddl_tabelas.sql
-- Estrutura do banco (herdada da Avaliação 1) - Marketplace / E-commerce
-- SGBD: MySQL / MariaDB
-- =====================================================================

-- 1. Criação das tabelas base (sem dependências)
CREATE TABLE clientes (
    id_cliente INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(150) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    cpf VARCHAR(14) NOT NULL UNIQUE,
    telefone VARCHAR(20),
    genero VARCHAR(20),
    data_nascimento DATE,
    data_cadastro DATETIME DEFAULT CURRENT_TIMESTAMP,
    status_conta VARCHAR(20) DEFAULT 'ATIVO'
);

CREATE TABLE vendedores (
    id_vendedor INT AUTO_INCREMENT PRIMARY KEY,
    nome_loja VARCHAR(150) NOT NULL,
    razao_social VARCHAR(150) NOT NULL,
    cnpj VARCHAR(20) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL UNIQUE,
    telefone VARCHAR(20),
    categoria_principal VARCHAR(50),
    data_adesao DATETIME DEFAULT CURRENT_TIMESTAMP,
    status_verificacao VARCHAR(20) DEFAULT 'PENDENTE'
);

CREATE TABLE categorias (
    id_categoria INT AUTO_INCREMENT PRIMARY KEY,
    id_categoria_pai INT,
    nome VARCHAR(100) NOT NULL,
    slug VARCHAR(100) UNIQUE,
    descricao TEXT,
    FOREIGN KEY (id_categoria_pai) REFERENCES categorias(id_categoria)
);

-- 2. Tabelas dependentes de Nível 1
CREATE TABLE enderecos (
    id_endereco INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT, -- Pode ser nulo se for endereço de vendedor
    id_vendedor INT, -- Pode ser nulo se for endereço de cliente
    tipo_endereco VARCHAR(50),
    rua VARCHAR(150) NOT NULL,
    numero VARCHAR(20),
    complemento VARCHAR(100),
    bairro VARCHAR(100),
    cidade VARCHAR(100),
    estado CHAR(2),
    cep VARCHAR(10) NOT NULL,
    principal BOOLEAN DEFAULT TRUE,
    FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente),
    FOREIGN KEY (id_vendedor) REFERENCES vendedores(id_vendedor)
);

CREATE TABLE produtos (
    id_produto INT AUTO_INCREMENT PRIMARY KEY,
    id_vendedor INT NOT NULL,
    id_categoria INT NOT NULL,
    nome VARCHAR(150) NOT NULL,
    descricao TEXT,
    preco_original DECIMAL(10,2) NOT NULL,
    preco_desconto DECIMAL(10,2),
    estoque INT NOT NULL DEFAULT 0,
    sku VARCHAR(50) UNIQUE,
    ativo BOOLEAN DEFAULT TRUE,
    data_cadastro DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_vendedor) REFERENCES vendedores(id_vendedor),
    FOREIGN KEY (id_categoria) REFERENCES categorias(id_categoria)
);

-- 3. Tabelas dependentes de Nível 2
CREATE TABLE pedidos (
    id_pedido INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT NOT NULL,
    id_endereco_entrega INT NOT NULL,
    data_pedido DATETIME DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(50) DEFAULT 'PENDENTE',
    valor_produtos DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    valor_frete DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    valor_desconto DECIMAL(10,2) DEFAULT 0.00,
    valor_total DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    cupom_aplicado VARCHAR(50),
    FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente),
    FOREIGN KEY (id_endereco_entrega) REFERENCES enderecos(id_endereco)
);

-- 4. Tabelas dependentes de Nível 3 (Fechamento do ciclo do pedido)
CREATE TABLE itens_pedido (
    id_item_pedido INT AUTO_INCREMENT PRIMARY KEY,
    id_pedido INT NOT NULL,
    id_produto INT NOT NULL,
    quantidade INT NOT NULL,
    preco_unitario DECIMAL(10,2) NOT NULL,
    comissao_marketplace DECIMAL(10,2),
    FOREIGN KEY (id_pedido) REFERENCES pedidos(id_pedido),
    FOREIGN KEY (id_produto) REFERENCES produtos(id_produto)
);

CREATE TABLE pagamentos (
    id_pagamento INT AUTO_INCREMENT PRIMARY KEY,
    id_pedido INT NOT NULL UNIQUE, -- UNIQUE garante a relação 1:1 com pedido
    forma_pagamento VARCHAR(50) NOT NULL,
    gateway_pagamento VARCHAR(50),
    status_pagamento VARCHAR(50) DEFAULT 'PROCESSANDO',
    id_transacao_gateway VARCHAR(100),
    parcelas INT DEFAULT 1,
    data_processamento DATETIME,
    FOREIGN KEY (id_pedido) REFERENCES pedidos(id_pedido)
);

CREATE TABLE avaliacoes (
    id_avaliacao INT AUTO_INCREMENT PRIMARY KEY,
    id_produto INT NOT NULL,
    id_cliente INT NOT NULL,
    id_pedido INT NOT NULL,
    nota_produto INT CHECK (nota_produto BETWEEN 1 AND 5),
    nota_vendedor INT CHECK (nota_vendedor BETWEEN 1 AND 5),
    comentario TEXT,
    sentimento_analisado VARCHAR(50),
    data_avaliacao DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_produto) REFERENCES produtos(id_produto),
    FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente),
    FOREIGN KEY (id_pedido) REFERENCES pedidos(id_pedido)
);
