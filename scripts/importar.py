# Nome: yana sayuri ribeiro taketomi
import os
import pandas as pd
import mysql.connector
from datetime import datetime, timedelta

ARQUIVO = "dados/base_teste.xlsx"
DB = {
    "host": "localhost",
    "port": 3306,
    "database": "integracao_dados",
    "user": "admin",
    "password": os.getenv("DB_PASSWORD", "sua_senha_aqui")
}

def excel_para_data(valor):
    try:
        if pd.isna(valor):
            return None
        if isinstance(valor, (datetime, pd.Timestamp)):
            return valor.date()
        return (datetime(1899, 12, 30) + timedelta(days=int(float(valor)))).date()
    except:
        return None

print("Conectando no MySQL...")
conn = mysql.connector.connect(**DB)
cur = conn.cursor()
print("Conectado!\n")

# 1. FORNECEDOR
print("Importando fornecedor...")
df = pd.read_excel(ARQUIVO, sheet_name="fornecedor")
df.columns = df.columns.str.strip()
for _, row in df.iterrows():
    cur.execute("""
        INSERT IGNORE INTO fornecedor (idfornecedor, razao_social)
        VALUES (%s, %s)
    """, (str(row["idfornecedor"]).strip(), str(row["razao_social"]).strip()))
conn.commit()
print(f"  {len(df)} registros processados em fornecedor\n")

# 2. PRODUTOS_FILIAL
print("Importando produtos_filial...")
df = pd.read_excel(ARQUIVO, sheet_name="produtos_filial")
df.columns = df.columns.str.strip()
for _, row in df.iterrows():
    cur.execute("""
        INSERT IGNORE INTO produtos_filial
            (filial_id, idproduto, descricao, estoque, preco_unitario, preco_compra, preco_venda, idfornecedor)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
    """, (
        int(row["filial_id"]) if pd.notna(row["filial_id"]) else None,
        str(row["idproduto"]).strip(),
        str(row["descricao"]).strip() if pd.notna(row["descricao"]) else None,
        float(row["estoque"]) if pd.notna(row["estoque"]) else 0,
        float(row["preco_unitario"]) if pd.notna(row["preco_unitario"]) else 0,
        float(row["preco_compra"]) if pd.notna(row["preco_compra"]) else 0,
        float(row["preco_venda"]) if pd.notna(row["preco_venda"]) else 0,
        str(row["idfornecedor"]).strip() if pd.notna(row["idfornecedor"]) else None
    ))
conn.commit()
print(f"  {len(df)} registros processados em produtos_filial\n")

# 3. PEDIDO_COMPRA
print("Importando pedido_compra...")
df = pd.read_excel(ARQUIVO, sheet_name="pedido_compra")
df = df.iloc[:, :12]
df.columns = ["pedido_id","data_pedido","item","produto_id","descricao_produto",
              "ordem_compra","qtde_pedida","filial_id","data_entrega",
              "qtde_entregue","preco_compra","fornecedor_id"]
for _, row in df.iterrows():
    q_ped = float(row["qtde_pedida"]) if pd.notna(row["qtde_pedida"]) else 0
    q_ent = float(row["qtde_entregue"]) if pd.notna(row["qtde_entregue"]) else 0
    cur.execute("""
        INSERT IGNORE INTO pedido_compra
            (pedido_id, data_pedido, item, produto_id, descricao_produto,
             ordem_compra, qtde_pedida, filial_id, data_entrega,
             qtde_entregue, qtde_pendente, preco_compra, fornecedor_id)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
    """, (
        float(row["pedido_id"]),
        excel_para_data(row["data_pedido"]),
        float(row["item"]),
        str(row["produto_id"]).strip(),
        str(row["descricao_produto"]).strip() if pd.notna(row["descricao_produto"]) else None,
        float(row["ordem_compra"]) if pd.notna(row["ordem_compra"]) else 0,
        q_ped,
        int(row["filial_id"]) if pd.notna(row["filial_id"]) else None,
        excel_para_data(row["data_entrega"]),
        q_ent,
        q_ped - q_ent,
        float(row["preco_compra"]) if pd.notna(row["preco_compra"]) else 0,
        str(row["fornecedor_id"]).strip() if pd.notna(row["fornecedor_id"]) else None
    ))
conn.commit()
print(f"  {len(df)} registros processados em pedido_compra\n")

# 4. ENTRADAS_MERCADORIA
print("Importando entradas_mercadoria...")
df = pd.read_excel(ARQUIVO, sheet_name="entradas_mercadoria")
df.columns = df.columns.str.strip()
for _, row in df.iterrows():
    cur.execute("""
        INSERT IGNORE INTO entradas_mercadoria
            (data_entrada, nro_nfe, item, produto_id, descricao_produto,
             ordem_compra, qtde_recebida, filial_id, custo_unitario)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
    """, (
        excel_para_data(row["data_entrada"]),
        str(row["nro_nfe"]).strip(),
        float(row["item"]),
        str(row["produto_id"]).strip(),
        str(row["descricao_produto"]).strip() if pd.notna(row["descricao_produto"]) else None,
        float(row["ordem_compra"]) if pd.notna(row["ordem_compra"]) else 0,
        float(row["qtde_recebida"]) if pd.notna(row["qtde_recebida"]) else None,
        int(row["filial_id"]) if pd.notna(row["filial_id"]) else None,
        float(row["custo_unitario"]) if pd.notna(row["custo_unitario"]) else 0
    ))
conn.commit()
print(f"  {len(df)} registros processados em entradas_mercadoria\n")

# 5. VENDA
print("Importando venda...")
df = pd.read_excel(ARQUIVO, sheet_name="venda")
df.columns = df.columns.str.strip()
for _, row in df.iterrows():
    cur.execute("""
        INSERT IGNORE INTO venda
            (venda_id, data_emissao, horariomov, produto_id,
             qtde_vendida, valor_unitario, filial_id, item, unidade_medida)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
    """, (
        int(row["venda_id"]),
        excel_para_data(row["data_emissao"]),
        str(row["horariomov"]).strip() if pd.notna(row["horariomov"]) else "00:00:00",
        str(row["produto_id"]).strip(),
        float(row["qtde_vendida"]) if pd.notna(row["qtde_vendida"]) else None,
        float(row["valor_unitario"]) if pd.notna(row["valor_unitario"]) else 0,
        int(row["filial_id"]) if pd.notna(row["filial_id"]) else 1,
        int(row["item"]) if pd.notna(row["item"]) else 0,
        str(row["unidade_medida"]).strip() if pd.notna(row["unidade_medida"]) else None
    ))
conn.commit()
print(f"  {len(df)} registros processados em venda\n")

cur.close()
conn.close()
print("Importação concluída com sucesso!")
