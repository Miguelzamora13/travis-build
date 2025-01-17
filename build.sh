language: ruby
dist: bionic
rvm: 2.5.9

services:
  - redis

cache:
  bundler: true

env:
  global:
    - COVERAGE=1
    - PATH=/snap/bin:$PATH
  matrix:
    - INTEGRATION_SPECS=0
    - INTEGRATION_SPECS=1

addons:
  snaps:
    - name: docker
      channel: latest/beta

stages:
  - test
  - ':ship: it to quay.io'

jobs:
  allow_failures:
    - script: ./script/docker-build-and-push
  include:
    - stage: test
      env:
      script: ./script/validate-example-payloads-with-docker

    - stage: ':ship: it to quay.io'
      env:
      script: ./script/docker-build-and-push
      if: (branch = master and type = push ) OR commit_message =~ /ship:docker/ OR env(SHIP_DOCKER) = true

before_install:
  - gem update --system 3.3.26 > /dev/null 2>&1

before_script:
  - eval "$(script/handle-docker-config)"
  - bundle install
  - bundle exec rake clean assets:precompile

script:
  - bundle exec rspec spec
  - bundle exec rake shfmt
  - bundle exec rake assert_clean
  - bundle exec rake shellcheck
  - bundle exec rake assert_examples

after_success: bundle exec codeclimate-test-reporter

after_failure: bundle exec rake dump_examples_logs

before_deploy:
  - sudo pip install -U -I Pygments
  - ./script/build-s3-index-html

deploy:
  provider: s3
  access_key_id:
    secure: fXt5NG5UGDvpnRFvUUk9J//iSo+Vh28oEUJvjZqiUZ9GRHp5TrIS5vL4bPlD/1RrJRp7BVVj1+4ThXZRzrMhF5xazK8k4ANaUhMdjmRa6arXtqBcXIyUvu//5e80nlXekqMKaW7f5wrLNiKZB+ck7ayGlI1NYLNQ5nCWC6Xxe6s=
  secret_access_key:
    secure: Jn9clQh78C2c1zoueTkn0r5kSCHrbb7bMojb8/Ne+6zg0pD/3w25mrhEC4y9b3M/lHoKArOPj4dn03ZErJleM8aOMNMIa6ck8GKP+7EoFlZ/1/C5733HazlldTWDd2+wTOYfSIGOM+mHDP5tmK0S7pr1zEm+/++UExuGZXiCSSI=
  bucket: travis-build-examples
  local_dir: examples
  skip_cleanup: true
  region: us-east-1
  on:
    branch: master
    condition: $INTEGRATION_SPECS == 1
    repo: travis-ci/travis-build
  edge: true
git:
  submodules: false
