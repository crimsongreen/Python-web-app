Software versions explained:

v1 is the first release and each software iteration goes up
by 1 (v2, v3, etc). main branch runs the latest stable code.

Build Image:

Checkout a particular branch

`git branch`

`git checkout v1`

The app version is equal to the branch name. 

`bin/build-image.sh v1`   

You can then proceed to start the service with that image

`bin/start-container.sh v1`

Alternatively you can run the latest code by following:

`git checkout main`

`bin/build-image.sh latest`

`bin/start-container.sh latest`

Deployment to AWS:

`bin/deploy.sh latest`

If this is your first time running this from your laptop
please make sure you have initialised the terraform aws provider
using `terraform init` you also must have aws cli installed and configured.

Contribution:
1. Fork this repo and clone to your desktop.
2. Add this repo as upstream
`git remote add upstream https://github.com/crimsongreen/Python-web-app`
3. Make sure your repo is up to date
`git fetch upstream`
4. checkout a new branch using issue tracker id as branch name
`git checkout -b <new-branch>`
5. When you're ready to commit
open a pull request against upstream `staging` branch
