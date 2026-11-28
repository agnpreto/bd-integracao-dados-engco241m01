-- Banco de Dados (ENGCO241M01) - MySQL 8.0+
-- Antes de executar: CREATE DATABASE IF NOT EXISTS integracao_dados;
-- USE integracao_dados;  (nao usa o schema public do PostgreSQL)

CREATE TABLE IF NOT EXISTS fornecedor (
    idfornecedor VARCHAR(25) NOT NULL PRIMARY KEY,
    razao_social VARCHAR(255) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS produtos_filial (
    filial_id INT NOT NULL,
    produto_id VARCHAR(25) NOT NULL,
    descricao VARCHAR(255) NOT NULL,
    estoque DECIMAL(18,3) NOT NULL DEFAULT 0,
    preco_unitario DECIMAL(14,4) NOT NULL DEFAULT 0,
    preco_compra DECIMAL(14,4) NOT NULL DEFAULT 0,
    preco_venda DECIMAL(14,4) NOT NULL DEFAULT 0,
    idfornecedor VARCHAR(25),
    CONSTRAINT pk_produtos_filial PRIMARY KEY (filial_id, produto_id),
    CONSTRAINT fk_produtos_fornecedor FOREIGN KEY (idfornecedor)
        REFERENCES fornecedor(idfornecedor)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS pedido_compra (
    pedido_id BIGINT NOT NULL,
    data_pedido DATE,
    item INT NOT NULL DEFAULT 0,
    produto_id VARCHAR(25) NOT NULL,
    descricao_produto VARCHAR(255),
    ordem_compra BIGINT NOT NULL DEFAULT 0,
    qtde_pedida DECIMAL(18,3),
    filial_id INT,
    data_entrega DATE,
    qtde_entregue DECIMAL(18,3) NOT NULL DEFAULT 0,
    qtde_pendente DECIMAL(18,3) NOT NULL DEFAULT 0,
    preco_compra DECIMAL(14,4),
    fornecedor_id VARCHAR(25),
    CONSTRAINT pk_pedido_compra PRIMARY KEY (pedido_id, produto_id, item),
    CONSTRAINT fk_pedido_fornecedor FOREIGN KEY (fornecedor_id)
        REFERENCES fornecedor(idfornecedor),
    INDEX idx_pedido_data_produto (data_pedido, produto_id),
    INDEX idx_pedido_ordem (ordem_compra, item, produto_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS entradas_mercadoria (
    data_entrada DATE,
    nro_nfe VARCHAR(255) NOT NULL,
    item INT NOT NULL DEFAULT 0,
    produto_id VARCHAR(25) NOT NULL,
    descricao_produto VARCHAR(255),
    ordem_compra BIGINT NOT NULL DEFAULT 0,
    qtde_recebida DECIMAL(18,3),
    filial_id INT,
    custo_unitario DECIMAL(14,4) NOT NULL DEFAULT 0,
    CONSTRAINT pk_entradas_mercadoria PRIMARY KEY
        (ordem_compra, item, produto_id, nro_nfe),
    INDEX idx_entrada_ordem (ordem_compra, item, produto_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS venda (
    venda_id BIGINT NOT NULL,
    data_emissao DATE NOT NULL,
    horariomov VARCHAR(8) NOT NULL DEFAULT '00:00:00',
    produto_id VARCHAR(25) NOT NULL,
    qtde_vendida DECIMAL(18,3),
    valor_unitario DECIMAL(14,4) NOT NULL DEFAULT 0,
    filial_id BIGINT NOT NULL DEFAULT 1,
    item INT NOT NULL DEFAULT 0,
    unidade_medida VARCHAR(3),
    CONSTRAINT pk_venda PRIMARY KEY
        (filial_id, venda_id, data_emissao, produto_id, item, horariomov),
    INDEX idx_venda_emissao_produto (data_emissao, produto_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
