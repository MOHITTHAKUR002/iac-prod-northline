#!/usr/bin/env bash
# Restore RDS from latest automated snapshot (RTO drill). Usage: ./scripts/restore-rds.sh <src-id> [dst-id]
set -euo pipefail
SRC="${1:?src id}"; DST="${2:-${SRC}-restore-$(date +%Y%m%d%H%M)}"; R="${AWS_REGION:-us-east-1}"
SNAP=$(aws rds describe-db-snapshots --region "$R" --db-instance-identifier "$SRC" --snapshot-type automated \
  --query 'sort_by(DBSnapshots,&SnapshotCreateTime)[-1].DBSnapshotIdentifier' --output text)
[[ -n "$SNAP" && "$SNAP" != None ]] || { echo "no snapshot for $SRC" >&2; exit 1; }
SG=$(aws rds describe-db-instances --region "$R" --db-instance-identifier "$SRC" --query 'DBInstances[0].VpcSecurityGroups[0].VpcSecurityGroupId' --output text)
SUB=$(aws rds describe-db-instances --region "$R" --db-instance-identifier "$SRC" --query 'DBInstances[0].DBSubnetGroup.DBSubnetGroupName' --output text)
aws rds restore-db-instance-from-db-snapshot --region "$R" --db-instance-identifier "$DST" \
  --db-snapshot-identifier "$SNAP" --db-subnet-group-name "$SUB" --vpc-security-group-ids "$SG" \
  --publicly-accessible false --no-multi-az
echo "Rewire DB_HOST to $DST endpoint, force ECS deploy. Wall-clock often exceeds 20-40m RUNBOOK estimate."
