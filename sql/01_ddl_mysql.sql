-- 01_ddl_mysql.sql  (MySQL 8+)
-- Mesmas correcoes da versao PostgreSQL, com sintaxe MySQL:
-- sem prefixo "public.", DECIMAL, BIGINT, InnoDB.
-- OBS: a carga dos dados foi feita e conferida no PostgreSQL; este script nao foi executado em MySQL.

CREATE TABLE fornecedor (
    idfornecedor  INT          NOT NULL,   -- numerico (planilha traz 'F1'; prefixo removido na carga)
    razao_social  VARCHAR(255) NOT NULL,
    CONSTRAINT pk_fornecedor PRIMARY KEY (idfornecedor)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE produtos_filial (
    filial_id       INT           NOT NULL,
    produto_id      VARCHAR(25)   NOT NULL,
    descricao       VARCHAR(255)  NOT NULL,
    estoque         DECIMAL(14,3) NOT NULL DEFAULT 0,
    preco_unitario  DECIMAL(12,4) NOT NULL DEFAULT 0,
    preco_compra    DECIMAL(12,4) NOT NULL DEFAULT 0,
    preco_venda     DECIMAL(12,4) NOT NULL DEFAULT 0,
    idfornecedor    INT           NULL,
    CONSTRAINT pk_produtos_filial PRIMARY KEY (filial_id, produto_id),
    CONSTRAINT fk_produtos_filial_fornecedor FOREIGN KEY (idfornecedor)
        REFERENCES fornecedor (idfornecedor)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE venda (
    venda_id        BIGINT        NOT NULL,
    data_emissao    DATE          NOT NULL,
    horariomov      TIME          NOT NULL DEFAULT '00:00:00',
    produto_id      VARCHAR(25)   NOT NULL,
    qtde_vendida    DECIMAL(14,3) NULL,
    valor_unitario  DECIMAL(12,4) NOT NULL DEFAULT 0,
    filial_id       INT           NOT NULL,
    item            INT           NOT NULL,
    unidade_medida  VARCHAR(3)    NULL,
    CONSTRAINT pk_venda PRIMARY KEY (filial_id, venda_id, data_emissao, produto_id, item, horariomov)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE pedido_compra (
    pedido_id          BIGINT        NOT NULL,
    data_pedido        DATE          NULL,
    item               INT           NOT NULL,
    produto_id         VARCHAR(25)   NOT NULL,
    descricao_produto  VARCHAR(255)  NULL,
    ordem_compra       BIGINT        NOT NULL,
    qtde_pedida        DECIMAL(14,3) NULL,
    filial_id          INT           NULL,
    data_entrega       DATE          NULL,
    qtde_entregue      DECIMAL(14,3) NOT NULL DEFAULT 0,
    qtde_pendente      DECIMAL(14,3) NOT NULL DEFAULT 0,
    preco_compra       DECIMAL(12,4) NULL,
    fornecedor_id      INT           NULL,
    CONSTRAINT pk_pedido_compra PRIMARY KEY (pedido_id, produto_id, item),
    CONSTRAINT fk_pedido_fornecedor FOREIGN KEY (fornecedor_id)
        REFERENCES fornecedor (idfornecedor),
    CONSTRAINT fk_pedido_produto FOREIGN KEY (filial_id, produto_id)
        REFERENCES produtos_filial (filial_id, produto_id),
    INDEX ix_pedido_compra_ordem (ordem_compra, produto_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE entradas_mercadoria (
    data_entrada       DATE          NULL,
    nro_nfe            VARCHAR(60)   NOT NULL,
    item               INT           NOT NULL,
    produto_id         VARCHAR(25)   NOT NULL,
    descricao_produto  VARCHAR(255)  NULL,
    qtde_recebida      DECIMAL(14,3) NULL,
    filial_id          INT           NULL,
    custo_unitario     DECIMAL(12,4) NOT NULL DEFAULT 0,
    ordem_compra       BIGINT        NOT NULL,
    CONSTRAINT pk_entradas_mercadoria PRIMARY KEY (ordem_compra, item, produto_id, nro_nfe)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- FKs NAO CRIADAS porque os dados violam (ver 04_validacao.sql):
--   venda -> produtos_filial (V01) e entradas_mercadoria -> pedido_compra (E01 e P07).
-- ALTER TABLE venda ADD CONSTRAINT fk_venda_produto
--     FOREIGN KEY (filial_id, produto_id) REFERENCES produtos_filial (filial_id, produto_id);
-- ALTER TABLE pedido_compra ADD CONSTRAINT uq_pedido_ordem UNIQUE (ordem_compra, produto_id, item);
-- ALTER TABLE entradas_mercadoria ADD CONSTRAINT fk_entrada_pedido
--     FOREIGN KEY (ordem_compra, produto_id, item) REFERENCES pedido_compra (ordem_compra, produto_id, item);
