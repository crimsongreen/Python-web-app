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