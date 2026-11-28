"""Teste automatizado apos importacao PostgreSQL/MySQL.
Nao cria banco e nao usa senhas em codigo; usa DB_* do ambiente.

Executar a partir da raiz: python scripts/testes_integracao.py
Os totais esperados abaixo foram calculados sobre o Excel original.
"""
from decimal import Decimal
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from importar import conectar, MOTOR  # noqa: E402


def contar(cur, consulta):
    cur.execute(consulta)
    return int(cur.fetchone()[0])


def conferir(cur, titulo, consulta, esperado):
    obtido = contar(cur, consulta)
    print(f"{titulo}: obtido={obtido}, esperado={esperado}")
    assert obtido == esperado, f"{titulo}: esperado {esperado}, obtido {obtido}"


def testar():
    conn = conectar()
    try:
        cur = conn.cursor()

        for tabela, quantidade in [
            ("fornecedor", 20), ("produtos_filial", 20),
            ("pedido_compra", 29), ("entradas_mercadoria", 20),
            ("venda", 33),
        ]:
            conferir(cur, tabela, f"SELECT COUNT(*) FROM {tabela}", quantidade)

        cur.execute("""
            SELECT COUNT(*), SUM(qtde_vendida),
                   SUM(qtde_vendida * valor_unitario)
            FROM venda
            WHERE data_emissao >= '2025-02-01'
              AND data_emissao < '2025-03-01'
        """)
        itens, quantidade, valor = cur.fetchone()
        print(f"Fevereiro: itens={itens}, quantidade={quantidade}, valor={valor}")
        assert itens == 14
        assert Decimal(str(quantidade)) == Decimal("173.220")
        assert Decimal(str(valor)) == Decimal("14093.1704")

        for tabela, campo in [
            ("venda", "data_emissao"),
            ("pedido_compra", "data_pedido"),
            ("pedido_compra", "data_entrega"),
            ("entradas_mercadoria", "data_entrada"),
        ]:
            conferir(cur, f"data obrigatoria {tabela}.{campo}",
                    f"SELECT COUNT(*) FROM {tabela} WHERE {campo} IS NULL", 0)

        conferir(cur, "venda sem cadastro na filial", """
            SELECT COUNT(*) FROM venda v
            WHERE NOT EXISTS (SELECT 1 FROM produtos_filial p
              WHERE p.filial_id=v.filial_id AND p.produto_id=v.produto_id)
        """, 13)

        conferir(cur, "pedido sem ordem valida", """
            SELECT COUNT(*) FROM pedido_compra WHERE ordem_compra = 0
        """, 11)

        conferir(cur, "pedido sem entrada", """
            SELECT COUNT(*) FROM pedido_compra p WHERE p.ordem_compra = 0
              OR NOT EXISTS (SELECT 1 FROM entradas_mercadoria e
                WHERE e.ordem_compra=p.ordem_compra
                AND e.item=p.item AND e.produto_id=p.produto_id)
        """, 11)

        conferir(cur, "entrada sem pedido", """
            SELECT COUNT(*) FROM entradas_mercadoria e
            WHERE NOT EXISTS (SELECT 1 FROM pedido_compra p
                WHERE p.ordem_compra=e.ordem_compra AND p.ordem_compra <> 0
                  AND p.item=e.item AND p.produto_id=e.produto_id)
        """, 2)

        conferir(cur, "entrada antes de pedido", """
            SELECT COUNT(*) FROM pedido_compra p JOIN entradas_mercadoria e
              ON e.ordem_compra=p.ordem_compra AND p.ordem_compra <> 0
              AND e.item=p.item AND e.produto_id=p.produto_id
            WHERE e.data_entrada < p.data_pedido
        """, 9)

        conferir(cur, "entrega antes de pedido", """
            SELECT COUNT(*) FROM pedido_compra
            WHERE data_entrega IS NOT NULL AND data_pedido IS NOT NULL
              AND data_entrega < data_pedido
        """, 20)

        # NAO modifica dados permanentemente; testa trigger dentro de transacao.
        try:
            cur.execute("""
                INSERT INTO produtos_filial
                    (filial_id, produto_id, descricao, estoque, preco_unitario,
                     preco_compra, preco_venda)
                VALUES (999, 'P_TESTE_TRIGGER', 'Teste de trigger', 0, 0, 0, 0)
            """)
            cur.execute("""
                SELECT p.idfornecedor, f.razao_social
                FROM produtos_filial p JOIN fornecedor f
                    ON f.idfornecedor = p.idfornecedor
                WHERE p.filial_id=999 AND p.produto_id='P_TESTE_TRIGGER'
            """)
            linha = cur.fetchone()
            assert linha is not None, "Trigger nao vinculou fornecedor"
            assert linha[0].startswith("AUTO_"), f"Fornecedor inesperado: {linha[0]}"
            assert "PROVISORIO" in linha[1], "Faltou marcar cadastro provisório"
            print(f"Trigger {MOTOR}: fornecedor de teste = {linha[0]}")
        finally:
            conn.rollback()
        print("TODOS OS TESTES AUTOMATIZADOS PASSARAM.")
    finally:
        conn.close()


if __name__ == "__main__":
    testar()
