
from getpass import getpass
from pathlib import Path

import pandas as pd
import psycopg2

# 1. Localizar e ler a planilha
arquivo = Path(__file__).resolve().parent.parent / "dados" / "base_teste.xlsx"

pedidos = pd.read_excel(arquivo, sheet_name="pedido_compra")
entradas = pd.read_excel(arquivo, sheet_name="entradas_mercadoria")

print("Pedidos encontrados na planilha:", len(pedidos))
print("Entradas encontradas na planilha:", len(entradas))

# 2. Conectar ao PostgreSQL
conn = psycopg2.connect(
    host="localhost",
    port=5432,
    database="projeto_faculdade",
    user="postgres",
    password=getpass("Senha do PostgreSQL: ")
)

try:
    # 3. Conferir os identificadores do banco
    with conn.cursor() as cur:
        cur.execute("""
            SELECT pedido_id, produto_id, item
            FROM pedido_compra
        """)
        chaves_pedidos = set(cur.fetchall())

        cur.execute("""
            SELECT ordem_compra, item, produto_id, nro_nfe
            FROM entradas_mercadoria
        """)
        chaves_entradas = set(cur.fetchall())

    # 4. Conferir os identificadores da planilha
    chaves_excel_pedidos = {
        (
            float(r["pedido_id"]),
            str(r["produto_id"]).strip(),
            float(r["item"])
        )
        for _, r in pedidos.iterrows()
    }

    chaves_excel_entradas = {
        (
            float(r["ordem_compra"]),
            float(r["item"]),
            str(r["produto_id"]).strip(),
            str(r["nro_nfe"]).strip()
        )
        for _, r in entradas.iterrows()
    }

    print(
        "Pedidos correspondentes:",
        len(chaves_pedidos & chaves_excel_pedidos)
    )
    print(
        "Entradas correspondentes:",
        len(chaves_entradas & chaves_excel_entradas)
    )

    if len(chaves_excel_pedidos) != len(pedidos):
        raise ValueError("Existem identificadores repetidos na planilha de pedidos!")

    if len(chaves_excel_entradas) != len(entradas):
        raise ValueError("Existem identificadores repetidos na planilha de entradas!")

    if chaves_pedidos != chaves_excel_pedidos:
        raise ValueError("As chaves dos pedidos não correspondem!")

    if chaves_entradas != chaves_excel_entradas:
        raise ValueError("As chaves das entradas não correspondem!")

    # 5. Atualizar as datas em uma transação
    with conn:
        with conn.cursor() as cur:

            # Atualizar datas dos pedidos
            for _, row in pedidos.iterrows():
                cur.execute("""
                    UPDATE pedido_compra
                    SET
                        data_pedido = COALESCE(data_pedido, %s),
                        data_entrega = COALESCE(data_entrega, %s)
                    WHERE pedido_id = %s
                      AND produto_id = %s
                      AND item = %s
                """, (
                    row["data_pedido"].date()
                    if pd.notna(row["data_pedido"]) else None,
                    row["data_entrega"].date()
                    if pd.notna(row["data_entrega"]) else None,
                    float(row["pedido_id"]),
                    str(row["produto_id"]).strip(),
                    float(row["item"])
                ))

                if cur.rowcount != 1:
                    raise ValueError(
                        "Pedido não atualizado corretamente"
                    )

            # Atualizar datas das entradas
            for _, row in entradas.iterrows():
                cur.execute("""
                    UPDATE entradas_mercadoria
                    SET
                        data_entrada = COALESCE(data_entrada, %s)
                    WHERE ordem_compra = %s
                      AND item = %s
                      AND produto_id = %s
                      AND nro_nfe = %s
                """, (
                    row["data_entrada"].date()
                    if pd.notna(row["data_entrada"]) else None,
                    float(row["ordem_compra"]),
                    float(row["item"]),
                    str(row["produto_id"]).strip(),
                    str(row["nro_nfe"]).strip()
                ))

                if cur.rowcount != 1:
                    raise ValueError(
                        "Entrada não atualizada corretamente"
                    )

    print("Datas atualizadas com sucesso!")

finally:
    conn.close()
