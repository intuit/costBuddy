import os
import subprocess
import sys

import boto3


def aws_account_id():
    """
    Using boto sts call, identifies the account id of the AWS profile loaded
    for this session
    :return: string, AWS account ID
    """
    try:
        client = boto3.client("sts")
        account_id = client.get_caller_identity()["Account"]
    except:
        print("Error occurred while running AWS  query. Please check the credentials")
        return None
    return account_id


def remove_chars(workspace):
    """
    Removes extra characters in the string
    :param workspace: string
    :return: string, after replacing the additional characters
    """
    return workspace.translate(str.maketrans({' ': '', '*': ''}))


def list_workspaces():
    """
    List the available workspaces.
    :return: LIST of available workspaces
    """
    try:
        output = subprocess.check_output(['terraform', 'workspace', 'list'])
    except subprocess.CalledProcessError:
        print("Error while listing terraform workspace")
        return [None]
    output_list = output.decode("utf-8").split('\n')
    return [remove_chars(w) for w in output_list if w]


def select_workspace(account_id):
    """
    Selects a particular workspace
    :param account_id: integer, AWS account ID
    :return: 0 if successful -1 if failed
    """
    try:
        output = subprocess.check_output(['terraform', 'workspace', 'select', account_id])
    except subprocess.CalledProcessError:
        print("Error while switching terraform workspace")
        return -1
    return 0


def create_workspace(account_id):
    """
    Create a new workspace
    :param account_id:  integer, AWS account ID
    :return: 0 if successful -1 if failed
    """
    try:
        output = subprocess.check_output(['terraform', 'workspace', 'new', account_id])
    except subprocess.CalledProcessError:
        print("Error while creating terraform workspace")
        return -1
    return 0


def run_terraform(arguments):
    sub_command = " ".join(arguments)
    try:
        os.system('terraform' + ' ' + sub_command)
    except:
        print("Error while running: terraform {}".format(sub_command))
        return -1
    return 0


if __name__ == '__main__':

    # Command line arguments from the user
    arguments = sys.argv

    current_account_id = aws_account_id()
    current_workspaces = list_workspaces()

    if current_account_id is None or current_workspaces is None:
        print("Unable to run terraform")
        sys.exit(-1)

    # Check if the workspace already exists
    if current_account_id in current_workspaces:
        select_workspace(current_account_id)
    else:
        create_workspace(current_account_id)

    # Execute terraform command
    output = run_terraform(arguments[1:])
    sys.exit(0)
