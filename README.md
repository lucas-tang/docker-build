# Instructions

1. Clone this as _build_ sumodule in your repository
   - `git submodule add https://github.com/angelnu/docker-build.git build `
2. `ln -s build/build.sh .`
3. `cp -av build/travis.yml .travis.yml`
4. `cp -av build/build.config .`
5. edit build.config
