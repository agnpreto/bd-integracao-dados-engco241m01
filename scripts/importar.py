#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
importar.py - importa dados/base_teste.xlsx para o PostgreSQL (versao corrigida).

Uso:
    export PGPASSWORD='sua_senha'        # a senha NAO fica no codigo
    python scripts/importar.py           # importa
    python scripts/importar.py --limpar  # esvazia as 5 tabelas antes de importar
    python scripts/importar.py --arquivo outro.xlsx

Variaveis de ambiente (todas opcionais): PGHOST (localhost), PGPORT (5432),
PGDATABASE (postgres), PGUSER (postgres), PGPASSWORD.

Principios:
  * nenhuma linha some em silencio: cada linha vira INSERIDA, DUPLICADA ou
    REJEITADA, e tudo que nao for "inserida limpa" vai para importacao_problemas.csv;
  * nenhum valor e inventado para chaves (ordem_compra, filial_id, item...);
    para medidas com DEFAULT 0 no DDL o 0 e aplicado, mas registrado como AVISO;
  * um erro numa linha desfaz so aquela linha (SAVEPOINT), nao a aba inteira.
"""
import argparse
import csv
import os
import re
import sys
from datetime import date, datetime, time, timedelta

import numpy as np
import pandas as pd

ARQUIVO = "dados/base_teste.xlsx"
LOG_CSV = "importacao_problemas.csv"
EXCEL_EPOCH = datetime(1899, 12, 30)
NUM = (int, float, np.integer, np.floating)


# ── Conversores: devolvem None para vazio e levantam ValueError se invalido ──
def vazio(v):
    if v is None:
        return True
    if isinstance(v, str):
        return v.strip() == ""
    try:
        return bool(pd.isna(v))
    except (TypeError, ValueError):
        return False


def txt(v):
    if vazio(v):
        return None
    if isinstance(v, (float, np.floating)) and float(v).is_integer():
        v = int(v)                      # 12345.0 -> "12345"
    return str(v).strip()


def id_fornecedor(v):
    """Normaliza o id do fornecedor para inteiro: 'F12' -> 12, 12 -> 12, 12.0 -> 12.
    A planilha traz 'F1'...'F20' em fornecedor/produtos_filial e 1...20 em pedido_compra;
    o enunciado pede id numerico, entao o prefixo 'F' e removido na carga."""
    if vazio(v):
        return None
    if isinstance(v, (float, np.floating)) and float(v).is_integer():
        v = int(v)
    m = re.fullmatch(r"[Ff]?\s*(\d+)", str(v).strip())
    if not m:
        raise ValueError(f"id de fornecedor invalido: {v!r}")
    return int(m.group(1))


def numero(v):
    if vazio(v):
        return None
    if isinstance(v, str):
        v = v.strip().replace(",", ".")
    return float(v)


def inteiro(v):
    n = numero(v)
    if n is None:
        return None
    if not float(n).is_integer():
        raise ValueError(f"esperado inteiro, veio {v!r}")
    return int(n)


def data(v):
    if vazio(v):
        return None
    if isinstance(v, datetime):         # inclui pd.Timestamp
        return v.date()
    if isinstance(v, date):
        return v
    if isinstance(v, NUM) and not isinstance(v, bool):   # serial do Excel
        n = int(v)
        if not 20000 <= n <= 80000:
            raise ValueError(f"serial de data fora do intervalo: {v!r}")
        return (EXCEL_EPOCH + timedelta(days=n)).date()
    s = str(v).strip()
    for fmt in ("%d/%m/%Y", "%Y-%m-%d", "%d-%m-%Y", "%d/%m/%y", "%Y-%m-%d %H:%M:%S"):
        try:
            return datetime.strptime(s, fmt).date()
        except ValueError:
            pass
    raise ValueError(f"data invalida: {v!r}")


def hora(v):
    if vazio(v):
        return None
    if isinstance(v, datetime):
        return v.time().replace(microsecond=0)
    if isinstance(v, time):
        return v.replace(microsecond=0)
    if isinstance(v, NUM) and not isinstance(v, bool):   # fracao do dia
        if not 0 <= float(v) < 1:
            raise ValueError(f"hora fora do intervalo: {v!r}")
        return (datetime.min + timedelta(seconds=round(float(v) * 86400))).time()
    s = str(v).strip()
    for fmt in ("%H:%M:%S", "%H:%M"):
        try:
            return datetime.strptime(s, fmt).time()
        except ValueError:
            pass
    raise ValueError(f"hora invalida: {v!r}")


# ── Especificacao das abas ──────────────────────────────────────────────────
# (coluna_no_banco, nomes_aceitos_na_planilha, conversor, tipo)
# tipo: "obrig" = vazio rejeita a linha | "opc" = vazio vira NULL |
#       ("padrao", x) = vazio vira x (e gera AVISO)
ZERO = ("padrao", 0)


def pos_pedido(v):
    """qtde_pendente: usa a da planilha; se nao houver, calcula pedida - entregue."""
    avisos = []
    calc = None
    if v["qtde_pedida"] is not None and v["qtde_entregue"] is not None:
        calc = v["qtde_pedida"] - v["qtde_entregue"]
    if v["qtde_pendente"] is None:
        v["qtde_pendente"] = calc if calc is not None else 0
    elif calc is not None and abs(v["qtde_pendente"] - calc) > 1e-6:
        avisos.append(f"qtde_pendente ({v['qtde_pendente']}) difere de pedida - entregue ({calc})")
    return avisos


TABELAS = [
    dict(aba="fornecedor", tabela="fornecedor", pk=["idfornecedor"], cols=[
        ("idfornecedor", ["idfornecedor", "idforncedor", "idfonecedor", "fornecedor_id"], id_fornecedor, "obrig"),
        ("razao_social", ["razao_social"], txt, "obrig"),
    ]),
    dict(aba="produtos_filial", tabela="produtos_filial", pk=["filial_id", "produto_id"], cols=[
        ("filial_id", ["filial_id"], inteiro, "obrig"),
        ("produto_id", ["produto_id", "idproduto"], txt, "obrig"),
        ("descricao", ["descricao", "decricao"], txt, "obrig"),
        ("estoque", ["estoque"], numero, ZERO),
        ("preco_unitario", ["preco_unitario"], numero, ZERO),
        ("preco_compra", ["preco_compra"], numero, ZERO),
        ("preco_venda", ["preco_venda"], numero, ZERO),
        ("idfornecedor", ["idfornecedor", "idfonecedor", "idforncedor", "fornecedor_id"], id_fornecedor, "opc"),
    ]),
    dict(aba="pedido_compra", tabela="pedido_compra", pk=["pedido_id", "produto_id", "item"],
         pos=pos_pedido, cols=[
        ("pedido_id", ["pedido_id"], inteiro, "obrig"),
        ("data_pedido", ["data_pedido"], data, "opc"),
        ("item", ["item"], inteiro, "obrig"),
        ("produto_id", ["produto_id", "idproduto"], txt, "obrig"),
        ("descricao_produto", ["descricao_produto"], txt, "opc"),
        ("ordem_compra", ["ordem_compra"], inteiro, "obrig"),
        ("qtde_pedida", ["qtde_pedida"], numero, "opc"),
        ("filial_id", ["filial_id"], inteiro, "opc"),
        ("data_entrega", ["data_entrega"], data, "opc"),
        ("qtde_entregue", ["qtde_entregue"], numero, ZERO),
        ("qtde_pendente", ["qtde_pendente"], numero, "opc"),
        ("preco_compra", ["preco_compra"], numero, "opc"),
        ("fornecedor_id", ["fornecedor_id", "idfornecedor"], id_fornecedor, "opc"),
    ]),
    dict(aba="entradas_mercadoria", tabela="entradas_mercadoria",
         pk=["ordem_compra", "item", "produto_id", "nro_nfe"], cols=[
        ("data_entrada", ["data_entrada"], data, "opc"),
        ("nro_nfe", ["nro_nfe"], txt, "obrig"),
        ("item", ["item"], inteiro, "obrig"),
        ("produto_id", ["produto_id", "idproduto"], txt, "obrig"),
        ("descricao_produto", ["descricao_produto"], txt, "opc"),
        ("ordem_compra", ["ordem_compra"], inteiro, "obrig"),
        ("qtde_recebida", ["qtde_recebida"], numero, "opc"),
        ("filial_id", ["filial_id"], inteiro, "opc"),
        ("custo_unitario", ["custo_unitario"], numero, ZERO),
    ]),
    dict(aba="venda", tabela="venda",
         pk=["filial_id", "venda_id", "data_emissao", "produto_id", "item", "horariomov"], cols=[
        ("venda_id", ["venda_id"], inteiro, "obrig"),
        ("data_emissao", ["data_emissao"], data, "obrig"),
        ("horariomov", ["horariomov"], hora, ("padrao", time(0, 0, 0))),
        ("produto_id", ["produto_id", "idproduto"], txt, "obrig"),
        ("qtde_vendida", ["qtde_vendida"], numero, "opc"),
        ("valor_unitario", ["valor_unitario"], numero, ZERO),
        ("filial_id", ["filial_id"], inteiro, "obrig"),
        ("item", ["item"], inteiro, "obrig"),
        ("unidade_medida", ["unidade_medida"], txt, "opc"),
    ]),
]


# ── Importacao de uma aba ───────────────────────────────────────────────────
def resumo(row):
    s = {k: v for k, v in row.to_dict().items() if not vazio(v)}
    return str(s)[:300]


def processar_aba(cur, df, spec, problemas):
    aba, tabela = spec["aba"], spec["tabela"]
    norm = {str(c).strip().lower(): c for c in df.columns}
    mapa = {}
    for nome, aliases, _, tipo in spec["cols"]:
        achou = next((norm[a] for a in aliases if a in norm), None)
        if achou is None:
            if tipo == "obrig":
                raise SystemExit(f"[{aba}] coluna obrigatoria ausente: {nome} "
                                 f"(aceitos: {aliases}). Colunas da planilha: {list(df.columns)}")
            print(f"  AVISO: coluna '{nome}' nao existe na aba '{aba}' (vai como NULL/padrao)")
        else:
            mapa[nome] = achou
            if str(achou).strip().lower() != nome:
                print(f"  coluna da planilha '{achou}' -> {nome}")
    extras = [c for c in df.columns if c not in set(mapa.values())]
    if extras:
        print(f"  ATENCAO: colunas da planilha NAO usadas: {extras}")

    nomes = [c[0] for c in spec["cols"]]
    sql = (f"INSERT INTO public.{tabela} ({', '.join(nomes)}) "
           f"VALUES ({', '.join(['%s'] * len(nomes))}) "
           f"ON CONFLICT ({', '.join(spec['pk'])}) DO NOTHING")

    st = dict(lidas=len(df), inseridas=0, duplicadas=0, rejeitadas=0, avisos=0)
    for idx, row in df.iterrows():
        linha = int(idx) + 2                      # linha na planilha (cabecalho = linha 1)
        cur.execute("SAVEPOINT linha")
        try:
            vals, avisos = {}, []
            for nome, _, conv, tipo in spec["cols"]:
                v = conv(row[mapa[nome]]) if nome in mapa else None
                if v is None:
                    if tipo == "obrig":
                        raise ValueError(f"campo obrigatorio vazio: {nome}")
                    if isinstance(tipo, tuple):
                        v = tipo[1]
                        avisos.append(f"{nome} vazio -> padrao {v}")
                vals[nome] = v
            if spec.get("pos"):
                avisos += spec["pos"](vals)
            cur.execute(sql, [vals[n] for n in nomes])
            if cur.rowcount == 1:
                st["inseridas"] += 1
            else:
                st["duplicadas"] += 1
                problemas.append((aba, linha, "DUPLICADA",
                                  "chave primaria ja existe; linha ignorada", resumo(row)))
            for a in avisos:
                st["avisos"] += 1
                problemas.append((aba, linha, "AVISO", a, resumo(row)))
        except Exception as e:                    # noqa: BLE001 - registramos e seguimos
            cur.execute("ROLLBACK TO SAVEPOINT linha")
            st["rejeitadas"] += 1
            motivo = (str(e).strip().splitlines() or [repr(e)])[0]
            problemas.append((aba, linha, "REJEITADA", motivo, resumo(row)))
        finally:
            cur.execute("RELEASE SAVEPOINT linha")
    return st


def conectar():
    import psycopg2
    cfg = dict(host=os.getenv("PGHOST", "localhost"), port=int(os.getenv("PGPORT", "5432")),
               dbname=os.getenv("PGDATABASE", "postgres"), user=os.getenv("PGUSER", "postgres"))
    return psycopg2.connect(**cfg)               # a senha vem de PGPASSWORD (libpq)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--arquivo", default=ARQUIVO)
    ap.add_argument("--limpar", action="store_true", help="TRUNCATE nas 5 tabelas antes de importar")
    args = ap.parse_args()

    print("Conectando no PostgreSQL...")
    try:
        conn = conectar()
    except Exception as e:                        # noqa: BLE001
        sys.exit(f"Falha ao conectar: {e}")
    cur = conn.cursor()

    if args.limpar:
        cur.execute("TRUNCATE public.entradas_mercadoria, public.venda, public.pedido_compra, "
                    "public.produtos_filial, public.fornecedor RESTART IDENTITY")
        conn.commit()
        print("Tabelas esvaziadas.\n")

    problemas, resultados = [], []
    for spec in TABELAS:
        print(f"Importando {spec['aba']}...")
        try:
            df = pd.read_excel(args.arquivo, sheet_name=spec["aba"], dtype=object)
        except ValueError as e:
            conn.rollback()
            sys.exit(f"Aba '{spec['aba']}' nao encontrada em {args.arquivo}: {e}")
        df.columns = [str(c).strip() for c in df.columns]
        df = df.dropna(how="all")
        st = processar_aba(cur, df, spec, problemas)
        conn.commit()
        cur.execute(f"SELECT COUNT(*) FROM public.{spec['tabela']}")
        st["no_banco"] = cur.fetchone()[0]
        resultados.append((spec["aba"], st))
        print(f"  lidas={st['lidas']} inseridas={st['inseridas']} duplicadas={st['duplicadas']} "
              f"rejeitadas={st['rejeitadas']} avisos={st['avisos']} | COUNT(*) no banco={st['no_banco']}\n")

    cur.close()
    conn.close()

    with open(LOG_CSV, "w", newline="", encoding="utf-8-sig") as f:
        w = csv.writer(f)
        w.writerow(["aba", "linha_planilha", "tipo", "motivo", "dados"])
        w.writerows(problemas)

    print("=" * 62)
    print(f"{'aba':22}{'lidas':>7}{'inser.':>8}{'dupl.':>7}{'rejeit.':>9}{'banco':>8}")
    for aba, st in resultados:
        print(f"{aba:22}{st['lidas']:>7}{st['inseridas']:>8}{st['duplicadas']:>7}"
              f"{st['rejeitadas']:>9}{st['no_banco']:>8}")
    print("=" * 62)
    total_rej = sum(st["rejeitadas"] for _, st in resultados)
    total_dup = sum(st["duplicadas"] for _, st in resultados)
    print(f"Detalhes de rejeitadas/duplicadas/avisos em: {LOG_CSV}")
    if total_rej or total_dup:
        print(f"ATENCAO: {total_rej} rejeitada(s) e {total_dup} duplicada(s). Revise o log antes de seguir.")
        sys.exit(1)
    print("Importacao concluida sem rejeicoes.")


if __name__ == "__main__":
    main()
