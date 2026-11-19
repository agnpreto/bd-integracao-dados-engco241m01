import json
from datetime import date
from pathlib import Path

import openpyxl
import psycopg2
from psycopg2 import sql


ARQUIVO = Path(__file__).resolve().parents[1] / "dados" / "base_teste.xlsx"

# O fornecedor precisa ser cadastrado antes dos produtos relacionados a ele.
TABELAS = (
    "fornecedor",
    "produtos_filial",
    "pedido_compra",
    "entradas_mercadoria",
    "venda",
)


def inserir(cursor, tabela, dados):
    comando = sql.SQL("INSERT INTO {} ({}) VALUES ({})").format(
        sql.Identifier(tabela),
        sql.SQL(", ").join(sql.Identifier(coluna) for coluna in dados),
        sql.SQL(", ").join(sql.Placeholder() for _ in dados),
    )
    cursor.execute(comando, tuple(dados.values()))


def importar_aba(cursor, planilha, tabela):
    linhas = iter(planilha[tabela].values)
    cabecalho = next(linhas)

    for numero_linha, valores in enumerate(linhas, start=2):
        if all(valor is None for valor in valores):
            continue

        dados = {}
        extras = []
        for coluna, valor in zip(cabecalho, valores):
            if coluna is None:
                extras.append(valor)
            else:
                dados[coluna.strip()] = (
                    valor.strip() if isinstance(valor, str) else valor
                )

        # O Excel já fornece as datas desta planilha como objetos de data.
        for coluna, valor in dados.items():
            if coluna.startswith("data_") and not isinstance(valor, date):
                raise ValueError(
                    f"Data inválida na aba {tabela}, linha {numero_linha}, "
                    f"coluna {coluna}: {valor!r}"
                )

        if tabela == "fornecedor":
            # Preserva o código do Excel (por exemplo, F1).
            # O PostgreSQL gera a chave numérica idfornecedor.
            dados["codigo_origem"] = dados.pop("idfornecedor")

        elif tabela == "produtos_filial":
            dados["produto_id"] = dados.pop("idproduto")
            codigo_origem = dados["idfornecedor"]

            cursor.execute(
                "SELECT idfornecedor FROM fornecedor WHERE codigo_origem = %s",
                (codigo_origem,),
            )
            fornecedor = cursor.fetchone()

            if fornecedor is None:
                raise ValueError(
                    f"Fornecedor {codigo_origem!r} não encontrado "
                    f"na linha {numero_linha} da aba {tabela}."
                )

            dados["idfornecedor"] = fornecedor[0]

        elif tabela == "pedido_compra":
            dados["qtde_pendente"] = (
                dados["qtde_pedida"] - dados["qtde_entregue"]
            )

            # Guarda os valores preenchidos em colunas sem cabeçalho.
            if any(valor is not None for valor in extras):
                inserir(cursor, "pedido_colunas_extras", {
                    "linha_excel": numero_linha,
                    "pedido_id": dados["pedido_id"],
                    "valores": json.dumps(extras, default=str, ensure_ascii=False),
                })

        inserir(cursor, tabela, dados)


def importar():
    planilha = openpyxl.load_workbook(ARQUIVO, read_only=True, data_only=True)
    try:
        # Usa PGHOST, PGPORT, PGDATABASE e PGUSER configurados no computador.
        conexao = psycopg2.connect("")
        try:
            # As cinco abas são gravadas juntas. Uma falha desfaz a tentativa.
            with conexao, conexao.cursor() as cursor:
                contagens = {}
                for tabela in TABELAS:
                    importar_aba(cursor, planilha, tabela)
                    cursor.execute(
                        sql.SQL("SELECT COUNT(*) FROM {}").format(
                            sql.Identifier(tabela)
                        )
                    )
                    contagens[tabela] = cursor.fetchone()[0]
        finally:
            conexao.close()
    finally:
        planilha.close()

    print("Importação concluída. Linhas conferidas no banco:")
    for tabela, quantidade in contagens.items():
        print(f"{tabela}: {quantidade}")


if __name__ == "__main__":
    importar()
