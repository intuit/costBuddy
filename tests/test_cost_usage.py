import json
import pytest

@pytest.fixture()
def cost_usage_data():
    """ Generates cost usage data"""

    return {
        "ResultsByTime": [
        {
            "Estimated": True,
            "TimePeriod": {
                "Start": "2019-11-06",
                "End": "2019-11-07"
            },
            "Total": {
                "BlendedCost": {
                    "Amount": "2.523114075",
                    "Unit": "USD"
                },
                "UnblendedCost": {
                    "Amount": "2.5219729944",
                    "Unit": "USD"
                },
                "UsageQuantity": {
                    "Amount": "470666.3868981499",
                    "Unit": "N/A"
                }
            },
            "Groups": []
        }
    ]
}


def lambda_handler(event, context):
    return event


def test_lambda_handler(cost_usage_data):
    ret = lambda_handler(cost_usage_data, "")
    assert 'Total' in ret["ResultsByTime"][0]

    data = ret["ResultsByTime"][0]
    assert 'Amount' in data["Total"]['BlendedCost']

    data = ret["ResultsByTime"][0]
    assert 'Amount' in data["Total"]['UnblendedCost']

    data = ret["ResultsByTime"][0]
    assert 'Amount' in data["Total"]['UsageQuantity']