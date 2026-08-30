"""
Build Snowflake Notebooks (.ipynb) from the hackathon SQL files.

Strategy:
- Each SQL file is split into cells on the "-- ===..." banner comments.
- The banner comment line(s) become a Markdown cell (heading + description).
- The SQL body that follows becomes a SQL cell.
- Multiple SQL files can be consolidated into one notebook.

Snowflake Notebooks support cells with:
  - "language": "sql" | "python" | "markdown" via cell metadata.
Snowsight import reads standard Jupyter .ipynb; each code cell gets
metadata {"language": "sql"} so Snowsight treats it as a SQL cell.

Run: python build_notebooks.py
"""

import json
import os
import re

BASE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.dirname(BASE)  # snowflake_hackathon folder
OUT = BASE                    # notebooks folder

BANNER_RE = re.compile(r'^--\s*=+\s*$')


def split_sql_into_blocks(sql_text):
    """
    Split a SQL file into (title, comment_lines, sql_body) blocks
    using the '-- ===' banner comments as delimiters.
    """
    lines = sql_text.splitlines()
    blocks = []
    i = 0
    n = len(lines)

    # Skip to first banner
    current_comments = []
    current_sql = []
    title = None

    def flush():
        nonlocal current_comments, current_sql, title
        if title or current_sql or current_comments:
            body = "\n".join(current_sql).strip()
            comment_text = "\n".join(current_comments).strip()
            if title or comment_text or body:
                blocks.append((title, comment_text, body))
        current_comments = []
        current_sql = []
        title = None

    while i < n:
        line = lines[i]
        if BANNER_RE.match(line):
            # A banner starts a new block - flush previous
            flush()
            # Collect the comment lines between this banner and the next banner
            i += 1
            comment_lines = []
            # First comment line after banner is the title
            while i < n and lines[i].strip().startswith('--') and not BANNER_RE.match(lines[i]):
                comment_lines.append(lines[i].strip().lstrip('-').strip())
                i += 1
            # Skip trailing banner line if present
            if i < n and BANNER_RE.match(lines[i]):
                i += 1
            title = comment_lines[0] if comment_lines else None
            current_comments = comment_lines[1:] if len(comment_lines) > 1 else []
        else:
            current_sql.append(line)
            i += 1
    flush()
    return blocks


def md_cell(text):
    return {
        "cell_type": "markdown",
        "id": None,
        "metadata": {},
        "source": _as_lines(text),
    }


def sql_cell(text, name):
    return {
        "cell_type": "code",
        "id": None,
        "execution_count": None,
        "metadata": {
            "language": "sql",
            "name": name,
        },
        "outputs": [],
        "source": _as_lines(text),
    }


def _as_lines(text):
    """Convert text to list-of-lines with trailing newlines (nbformat style)."""
    lines = text.split("\n")
    return [l + "\n" for l in lines[:-1]] + [lines[-1]] if lines else [""]


def build_notebook(title, intro_md, sql_files, out_name):
    """Build one notebook from a list of source SQL files."""
    cells = []
    # Title cell
    cells.append(md_cell("# " + title + "\n\n" + intro_md))

    cell_counter = 0
    for sql_path in sql_files:
        full = os.path.join(SRC, sql_path)
        if not os.path.exists(full):
            print("  WARNING missing:", sql_path)
            continue
        with open(full, "r", encoding="utf-8") as f:
            sql_text = f.read()

        blocks = split_sql_into_blocks(sql_text)
        for (btitle, comment, body) in blocks:
            # Markdown cell for the section header
            md_parts = []
            if btitle:
                md_parts.append("## " + btitle)
            if comment:
                md_parts.append(comment)
            if md_parts:
                cells.append(md_cell("\n\n".join(md_parts)))
            # Determine if the body is only comments/blank (no executable SQL)
            body_stripped = body.strip()
            code_lines = [ln for ln in body_stripped.split("\n")
                          if ln.strip() and not ln.strip().startswith("--")]
            if not body_stripped:
                continue
            if not code_lines:
                # Body is pure comments -> fold into a markdown note instead of a SQL cell
                note = "\n".join(ln.strip().lstrip("-").strip()
                                 for ln in body_stripped.split("\n") if ln.strip())
                if note:
                    cells.append(md_cell("> " + note.replace("\n", "  \n> ")))
                continue
            # Real SQL cell
            cell_counter += 1
            cells.append(sql_cell(body, "cell_" + str(cell_counter)))

    # Assign IDs
    for idx, c in enumerate(cells):
        c["id"] = out_name.replace(".ipynb", "") + "_" + str(idx)

    notebook = {
        "cells": cells,
        "metadata": {
            "kernelspec": {
                "display_name": "Streamlit Notebook",
                "name": "streamlit"
            },
            "language_info": {
                "name": "python",
                "version": "3.11"
            }
        },
        "nbformat": 4,
        "nbformat_minor": 5,
    }

    out_path = os.path.join(OUT, out_name)
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(notebook, f, indent=1)
    print("Created:", out_name, "(" + str(len([c for c in cells if c['cell_type']=='code'])) + " SQL cells)")


# ============================================================
# NOTEBOOK DEFINITIONS (consolidated grouping)
# ============================================================

NOTEBOOKS = [
    {
        "title": "NB 01 - Setup: Database, Schemas, Tables & Sample Data",
        "intro": ("Sets up the full foundation: database, schemas, warehouses, roles, "
                  "all RAW/PROCESSED/RESULTS/VECTORS tables, and loads the Manapakkam "
                  "fire sample data.\n\n**Run all cells top to bottom.**"),
        "files": ["01_setup_database.sql", "02_raw_tables.sql"],
        "out": "NB_01_Setup.ipynb",
    },
    {
        "title": "NB 02 - Cortex Search Services & Embeddings",
        "intro": ("Creates 5 Cortex Search services for RAG and the fraud pattern "
                  "embedding infrastructure (EMBED_TEXT_768 + VECTOR_COSINE_SIMILARITY)."),
        "files": ["03_cortex_search_services.sql"],
        "out": "NB_02_Cortex_Search.ipynb",
    },
    {
        "title": "NB 03 - Agents & Orchestrator",
        "intro": ("The 5-agent claims pipeline (Intake, Validation, Fraud, Assessment, "
                  "Resolution) + orchestrator. Uses Cortex COMPLETE, SENTIMENT, EMBED, "
                  "SEARCH, and Guardrails."),
        "files": ["05_agents_orchestrator.sql"],
        "out": "NB_03_Agents.ipynb",
    },
    {
        "title": "NB 04 - Customer 360 Build",
        "intro": ("Materializes FCT_CUSTOMER_360 by aggregating structured features and "
                  "Cortex-extracted unstructured signals (sentiment, frustration, intent)."),
        "files": ["11_customer_360_build.sql"],
        "out": "NB_04_Customer360.ipynb",
    },
    {
        "title": "NB 05 - Churn Control & Next Best Action",
        "intro": ("Daily churn scan, LLM root cause analysis, and RAG-driven retention "
                  "NBA generation."),
        "files": ["12_churn_pipeline.sql"],
        "out": "NB_05_Churn.ipynb",
    },
    {
        "title": "NB 06 - Streams & Tasks (Automation)",
        "intro": ("Event-driven Streams + scheduled Task DAG for real-time claims "
                  "processing and daily analytics."),
        "files": ["13_streams_and_tasks.sql"],
        "out": "NB_06_Streams_Tasks.ipynb",
    },
    {
        "title": "NB 07 - Document Ingestion (PDF -> Text -> Vector)",
        "intro": ("Internal stages, LOB-specific tables from the Features spec, and the "
                  "PARSE_DOCUMENT -> EMBED_TEXT_768 pipeline + document search service."),
        "files": ["15_document_ingestion.sql"],
        "out": "NB_07_Documents.ipynb",
    },
]


if __name__ == "__main__":
    print("Building Snowflake Notebooks...\n")
    for nb in NOTEBOOKS:
        build_notebook(nb["title"], nb["intro"], nb["files"], nb["out"])
    print("\nDone. Import each .ipynb into Snowsight: Projects > Notebooks > Import .ipynb")
