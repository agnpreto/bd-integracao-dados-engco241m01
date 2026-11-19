-- DDL corrigido para MySQL

CREATE TABLE fornecedor (
    idfornecedor INTEGER AUTO_INCREMENT PRIMARY KEY,
    codigo_origem VARCHAR(25) UNIQUE,
    razao_social VARCHAR(255) NOT NULL
);

CREATE TABLE produtos_filial (
    filial_id INTEGER NOT NULL,
    produto_id VARCHAR(25) NOT NULL,
    descricao VARCHAR(255) NOT NULL,
    estoque NUMERIC(16, 4) NOT NULL,
    preco_unitario NUMERIC(16, 4),
    preco_compra NUMERIC(16, 4),
    preco_venda NUMERIC(16, 4),
    idfornecedor INTEGER,
    PRIMARY KEY (filial_id, produto_id),
    FOREIGN KEY (idfornecedor) REFERENCES fornecedor (idfornecedor)
);

CREATE TABLE venda (
    venda_id BIGINT NOT NULL,
    data_emissao DATE NOT NULL,
    horariomov TIME NOT NULL,
    produto_id VARCHAR(25) NOT NULL,
    qtde_vendida NUMERIC(16, 4),
    valor_unitario NUMERIC(16, 4) NOT NULL,
    filial_id INTEGER NOT NULL,
    item INTEGER NOT NULL,
    unidade_medida VARCHAR(3),
    PRIMARY KEY (filial_id, venda_id, data_emissao, produto_id, item, horariomov)
);

CREATE TABLE pedido_compra (
    pedido_id BIGINT NOT NULL,
    data_pedido DATE,
    item INTEGER NOT NULL,
    produto_id VARCHAR(25) NOT NULL,
    descricao_produto VARCHAR(255),
    ordem_compra BIGINT,
    qtde_pedida NUMERIC(16, 4),
    filial_id INTEGER,
    data_entrega DATE,
    qtde_entregue NUMERIC(16, 4),
    qtde_pendente NUMERIC(16, 4),
    preco_compra NUMERIC(16, 4),
    fornecedor_id INTEGER,
    PRIMARY KEY (pedido_id, produto_id, item)
);

CREATE TABLE entradas_mercadoria (
    data_entrada DATE,
    nro_nfe VARCHAR(255) NOT NULL,
    item INTEGER NOT NULL,
    produto_id VARCHAR(25) NOT NULL,
    descricao_produto VARCHAR(255),
    ordem_compra BIGINT NOT NULL,
    qtde_recebida NUMERIC(16, 4),
    filial_id INTEGER,
    custo_unitario NUMERIC(16, 4),
    PRIMARY KEY (ordem_compra, item, produto_id, nro_nfe)
);

-- Guarda os valores das colunas sem cabeçalho na aba pedido_compra.
CREATE TABLE pedido_colunas_extras (
    linha_excel INTEGER PRIMARY KEY,
    pedido_id BIGINT NOT NULL,
    valores TEXT NOT NULL
);
