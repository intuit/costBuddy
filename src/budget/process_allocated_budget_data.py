#!/bin/env python
# -*- coding: utf-8 -*-


from lib.budget import AccountBudget


def lambda_handler(event, context):
    """
    This lambda is triggered by cloud watch event scheduler everyday once to process allocated budget file.
    """
    budget = AccountBudget()
    budget.process_monthly_budget()
