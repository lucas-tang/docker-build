# Instructions

**NOTE**: Archiving this since I moved to GitHub Actions and the [k8s community](https://github.com/k8s-at-home). I will not delete it since it was used by others
but please notice that I am also dissabling the weekly builds since the trigger docker pull limit errors and I do not want the spam nor have the
interest to upgrade the CI to use the Github container registry. IF there is interest of others please contact me in the k8s-at-home Discord.

## common

1. Clone this as _build_ sumodule in your repository
   - `git submodule add https://github.com/angelnu/docker-build.git build `
2. `ln -s build/build.sh .`
3. `cp -av build/build.config .`
4. edit build.config

## travis

1. `cp -av build/travis.yml .travis.yml`

## drone

1. `cp -av build/drone.yml .drone.yml`
