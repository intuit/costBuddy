#!/bin/env python
# -*- coding: utf-8 -*-

from lib.ce_cost_usage import CostExplorerUsage
from lib.ce_projected_spend import CostExplorerProjected


def lambda_handler(event, context):
    """
    This lambda is triggered by cloud watch event scheduler everyday once to fetch cost usage and projected spend cost
    using AWS cost explore API.
    """
    account_id = event.get('account_id')
    usage_cost = CostExplorerUsage(account_id)
    usage_cost.daily_service_usage()
    usage_cost.account_month_to_date_spend()
    usage_cost.service_month_to_date_spend()

    projected_spend = CostExplorerProjected(account_id)
    projected_spend.account_monthly_projected_spend()
    projected_spend.service_monthly_projected_spend()