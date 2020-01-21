# Contribution Guidelines

First of all, thanks for your interest in this project!

Depending on what changes you'd like to see, there may be different steps
for you to take, but in general:

#### Talk to us!

If you're thinking of adding a feature or fixing a bug, make
sure you know that nobody's already working on it. Check if there's an open
issue, and if there isn't, feel free to make one! If we know what you're
trying to accomplish, chances are we can help you out or point you in the
right direction.

#### Read through what's already here

Consistency helps us understand each other better. If you write code in a
similar style to ours, we'll be able to review and approve it faster. If
you write documentation with the same voice, readers will be able to
transition smoothly between topics.

## Code changes

#### Contributing to source code

The first step in changing the code is running the code! In order to build
and run the code, you should have the following tools installed:

* Python3
* Git

###### Install requirements

* Clone the costBuddy repo.

    `git clone https://github.com/intuit/costBuddy.git`
* Install the python dependent libraries 

    `python3 setup.py install`
* Source codes are residing under `costBuddy/src` directory.
* Run `pytest` under project root directory to execute the test cases.

#### Development workflow

This project is written in Python and deployment module in Terraform.
we recommend using PyCharm with git and terraform plugin.



### Pull requests for Code

#### Branching and Rebasing

Pull requests for code changes should be branched from `master`, and should
be rebased against the latest `master` code. After merging a branch, the
history should be clean and shallow, as shown below:

```
*   e36331b - Merge branch 'issue1234' - (HEAD -> master)
|\
| * 047d6fd - #1234: Adds documentation - (issue1234)
| * 8bb93f7 - #1234: Adds regression tests
| * c61db8b - #1234: Fixes bug in parser
|/
* 89fd7b3 - Initial commit (master-before-merge)
```

> You can print a commit graph similar to this one using the command
> `git log --oneline --graph --all`

If your branch falls behind, you can bring it up-to-date by checking out your
branch and using `git rebase master`. Below you can see the difference between
a branch that's "fallen behind" versus one that's up-to-date:

```
* b47014b - #9876: Adds tests to api - (HEAD -> issue9876)
* bbc4d83 - #9876: Adds feature to api
*   e36331b - Merge branch 'issue1234' - (master)
|\
| * 047d6fd - #1234: Adds documentation - (issue1234)
| * 8bb93f7 - #1234: Adds regression tests
| * c61db8b - #1234: Fixes bug in parser
|/
| * 0a1f493 - #9876: Adds tests to api - (issue9876-fell-behind)
| * 3dcf143 - #9876: Adds feature to api
|/
* 89fd7b3 - Initial commit - (master-before-merge)
```

#### Don't commit secrets!

Make sure that you haven't accidentally committed any usernames, passwords,
or other sensitive information in the codebase. Secrets should always be
provided to the program through environment variables or configuration files
(_ones that don't get committed!_). See some of our [configuration docs] to
see how to handle these properly.

#### Squashing

If you've made a ton of commits in your branch, we may ask you to squash your
branch before we merge it (we could also do it for you :)). Squashing takes
all of the changes from all of your commits and "squashes" them into a single
new commit. This helps us maintain a clean and readable version history.

