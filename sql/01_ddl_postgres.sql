-- 01_ddl_postgres.sql  (PostgreSQL)
-- DDL corrigido. Ordem de criacao: fornecedor -> produtos_filial -> venda -> pedido_compra -> entradas_mercadoria.
-- Erros de estrutura (sintaxe, colunas inexistentes, tipos) foram corrigidos.
-- FKs: so foram criadas as que os dados suportam (conferido na validacao); as que os dados
-- violam estao comentadas no fim, com o motivo, para que a carga traga TODAS as linhas.

CREATE TABLE public.fornecedor (
    idfornecedor  integer      NOT NULL,   -- numerico (planilha traz 'F1'; prefixo removido na carga)
    razao_social  varchar(255) NOT NULL,
    CONSTRAINT pk_fornecedor PRIMARY KEY (idfornecedor)
);

CREATE TABLE public.produtos_filial (
    filial_id       integer       NOT NULL,
    produto_id      varchar(25)   NOT NULL,
    descricao       varchar(255)  NOT NULL,
    estoque         numeric(14,3) NOT NULL DEFAULT 0,
    preco_unitario  numeric(12,4) NOT NULL DEFAULT 0,
    preco_compra    numeric(12,4) NOT NULL DEFAULT 0,
    preco_venda     numeric(12,4) NOT NULL DEFAULT 0,
    idfornecedor    integer       NULL,
    CONSTRAINT pk_produtos_filial PRIMARY KEY (filial_id, produto_id),
    CONSTRAINT fk_produtos_filial_fornecedor FOREIGN KEY (idfornecedor)
        REFERENCES public.fornecedor (idfornecedor)
);

CREATE TABLE public.venda (
    venda_id        bigint        NOT NULL,
    data_emissao    date          NOT NULL,
    horariomov      time          NOT NULL DEFAULT '00:00:00',
    produto_id      varchar(25)   NOT NULL,
    qtde_vendida    numeric(14,3) NULL,
    valor_unitario  numeric(12,4) NOT NULL DEFAULT 0,
    filial_id       integer       NOT NULL,
    item            integer       NOT NULL,
    unidade_medida  varchar(3)    NULL,
    CONSTRAINT pk_venda PRIMARY KEY (filial_id, venda_id, data_emissao, produto_id, item, horariomov)
);

CREATE TABLE public.pedido_compra (
    pedido_id          bigint        NOT NULL,
    data_pedido        date          NULL,
    item               integer       NOT NULL,
    produto_id         varchar(25)   NOT NULL,
    descricao_produto  varchar(255)  NULL,
    ordem_compra       bigint        NOT NULL,
    qtde_pedida        numeric(14,3) NULL,
    filial_id          integer       NULL,
    data_entrega       date          NULL,
    qtde_entregue      numeric(14,3) NOT NULL DEFAULT 0,
    qtde_pendente      numeric(14,3) NOT NULL DEFAULT 0,
    preco_compra       numeric(12,4) NULL,
    fornecedor_id      integer       NULL,          -- NULL = sem fornecedor (0 nao e fornecedor valido)
    CONSTRAINT pk_pedido_compra PRIMARY KEY (pedido_id, produto_id, item),
    CONSTRAINT fk_pedido_fornecedor FOREIGN KEY (fornecedor_id)
        REFERENCES public.fornecedor (idfornecedor),
    CONSTRAINT fk_pedido_produto FOREIGN KEY (filial_id, produto_id)
        REFERENCES public.produtos_filial (filial_id, produto_id)
);
CREATE INDEX ix_pedido_compra_ordem ON public.pedido_compra (ordem_compra, produto_id);

CREATE TABLE public.entradas_mercadoria (
    data_entrada       date          NULL,
    nro_nfe            varchar(60)   NOT NULL,
    item               integer       NOT NULL,
    produto_id         varchar(25)   NOT NULL,
    descricao_produto  varchar(255)  NULL,
    qtde_recebida      numeric(14,3) NULL,
    filial_id          integer       NULL,
    custo_unitario     numeric(12,4) NOT NULL DEFAULT 0,
    ordem_compra       bigint        NOT NULL,      -- coluna que faltava; liga a entrada ao pedido
    CONSTRAINT pk_entradas_mercadoria PRIMARY KEY (ordem_compra, item, produto_id, nro_nfe)
);

-- ---------------------------------------------------------------------------
-- FKs NAO CRIADAS porque os dados violam (ver 04_validacao.sql). Criar so depois
-- de o cliente corrigir os dados:
--   * venda -> produtos_filial: vendas dos produtos P21 a P28 nao tem cadastro (V01)
--       ALTER TABLE public.venda ADD CONSTRAINT fk_venda_produto
--           FOREIGN KEY (filial_id, produto_id) REFERENCES public.produtos_filial (filial_id, produto_id);
--   * entradas_mercadoria -> pedido_compra: entradas sem pedido (E01) e ordem_compra = 0
--     repetida em 11 pedidos (P07), o que impede ate a unicidade de (ordem_compra, produto_id, item)
--       ALTER TABLE public.pedido_compra ADD CONSTRAINT uq_pedido_ordem UNIQUE (ordem_compra, produto_id, item);
--       ALTER TABLE public.entradas_mercadoria ADD CONSTRAINT fk_entrada_pedido
--           FOREIGN KEY (ordem_compra, produto_id, item) REFERENCES public.pedido_compra (ordem_compra, produto_id, item);
-- ---------------------------------------------------------------------------
