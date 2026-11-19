import os
import re
import sys
from datetime import date, datetime, time, timedelta
from decimal import Decimal
from pathlib import Path

import pandas as pd
import psycopg2

RAIZ = Path(__file__).resolve().parent.parent
ARQUIVO = os.environ.get("ARQUIVO_XLSX", str(RAIZ / "dados" / "base_teste.xlsx"))


def conectar():
    if "PGPASSWORD" not in os.environ:
        sys.exit("Faltou definir PGPASSWORD (e se precisar: PGHOST/PGPORT/PGDATABASE/PGUSER).")
    return psycopg2.connect(
        host=os.environ.get("PGHOST", "localhost"),
        port=int(os.environ.get("PGPORT", "5432")),
        dbname=os.environ.get("PGDATABASE", "postgres"),
        user=os.environ.get("PGUSER", "postgres"),
        password=os.environ["PGPASSWORD"],
    )


# --funcoes de conversao --

def vazio(v):
    return v is None or (not isinstance(v, str) and pd.isna(v)) or (isinstance(v, str) and v.strip() == "")


def txt(v, obrigatorio=False, nome="campo"):
    if vazio(v):
        if obrigatorio:
            raise ValueError(f"{nome} obrigatorio ta vazio")
        return None
    return str(v).strip()


def num(v, obrigatorio=False, nome="campo", padrao=None):
    if vazio(v):
        if obrigatorio:
            raise ValueError(f"{nome} obrigatorio ta vazio")
        return padrao
    return Decimal(str(v).strip().replace(",", "."))


def inteiro(v, obrigatorio=False, nome="campo", padrao=None):
    d = num(v, obrigatorio, nome, None)
    if d is None:
        return padrao
    if d != d.to_integral_value():
        raise ValueError(f"{nome}={d} nao e inteiro")
    return int(d)


def data(v, obrigatorio=False, nome="campo"):
    if vazio(v):
        if obrigatorio:
            raise ValueError(f"{nome} obrigatorio ta vazio")
        return None
    if isinstance(v, (pd.Timestamp, datetime)):
        return v.date()
    if isinstance(v, date):
        return v
    if isinstance(v, (int, float, Decimal)):          # serial de data do Excel
        return (datetime(1899, 12, 30) + timedelta(days=int(v))).date()
    if isinstance(v, str):                            # aceita dd/mm/aaaa e aaaa-mm-dd
        return pd.to_datetime(v.strip(), dayfirst=True).date()
    raise ValueError(f"{nome}: nao entendi esse formato de data ({type(v).__name__}: {v!r})")


def hora(v):
    if vazio(v):
        return time(0, 0, 0)
    if isinstance(v, (time, datetime)):
        return v if isinstance(v, time) else v.time()
    s = str(v).strip()
    return datetime.strptime(s if s.count(":") == 2 else s + ":00", "%H:%M:%S").time()


def id_fornecedor(v, obrigatorio=False, nome="idfornecedor"):
    """Converte 'F8' -> 8 ou 8 -> 8 (o 'F' e so prefixo visual, ver docs/parte1_importacao.md)."""
    if vazio(v):
        if obrigatorio:
            raise ValueError(f"{nome} obrigatorio ta vazio")
        return None
    m = re.fullmatch(r"[Ff]?\s*(\d+)(?:\.0+)?", str(v).strip())
    if not m:
        raise ValueError(f"{nome}={v!r} nao bate com F<numero>")
    return int(m.group(1))


# -- leitura da planilha --

def ler_aba(aba, colunas):
    df = pd.read_excel(ARQUIVO, sheet_name=aba)
    df.columns = [str(c).strip() for c in df.columns]
    faltando = [c for c in colunas if c not in df.columns]
    if faltando:
        sys.exit(f"Aba '{aba}': ta faltando coluna {faltando}")
    extras = [c for c in df.columns if c not in colunas]
    extras_com_dado = [c for c in extras if df[c].notna().any()]
    if extras_com_dado:
        linhas = df.index[df[extras_com_dado].notna().any(axis=1)] + 2   # +2: linha do cabecalho e comeca em 1
        print(f"  AVISO aba '{aba}': {len(extras_com_dado)} coluna(s) fora do layout ({extras_com_dado[0]}..{extras_com_dado[-1]}) "
              f"tem dado nas linhas {linhas.min()}-{linhas.max()} ({len(linhas)} linha(s)). "
              f"Nao importei essas colunas; ver docs/parte1_importacao.md.")
    df = df[colunas]
    df = df.dropna(how="all")
    return df


# -- carga no banco --

resumo = []   # (tabela, lidas, inseridas, duplicadas, rejeitadas)
rejeitadas = []


def carregar(conn, tabela, df, sql, montar):
    cur = conn.cursor()
    ins = dup = rej = 0
    for i, row in df.iterrows():
        linha_xlsx = i + 2
        cur.execute("SAVEPOINT linha")
        try:
            cur.execute(sql, montar(row))
            if cur.rowcount == 1:
                ins += 1
            else:
                dup += 1       # ON CONFLICT DO NOTHING: ja tinha chave igual
            cur.execute("RELEASE SAVEPOINT linha")
        except Exception as e:                       # se der erro, volta so o savepoint dessa linha
            cur.execute("ROLLBACK TO SAVEPOINT linha")
            rej += 1
            rejeitadas.append((tabela, linha_xlsx, str(e).strip().splitlines()[0]))
    cur.close()
    resumo.append((tabela, len(df), ins, dup, rej))
    print(f"  {tabela}: lidas={len(df)} inseridas={ins} duplicadas={dup} rejeitadas={rej}")


def main():
    print(f"Arquivo: {ARQUIVO}")
    conn = conectar()
    conn.autocommit = False
    print("Conectado.\n")

    # 1. fornecedor
    print("Importando fornecedor...")
    df = ler_aba("fornecedor", ["idfornecedor", "razao_social"])
    carregar(conn, "fornecedor", df,
             """INSERT INTO public.fornecedor (idfornecedor, razao_social) VALUES (%s, %s)
                ON CONFLICT (idfornecedor) DO NOTHING""",
             lambda r: (id_fornecedor(r["idfornecedor"], True),
                        txt(r["razao_social"], True, "razao_social")))
   
    cur = conn.cursor()
    cur.execute("""SELECT setval(pg_get_serial_sequence('public.fornecedor','idfornecedor'),
                          COALESCE((SELECT MAX(idfornecedor) FROM public.fornecedor), 1))""")
    cur.close()

    # 2. produtos_filial
    print("Importando produtos_filial...")
    df = ler_aba("produtos_filial", ["filial_id", "idproduto", "descricao", "estoque",
                                     "preco_unitario", "preco_compra", "preco_venda", "idfornecedor"])
    carregar(conn, "produtos_filial", df,
             """INSERT INTO public.produtos_filial
                    (filial_id, produto_id, descricao, estoque, preco_unitario, preco_compra, preco_venda, idfornecedor)
                VALUES (%s,%s,%s,%s,%s,%s,%s,%s)
                ON CONFLICT (filial_id, produto_id) DO NOTHING""",
             lambda r: (inteiro(r["filial_id"], True, "filial_id"),
                        txt(r["idproduto"], True, "idproduto"),
                        txt(r["descricao"], True, "descricao"),
                        num(r["estoque"], padrao=Decimal(0)),
                        num(r["preco_unitario"], padrao=Decimal(0)),
                        num(r["preco_compra"], padrao=Decimal(0)),
                        num(r["preco_venda"], padrao=Decimal(0)),
                        id_fornecedor(r["idfornecedor"])))

    # 3. pedido_compra
    print("Importando pedido_compra...")
    df = ler_aba("pedido_compra", ["pedido_id", "data_pedido", "item", "produto_id", "descricao_produto",
                                   "ordem_compra", "qtde_pedida", "filial_id", "data_entrega",
                                   "qtde_entregue", "preco_compra", "fornecedor_id"])

    def oc(v):
        n = inteiro(v, nome="ordem_compra")
        return None if n in (None, 0) else n          # 0 significa sem OC ainda, virou NULL

    carregar(conn, "pedido_compra", df,
             """INSERT INTO public.pedido_compra
                    (pedido_id, data_pedido, item, produto_id, descricao_produto, ordem_compra, qtde_pedida,
                     filial_id, data_entrega, qtde_entregue, preco_compra, fornecedor_id)
                VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
                ON CONFLICT (pedido_id, produto_id, item) DO NOTHING""",
             lambda r: (inteiro(r["pedido_id"], True, "pedido_id"),
                        data(r["data_pedido"], nome="data_pedido"),
                        inteiro(r["item"], True, "item"),
                        txt(r["produto_id"], True, "produto_id"),
                        txt(r["descricao_produto"]),
                        oc(r["ordem_compra"]),
                        num(r["qtde_pedida"]),
                        inteiro(r["filial_id"]),
                        data(r["data_entrega"], nome="data_entrega"),
                        num(r["qtde_entregue"], padrao=Decimal(0)),
                        num(r["preco_compra"], padrao=Decimal(0)),
                        id_fornecedor(r["fornecedor_id"], nome="fornecedor_id")))

    # 4. entradas_mercadoria
    print("Importando entradas_mercadoria...")
    df = ler_aba("entradas_mercadoria", ["data_entrada", "nro_nfe", "item", "produto_id", "descricao_produto",
                                         "ordem_compra", "qtde_recebida", "filial_id", "custo_unitario"])
    carregar(conn, "entradas_mercadoria", df,
             """INSERT INTO public.entradas_mercadoria
                    (data_entrada, nro_nfe, item, produto_id, descricao_produto, ordem_compra,
                     qtde_recebida, filial_id, custo_unitario)
                VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s)
                ON CONFLICT (ordem_compra, item, produto_id, nro_nfe) DO NOTHING""",
             lambda r: (data(r["data_entrada"], nome="data_entrada"),
                        txt(r["nro_nfe"], True, "nro_nfe"),
                        inteiro(r["item"], True, "item"),
                        txt(r["produto_id"], True, "produto_id"),
                        txt(r["descricao_produto"]),
                        inteiro(r["ordem_compra"], True, "ordem_compra"),
                        num(r["qtde_recebida"]),
                        inteiro(r["filial_id"]),
                        num(r["custo_unitario"], padrao=Decimal(0))))

    # 5. venda
    print("Importando venda...")
    df = ler_aba("venda", ["venda_id", "data_emissao", "horariomov", "produto_id", "qtde_vendida",
                           "valor_unitario", "filial_id", "item", "unidade_medida"])
    carregar(conn, "venda", df,
             """INSERT INTO public.venda
                    (venda_id, data_emissao, horariomov, produto_id, qtde_vendida,
                     valor_unitario, filial_id, item, unidade_medida)
                VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s)
                ON CONFLICT (filial_id, venda_id, data_emissao, produto_id, item, horariomov) DO NOTHING""",
             lambda r: (inteiro(r["venda_id"], True, "venda_id"),
                        data(r["data_emissao"], True, "data_emissao"),
                        hora(r["horariomov"]),
                        txt(r["produto_id"], True, "produto_id"),
                        num(r["qtde_vendida"]),
                        num(r["valor_unitario"], padrao=Decimal(0)),
                        inteiro(r["filial_id"], True, "filial_id"),      # sem padrao 1: se faltar filial tem que acusar erro
                        inteiro(r["item"], padrao=0),
                        txt(r["unidade_medida"])))

    conn.commit()

    # -- conferindo planilha x banco --

    print("\nConferencia (linhas na planilha x linhas no banco):")
    cur = conn.cursor()
    divergiu = False
    for tabela, lidas, ins, dup, rej in resumo:
        cur.execute(f"SELECT COUNT(*) FROM public.{tabela}")
        no_banco = cur.fetchone()[0]
        ok = (no_banco == lidas)
        divergiu |= not ok
        print(f"  {tabela:<20} planilha={lidas:<4} banco={no_banco:<4} {'OK' if ok else 'DIVERGE'}")
    cur.close()
    conn.close()

    if rejeitadas:
        print("\nLinhas REJEITADAS (numero = linha da planilha):")
        for t, n, msg in rejeitadas:
            print(f"  {t} linha {n}: {msg}")

    print("=" * 50)
    if rejeitadas or divergiu:
        print("Importacao terminou COM PENDENCIAS. Da uma olhada nos avisos acima.")
        sys.exit(1)
    print("Importacao concluida: tudo certo, contagens bateram.")
    print("=" * 50)


if __name__ == "__main__":
    main()