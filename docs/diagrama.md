# Diagrama entidade-relacionamento

```mermaid
erDiagram
    CLIENTE ||--o{ ENDERECO : "cadastra"
    VENDEDOR ||--o{ ENDERECO : "possui"
    CLIENTE ||--o{ PEDIDO : "faz"
    VENDEDOR ||--o{ PRODUTO : "cadastra"
    CATEGORIA ||--o{ PRODUTO : "classifica"
    CATEGORIA |o--o{ CATEGORIA : "possui subcategorias"
    PRODUTO ||--o{ ITEM_PEDIDO : "consta em"
    PEDIDO ||--|{ ITEM_PEDIDO : "contem"
    PEDIDO ||--|| PAGAMENTO : "possui"
    PEDIDO ||--|| ENDERECO : "entrega em"
    PRODUTO ||--o{ AVALIACAO : "recebe"
    CLIENTE ||--o{ AVALIACAO : "escreve"

    CLIENTE {
        idCliente int PK
        nome string
        email string UK
        cpf string UK
        telefone string
        genero string
        data_nascimento date
        data_cadastro datetime
        status_conta string
    }

    VENDEDOR {
        idVendedor int PK
        nome_loja string
        razao_social string
        cnpj string UK
        email string UK
        telefone string
        categoria_principal string
        data_adesao datetime
        status_verificacao string
    }

    ENDERECO {
        idEndereco int PK
        idCliente int FK "Nulo se for do vendedor"
        idVendedor int FK "Nulo se for do cliente"
        tipo_endereco string
        rua string
        numero string
        complemento string
        bairro string
        cidade string
        estado string
        cep string
        principal boolean
    }

    CATEGORIA {
        idCategoria int PK
        idCategoriaPai int FK "Para criar subcategorias"
        nome string
        slug string UK
        descricao string
    }

    PRODUTO {
        idProduto int PK
        idVendedor int FK
        idCategoria int FK
        nome string
        descricao string
        preco_original decimal
        preco_desconto decimal
        estoque int
        sku string UK
        ativo boolean
        data_cadastro datetime
    }

    PEDIDO {
        idPedido int PK
        idCliente int FK
        idEnderecoEntrega int FK
        data_pedido datetime
        status string
        valor_produtos decimal
        valor_frete decimal
        valor_desconto decimal
        valor_total decimal
        cupom_aplicado string
    }

    ITEM_PEDIDO {
        idItemPedido int PK
        idPedido int FK
        idProduto int FK
        quantidade int
        preco_unitario decimal
        comissao_marketplace decimal
    }

    PAGAMENTO {
        idPagamento int PK
        idPedido int FK "UK"
        forma_pagamento string
        gateway_pagamento string
        status_pagamento string
        id_transacao_gateway string
        parcelas int
        data_processamento datetime
    }

    AVALIACAO {
        idAvaliacao int PK
        idProduto int FK
        idCliente int FK
        idPedido int FK
        nota_produto int
        nota_vendedor int
        comentario string
        sentimento_analisado string
        data_avaliacao datetime
    }
