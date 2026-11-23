#!/usr/bin/env python3
"""
Importa dados/base_teste.xlsx para PostgreSQL ou MySQL.
Autora : Raniele Almeida (2423948)
"""
import os
import re
import sys
from datetime import date, datetime, timedelta

import pandas as pd

# (variáveis de ambiente; sem senha pra não sofrer no código hehehe)
RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ARQUIVO = os.getenv("ARQUIVO_XLSX", os.path.join(RAIZ, "dados", "base_teste.xlsx"))
DB_KIND = os.getenv("DB_KIND", "postgres").lower()          
DB = {
    "host": os.getenv("DB_HOST", "localhost"),
    "port": int(os.getenv("DB_PORT", "5432" if DB_KIND == "postgres" else "3306")),
    "user": os.getenv("DB_USER", "postgres" if DB_KIND == "postgres" else "root"),
    "password": os.getenv("DB_PASSWORD", "sua_senha_aqui"),
}
DB_NAME = os.getenv("DB_NAME", "postgres" if DB_KIND == "postgres" else "bd_integracao")

# Colunas esperadas em cada aba (a ordem é a do INSERT...eu vi no YOUTUBE).
COLUNAS = {
    "fornecedor": ["idfornecedor", "razao_social"],
    "produtos_filial": ["filial_id", "idproduto", "descricao", "estoque",
                        "preco_unitario", "preco_compra", "preco_venda", "idfornecedor"],
    "pedido_compra": ["pedido_id", "data_pedido", "item", "produto_id",
                      "descricao_produto", "ordem_compra", "qtde_pedida", "filial_id",
                      "data_entrega", "qtde_entregue", "preco_compra", "fornecedor_id"],
    "entradas_mercadoria": ["data_entrada", "nro_nfe", "item", "produto_id",
                            "descricao_produto", "ordem_compra", "qtde_recebida",
                            "filial_id", "custo_unitario"],
    "venda": ["venda_id", "data_emissao", "horariomov", "produto_id", "qtde_vendida",
              "valor_unitario", "filial_id", "item", "unidade_medida"],
}
ORDEM_CARGA = ["fornecedor", "produtos_filial", "pedido_compra",
               "entradas_mercadoria", "venda"]            # respeita as FKs pra não da erro na chave estrangeira


# erro vira exceção (nada de "except: return None")
def vazio(v):
    return v is None or (not isinstance(v, str) and pd.isna(v)) or \
        (isinstance(v, str) and v.strip() == "")


def para_texto(v, obrigatorio=False):
    if vazio(v):
        if obrigatorio:
            raise ValueError("texto obrigatório vazio")
        return None
    return str(v).strip()


def para_numero(v, obrigatorio=False, padrao=None):
    if vazio(v):
        if obrigatorio and padrao is None:
            raise ValueError("número obrigatório vazio")
        return padrao
    return float(v)


def para_inteiro(v, obrigatorio=False, padrao=None):
    n = para_numero(v, obrigatorio, padrao)
    if n is None:
        return None
    if n != int(n):
        raise ValueError(f"esperava inteiro, veio {n}")
    return int(n)


def para_data(v, obrigatorio=False):
    """O pandas já entrega Timestamp para células de data. O script original
    tratava tudo como 'serial do Excel' (int(Timestamp) dava erro e o
    'except' devolvia None): TODAS as datas viravam NULL."""
    if vazio(v):
        if obrigatorio:
            raise ValueError("data obrigatória vazia")
        return None
    if isinstance(v, (datetime, pd.Timestamp)):
        return v.date()
    if isinstance(v, date):
        return v
    if isinstance(v, (int, float)):                       
        return (datetime(1899, 12, 30) + timedelta(days=int(v))).date()
    return pd.to_datetime(str(v), dayfirst=True).date()   


def id_fornecedor(v):
    """'F12' -> 12 (o banco usa inteiro; ver [E3] no DDL)."""
    m = re.fullmatch(r"\s*[Ff]?\s*(\d+)\s*", str(v))
    if not m:
        raise ValueError(f"idfornecedor inválido: {v!r}")
    return int(m.group(1))


# cada função devolve (linhas_validas, rejeitadas)
# linhas_validas = [(linha_na_planilha, tupla_de_parametros)]
def ler_aba(aba):
    df = pd.read_excel(ARQUIVO, sheet_name=aba)
    df.columns = [str(c).strip() for c in df.columns]
    esperadas = COLUNAS[aba]
    faltando = [c for c in esperadas if c not in df.columns]
    if faltando:
        raise SystemExit(f"Aba '{aba}': colunas ausentes {faltando}")
    extras = [c for c in df.columns if c not in esperadas]
    com_dado = int(df[extras].notna().any(axis=1).sum()) if extras else 0
    if com_dado:
        print(f"  AVISO aba '{aba}': {len(extras)} coluna(s) fora do layout "
              f"({extras[0]}..{extras[-1]}) com dados em {com_dado} linha(s); IGNORADAS.")
    df = df[esperadas].dropna(how="all")                  # descarta linhas 100% vazias
    return df


def converter(df, aba, fn):
    ok, rej = [], []
    for idx, row in df.iterrows():
        linha = idx + 2                                   # +1 cabeçalho, +1 base 1
        try:
            ok.append((linha, fn(row)))
        except Exception as e:                            
            rej.append((aba, linha, f"conversão: {e}"))
    return ok, rej


def linha_fornecedor(r):
    return (id_fornecedor(r["idfornecedor"]),
            para_texto(r["idfornecedor"], True),
            para_texto(r["razao_social"], True))


def linha_produto(r):
    return (para_inteiro(r["filial_id"], True), para_texto(r["idproduto"], True),
            para_texto(r["descricao"], True), para_numero(r["estoque"], padrao=0),
            para_numero(r["preco_unitario"], padrao=0), para_numero(r["preco_compra"], padrao=0),
            para_numero(r["preco_venda"], padrao=0),
            id_fornecedor(r["idfornecedor"]) if not vazio(r["idfornecedor"]) else None)


def linha_pedido(r):
    pedida = para_numero(r["qtde_pedida"])
    entregue = para_numero(r["qtde_entregue"], padrao=0)
    pendente = (pedida - entregue) if pedida is not None else 0   # não existe na planilha
    return (para_inteiro(r["pedido_id"], True), para_data(r["data_pedido"]),
            para_inteiro(r["item"], True), para_texto(r["produto_id"], True),
            para_texto(r["descricao_produto"]),
            para_inteiro(r["ordem_compra"], padrao=0),    # 0 = 'sem ordem', como veio
            pedida, para_inteiro(r["filial_id"]), para_data(r["data_entrega"]),
            entregue, pendente, para_numero(r["preco_compra"], padrao=0),
            para_inteiro(r["fornecedor_id"]))


def linha_entrada(r):
    return (para_data(r["data_entrada"]), para_texto(r["nro_nfe"], True),
            para_inteiro(r["item"], True), para_texto(r["produto_id"], True),
            para_texto(r["descricao_produto"]), para_inteiro(r["ordem_compra"], padrao=0),
            para_numero(r["qtde_recebida"]), para_inteiro(r["filial_id"]),
            para_numero(r["custo_unitario"], padrao=0))


def linha_venda(r):
    h = para_texto(r["horariomov"]) or "00:00:00"
    return (para_inteiro(r["venda_id"], True), para_data(r["data_emissao"], True), h,
            para_texto(r["produto_id"], True), para_numero(r["qtde_vendida"]),
            para_numero(r["valor_unitario"], padrao=0),
            para_inteiro(r["filial_id"], True),           # sem "default filial 1"
            para_inteiro(r["item"], padrao=0), para_texto(r["unidade_medida"]))


CONVERSORES = {"fornecedor": linha_fornecedor, "produtos_filial": linha_produto,
               "pedido_compra": linha_pedido, "entradas_mercadoria": linha_entrada,
               "venda": linha_venda}

SQL_INSERT = {
    "fornecedor": "INSERT INTO fornecedor (idfornecedor, codigo_origem, razao_social) VALUES (%s,%s,%s)",
    "produtos_filial": "INSERT INTO produtos_filial (filial_id, produto_id, descricao, estoque, "
                       "preco_unitario, preco_compra, preco_venda, idfornecedor) "
                       "VALUES (%s,%s,%s,%s,%s,%s,%s,%s)",
    "pedido_compra": "INSERT INTO pedido_compra (pedido_id, data_pedido, item, produto_id, "
                     "descricao_produto, ordem_compra, qtde_pedida, filial_id, data_entrega, "
                     "qtde_entregue, qtde_pendente, preco_compra, fornecedor_id) "
                     "VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)",
    "entradas_mercadoria": "INSERT INTO entradas_mercadoria (data_entrada, nro_nfe, item, produto_id, "
                           "descricao_produto, ordem_compra, qtde_recebida, filial_id, custo_unitario) "
                           "VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s)",
    "venda": "INSERT INTO venda (venda_id, data_emissao, horariomov, produto_id, qtde_vendida, "
             "valor_unitario, filial_id, item, unidade_medida) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s)",
}


# BC
def conectar():
    if DB_KIND == "postgres":
        import psycopg2
        return psycopg2.connect(dbname=DB_NAME, **DB)
    if DB_KIND == "mysql":
        import pymysql
        return pymysql.connect(database=DB_NAME, **DB)
    raise SystemExit("DB_KIND deve ser 'postgres' ou 'mysql'")


def inserir(cur, aba, linhas):
    """Insere linha a linha. Se uma linha falhar, só ELA é desfeita (savepoint)
    e fica registrada. O original chamava conn.rollback() dentro do loop, o que
    desfazia TODAS as linhas já inseridas da tabela, e ON CONFLICT DO NOTHING
    escondia duplicadas."""
    inseridas, rejeitadas = 0, []
    for linha, params in linhas:
        try:
            cur.execute("SAVEPOINT sp")
            cur.execute(SQL_INSERT[aba], params)
            cur.execute("RELEASE SAVEPOINT sp")
            inseridas += 1
        except Exception as e:                            
            cur.execute("ROLLBACK TO SAVEPOINT sp")
            rejeitadas.append((aba, linha, f"banco: {str(e).strip().splitlines()[0]}"))
    return inseridas, rejeitadas


def limpar(cur):
    for aba in reversed(ORDEM_CARGA):                     # filhas antes das mães
        cur.execute(f"DELETE FROM {aba}")


def pos_carga(cur):
    """Após inserir fornecedores com id explícito, a sequência IDENTITY do
    PostgreSQL continua em 1 e a trigger da Parte 3 colidiria com o id 1.
    (No MySQL o AUTO_INCREMENT avança sozinho.)"""
    if DB_KIND == "postgres":
        cur.execute("SELECT setval(pg_get_serial_sequence('fornecedor','idfornecedor'), "
                    "(SELECT COALESCE(MAX(idfornecedor),1) FROM fornecedor))")


def main():
    zerar = "--limpar" in sys.argv
    print(f"Conectando em {DB_KIND} ({DB['host']}:{DB['port']}/{DB_NAME})...")
    conn = conectar()
    cur = conn.cursor()
    if zerar:
        limpar(cur)
        conn.commit()
        print("Tabelas limpas.")

    resumo, rejeitos = [], []
    for aba in ORDEM_CARGA:
        print(f"Importando {aba}...")
        df = ler_aba(aba)
        validas, rej_conv = converter(df, aba, CONVERSORES[aba])
        inseridas, rej_db = inserir(cur, aba, validas)
        conn.commit()
        cur.execute(f"SELECT COUNT(*) FROM {aba}")
        no_banco = cur.fetchone()[0]
        resumo.append((aba, len(df), inseridas, no_banco))
        rejeitos += rej_conv + rej_db
        print(f"  planilha={len(df)}  inseridas={inseridas}  rejeitadas={len(rej_conv) + len(rej_db)}")
    pos_carga(cur)
    conn.commit()

    print("\n=== Conferência (linhas da planilha x COUNT(*) no banco) ===")
    print(f"{'tabela':<22}{'planilha':>9}{'inseridas':>10}{'banco':>7}  status")
    falhou = False
    for aba, plan, ins, banco in resumo:
        ok = plan == ins == banco
        falhou |= not ok
        print(f"{aba:<22}{plan:>9}{ins:>10}{banco:>7}  {'OK' if ok else 'DIVERGE'}")
    if rejeitos:
        falhou = True
        print("\n=== Linhas rejeitadas (linha = número da linha na planilha) ===")
        for aba, linha, motivo in rejeitos:
            print(f"  {aba} linha {linha}: {motivo}")
    cur.close()
    conn.close()
    print("\nImportação concluída " + ("COM PROBLEMAS." if falhou else "sem divergências."))
    sys.exit(1 if falhou else 0)


if __name__ == "__main__":
    main()
