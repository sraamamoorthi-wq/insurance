#!/bin/bash
# ============================================================================
# IDP Insurance Platform — One-Click Deploy
# ============================================================================
# Usage: bash deploy.sh [--skip-dcm] [--skip-seed] [--skip-bootstrap]
#
# Prerequisites:
#   - Snowflake CLI (snow) v3.16+ installed and configured
#   - ACCOUNTADMIN role access
#   - Compute pool and warehouse available
#
# Deployment order:
#   1. pre_deploy.sql    — Notification integration, cross-DB grants
#   2. DCM deploy        — Tables, views, procedures, streams, tasks, DMFs
#   3. seed_data.sql     — All reference + sample data
#   4. post_deploy.sql   — Cortex Search, embeddings, DMF schedules, pipeline bootstrap
# ============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

DCM_PROJECT="INSURANCE_DB.RAW.INSURANCE_DCM_PROJECT"
ROLE="ACCOUNTADMIN"
SKIP_DCM=false
SKIP_SEED=false
SKIP_BOOTSTRAP=false

for arg in "$@"; do
    case $arg in
        --skip-dcm) SKIP_DCM=true ;;
        --skip-seed) SKIP_SEED=true ;;
        --skip-bootstrap) SKIP_BOOTSTRAP=true ;;
    esac
done

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║       IDP Insurance Platform — Deployment Script          ║"
echo "║       Team: IDP @ Data | Lead: Raamamoorthi Sundar       ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# ── Step 0: Verify prerequisites ────────────────────────────────────
echo -e "${YELLOW}[0/5]${NC} Checking prerequisites..."
if ! command -v snow &> /dev/null; then
    echo -e "${RED}ERROR: Snowflake CLI (snow) not found. Install: pip install snowflake-cli${NC}"
    exit 1
fi
echo -e "${GREEN}  ✓ Snowflake CLI found: $(snow --version 2>&1 | head -1)${NC}"

# ── Step 1: Pre-deploy ──────────────────────────────────────────────
echo -e "\n${YELLOW}[1/5]${NC} Running pre_deploy.sql (notification integration, grants)..."
snow sql -f insurance-dcm/pre_deploy.sql --role $ROLE 2>&1
echo -e "${GREEN}  ✓ Pre-deploy complete${NC}"

# ── Step 2: DCM Deploy ──────────────────────────────────────────────
if [ "$SKIP_DCM" = false ]; then
    echo -e "\n${YELLOW}[2/5]${NC} Running DCM deployment..."

    echo "  → Analyzing definitions..."
    snow dcm raw-analyze $DCM_PROJECT 2>&1

    echo "  → Planning changes..."
    snow dcm plan $DCM_PROJECT --save-output 2>&1

    echo "  → Deploying..."
    snow dcm deploy $DCM_PROJECT --alias "one-click-deploy-$(date +%Y%m%d-%H%M%S)" 2>&1

    echo -e "${GREEN}  ✓ DCM deploy complete${NC}"
else
    echo -e "\n${YELLOW}[2/5]${NC} Skipping DCM deploy (--skip-dcm)"
fi

# ── Step 3: Seed Data ───────────────────────────────────────────────
if [ "$SKIP_SEED" = false ]; then
    echo -e "\n${YELLOW}[3/5]${NC} Loading seed data (customers, policies, claims, reference tables)..."
    snow sql -f insurance-dcm/seed_data.sql --role $ROLE 2>&1
    echo -e "${GREEN}  ✓ Seed data loaded${NC}"
else
    echo -e "\n${YELLOW}[3/5]${NC} Skipping seed data (--skip-seed)"
fi

# ── Step 4: Post-deploy bootstrap ──────────────────────────────────
if [ "$SKIP_BOOTSTRAP" = false ]; then
    echo -e "\n${YELLOW}[4/5]${NC} Running post_deploy.sql (Cortex Search, embeddings, pipeline bootstrap)..."
    echo "  → This step takes 3-5 minutes (processes 10 claims through 5-agent AI pipeline)..."
    snow sql -f insurance-dcm/post_deploy.sql --role $ROLE 2>&1
    echo -e "${GREEN}  ✓ Post-deploy bootstrap complete${NC}"
else
    echo -e "\n${YELLOW}[4/5]${NC} Skipping bootstrap (--skip-bootstrap)"
fi

# ── Step 5: Verification ───────────────────────────────────────────
echo -e "\n${YELLOW}[5/5]${NC} Verifying deployment..."
snow sql -q "
SELECT
    (SELECT COUNT(*) FROM INSURANCE_DB.RAW.CUSTOMERS) AS customers,
    (SELECT COUNT(*) FROM INSURANCE_DB.RAW.POLICIES) AS policies,
    (SELECT COUNT(*) FROM INSURANCE_DB.RAW.CLAIMS_LANDING) AS claims,
    (SELECT COUNT(*) FROM INSURANCE_DB.PROCESSED.FCT_CUSTOMER_360) AS c360,
    (SELECT COUNT(*) FROM INSURANCE_DB.RESULTS.RESOLUTIONS) AS resolutions,
    (SELECT COUNT(*) FROM INSURANCE_DB.VECTORS.FRAUD_PATTERN_EMBEDDINGS) AS embeddings,
    (SELECT COUNT(*) FROM INSURANCE_DB.PROCESSED.CHURN_ALERTS) AS churn_alerts
" --role $ROLE 2>&1

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                 DEPLOYMENT COMPLETE                       ║"
echo "║                                                           ║"
echo "║  Next steps:                                              ║"
echo "║  1. Open IDP Landing Page in Snowsight                   ║"
echo "║  2. Run the Integration Test Suite (13 tests)             ║"
echo "║  3. Resume tasks for event-driven automation:             ║"
echo "║     ALTER TASK ...TASK_CLAIMS_ORCHESTRATOR RESUME;        ║"
echo "║                                                           ║"
echo "╚════════════════════════════════════════════════════════════╝"
