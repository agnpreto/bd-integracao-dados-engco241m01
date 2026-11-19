-- 01_ddl_mysql.sql
-- Script DDL do banco no MySQL (adaptado da versao do Postgres).
-- Aqui troquei os tipos do Postgres pelos equivalentes do MySQL (tipo INT no lugar de integer,
-- DECIMAL no lugar de numeric e AUTO_INCREMENT no lugar de GENERATED ... AS IDENTITY),
-- mantendo as mesmas correcoes de chaves, nulos e precos das planilhas.

-- desligo a checagem de FK temporariamente pro DROP nao dar erro de dependencia
SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS venda;
DROP TABLE IF EXISTS entradas_mercadoria;
DROP TABLE IF EXISTS pedido_compra;
DROP TABLE IF EXISTS produtos_filial;
DROP TABLE IF EXISTS fornecedor;
SET FOREIGN_KEY_CHECKS = 1;

-- tabela de fornecedores
CREATE TABLE fornecedor (
    idfornecedor INT          NOT NULL AUTO_INCREMENT,
    razao_social VARCHAR(255) NOT NULL,
    CONSTRAINT fornecedor_pkey PRIMARY KEY (idfornecedor)
) ENGINE=InnoDB;

-- produtos por filial
CREATE TABLE produtos_filial (
    filial_id      INT           NOT NULL, -- antes podia ser null mas entrava na PK
    produto_id     VARCHAR(25)   NOT NULL, -- padronizei em 25 caracteres
    descricao      VARCHAR(255)  NOT NULL, -- arrumei "decricao"
    estoque        DECIMAL(14,3) NOT NULL DEFAULT 0, -- DECIMAL pra nao dar erro de float
    preco_unitario DECIMAL(12,4) NOT NULL DEFAULT 0,
    preco_compra   DECIMAL(12,4) NOT NULL DEFAULT 0,
    preco_venda    DECIMAL(12,4) NOT NULL DEFAULT 0,
    idfornecedor   INT           NULL,     -- arrumei "idfonecedor" e virgula faltando
    CONSTRAINT produtos_filial_pkey PRIMARY KEY (filial_id, produto_id),
    CONSTRAINT produtos_filial_fornecedor_fk FOREIGN KEY (idfornecedor)
        REFERENCES fornecedor (idfornecedor)
) ENGINE=InnoDB;

-- pedidos de compra
CREATE TABLE pedido_compra (
    pedido_id         BIGINT        NOT NULL DEFAULT 0,
    data_pedido       DATE          NULL,
    item              INT           NOT NULL DEFAULT 0,
    produto_id        VARCHAR(25)   NOT NULL DEFAULT '0',
    descricao_produto VARCHAR(255)  NULL,
    ordem_compra      BIGINT        NULL, -- deixei NULL quando nao tem OC ainda
    qtde_pedida       DECIMAL(14,3) NULL,
    filial_id         INT           NULL,
    data_entrega      DATE          NULL,
    qtde_entregue     DECIMAL(14,3) NOT NULL DEFAULT 0,
    -- coluna calculada automaticamente (pedida - entregue) pra nao ficar divergente
    qtde_pendente     DECIMAL(14,3) GENERATED ALWAYS AS (COALESCE(qtde_pedida, 0) - qtde_entregue) STORED,
    preco_compra      DECIMAL(12,4) NULL DEFAULT 0,
    fornecedor_id     INT           NULL, -- tirei DEFAULT 0 pq nao existe fornecedor 0
    CONSTRAINT pedido_compra_pkey PRIMARY KEY (pedido_id, produto_id, item),
    CONSTRAINT pedido_compra_fornecedor_fk FOREIGN KEY (fornecedor_id)
        REFERENCES fornecedor (idfornecedor),
    INDEX idx_pedido_compra_ordem (ordem_compra) -- indice pra ajudar nas buscas por OC
) ENGINE=InnoDB;

-- entradas de mercadoria (notas)
CREATE TABLE entradas_mercadoria (
    data_entrada      DATE          NULL,
    nro_nfe           VARCHAR(255)  NOT NULL,
    item              INT           NOT NULL DEFAULT 0,
    produto_id        VARCHAR(25)   NOT NULL DEFAULT '0',
    descricao_produto VARCHAR(255)  NULL,
    ordem_compra      BIGINT        NOT NULL, -- adicionei pq entrava na PK mas faltava na tabela
    qtde_recebida     DECIMAL(14,3) NULL,
    filial_id         INT           NULL,
    custo_unitario    DECIMAL(12,4) NOT NULL DEFAULT 0,
    CONSTRAINT entradas_mercadoria_pkey PRIMARY KEY (ordem_compra, item, produto_id, nro_nfe)
) ENGINE=InnoDB;

-- vendas
CREATE TABLE venda (
    venda_id       BIGINT        NOT NULL,
    data_emissao   DATE          NOT NULL,
    horariomov     TIME          NOT NULL DEFAULT '00:00:00', -- deixei como TIME
    produto_id     VARCHAR(25)   NOT NULL, -- tirei DEFAULT '' pra nao aceitar vazio
    qtde_vendida   DECIMAL(14,3) NULL,
    valor_unitario DECIMAL(12,4) NOT NULL DEFAULT 0,
    filial_id      INT           NOT NULL, -- tirei DEFAULT 1 que mascarava filial faltando
    item           INT           NOT NULL DEFAULT 0,
    unidade_medida VARCHAR(3)    NULL,
    CONSTRAINT pk_venda PRIMARY KEY (filial_id, venda_id, data_emissao, produto_id, item, horariomov),
    CONSTRAINT venda_produto_nao_vazio CHECK (produto_id <> ''), -- (no MySQL 8+ funciona; em versao antiga CHECK era ignorado)
    INDEX idx_venda_data (data_emissao) -- indice pra ajudar filtro por data
) ENGINE=InnoDB;