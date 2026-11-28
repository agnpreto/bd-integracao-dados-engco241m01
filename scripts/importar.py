"""Importacao auditavel da planilha do cliente para PostgreSQL ou MySQL.

Uso (a partir da raiz do repositorio):
  pip install -r scripts/requirements.txt
  # Definir DB_PASSWORD e demais DB_* no ambiente, nao neste arquivo.
  python scripts/importar.py

Motor: DB_ENGINE=postgres (padrao) ou DB_ENGINE=mysql.
Requer banco vazio com as tabelas criadas pelo DDL correspondente.
Planilha original preservada; campos extras sao registrados em CSV separado.
"""
import csv
import os
import re
import sys
from datetime import date, datetime, timedelta
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path

import pandas as pd

RAIZ = Path(__file__).resolve().parents[1]
ARQUIVO = Path(os.getenv("EXCEL_FILE", str(RAIZ / "dados" / "base_teste.xlsx")))
MOTOR = os.getenv("DB_ENGINE", "postgres").lower().strip()
if MOTOR not in {"postgres", "mysql"}:
    raise ValueError("DB_ENGINE deve ser 'postgres' ou 'mysql'.")

# Colunas reais de cada aba; evitar renomear a planilha "por posicao".
CAMPOS = {
    "fornecedor": ["idfornecedor", "razao_social"],
    "produtos_filial": [
        "filial_id", "idproduto", "descricao", "estoque",
        "preco_unitario", "preco_compra", "preco_venda", "idfornecedor"
    ],
    "pedido_compra": [
        "pedido_id", "data_pedido", "item", "produto_id", "descricao_produto",
        "ordem_compra", "qtde_pedida", "filial_id", "data_entrega",
        "qtde_entregue", "preco_compra", "fornecedor_id"
    ],
    "entradas_mercadoria": [
        "data_entrada", "nro_nfe", "item", "produto_id",
        "descricao_produto", "ordem_compra", "qtde_recebida",
        "filial_id", "custo_unitario"
    ],
    "venda": [
        "venda_id", "data_emissao", "horariomov", "produto_id",
        "qtde_vendida", "valor_unitario", "filial_id", "item", "unidade_medida"
    ]
}
CHAVES = {
    "fornecedor": ["idfornecedor"],
    "produtos_filial": ["filial_id", "produto_id"],
    "pedido_compra": ["pedido_id", "produto_id", "item"],
    "entradas_mercadoria": ["ordem_compra", "item", "produto_id", "nro_nfe"],
    "venda": ["filial_id", "venda_id", "data_emissao", "produto_id", "item", "horariomov"],
}
ORDEM = ["fornecedor", "produtos_filial", "pedido_compra", "entradas_mercadoria", "venda"]


def nulo(v):
    try:
        return v is None or bool(pd.isna(v))
    except (TypeError, ValueError):
        return False


def texto(v, obrigatorio=False):
    if nulo(v):
        if obrigatorio:
            raise ValueError("Texto obrigatorio ausente")
        return None
    resultado = str(v).strip()
    if not resultado and obrigatorio:
        raise ValueError("Texto obrigatorio vazio")
    return resultado or None


def inteiro(v, obrigatorio=False):
    if nulo(v):
        if obrigatorio:
            raise ValueError("Inteiro obrigatorio ausente")
        return None
    d = Decimal(str(v))
    if d != d.to_integral_value():
        raise ValueError(f"Inteiro invalido: {v}")
    return int(d)


def decimal(v, casas=3, padrao=None):
    if nulo(v):
        return padrao
    # Quantidade: 3 casas; dinheiro: 4. Evita propagacao de FLOAT pelo DB.
    return Decimal(str(v)).quantize(Decimal(1).scaleb(-casas), rounding=ROUND_HALF_UP)


def data_excel(v, obrigatorio=False):
    """Trata tanto serial numerico do Excel quanto Timestamp/datetime do pandas."""
    if nulo(v):
        if obrigatorio:
            raise ValueError("Data obrigatoria ausente")
        return None
    if isinstance(v, pd.Timestamp):
        return v.date()
    if isinstance(v, datetime):
        return v.date()
    if isinstance(v, date):
        return v
    if isinstance(v, (int, float, Decimal)) or (
        isinstance(v, str) and re.fullmatch(r"\d+(\.\d+)?", v.strip())
    ):
        serial = float(v)
        if not (1 <= serial <= 2958465):
            raise ValueError(f"Serial Excel fora do intervalo: {v}")
        return (datetime(1899, 12, 30) + timedelta(days=serial)).date()
    try:
        return pd.to_datetime(v, dayfirst=True, errors="raise").date()
    except (ValueError, TypeError, OverflowError) as exc:
        raise ValueError(f"Data invalida: {v!r}") from exc


def referencia_fornecedor(v):
    """Na planilha pedido_compra usa 1..20, fornecedor usa F1..F20."""
    x = texto(v)
    if x is None:
        return None
    if re.fullmatch(r"\d+(\.0+)?", x):
        return "F" + str(int(float(x)))
    return x


def converter(aba, linha):
    g = linha.get
    if aba == "fornecedor":
        return {
            "idfornecedor": texto(g("idfornecedor"), True),
            "razao_social": texto(g("razao_social"), True),
        }
    if aba == "produtos_filial":
        return {
            "filial_id": inteiro(g("filial_id"), True),
            "produto_id": texto(g("idproduto"), True),
            "descricao": texto(g("descricao"), True),
            "estoque": decimal(g("estoque"), padrao=Decimal("0")),
            "preco_unitario": decimal(g("preco_unitario"), 4, Decimal("0")),
            "preco_compra": decimal(g("preco_compra"), 4, Decimal("0")),
            "preco_venda": decimal(g("preco_venda"), 4, Decimal("0")),
            "idfornecedor": referencia_fornecedor(g("idfornecedor")),
        }
    if aba == "pedido_compra":
        pedida = decimal(g("qtde_pedida"))
        entregue = decimal(g("qtde_entregue"), padrao=Decimal("0"))
        return {
            "pedido_id": inteiro(g("pedido_id"), True),
            "data_pedido": data_excel(g("data_pedido")),
            "item": inteiro(g("item"), True),
            "produto_id": texto(g("produto_id"), True),
            "descricao_produto": texto(g("descricao_produto")),
            "ordem_compra": inteiro(g("ordem_compra"), True),
            "qtde_pedida": pedida,
            "filial_id": inteiro(g("filial_id")),
            "data_entrega": data_excel(g("data_entrega")),
            "qtde_entregue": entregue,
            # Derivado: a planilha nao tem coluna com cabecalho qtde_pendente.
            "qtde_pendente": (pedida - entregue if pedida is not None else Decimal("0")),
            "preco_compra": decimal(g("preco_compra"), 4),
            "fornecedor_id": referencia_fornecedor(g("fornecedor_id")),
        }
    if aba == "entradas_mercadoria":
        return {
            "data_entrada": data_excel(g("data_entrada")),
            "nro_nfe": texto(g("nro_nfe"), True),
            "item": inteiro(g("item"), True),
            "produto_id": texto(g("produto_id"), True),
            "descricao_produto": texto(g("descricao_produto")),
            "ordem_compra": inteiro(g("ordem_compra"), True),
            "qtde_recebida": decimal(g("qtde_recebida")),
            "filial_id": inteiro(g("filial_id")),
            "custo_unitario": decimal(g("custo_unitario"), 4, Decimal("0")),
        }
    if aba == "venda":
        return {
            "venda_id": inteiro(g("venda_id"), True),
            "data_emissao": data_excel(g("data_emissao"), True),
            "horariomov": texto(g("horariomov")) or "00:00:00",
            "produto_id": texto(g("produto_id"), True),
            "qtde_vendida": decimal(g("qtde_vendida")),
            "valor_unitario": decimal(g("valor_unitario"), 4, Decimal("0")),
            "filial_id": inteiro(g("filial_id"), True),
            "item": inteiro(g("item"), True),
            "unidade_medida": texto(g("unidade_medida")),
        }
    raise ValueError(f"Aba desconhecida: {aba}")


def carregar_planilha():
    frames = pd.read_excel(ARQUIVO, sheet_name=None, engine="openpyxl")
    if set(frames) != set(CAMPOS):
        raise ValueError(f"Abas recebidas: {list(frames)}; esperadas: {list(CAMPOS)}")
    registros = {}
    extras = []
    for aba in ORDEM:
        df = frames[aba]
        df.columns = [str(x).strip() for x in df.columns]
        faltantes = sorted(set(CAMPOS[aba]) - set(df.columns))
        if faltantes:
            raise ValueError(f"{aba}: colunas obrigatorias ausentes: {faltantes}")
        for numero, col in enumerate(df.columns, start=1):
            if col not in CAMPOS[aba]:
                for idx, valor in df[col].items():
                    if not nulo(valor):
                        # A primeira linha da planilha e cabecalho; indice 0 => linha 2.
                        from openpyxl.utils import get_column_letter
                        extras.append((aba, f"{get_column_letter(numero)}{idx + 2}", col, str(valor)))
        saida = []
        visto = set()
        for idx, row in df.iterrows():
            try:
                item = converter(aba, row)
                chave = tuple(item[c] for c in CHAVES[aba])
                if chave in visto:
                    raise ValueError(f"Chave duplicada na planilha: {chave}")
                visto.add(chave)
                saida.append(item)
            except (ValueError, TypeError, ArithmeticError) as exc:
                raise ValueError(f"Erro em {aba}, linha Excel {idx + 2}: {exc}") from exc
        registros[aba] = saida
        print(f"Planilha: {aba}: {len(saida)} registros estruturados")
    print(f"Celulas nao vazias fora de colunas nomeadas: {len(extras)} (nao descartadas)")
    return registros, extras


def conectar():
    senha = os.getenv("DB_PASSWORD")
    if senha is None:
        raise RuntimeError("Defina DB_PASSWORD no ambiente. Nao armazene senhas no GitHub.")
    parametros = {
        "host": os.getenv("DB_HOST", "localhost"),
        "port": int(os.getenv("DB_PORT", "5432" if MOTOR == "postgres" else "3306")),
        "database": os.getenv("DB_NAME", "integracao_dados"),
        "user": os.getenv("DB_USER", "postgres" if MOTOR == "postgres" else "root"),
        "password": senha,
    }
    if MOTOR == "postgres":
        import psycopg2
        return psycopg2.connect(**parametros)
    import pymysql
    return pymysql.connect(
        host=parametros["host"], port=parametros["port"],
        database=parametros["database"], user=parametros["user"],
        password=parametros["password"], charset="utf8mb4",
        autocommit=False,
    )


def atualizar_ou_inserir(cur, aba, dado):
    """UPSERT explicito e portavel, com erros propagados e sem INSERT IGNORE."""
    colunas = list(dado)
    chaves = CHAVES[aba]
    condicao = " AND ".join(f"{c} = %s" for c in chaves)
    cur.execute(f"SELECT COUNT(*) FROM {aba} WHERE {condicao}", [dado[k] for k in chaves])
    existe = cur.fetchone()[0] > 0
    if existe:
        outras = [c for c in colunas if c not in chaves]
        if outras:
            set_sql = ", ".join(f"{c} = %s" for c in outras)
            cur.execute(
                f"UPDATE {aba} SET {set_sql} WHERE {condicao}",
                [dado[c] for c in outras] + [dado[k] for k in chaves],
            )
        return "atualizado"
    marcadores = ", ".join(["%s"] * len(colunas))
    cur.execute(
        f"INSERT INTO {aba} ({', '.join(colunas)}) VALUES ({marcadores})",
        [dado[c] for c in colunas],
    )
    return "inserido"


def importar(registros):
    conn = conectar()
    try:
        cur = conn.cursor()
        for aba in ORDEM:
            inseridos, atualizados = 0, 0
            for numero, dado in enumerate(registros[aba], start=2):
                try:
                    modo = atualizar_ou_inserir(cur, aba, dado)
                except Exception as exc:
                    raise RuntimeError(f"Falha de importacao: {aba}, linha Excel {numero}: {exc}") from exc
                inseridos += modo == "inserido"
                atualizados += modo == "atualizado"
            cur.execute(f"SELECT COUNT(*) FROM {aba}")
            banco = cur.fetchone()[0]
            esperado = len(registros[aba])
            if banco != esperado:
                raise RuntimeError(
                    f"Contagem diferente em {aba}: planilha={esperado} banco={banco}. "
                    "Use um banco de testes vazio, sem dados de outros projetos."
                )
            print(f"OK {aba}: {banco} no banco / {esperado} na planilha "
                  f"(inseridos={inseridos}, atualizados={atualizados})")

        cur.execute("""
            SELECT COUNT(*), SUM(qtde_vendida),
                   SUM(qtde_vendida * valor_unitario)
            FROM venda
            WHERE data_emissao >= '2025-02-01' AND data_emissao < '2025-03-01'
        """)
        numero, quantidade, total = cur.fetchone()
        print(f"Fevereiro/2025: itens={numero}, quantidade={quantidade}, total_sem_arredondar={total}")
        conn.commit()
        print("Importacao CONFIRMADA no banco (commit efetuado).")
    except Exception:
        conn.rollback()
        print("ERRO: transacao desfeita (rollback). Nada foi confirmado nesta execucao.", file=sys.stderr)
        raise
    finally:
        conn.close()


def registrar_extras(extras):
    destino = RAIZ / "docs" / "celulas_sem_cabecalho.csv"
    with destino.open("w", encoding="utf-8", newline="") as arquivo:
        escritor = csv.writer(arquivo)
        escritor.writerow(["aba", "celula", "nome_coluna_pandas", "valor_original"])
        escritor.writerows(extras)
    print(f"Registro das celulas adicionais salvo em {destino}")


if __name__ == "__main__":
    if not ARQUIVO.exists():
        raise FileNotFoundError(f"Planilha nao localizada: {ARQUIVO}")
    linhas, celulas = carregar_planilha()
    # Preserva as evidencias de valores que nao pertencem ao cabecalho original.
    registrar_extras(celulas)
    importar(linhas)
