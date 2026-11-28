-- Banco de Dados (ENGCO241M01) - PostgreSQL 13+
-- Executar em um banco de testes criado previamente.
-- Preserve sql/01_ddl_enunciado.sql para mostrar os erros do material original.
-- Relacionamentos que apresentam divergencias na planilha sao verificados,
-- nao bloqueados com FOREIGN KEY, para permitir a auditoria de todas as linhas.

CREATE TABLE IF NOT EXISTS public.fornecedor (
    idfornecedor VARCHAR(25) PRIMARY KEY,
    razao_social VARCHAR(255) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.produtos_filial (
    filial_id INTEGER NOT NULL,
    produto_id VARCHAR(25) NOT NULL,
    descricao VARCHAR(255) NOT NULL,
    estoque NUMERIC(18,3) NOT NULL DEFAULT 0,
    preco_unitario NUMERIC(14,4) NOT NULL DEFAULT 0,
    preco_compra NUMERIC(14,4) NOT NULL DEFAULT 0,
    preco_venda NUMERIC(14,4) NOT NULL DEFAULT 0,
    idfornecedor VARCHAR(25),
    CONSTRAINT pk_produtos_filial PRIMARY KEY (filial_id, produto_id),
    CONSTRAINT fk_produtos_fornecedor FOREIGN KEY (idfornecedor)
        REFERENCES public.fornecedor(idfornecedor)
);

CREATE TABLE IF NOT EXISTS public.pedido_compra (
    pedido_id BIGINT NOT NULL,
    data_pedido DATE,
    item INTEGER NOT NULL DEFAULT 0,
    produto_id VARCHAR(25) NOT NULL,
    descricao_produto VARCHAR(255),
    ordem_compra BIGINT NOT NULL DEFAULT 0,
    qtde_pedida NUMERIC(18,3),
    filial_id INTEGER,
    data_entrega DATE,
    qtde_entregue NUMERIC(18,3) NOT NULL DEFAULT 0,
    qtde_pendente NUMERIC(18,3) NOT NULL DEFAULT 0,
    preco_compra NUMERIC(14,4),
    fornecedor_id VARCHAR(25),
    CONSTRAINT pk_pedido_compra PRIMARY KEY (pedido_id, produto_id, item),
    CONSTRAINT fk_pedido_fornecedor FOREIGN KEY (fornecedor_id)
        REFERENCES public.fornecedor(idfornecedor)
);

CREATE TABLE IF NOT EXISTS public.entradas_mercadoria (
    data_entrada DATE,
    nro_nfe VARCHAR(255) NOT NULL,
    item INTEGER NOT NULL DEFAULT 0,
    produto_id VARCHAR(25) NOT NULL,
    descricao_produto VARCHAR(255),
    ordem_compra BIGINT NOT NULL DEFAULT 0,
    qtde_recebida NUMERIC(18,3),
    filial_id INTEGER,
    custo_unitario NUMERIC(14,4) NOT NULL DEFAULT 0,
    CONSTRAINT pk_entradas_mercadoria
        PRIMARY KEY (ordem_compra, item, produto_id, nro_nfe)
);

CREATE TABLE IF NOT EXISTS public.venda (
    venda_id BIGINT NOT NULL,
    data_emissao DATE NOT NULL,
    horariomov VARCHAR(8) NOT NULL DEFAULT '00:00:00',
    produto_id VARCHAR(25) NOT NULL,
    qtde_vendida NUMERIC(18,3),
    valor_unitario NUMERIC(14,4) NOT NULL DEFAULT 0,
    filial_id BIGINT NOT NULL DEFAULT 1,
    item INTEGER NOT NULL DEFAULT 0,
    unidade_medida VARCHAR(3),
    CONSTRAINT pk_venda PRIMARY KEY
        (filial_id, venda_id, data_emissao, produto_id, item, horariomov)
);

CREATE INDEX IF NOT EXISTS idx_venda_emissao_produto
    ON public.venda (data_emissao, produto_id);
CREATE INDEX IF NOT EXISTS idx_pedido_data_produto
    ON public.pedido_compra (data_pedido, produto_id);
CREATE INDEX IF NOT EXISTS idx_pedido_ordem
    ON public.pedido_compra (ordem_compra, item, produto_id);
CREATE INDEX IF NOT EXISTS idx_entrada_ordem
    ON public.entradas_mercadoria (ordem_compra, item, produto_id);
